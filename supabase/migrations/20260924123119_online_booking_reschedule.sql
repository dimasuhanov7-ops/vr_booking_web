-- =============================================================================
-- Перенос брони и смена состава из админки: booking_reschedule_order.
--
-- Сотруднику позиции брони (booking_order_items) по RLS только читаются, поэтому
-- время и станции меняются одной SECURITY DEFINER-функцией: старые позиции
-- удаляются и вставляются новые отрезки в одной транзакции. Пересечение с
-- чужой бронью → 23P01, и всё откатывается — бронь остаётся как была.
--
-- Проверки — как в booking_create_order: число и длина отрезков, общее окно
-- ≤ 5 ч, часы работы клуба, станции клуба, закрытые окна (SLOT_CLOSED), цена по
-- ступеням. Отличие: уже начавшийся сеанс можно продлить или сократить — новое
-- начало не раньше min(сейчас, прежнее начало).
--
-- Если пакет брони перестал совпадать по составу/длительности/залу, пакет
-- снимается (цена дальше считается по часам). В журнал пишется запись
-- entity = 'booking_reschedule'; таблица Google обновляется через booking-mirror.
-- =============================================================================

create or replace function public.booking_reschedule_order(
  p_order_id uuid,
  p_segments jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
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
  if v_seg_count > 5 then
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
    if v_seg_minutes not in (60, 120, 180, 240, 300) then
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

  if round(extract(epoch from (v_max_end - v_min_start)) / 60) > 300 then
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
$fn$;

comment on function public.booking_reschedule_order is
  'Перенос брони / смена состава сотрудником: атомарная замена отрезков с теми же проверками, что при создании.';

revoke all on function public.booking_reschedule_order(uuid, jsonb) from public, anon;
grant execute on function public.booking_reschedule_order(uuid, jsonb) to authenticated;
