-- =============================================================================
-- Длительности сеанса: 60 / 90 / 120 / 180  ->  60 / 120 / 180 / 240 / 300
--
-- У клубов нет сеанса 1,5 ч; добавлены 4 ч и 5 ч. Меняем оба места, где
-- длительность зашита в БД: RPC booking_create_order (BAD_DURATION) и
-- RLS-политику вставки booking_order_items. Старые брони на 90 мин остаются
-- валидными (проверка только на INSERT).
-- =============================================================================

-- ---- 1. RPC: допустимые длительности ----------------------------------------
create or replace function public.booking_create_order(
  p_club_id       uuid,
  p_client_name   text,
  p_client_phone  text,
  p_station_ids   uuid[],
  p_starts_at     timestamptz,
  p_minutes       int,
  p_people_count  int     default null,
  p_discount_code text    default null,
  p_comment       text    default null,
  p_source        text    default 'site'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_club        public.booking_clubs;
  v_discount    public.booking_discounts;
  v_order_id    uuid;
  v_count       int;
  v_ends_at     timestamptz;
  v_local_start timestamp;
  v_local_end   timestamp;
begin
  v_count := coalesce(array_length(p_station_ids, 1), 0);
  if v_count = 0 then
    raise exception 'NO_STATIONS' using errcode = 'P0001';
  end if;
  if p_minutes not in (60, 120, 180, 240, 300) then
    raise exception 'BAD_DURATION' using errcode = 'P0001';
  end if;

  select * into v_club from public.booking_clubs where id = p_club_id and is_active;
  if not found then
    raise exception 'CLUB_NOT_FOUND' using errcode = 'P0002';
  end if;

  if p_starts_at <= now() then
    raise exception 'STARTS_IN_PAST' using errcode = 'P0001';
  end if;

  v_ends_at     := p_starts_at + make_interval(mins => p_minutes);
  v_local_start := p_starts_at at time zone v_club.timezone;
  v_local_end   := v_ends_at   at time zone v_club.timezone;
  if v_local_start::time < v_club.open_time
     or v_local_end::time > v_club.close_time
     or v_local_end::date <> v_local_start::date then
    raise exception 'OUTSIDE_WORKING_HOURS' using errcode = 'P0001';
  end if;

  select count(*) into v_count
  from public.booking_stations s
  join public.booking_rooms    r on r.id = s.room_id
  where s.id = any (p_station_ids)
    and s.is_active
    and r.club_id = p_club_id;

  if v_count <> coalesce(array_length(p_station_ids, 1), 0) then
    raise exception 'STATION_NOT_IN_CLUB' using errcode = 'P0001';
  end if;

  v_discount := public.booking_resolve_discount(
    p_discount_code, array_length(p_station_ids, 1)
  );

  insert into public.booking_orders (
    club_id, client_name, client_phone, people_count, comment, source, discount_id, status
  )
  values (
    p_club_id, btrim(p_client_name), btrim(p_client_phone), p_people_count,
    nullif(btrim(p_comment), ''), coalesce(nullif(p_source, ''), 'site'),
    v_discount.id, 'confirmed'
  )
  returning id into v_order_id;

  insert into public.booking_order_items (order_id, station_id, starts_at, ends_at, price)
  select v_order_id, sid, p_starts_at, v_ends_at,
         public.booking_station_price(sid, p_starts_at, p_minutes)
  from unnest(p_station_ids) as sid;

  return v_order_id;
end;
$$;

comment on function public.booking_create_order is
  'Создаёт групповую бронь на несколько станций (в т.ч. из разных залов) одной транзакцией';
-- create or replace сохраняет существующие GRANT/REVOKE — переустанавливать не нужно.

-- ---- 2. RLS: длительность позиции при анонимной вставке ----------------------
drop policy if exists booking_order_items_anon_insert on public.booking_order_items;
create policy booking_order_items_anon_insert on public.booking_order_items
  for insert to anon
  with check (
    starts_at > now()
    and ends_at > starts_at
    and round(extract(epoch from (ends_at - starts_at)) / 60) in (60, 120, 180, 240, 300)
    and exists (
      select 1
      from public.booking_stations s
      join public.booking_rooms     r on r.id = s.room_id
      join public.booking_clubs     c on c.id = r.club_id
      where s.id = booking_order_items.station_id
        and s.is_active
        and c.is_active
        and (starts_at at time zone c.timezone)::time >= c.open_time
        and (ends_at   at time zone c.timezone)::time <= c.close_time
        and (starts_at at time zone c.timezone)::date = (ends_at at time zone c.timezone)::date
    )
  );
