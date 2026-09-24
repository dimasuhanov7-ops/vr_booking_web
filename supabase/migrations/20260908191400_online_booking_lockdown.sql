-- =============================================================================
-- Ужесточение публичного контура брони (аудит 2026-09-08, docs/AUDIT.md § C1, C2).
--
-- 1. Закрываем прямую запись анонимом в booking_orders / booking_order_items.
--    booking_create_order — SECURITY DEFINER, работает от владельца, и гранты
--    ей не нужны. Пока они были, существовала вторая дверь с более слабой
--    проверкой: через PostgREST можно было поставить price = 0, смешать станции
--    разных клубов, подставить source = 'staff' и дописать позицию в чужую
--    бронь (владельца у заказа нет). Оставляем единственный вход — RPC.
--
-- 2. Ограничиваем частоту броней. Раньше защиты не было вообще: скрипт
--    занимал всё расписание обоих клубов на месяц вперёд. Лимиты не действуют
--    на авторизованного сотрудника (booking_is_staff()).
--
-- 3. Достраиваем валидацию отрезков: их число, порядок, непересечение и общее
--    окно брони. Раньше каждый отрезок проверялся сам по себе, поэтому
--    «бронь» из 50 кусков на весь день проходила.
--
-- ПОРЯДОК ПРИМЕНЕНИЯ. Миграция опирается на booking_is_staff() и на
-- segments-сигнатуру booking_create_order, поэтому применяется ПОСЛЕ:
--   20260907120000_online_booking_durations
--   20260908120000_online_booking_packages
--   20260909120000_online_booking_staff_auth
--   20260910120000_online_booking_hourly_segments
-- Затем — передеплой Edge Function booking-intake.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Единственный вход — RPC
-- -----------------------------------------------------------------------------
revoke insert on public.booking_orders      from anon;
revoke insert on public.booking_order_items from anon;

drop policy if exists booking_orders_anon_insert      on public.booking_orders;
drop policy if exists booking_order_items_anon_insert on public.booking_order_items;

comment on table public.booking_orders is
  'Онлайн-бронь (оплата на месте). Создаётся ТОЛЬКО через booking_create_order(); '
  'прямой insert анониму закрыт — см. 20260911120000.';

-- Лимиты считаются по цифрам телефона, поэтому индекс — функциональный.
create index if not exists booking_orders_phone_digits_created_idx
  on public.booking_orders ((regexp_replace(client_phone, '\D', '', 'g')), created_at desc);

-- -----------------------------------------------------------------------------
-- 2-3. booking_create_order: лимиты + валидация отрезков
-- -----------------------------------------------------------------------------

-- Дропаем все исторические сигнатуры, чтобы не осталось неоднозначной перегрузки.
drop function if exists public.booking_create_order(
  uuid, text, text, uuid[], timestamptz, int, int, text, text, text);
drop function if exists public.booking_create_order(
  uuid, text, text, uuid[], timestamptz, int, int, text, text, text, uuid);
drop function if exists public.booking_create_order(
  uuid, text, text, jsonb, int, text, text, text, uuid);

create function public.booking_create_order(
  p_club_id       uuid,
  p_client_name   text,
  p_client_phone  text,
  p_segments      jsonb,
  p_people_count  int     default null,
  p_discount_code text    default null,
  p_comment       text    default null,
  p_source        text    default 'site',
  p_package_id    uuid    default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_club        public.booking_clubs;
  v_discount    public.booking_discounts;
  v_pack        public.booking_packages;
  v_order_id    uuid;
  v_seg         jsonb;
  v_seg_ids     uuid[];
  v_seg_start   timestamptz;
  v_seg_end     timestamptz;
  v_seg_minutes int;
  v_prev_end    timestamptz;
  v_min_start   timestamptz;
  v_max_end     timestamptz;
  v_all_ids     uuid[] := '{}';
  v_count       int;
  v_vr          int;
  v_ps          int;
  v_local_start timestamp;
  v_local_end   timestamp;
  v_seg_count   int;
  v_phone       text;
  v_staff       boolean;
  v_source      text;
begin
  if p_segments is null or jsonb_typeof(p_segments) <> 'array'
     or jsonb_array_length(p_segments) = 0 then
    raise exception 'NO_STATIONS' using errcode = 'P0001';
  end if;

  v_seg_count := jsonb_array_length(p_segments);
  -- Сеанс максимум 5 часов, состав меняется не чаще раза в час.
  if v_seg_count > 5 then
    raise exception 'BAD_DURATION' using errcode = 'P0001';
  end if;

  select * into v_club from public.booking_clubs where id = p_club_id and is_active;
  if not found then
    raise exception 'CLUB_NOT_FOUND' using errcode = 'P0002';
  end if;

  v_staff := public.booking_is_staff();
  v_phone := regexp_replace(coalesce(p_client_phone, ''), '\D', '', 'g');

  -- Источник 'staff' вправе указать только авторизованный сотрудник:
  -- иначе анонимный клиент искажал бы аналитику по источникам.
  v_source := coalesce(nullif(btrim(p_source), ''), 'site');
  if v_source = 'staff' and not v_staff then
    v_source := 'site';
  end if;

  -- ---- Антиспам (публичный контур) -----------------------------------------
  if not v_staff then
    if length(v_phone) < 10 then
      raise exception 'BAD_PHONE' using errcode = 'P0001';
    end if;

    -- Не больше 3 броней с одного номера за час.
    if (
      select count(*) from public.booking_orders o
      where regexp_replace(o.client_phone, '\D', '', 'g') = v_phone
        and o.created_at > now() - interval '1 hour'
    ) >= 3 then
      raise exception 'RATE_LIMITED' using errcode = 'P0001';
    end if;

    -- Не больше 5 неотменённых броней в будущем на один номер.
    if (
      select count(distinct o.id)
      from public.booking_orders o
      join public.booking_order_items i on i.order_id = o.id
      where regexp_replace(o.client_phone, '\D', '', 'g') = v_phone
        and o.status <> 'cancelled'
        and i.starts_at > now()
    ) >= 5 then
      raise exception 'TOO_MANY_ACTIVE' using errcode = 'P0001';
    end if;
  end if;

  insert into public.booking_orders (
    club_id, client_name, client_phone, people_count, comment, source,
    discount_id, package_id, status
  )
  values (
    p_club_id, btrim(p_client_name), btrim(p_client_phone), p_people_count,
    nullif(btrim(p_comment), ''), v_source,
    null, p_package_id, 'confirmed'
  )
  returning id into v_order_id;

  -- ---- Отрезки --------------------------------------------------------------
  for v_seg in select * from jsonb_array_elements(p_segments)
  loop
    v_seg_ids := array(
      select jsonb_array_elements_text(v_seg -> 'station_ids')::uuid
    );
    v_seg_start := (v_seg ->> 'starts_at')::timestamptz;
    v_seg_end   := (v_seg ->> 'ends_at')::timestamptz;

    if coalesce(array_length(v_seg_ids, 1), 0) = 0 then
      raise exception 'NO_STATIONS' using errcode = 'P0001';
    end if;
    if v_seg_end <= v_seg_start then
      raise exception 'BAD_DURATION' using errcode = 'P0001';
    end if;
    v_seg_minutes := round(extract(epoch from (v_seg_end - v_seg_start)) / 60);
    if v_seg_minutes not in (60, 120, 180, 240, 300) then
      raise exception 'BAD_DURATION' using errcode = 'P0001';
    end if;
    if v_seg_start <= now() then
      raise exception 'STARTS_IN_PAST' using errcode = 'P0001';
    end if;

    -- Отрезки одной брони идут по возрастанию и не пересекаются между собой.
    -- (EXCLUDE-констрейнт ловит только пересечение по конкретной станции.)
    if v_prev_end is not null and v_seg_start < v_prev_end then
      raise exception 'BAD_DURATION' using errcode = 'P0001';
    end if;
    v_prev_end := v_seg_end;

    v_local_start := v_seg_start at time zone v_club.timezone;
    v_local_end   := v_seg_end   at time zone v_club.timezone;
    if v_local_start::time < v_club.open_time
       or v_local_end::time > v_club.close_time
       or v_local_end::date <> v_local_start::date then
      raise exception 'OUTSIDE_WORKING_HOURS' using errcode = 'P0001';
    end if;

    -- Станции отрезка принадлежат клубу и активны.
    select count(*) into v_count
    from public.booking_stations s
    join public.booking_rooms    r on r.id = s.room_id
    where s.id = any (v_seg_ids) and s.is_active and r.club_id = p_club_id;
    if v_count <> array_length(v_seg_ids, 1) then
      raise exception 'STATION_NOT_IN_CLUB' using errcode = 'P0001';
    end if;

    v_min_start := least(v_min_start, v_seg_start);
    v_max_end   := greatest(v_max_end, v_seg_end);
    v_all_ids   := v_all_ids || v_seg_ids;

    insert into public.booking_order_items (order_id, station_id, starts_at, ends_at, price)
    select v_order_id, sid, v_seg_start, v_seg_end,
           public.booking_station_price(sid, v_seg_start, v_seg_minutes)
    from unnest(v_seg_ids) as sid;
  end loop;

  -- Вся бронь укладывается в один сеанс, а не растягивается на день.
  if round(extract(epoch from (v_max_end - v_min_start)) / 60) > 300 then
    raise exception 'BAD_DURATION' using errcode = 'P0001';
  end if;

  -- ---- Пакет: только для однородной брони (ровно один отрезок) --------------
  if p_package_id is not null then
    if v_seg_count <> 1 then
      raise exception 'PACKAGE_MISMATCH' using errcode = 'P0001';
    end if;
    select * into v_pack from public.booking_packages
     where id = p_package_id and is_active and club_id = p_club_id;
    if not found then
      raise exception 'PACKAGE_NOT_FOUND' using errcode = 'P0001';
    end if;
    if v_seg_minutes <> v_pack.minutes then
      raise exception 'PACKAGE_MISMATCH' using errcode = 'P0001';
    end if;
    select
      count(*) filter (where s.type = 'vr_headset'),
      count(*) filter (where s.type = 'ps5')
      into v_vr, v_ps
    from public.booking_stations s where s.id = any (v_all_ids);
    if v_vr <> v_pack.headsets or v_ps <> v_pack.consoles then
      raise exception 'PACKAGE_MISMATCH' using errcode = 'P0001';
    end if;
    if v_pack.room_id is not null and exists (
      select 1 from public.booking_stations s
       where s.id = any (v_all_ids) and s.room_id <> v_pack.room_id
    ) then
      raise exception 'PACKAGE_MISMATCH' using errcode = 'P0001';
    end if;
  end if;

  -- ---- Скидка — по числу уникальных станций брони ---------------------------
  v_discount := public.booking_resolve_discount(
    p_discount_code,
    (select count(distinct x) from unnest(v_all_ids) as x)::int
  );
  if v_discount.id is not null then
    update public.booking_orders set discount_id = v_discount.id where id = v_order_id;
  end if;

  return v_order_id;
end;
$$;

comment on function public.booking_create_order is
  'Единственный способ создать бронь. Принимает отрезки (p_segments): непрерывные '
  'окна с фиксированным составом станций. Публичный контур ограничен по частоте '
  '(3 брони/час и 5 активных на номер); сотрудник (booking_is_staff()) — без лимитов.';

revoke all on function public.booking_create_order(
  uuid, text, text, jsonb, int, text, text, text, uuid) from public;
grant execute on function public.booking_create_order(
  uuid, text, text, jsonb, int, text, text, text, uuid) to anon, authenticated;
