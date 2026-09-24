-- Ступени цены: «до N станций одна цена за час, дальше другая».
-- Файл-исходник: supabase/migrations/20260919120000_online_booking_price_tiers.sql
-- Здесь booking_create_order патчится из текущего определения теми же двумя
-- заменами, что и в файле, — чтобы не дублировать 200 строк.

alter table public.booking_prices
  add column if not exists min_qty integer not null default 1;

alter table public.booking_prices
  drop constraint if exists booking_prices_min_qty_check;
alter table public.booking_prices
  add constraint booking_prices_min_qty_check check (min_qty >= 1);

alter table public.booking_prices
  drop constraint if exists booking_prices_club_id_station_type_day_kind_key;
alter table public.booking_prices
  drop constraint if exists booking_prices_club_type_day_qty_key;
alter table public.booking_prices
  add constraint booking_prices_club_type_day_qty_key
  unique (club_id, station_type, day_kind, min_qty);

drop function if exists public.booking_station_price(uuid, timestamptz, int);

create or replace function public.booking_station_price(
  p_station_id uuid,
  p_starts_at  timestamptz,
  p_minutes    integer,
  p_qty        integer default 1
)
returns numeric
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare v_type text; v_club_id uuid; v_tz text; v_rate numeric;
begin
  select s.type, c.id, c.timezone into v_type, v_club_id, v_tz
  from public.booking_stations s
  join public.booking_rooms r on r.id = s.room_id
  join public.booking_clubs c on c.id = r.club_id
  where s.id = p_station_id;
  if not found then raise exception 'STATION_NOT_FOUND' using errcode = 'P0002'; end if;

  -- Подходящая ступень: самая высокая из тех, что не больше количества.
  select p.price_per_hour into v_rate
  from public.booking_prices p
  where p.club_id = v_club_id and p.station_type = v_type
    and p.day_kind = public.booking_day_kind(p_starts_at, v_tz)
    and p.min_qty <= greatest(coalesce(p_qty, 1), 1)
  order by p.min_qty desc
  limit 1;

  return round(coalesce(v_rate, 0) * p_minutes / 60.0);
end;
$function$;

revoke all on function public.booking_station_price(uuid, timestamptz, int, int)
  from public, anon, authenticated;

create or replace function public.booking_quote(
  p_station_ids uuid[],
  p_starts_at   timestamptz,
  p_minutes     integer
)
returns table(station_id uuid, price numeric)
language sql
stable
security definer
set search_path to 'public'
as $function$
  with kit as (
    select s.id, s.type,
           count(*) filter (where s.type = 'vr_headset') over () as vr,
           count(*) filter (where s.type = 'ps5')        over () as ps
    from public.booking_stations s
    where s.id = any (p_station_ids)
  )
  select k.id,
         public.booking_station_price(
           k.id, p_starts_at, p_minutes,
           (case when k.type = 'ps5' then k.ps else k.vr end)::int)
  from kit k;
$function$;

do $mig$
declare
  src     text;
  patched text;
begin
  select pg_get_functiondef(p.oid) into src
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'booking_create_order';
  if src is null then
    raise exception 'booking_create_order не найдена';
  end if;

  patched := replace(src, $q$    insert into public.booking_order_items (order_id, station_id, starts_at, ends_at, price)
    select v_order_id, sid, v_seg_start, v_seg_end,
           public.booking_station_price(sid, v_seg_start, v_seg_minutes)
    from unnest(v_seg_ids) as sid;$q$, $q$    -- Цена станции зависит от того, сколько станций того же типа в отрезке:
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
    where s.id = any (v_seg_ids);$q$);
  if patched = src then
    raise exception 'блок вставки позиций не найден — определение изменилось';
  end if;
  src := patched;

  patched := replace(src, $q$  v_seg_count   int;$q$, $q$  v_seg_count   int;
  v_seg_vr      int;
  v_seg_ps      int;$q$);
  if patched = src then
    raise exception 'блок declare не найден — определение изменилось';
  end if;

  execute patched;
end
$mig$;
