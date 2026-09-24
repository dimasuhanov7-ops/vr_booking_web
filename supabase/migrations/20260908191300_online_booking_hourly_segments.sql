-- Онлайн-бронирование: разное число станций на разные часы одной брони.
--
-- booking_create_order переводится с плоского (p_station_ids + p_starts_at +
-- p_minutes) на «отрезки»: p_segments jsonb =
--   [{ "station_ids": ["uuid", ...], "starts_at": "...", "ends_at": "..." }, ...]
-- Каждый отрезок — непрерывное окно с фиксированным набором станций; клиент
-- склеивает подряд идущие часы с одинаковым составом. Простой случай
-- («один состав на весь сеанс») — это один отрезок.
--
-- НЕ ПРИМЕНЕНО. Порядок: применить эту миграцию, затем передеплоить
-- Edge Function booking-intake.

-- Старую сигнатуру (11 аргументов, из 20260908120000) дропаем.
drop function if exists public.booking_create_order(
  uuid, text, text, uuid[], timestamptz, int, int, text, text, text, uuid);

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
  v_min_start   timestamptz;
  v_all_ids     uuid[] := '{}';
  v_count       int;
  v_vr          int;
  v_ps          int;
  v_local_start timestamp;
  v_local_end   timestamp;
  v_seg_count   int;
begin
  if p_segments is null or jsonb_typeof(p_segments) <> 'array'
     or jsonb_array_length(p_segments) = 0 then
    raise exception 'NO_STATIONS' using errcode = 'P0001';
  end if;
  v_seg_count := jsonb_array_length(p_segments);

  select * into v_club from public.booking_clubs where id = p_club_id and is_active;
  if not found then
    raise exception 'CLUB_NOT_FOUND' using errcode = 'P0002';
  end if;

  insert into public.booking_orders (
    club_id, client_name, client_phone, people_count, comment, source,
    discount_id, package_id, status
  )
  values (
    p_club_id, btrim(p_client_name), btrim(p_client_phone), p_people_count,
    nullif(btrim(p_comment), ''), coalesce(nullif(p_source, ''), 'site'),
    null, p_package_id, 'confirmed'
  )
  returning id into v_order_id;

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
    v_all_ids   := v_all_ids || v_seg_ids;

    insert into public.booking_order_items (order_id, station_id, starts_at, ends_at, price)
    select v_order_id, sid, v_seg_start, v_seg_end,
           public.booking_station_price(sid, v_seg_start, v_seg_minutes)
    from unnest(v_seg_ids) as sid;
  end loop;

  -- Пакет — только для однородной брони (ровно один отрезок).
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

  -- Скидка — по числу уникальных станций брони.
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
  'Создаёт бронь по отрезкам (p_segments): непрерывные окна с фиксированным '
  'составом станций — так одна бронь держит разное число станций в разные часы.';

revoke all on function public.booking_create_order(
  uuid, text, text, jsonb, int, text, text, text, uuid) from public;
grant execute on function public.booking_create_order(
  uuid, text, text, jsonb, int, text, text, text, uuid) to anon, authenticated;
