-- Запись на сеанс закрывается за 30 минут до его начала.
--
-- Клиентам (сайт, ВК, приложение) — TOO_LATE_TO_BOOK, если старт раньше, чем
-- через 30 минут. Персоналу ограничение не мешает: сотрудник записывает гостя
-- у стойки или по телефону на ближайшее время. Прошедшее время запрещено всем,
-- как и раньше (STARTS_IN_PAST).
--
-- Тот же порог в виджете: SlotGeneratorService.bookingLead — слоты, до начала
-- которых меньше 30 минут, клиенту не показываются.

create or replace function public.booking_create_order(
  p_club_id uuid,
  p_client_name text,
  p_client_phone text,
  p_segments jsonb,
  p_people_count integer default null::integer,
  p_discount_code text default null::text,
  p_comment text default null::text,
  p_source text default 'site'::text,
  p_package_id uuid default null::uuid
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
  if v_seg_count > 5 then
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
    discount_id, package_id, status
  )
  values (
    p_club_id, btrim(p_client_name), btrim(p_client_phone), p_people_count,
    nullif(btrim(p_comment), ''), v_source,
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
    -- Запись закрывается за 30 минут до начала (кроме персонала).
    if not v_staff and v_seg_start < now() + interval '30 minutes' then
      raise exception 'TOO_LATE_TO_BOOK' using errcode = 'P0001';
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

    insert into public.booking_order_items (order_id, station_id, starts_at, ends_at, price)
    select v_order_id, sid, v_seg_start, v_seg_end,
           public.booking_station_price(sid, v_seg_start, v_seg_minutes)
    from unnest(v_seg_ids) as sid;
  end loop;

  if round(extract(epoch from (v_max_end - v_min_start)) / 60) > 300 then
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
