-- Настройки онлайн-записи — в админку, а не в код (разбор виджета 12.10,
-- пункты 10 и 17), плюс то, что бронь должна нести с собой:
--
--  * booking_clubs.lead_minutes  — за сколько минут до начала закрывается запись;
--  * booking_clubs.horizon_days  — на сколько дней вперёд открыта запись;
--  * booking_clubs.durations     — какие длительности сеанса предлагать (минуты);
--  * booking_clubs.privacy_url   — ссылка на политику конфиденциальности под формой;
--  * booking_orders.utm          — UTM-метки рекламы, с которой пришёл клиент;
--  * комментарий клиента обрезается до 500 символов;
--  * booking_order_amounts / booking_order_receipt — итог брони считает база,
--    виджет показывает его на экране «Бронь подтверждена» (пункт 16).
--
-- Персонала настройки не касаются: сотрудник по-прежнему записывает в любой
-- момент и на любую длительность до 12 часов (кратную часу).

-- 1. Колонки и проверки ------------------------------------------------------

alter table public.booking_clubs
  add column if not exists lead_minutes int not null default 30,
  add column if not exists horizon_days int not null default 30,
  add column if not exists durations    int[] not null default '{60,120,180,240,300}',
  add column if not exists privacy_url  text;

alter table public.booking_clubs
  add constraint booking_clubs_lead_minutes_check
    check (lead_minutes between 0 and 240),
  add constraint booking_clubs_horizon_days_check
    check (horizon_days between 1 and 180),
  add constraint booking_clubs_durations_check
    check (cardinality(durations) between 1 and 8
           and durations <@ array[60,120,180,240,300,360,420,480]),
  add constraint booking_clubs_privacy_url_check
    check (privacy_url is null
           or (privacy_url ~ '^https?://[^\s]+$' and length(privacy_url) <= 300));

alter table public.booking_orders
  add column if not exists utm jsonb;

alter table public.booking_orders
  add constraint booking_orders_utm_check
    check (utm is null
           or (jsonb_typeof(utm) = 'object' and length(utm::text) <= 1000));

-- 2. Приём брони -------------------------------------------------------------
-- Подпись меняется (новый p_utm), поэтому старую версию удаляем: иначе
-- PostgREST увидит две перегрузки и не сможет выбрать.

drop function if exists public.booking_create_order(
  uuid, text, text, jsonb, integer, text, text, text, uuid);

create function public.booking_create_order(
  p_club_id       uuid,
  p_client_name   text,
  p_client_phone  text,
  p_segments      jsonb,
  p_people_count  integer default null,
  p_discount_code text    default null,
  p_comment       text    default null,
  p_source        text    default 'site',
  p_package_id    uuid    default null,
  p_utm           jsonb   default null
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
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
  v_total       int;
  v_all_ids     uuid[] := '{}';
  v_count       int;
  v_vr          int;
  v_ps          int;
  v_local_start timestamp;
  v_local_end   timestamp;
  v_seg_count   int;
  v_seg_vr      int;
  v_seg_ps      int;
  v_phone       text;
  v_staff       boolean;
  v_source      text;
  v_utm         jsonb;
begin
  if p_segments is null or jsonb_typeof(p_segments) <> 'array'
     or jsonb_array_length(p_segments) = 0 then
    raise exception 'NO_STATIONS' using errcode = 'P0001';
  end if;

  -- Отрезок — часы с одинаковым составом; больше 12 не бывает даже у персонала.
  v_seg_count := jsonb_array_length(p_segments);
  if v_seg_count > 12 then
    raise exception 'BAD_DURATION' using errcode = 'P0001';
  end if;

  select * into v_club from public.booking_clubs where id = p_club_id and is_active;
  if not found then
    raise exception 'CLUB_NOT_FOUND' using errcode = 'P0002';
  end if;

  v_staff := public.booking_is_staff();
  -- Ключ телефона, а не «все цифры»: иначе лимит обходится вводом 8… вместо +7…
  v_phone := public.booking_phone_key(p_client_phone);

  if not v_club.intake_open and not v_staff then
    raise exception 'INTAKE_CLOSED' using errcode = 'P0001';
  end if;

  v_source := coalesce(nullif(btrim(p_source), ''), 'site');
  if v_source = 'staff' and not v_staff then
    v_source := 'site';
  end if;

  -- Только известные UTM-ключи, каждый не длиннее 100 символов.
  if p_utm is not null and jsonb_typeof(p_utm) = 'object' then
    select jsonb_object_agg(e.key, left(btrim(e.value), 100))
      into v_utm
      from jsonb_each_text(p_utm) as e(key, value)
     where e.key in ('utm_source', 'utm_medium', 'utm_campaign',
                     'utm_content', 'utm_term')
       and btrim(coalesce(e.value, '')) <> '';
  end if;

  if not v_staff then
    if length(v_phone) < 10 then
      raise exception 'BAD_PHONE' using errcode = 'P0001';
    end if;

    if (
      select count(*) from public.booking_orders o
      where public.booking_phone_key(o.client_phone) = v_phone
        and o.created_at > now() - interval '1 hour'
    ) >= 3 then
      raise exception 'RATE_LIMITED' using errcode = 'P0001';
    end if;

    if (
      select count(distinct o.id)
      from public.booking_orders o
      join public.booking_order_items i on i.order_id = o.id
      where public.booking_phone_key(o.client_phone) = v_phone
        and o.status <> 'cancelled'
        and i.starts_at > now()
    ) >= 5 then
      raise exception 'TOO_MANY_ACTIVE' using errcode = 'P0001';
    end if;
  end if;

  insert into public.booking_orders (
    club_id, client_name, client_phone, people_count, comment, source,
    discount_id, package_id, status, utm
  )
  values (
    p_club_id, btrim(p_client_name), btrim(p_client_phone), p_people_count,
    left(nullif(btrim(p_comment), ''), 500), v_source,
    null, p_package_id, 'confirmed', v_utm
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
    if v_seg_minutes < 60 or v_seg_minutes % 60 <> 0 then
      raise exception 'BAD_DURATION' using errcode = 'P0001';
    end if;
    if v_seg_start <= now() then
      raise exception 'STARTS_IN_PAST' using errcode = 'P0001';
    end if;

    v_local_start := v_seg_start at time zone v_club.timezone;
    v_local_end   := v_seg_end   at time zone v_club.timezone;

    if not v_staff then
      -- Запись закрывается за lead_minutes до начала (настройка клуба).
      if v_seg_start < now() + make_interval(mins => v_club.lead_minutes) then
        raise exception 'TOO_LATE_TO_BOOK' using errcode = 'P0001';
      end if;
      -- И открыта не дальше horizon_days вперёд.
      if v_local_start::date
           > (now() at time zone v_club.timezone)::date + v_club.horizon_days then
        raise exception 'TOO_FAR_AHEAD' using errcode = 'P0001';
      end if;
    end if;

    if v_prev_end is not null and v_seg_start < v_prev_end then
      raise exception 'BAD_DURATION' using errcode = 'P0001';
    end if;
    v_prev_end := v_seg_end;

    if v_local_start::time < v_club.open_time
       or v_local_end::time > v_club.close_time
       or v_local_end::date <> v_local_start::date then
      raise exception 'OUTSIDE_WORKING_HOURS' using errcode = 'P0001';
    end if;

    select count(*) into v_count
    from public.booking_stations s
    join public.booking_rooms    r on r.id = s.room_id
    where s.id = any (v_seg_ids) and s.is_active and r.club_id = p_club_id;
    if v_count <> array_length(v_seg_ids, 1) then
      raise exception 'STATION_NOT_IN_CLUB' using errcode = 'P0001';
    end if;

    if exists (
      select 1
      from public.booking_availability a
      join public.booking_rooms    r on r.club_id = a.club_id
                                    and (a.room_id is null or r.id = a.room_id)
      join public.booking_stations s on s.room_id = r.id
      where a.club_id = p_club_id
        and s.id = any (v_seg_ids)
        and (a.day is null or a.day = v_local_start::date)
        and tstzrange(
              (v_local_start::date::timestamp
                 + make_interval(mins => coalesce(a.from_minutes, 0)))
                at time zone v_club.timezone,
              (v_local_start::date::timestamp
                 + make_interval(mins => coalesce(a.to_minutes, 1440)))
                at time zone v_club.timezone,
              '[)'
            ) && tstzrange(v_seg_start, v_seg_end, '[)')
    ) then
      raise exception 'SLOT_CLOSED' using errcode = 'P0001';
    end if;

    v_min_start := least(v_min_start, v_seg_start);
    v_max_end   := greatest(v_max_end, v_seg_end);
    v_all_ids   := v_all_ids || v_seg_ids;

    -- Цена станции зависит от того, сколько станций того же типа в отрезке:
    -- «до 6 шлемов одна цена, дальше другая» (ступени в booking_prices.min_qty).
    select count(*) filter (where s.type = 'vr_headset'),
           count(*) filter (where s.type = 'ps5')
      into v_seg_vr, v_seg_ps
      from public.booking_stations s
     where s.id = any (v_seg_ids);

    insert into public.booking_order_items (order_id, station_id, starts_at, ends_at, price)
    select v_order_id, s.id, v_seg_start, v_seg_end,
           public.booking_station_price(
             s.id, v_seg_start, v_seg_minutes,
             case when s.type = 'ps5' then v_seg_ps else v_seg_vr end)
    from public.booking_stations s
    where s.id = any (v_seg_ids);
  end loop;

  -- Клиенту — только длительности из настройки клуба; персоналу — до 12 часов.
  v_total := round(extract(epoch from (v_max_end - v_min_start)) / 60);
  if v_staff then
    if v_total > 720 then
      raise exception 'BAD_DURATION' using errcode = 'P0001';
    end if;
  elsif not (v_total = any (v_club.durations)) then
    raise exception 'BAD_DURATION' using errcode = 'P0001';
  end if;

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

  v_discount := public.booking_resolve_discount(
    p_discount_code,
    (select count(distinct x) from unnest(v_all_ids) as x)::int
  );
  if v_discount.id is not null then
    update public.booking_orders set discount_id = v_discount.id where id = v_order_id;
  end if;

  return v_order_id;
end;
$function$;

revoke all on function public.booking_create_order(
  uuid, text, text, jsonb, integer, text, text, text, uuid, jsonb) from public;
grant execute on function public.booking_create_order(
  uuid, text, text, jsonb, integer, text, text, text, uuid, jsonb)
  to anon, authenticated, service_role;

-- 3. Перенос брони персоналом: длительность — до 12 часов, кратно часу -------
-- Тело прежнее (20260924123119_online_booking_reschedule), меняются только
-- проверки длительности: в настройке клуба теперь могут быть сеансы длиннее 5 ч.

create or replace function public.booking_reschedule_order(p_order_id uuid, p_segments jsonb)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_order       public.booking_orders;
  v_club        public.booking_clubs;
  v_pack        public.booking_packages;
  v_old_start   timestamptz;
  v_old         jsonb;
  v_new         jsonb;
  v_seg         jsonb;
  v_seg_ids     uuid[];
  v_seg_start   timestamptz;
  v_seg_end     timestamptz;
  v_seg_minutes int;
  v_seg_vr      int;
  v_seg_ps      int;
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
begin
  if not public.booking_is_staff() then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;

  if p_segments is null or jsonb_typeof(p_segments) <> 'array'
     or jsonb_array_length(p_segments) = 0 then
    raise exception 'NO_STATIONS' using errcode = 'P0001';
  end if;
  v_seg_count := jsonb_array_length(p_segments);
  if v_seg_count > 12 then
    raise exception 'BAD_DURATION' using errcode = 'P0001';
  end if;

  select * into v_order from public.booking_orders where id = p_order_id for update;
  if not found then
    raise exception 'ORDER_NOT_FOUND' using errcode = 'P0002';
  end if;
  if v_order.status = 'cancelled' then
    raise exception 'ORDER_CANCELLED' using errcode = 'P0001';
  end if;

  select * into v_club from public.booking_clubs where id = v_order.club_id;

  -- Прежнее расписание — для правила «не раньше прежнего начала» и журнала.
  select min(i.starts_at),
         jsonb_build_object(
           'day',  to_char(min(i.starts_at) at time zone v_club.timezone, 'YYYY-MM-DD'),
           'from', to_char(min(i.starts_at) at time zone v_club.timezone, 'HH24:MI'),
           'to',   to_char(max(i.ends_at)   at time zone v_club.timezone, 'HH24:MI'),
           'vr',   count(distinct i.station_id) filter (where s.type = 'vr_headset'),
           'ps',   count(distinct i.station_id) filter (where s.type = 'ps5'))
    into v_old_start, v_old
  from public.booking_order_items i
  join public.booking_stations s on s.id = i.station_id
  where i.order_id = p_order_id;

  delete from public.booking_order_items where order_id = p_order_id;

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
    if v_seg_minutes < 60 or v_seg_minutes % 60 <> 0 then
      raise exception 'BAD_DURATION' using errcode = 'P0001';
    end if;
    if v_seg_start < least(now(), coalesce(v_old_start, now())) then
      raise exception 'STARTS_IN_PAST' using errcode = 'P0001';
    end if;

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

    select count(*) into v_count
    from public.booking_stations s
    join public.booking_rooms    r on r.id = s.room_id
    where s.id = any (v_seg_ids) and s.is_active and r.club_id = v_order.club_id;
    if v_count <> array_length(v_seg_ids, 1) then
      raise exception 'STATION_NOT_IN_CLUB' using errcode = 'P0001';
    end if;

    if exists (
      select 1
      from public.booking_availability a
      join public.booking_rooms    r on r.club_id = a.club_id
                                    and (a.room_id is null or r.id = a.room_id)
      join public.booking_stations s on s.room_id = r.id
      where a.club_id = v_order.club_id
        and s.id = any (v_seg_ids)
        and (a.day is null or a.day = v_local_start::date)
        and tstzrange(
              (v_local_start::date::timestamp
                 + make_interval(mins => coalesce(a.from_minutes, 0)))
                at time zone v_club.timezone,
              (v_local_start::date::timestamp
                 + make_interval(mins => coalesce(a.to_minutes, 1440)))
                at time zone v_club.timezone,
              '[)'
            ) && tstzrange(v_seg_start, v_seg_end, '[)')
    ) then
      raise exception 'SLOT_CLOSED' using errcode = 'P0001';
    end if;

    v_min_start := least(v_min_start, v_seg_start);
    v_max_end   := greatest(v_max_end, v_seg_end);
    v_all_ids   := v_all_ids || v_seg_ids;

    select count(*) filter (where s.type = 'vr_headset'),
           count(*) filter (where s.type = 'ps5')
      into v_seg_vr, v_seg_ps
      from public.booking_stations s
     where s.id = any (v_seg_ids);

    -- Цена — по ступеням booking_prices.min_qty, как в booking_create_order.
    insert into public.booking_order_items (order_id, station_id, starts_at, ends_at, price)
    select p_order_id, s.id, v_seg_start, v_seg_end,
           public.booking_station_price(
             s.id, v_seg_start, v_seg_minutes,
             case when s.type = 'ps5' then v_seg_ps else v_seg_vr end)
    from public.booking_stations s
    where s.id = any (v_seg_ids);
  end loop;

  if round(extract(epoch from (v_max_end - v_min_start)) / 60) > 720 then
    raise exception 'BAD_DURATION' using errcode = 'P0001';
  end if;

  -- Пакет, который больше не подходит, снимаем: цена дальше — по часам.
  if v_order.package_id is not null then
    select * into v_pack from public.booking_packages where id = v_order.package_id;
    select count(distinct x) filter (where s.type = 'vr_headset'),
           count(distinct x) filter (where s.type = 'ps5')
      into v_vr, v_ps
      from unnest(v_all_ids) as x
      join public.booking_stations s on s.id = x;
    if v_pack.id is null
       or v_seg_count <> 1
       or v_seg_minutes <> v_pack.minutes
       or v_vr <> v_pack.headsets
       or v_ps <> v_pack.consoles
       or (v_pack.room_id is not null and exists (
             select 1 from public.booking_stations s
              where s.id = any (v_all_ids) and s.room_id <> v_pack.room_id)) then
      update public.booking_orders set package_id = null where id = p_order_id;
    end if;
  end if;

  select jsonb_build_object(
           'day',  to_char(v_min_start at time zone v_club.timezone, 'YYYY-MM-DD'),
           'from', to_char(v_min_start at time zone v_club.timezone, 'HH24:MI'),
           'to',   to_char(v_max_end   at time zone v_club.timezone, 'HH24:MI'),
           'vr',   count(distinct x) filter (where s.type = 'vr_headset'),
           'ps',   count(distinct x) filter (where s.type = 'ps5'))
    into v_new
  from unnest(v_all_ids) as x
  join public.booking_stations s on s.id = x;

  insert into public.booking_audit_log (actor_id, entity, entity_id, action, before, after)
  values (
    auth.uid(), 'booking_reschedule', p_order_id, 'update',
    v_old || jsonb_build_object('club_id', v_order.club_id, 'client_name', v_order.client_name),
    v_new || jsonb_build_object('club_id', v_order.club_id, 'client_name', v_order.client_name)
  );

  -- Строка в Google Таблице — новое время. Сбой зеркала перенос не отменяет.
  begin
    perform public.booking_mirror_call(jsonb_build_object('order_id', p_order_id));
  exception when others then
    null;
  end;
end;
$function$;

-- 4. Итог брони считает база ------------------------------------------------
-- Та же формула, что в booking-mirror и админке: база — цена пакета или сумма
-- позиций; промокод: процент с округлением до рубля, фиксированная сумма —
-- не больше базы.

create or replace function public.booking_order_amounts(p_order_id uuid)
returns table (gross numeric, discount numeric, net numeric)
language sql
stable
security definer
set search_path to 'public'
as $function$
  with o as (
    select pk.price as pack_price, d.kind, d.value
      from public.booking_orders o
      left join public.booking_packages  pk on pk.id = o.package_id
      left join public.booking_discounts d  on d.id  = o.discount_id
     where o.id = p_order_id
  ),
  base as (
    select coalesce(
             o.pack_price,
             (select coalesce(sum(i.price), 0)
                from public.booking_order_items i
               where i.order_id = p_order_id)) as b,
           o.kind, o.value
      from o
  )
  select b,
         x.d,
         b - x.d
    from base,
         lateral (select case
                           when b <= 0 or coalesce(value, 0) <= 0 then 0
                           when kind = 'fixed' then least(value, b)
                           else round(b * least(value, 100) / 100)
                         end as d) x;
$function$;

revoke all on function public.booking_order_amounts(uuid) from public, anon, authenticated;
grant execute on function public.booking_order_amounts(uuid) to service_role;

-- Клиенту — только итог своей брони: та же пара (id, телефон), что для отмены.
create or replace function public.booking_order_receipt(p_order_id uuid, p_client_phone text)
returns numeric
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_phone text;
  v_net   numeric;
begin
  select public.booking_phone_key(o.client_phone) into v_phone
    from public.booking_orders o where o.id = p_order_id;
  if v_phone is null or v_phone <> public.booking_phone_key(p_client_phone) then
    raise exception 'ORDER_NOT_FOUND' using errcode = 'P0002';
  end if;
  select a.net into v_net from public.booking_order_amounts(p_order_id) a;
  return v_net;
end;
$function$;

revoke all on function public.booking_order_receipt(uuid, text) from public;
grant execute on function public.booking_order_receipt(uuid, text)
  to anon, authenticated, service_role;
