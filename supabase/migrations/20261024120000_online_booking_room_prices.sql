-- Цены по залам: у зала может быть своя цена шлема и PS5.
--
-- Раньше цена жила на клубе: booking_prices (клуб × тип станции × будни/выходные
-- × ступень min_qty). Для V-Ray нужно, чтобы Малый зал (4 шлема + 2 PS5) имел
-- свои цены, отличные от Большого зала (арены).
--
-- Устройство:
--  * booking_room_prices — отдельная таблица (зал × тип × будни/выходные),
--    одна цена без ступеней. Старая booking_prices НЕ меняется: установленные
--    приложения сотрудников сохраняют цены upsert'ом по (club_id, station_type,
--    day_kind, min_qty), и новый ключ их бы сломал.
--  * Цена станции: есть строка в booking_room_prices для её зала — берём её;
--    нет — тариф клуба со ступенями, как раньше. Пока таблица пуста, ничего
--    не меняется.
--  * Ступени «от N шлемов» считаются отдельно: станции с собственной ценой зала
--    считаются в своей группе (зал + тип), остальные — вместе по клубу.
--  * Одна функция booking_segment_prices считает цены всех станций отрезка;
--    её используют booking_create_order, booking_reschedule_order и booking_quote.

-- 1. Таблица ------------------------------------------------------------------

create table if not exists public.booking_room_prices (
  id              uuid primary key default gen_random_uuid(),
  room_id         uuid not null references public.booking_rooms(id) on delete cascade,
  station_type    text not null check (station_type in ('vr_headset', 'ps5')),
  day_kind        text not null check (day_kind in ('weekday', 'weekend')),
  price_per_hour  numeric not null check (price_per_hour >= 0),
  updated_at      timestamptz not null default now(),
  unique (room_id, station_type, day_kind)
);

comment on table public.booking_room_prices is
  'Собственная цена за час для зала. Перекрывает тариф клуба (booking_prices) '
  'для станций этого зала; одна цена, без ступеней.';

alter table public.booking_room_prices enable row level security;

drop policy if exists booking_room_prices_public_read on public.booking_room_prices;
create policy booking_room_prices_public_read on public.booking_room_prices
  for select to anon, authenticated using (true);

drop policy if exists booking_room_prices_staff_write on public.booking_room_prices;
create policy booking_room_prices_staff_write on public.booking_room_prices
  for all to authenticated
  using (public.booking_is_staff())
  with check (public.booking_is_staff());

grant select on public.booking_room_prices to anon, authenticated;
grant insert, update, delete on public.booking_room_prices to authenticated;

drop trigger if exists booking_room_prices_audit on public.booking_room_prices;
create trigger booking_room_prices_audit
  after insert or update or delete on public.booking_room_prices
  for each row execute function public.booking_write_audit();

-- 2. Цены всех станций отрезка -------------------------------------------------

create or replace function public.booking_segment_prices(
  p_station_ids uuid[],
  p_starts_at   timestamptz,
  p_minutes     integer
)
returns table (station_id uuid, price numeric)
language sql
stable
security definer
set search_path to 'public'
as $function$
  with st as (
    select s.id, s.type, s.room_id, r.club_id,
           public.booking_day_kind(p_starts_at, c.timezone) as dk
      from public.booking_stations s
      join public.booking_rooms r on r.id = s.room_id
      join public.booking_clubs c on c.id = r.club_id
     where s.id = any (p_station_ids)
  ),
  own as (
    select st.*, rp.price_per_hour as own_rate
      from st
      left join public.booking_room_prices rp
        on rp.room_id = st.room_id
       and rp.station_type = st.type
       and rp.day_kind = st.dk
  ),
  grp as (
    -- Станции с ценой зала считаются в группе «зал + тип», остальные — вместе.
    select own.*,
           count(*) over (
             partition by own.type,
                          case when own.own_rate is not null
                               then own.room_id::text else 'club' end
           ) as qty
      from own
  )
  select g.id,
         round(
           coalesce(
             g.own_rate,
             (select p.price_per_hour
                from public.booking_prices p
               where p.club_id = g.club_id
                 and p.station_type = g.type
                 and p.day_kind = g.dk
                 and p.min_qty <= greatest(g.qty, 1)
               order by p.min_qty desc
               limit 1),
             0) * p_minutes / 60.0)
    from grp g;
$function$;

revoke all on function public.booking_segment_prices(uuid[], timestamptz, integer)
  from public, anon, authenticated;
grant execute on function public.booking_segment_prices(uuid[], timestamptz, integer)
  to service_role;

-- 3. booking_quote — через ту же функцию -------------------------------------------

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
  select sp.station_id, sp.price
    from public.booking_segment_prices(p_station_ids, p_starts_at, p_minutes) sp;
$function$;

-- 4. Приём брони и перенос: цена позиции — из booking_segment_prices ---------------
-- Тела функций не переписываем: из актуального определения заменяем только
-- выражение цены в insert позиций (так же делалось в online_booking_price_tiers).

do $mig$
declare
  fn      text;
  src     text;
  patched text;
  pat     text := 'public\.booking_station_price\(\s*s\.id,\s*v_seg_start,\s*v_seg_minutes,\s*case when s\.type = ''ps5'' then v_seg_ps else v_seg_vr end\)';
  rep     text := '(select sp.price from public.booking_segment_prices(v_seg_ids, v_seg_start, v_seg_minutes) sp where sp.station_id = s.id)';
begin
  foreach fn in array array['booking_create_order', 'booking_reschedule_order'] loop
    select pg_get_functiondef(p.oid) into src
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = fn;
    if src is null then
      raise exception '% не найдена', fn;
    end if;

    -- Ровно одно вхождение: ноль — определение изменилось, больше — незнакомый вид.
    if (select count(*) from regexp_matches(src, pat, 'g')) <> 1 then
      raise exception 'в % выражение цены позиции найдено не один раз', fn;
    end if;
    patched := regexp_replace(src, pat, rep);
    execute patched;
  end loop;
end
$mig$;
