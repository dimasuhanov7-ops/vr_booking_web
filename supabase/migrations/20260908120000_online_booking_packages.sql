-- =============================================================================
-- Пакеты бронирования (booking_packages)
--
-- Фиксированная цена за набор станций определённого типа на фиксированную
-- длительность в конкретном зале. Витрина как у booking_prices: публичное
-- чтение, редактирование — персоналом (позже). Виджет показывает пакеты в
-- шаге «план зала»; выбор пакета ставит длительность и подбирает станции,
-- итог = цена пакета.
--
-- booking_create_order получает p_package_id: сверяет клуб / зал / длительность
-- / состав по типам и пишет booking_orders.package_id для учёта.
-- =============================================================================

create table if not exists public.booking_packages (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid not null references public.booking_clubs(id) on delete cascade,
  room_id     uuid references public.booking_rooms(id) on delete cascade,
  name        text not null check (length(btrim(name)) between 1 and 80),
  headsets    int  not null default 0 check (headsets >= 0),
  consoles    int  not null default 0 check (consoles >= 0),
  minutes     int  not null check (minutes in (60, 120, 180, 240, 300)),
  price       numeric not null check (price >= 0),
  note        text,
  sort_order  int  not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  check (headsets + consoles > 0),
  unique (club_id, name)
);

comment on table public.booking_packages is
  'Пакеты: фикс. цена за набор станций на фикс. длительность в зале';

create index if not exists booking_packages_club_id_idx on public.booking_packages(club_id);
create index if not exists booking_packages_room_id_idx on public.booking_packages(room_id);

alter table public.booking_packages enable row level security;

drop policy if exists booking_packages_public_read on public.booking_packages;
create policy booking_packages_public_read on public.booking_packages
  for select to anon, authenticated using (is_active);

-- ---- booking_orders.package_id ---------------------------------------------
alter table public.booking_orders
  add column if not exists package_id uuid references public.booking_packages(id);

create index if not exists booking_orders_package_id_idx on public.booking_orders(package_id);

-- ---- booking_create_order: + p_package_id ----------------------------------
-- Новая сигнатура (11 аргументов) — старую дропаем, иначе перегрузка неоднозначна.
drop function if exists public.booking_create_order(
  uuid, text, text, uuid[], timestamptz, int, int, text, text, text);

create function public.booking_create_order(
  p_club_id       uuid,
  p_client_name   text,
  p_client_phone  text,
  p_station_ids   uuid[],
  p_starts_at     timestamptz,
  p_minutes       int,
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
  v_count       int;
  v_vr          int;
  v_ps          int;
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

  -- Пакет: сверяем клуб / длительность / зал / состав по типам станций.
  if p_package_id is not null then
    select * into v_pack from public.booking_packages
     where id = p_package_id and is_active and club_id = p_club_id;
    if not found then
      raise exception 'PACKAGE_NOT_FOUND' using errcode = 'P0001';
    end if;
    if p_minutes <> v_pack.minutes then
      raise exception 'PACKAGE_MISMATCH' using errcode = 'P0001';
    end if;
    select
      count(*) filter (where s.type = 'vr_headset'),
      count(*) filter (where s.type = 'ps5')
      into v_vr, v_ps
    from public.booking_stations s where s.id = any (p_station_ids);
    if v_vr <> v_pack.headsets or v_ps <> v_pack.consoles then
      raise exception 'PACKAGE_MISMATCH' using errcode = 'P0001';
    end if;
    if v_pack.room_id is not null and exists (
      select 1 from public.booking_stations s
       where s.id = any (p_station_ids) and s.room_id <> v_pack.room_id
    ) then
      raise exception 'PACKAGE_MISMATCH' using errcode = 'P0001';
    end if;
  end if;

  v_discount := public.booking_resolve_discount(
    p_discount_code, array_length(p_station_ids, 1)
  );

  insert into public.booking_orders (
    club_id, client_name, client_phone, people_count, comment, source,
    discount_id, package_id, status
  )
  values (
    p_club_id, btrim(p_client_name), btrim(p_client_phone), p_people_count,
    nullif(btrim(p_comment), ''), coalesce(nullif(p_source, ''), 'site'),
    v_discount.id, p_package_id, 'confirmed'
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
  'Создаёт групповую бронь на несколько станций (в т.ч. из разных залов); p_package_id — необязательный пакет';

revoke all on function public.booking_create_order(
  uuid, text, text, uuid[], timestamptz, int, int, text, text, text, uuid) from public;
grant execute on function public.booking_create_order(
  uuid, text, text, uuid[], timestamptz, int, int, text, text, text, uuid) to anon, authenticated;

-- ---- Сид: пакеты из макета ------------------------------------------------
insert into public.booking_packages (club_id, room_id, name, headsets, consoles, minutes, price, note, sort_order)
select c.id, r.id, p.name, p.headsets, p.consoles, p.minutes, p.price, p.note, p.sort_order
from (values
  ('effect_vr', 'Зал',         'Вдвоём',            2, 0, 120,  5000, '2 шлема на 2 часа',        10),
  ('effect_vr', 'Зал',         'Компания',          4, 0, 120, 10000, 'все 4 шлема, 2 часа',      20),
  ('effect_vr', 'Зал',         'Полный зал',        4, 2, 120, 14000, '4 шлема и 2 PS5, 2 часа',  30),
  ('v_ray',     'Большой зал', 'Команда',           6, 0, 120, 14000, '6 шлемов на арене, 2 часа',10),
  ('v_ray',     'Большой зал', 'Арена',            12, 0, 120, 26000, 'все 12 шлемов, 2 часа',    20),
  ('v_ray',     'Малый зал',   'Малый зал целиком', 4, 2, 120, 14000, '4 шлема и 2 PS5, 2 часа',  30),
  ('v_ray',     'Малый зал',   'Шлемы и PS5',       2, 2,  60,  4300, '2 шлема и 2 PS5, 1 час',   40)
) as p(club_slug, room_name, name, headsets, consoles, minutes, price, note, sort_order)
join public.booking_clubs c on c.slug = p.club_slug
join public.booking_rooms r on r.club_id = c.id and r.name = p.room_name
on conflict (club_id, name) do update
  set room_id = excluded.room_id, headsets = excluded.headsets,
      consoles = excluded.consoles, minutes = excluded.minutes,
      price = excluded.price, note = excluded.note,
      sort_order = excluded.sort_order, updated_at = now();
