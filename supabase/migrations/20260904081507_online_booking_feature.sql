-- =============================================================================
-- Онлайн-бронирование VR-клубов (публичный виджет).
--
-- Все объекты — в схеме public с префиксом `booking_`, чтобы не конфликтовать
-- с существующей таблицей public.bookings (зеркало Bukza).
--
-- Модель (по макету дизайна «Виджет бронирования VR»):
--   * booking_clubs / booking_rooms / booking_stations — справочник станций
--     с раскладкой по рядам (row_index) для «плана зала»;
--   * booking_prices — тариф за час: клуб × тип станции × будни/выходные,
--     редактируется без миграций;
--   * booking_discounts — промокоды и автоскидки (инфраструктура на будущее,
--     сейчас без данных и без UI);
--   * booking_orders / booking_order_items — брони; EXCLUDE-констрейнт против
--     двойной брони на уровне БД (нарушение → SQLSTATE 23P01);
--   * RPC booking_busy_intervals / booking_quote / booking_validate_discount /
--     booking_create_order — единственный публичный API для анонимного клиента.
--
-- Сеансы: 60 / 90 / 120 / 180 минут, идут встык с паузой clubs.slot_gap_minutes
-- (Effect VR — 10 мин, V-Ray — 0). Оплата на месте; суммы в виджете справочные.
-- =============================================================================

create extension if not exists btree_gist with schema extensions;

-- -----------------------------------------------------------------------------
-- Справочник: клубы -> залы -> станции
-- -----------------------------------------------------------------------------
create table if not exists public.booking_clubs (
  id                 uuid primary key default gen_random_uuid(),
  slug               text not null unique,
  name               text not null,
  timezone           text not null default 'Europe/Moscow',
  open_time          time not null default '11:00',
  close_time         time not null default '23:00',
  slot_gap_minutes   int  not null default 0 check (slot_gap_minutes between 0 and 60),
  sort_order         int  not null default 0,
  is_active          boolean not null default true
);

comment on table public.booking_clubs is 'Клубы, доступные для онлайн-бронирования';
comment on column public.booking_clubs.close_time is 'ends_at брони должен быть не позже (локальное время клуба)';
comment on column public.booking_clubs.slot_gap_minutes is 'Пауза между сеансами: шаг сетки = длительность + пауза';

create table if not exists public.booking_rooms (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid not null references public.booking_clubs(id) on delete cascade,
  name        text not null,
  sort_order  int  not null default 0,
  unique (club_id, name)
);

comment on table public.booking_rooms is
  'Залы клуба. Бронь на «весь клуб» — это выбор станций из нескольких залов в одной брони (без отдельной сущности).';

create table if not exists public.booking_stations (
  id               uuid primary key default gen_random_uuid(),
  room_id          uuid not null references public.booking_rooms(id) on delete cascade,
  type             text not null check (type in ('vr_headset', 'ps5')),
  label            text not null,
  row_index        int  not null default 0,
  position_in_row  int  not null default 0,
  sort_order       int  not null default 0,
  is_active        boolean not null default true,
  unique (room_id, label)
);

comment on table public.booking_stations is 'Конкретный шлем/приставка; row_index/position_in_row — раскладка «плана зала»';

create index if not exists booking_rooms_club_id_idx    on public.booking_rooms(club_id);
create index if not exists booking_stations_room_id_idx on public.booking_stations(room_id);

-- -----------------------------------------------------------------------------
-- Тарифы: цена за час, клуб × тип станции × будни/выходные
-- -----------------------------------------------------------------------------
create table if not exists public.booking_prices (
  id              uuid primary key default gen_random_uuid(),
  club_id         uuid not null references public.booking_clubs(id) on delete cascade,
  station_type    text not null check (station_type in ('vr_headset', 'ps5')),
  day_kind        text not null check (day_kind in ('weekday', 'weekend')),
  price_per_hour  numeric not null check (price_per_hour >= 0),
  updated_at      timestamptz not null default now(),
  unique (club_id, station_type, day_kind)
);

comment on table public.booking_prices is 'Цена за час. Меняется без миграций (через админку/SQL)';

create index if not exists booking_prices_club_id_idx on public.booking_prices(club_id);

-- -----------------------------------------------------------------------------
-- Скидки (инфраструктура на будущее; сейчас без данных и без UI)
-- -----------------------------------------------------------------------------
create table if not exists public.booking_discounts (
  id            uuid primary key default gen_random_uuid(),
  code          text unique,
  title         text,
  kind          text not null check (kind in ('percent', 'fixed')),
  value         numeric not null check (value >= 0),
  min_stations  int not null default 1 check (min_stations >= 1),
  valid_from    timestamptz,
  valid_until   timestamptz,
  active        boolean not null default true
);

comment on table public.booking_discounts is
  'code IS NOT NULL — промокод; code IS NULL — автоскидка по числу станций';

-- -----------------------------------------------------------------------------
-- Брони
-- -----------------------------------------------------------------------------
create table if not exists public.booking_orders (
  id            uuid primary key default gen_random_uuid(),
  club_id       uuid not null references public.booking_clubs(id),
  client_name   text not null check (length(btrim(client_name)) between 2 and 120),
  client_phone  text not null check (length(btrim(client_phone)) between 5 and 30),
  people_count  int check (people_count is null or people_count between 1 and 100),
  comment       text,
  source        text not null default 'site'
                  check (source in ('site', 'vk', 'tg', 'app', 'staff')),
  discount_id   uuid references public.booking_discounts(id),
  status        text not null default 'confirmed'
                  check (status in ('confirmed', 'cancelled', 'completed', 'no_show')),
  created_at    timestamptz not null default now()
);

comment on table public.booking_orders is 'Онлайн-бронь (оплата на месте, здесь только резерв станций)';

create index if not exists booking_orders_club_id_idx     on public.booking_orders(club_id);
create index if not exists booking_orders_discount_id_idx  on public.booking_orders(discount_id);

create table if not exists public.booking_order_items (
  id          uuid primary key default gen_random_uuid(),
  order_id    uuid not null references public.booking_orders(id) on delete cascade,
  station_id  uuid not null references public.booking_stations(id),
  starts_at   timestamptz not null,
  ends_at     timestamptz not null,
  price       numeric not null default 0 check (price >= 0),
  -- Зеркалит booking_orders.status <> 'cancelled' (поддерживается триггером).
  -- Нужно, чтобы отменённая бронь освобождала слот: EXCLUDE ниже — частичный.
  is_active   boolean not null default true,
  time_range  tstzrange generated always as (tstzrange(starts_at, ends_at, '[)')) stored,
  check (ends_at > starts_at)
);

comment on table public.booking_order_items is 'Одна станция на один слот; price — зафиксированная стоимость на момент брони';

create index if not exists booking_order_items_order_id_idx on public.booking_order_items(order_id);

-- Синхронизация is_active с booking_orders.status.
-- SECURITY DEFINER: инвариант поддерживается независимо от прав того, кто меняет статус.
create or replace function public.booking_sync_item_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.booking_order_items
     set is_active = (new.status <> 'cancelled')
   where order_id = new.id
     and is_active <> (new.status <> 'cancelled');
  return new;
end;
$$;

drop trigger if exists booking_orders_status_sync on public.booking_orders;
create trigger booking_orders_status_sync
  after update of status on public.booking_orders
  for each row execute function public.booking_sync_item_activity();

alter table public.booking_order_items
  drop constraint if exists booking_no_overlapping_items;
alter table public.booking_order_items
  add constraint booking_no_overlapping_items
  exclude using gist (station_id with =, time_range with &&)
  where (is_active);

-- =============================================================================
-- Вспомогательные функции ценообразования
-- =============================================================================

-- Тип дня по дате в таймзоне клуба: 6=сб, 0=вс -> weekend.
create or replace function public.booking_day_kind(p_when timestamptz, p_tz text)
returns text
language sql
stable
set search_path = pg_catalog
as $$
  select case
    when extract(dow from (p_when at time zone p_tz))::int in (0, 6) then 'weekend'
    else 'weekday'
  end;
$$;

-- Стоимость одной станции за сеанс.
create or replace function public.booking_station_price(
  p_station_id uuid,
  p_starts_at  timestamptz,
  p_minutes    int
)
returns numeric
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_type      text;
  v_club_id   uuid;
  v_tz        text;
  v_rate      numeric;
begin
  select s.type, c.id, c.timezone
    into v_type, v_club_id, v_tz
  from public.booking_stations s
  join public.booking_rooms    r on r.id = s.room_id
  join public.booking_clubs    c on c.id = r.club_id
  where s.id = p_station_id;

  if not found then
    raise exception 'STATION_NOT_FOUND' using errcode = 'P0002';
  end if;

  select p.price_per_hour into v_rate
  from public.booking_prices p
  where p.club_id = v_club_id
    and p.station_type = v_type
    and p.day_kind = public.booking_day_kind(p_starts_at, v_tz);

  return round(coalesce(v_rate, 0) * p_minutes / 60.0);
end;
$$;

-- =============================================================================
-- Публичные RPC (SECURITY DEFINER)
-- =============================================================================

-- Занятость всех станций клуба на дату. Только station_id/room_id и время —
-- без ФИО/телефонов других клиентов.
create or replace function public.booking_busy_intervals(
  p_club_id uuid,
  p_day     date
)
returns table (station_id uuid, room_id uuid, starts_at timestamptz, ends_at timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select i.station_id, s.room_id, i.starts_at, i.ends_at
  from public.booking_order_items i
  join public.booking_stations   s on s.id = i.station_id
  join public.booking_rooms      r on r.id = s.room_id
  join public.booking_clubs      c on c.id = r.club_id
  where c.id = p_club_id
    and i.is_active
    and i.time_range && tstzrange(
          (p_day::timestamp)       at time zone c.timezone,
          ((p_day + 1)::timestamp) at time zone c.timezone,
          '[)'
        );
$$;

comment on function public.booking_busy_intervals is
  'Занятость станций клуба на дату для сетки слотов и плана зала (без персональных данных)';

-- Расчёт стоимости по выбранным станциям и слоту.
create or replace function public.booking_quote(
  p_station_ids uuid[],
  p_starts_at   timestamptz,
  p_minutes     int
)
returns table (station_id uuid, price numeric)
language sql
stable
security definer
set search_path = public
as $$
  select sid, public.booking_station_price(sid, p_starts_at, p_minutes)
  from unnest(p_station_ids) as sid;
$$;

comment on function public.booking_quote is 'Стоимость каждой станции за сеанс — для итоговой суммы в виджете';

-- Разрешение скидки (промокод или автоскидка). Сейчас скидок нет — вернёт 0 строк.
create or replace function public.booking_resolve_discount(
  p_code           text,
  p_station_count  int
)
returns public.booking_discounts
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_row public.booking_discounts;
  v_now timestamptz := now();
begin
  if p_station_count is null or p_station_count < 1 then
    return null;
  end if;

  if p_code is not null and length(btrim(p_code)) > 0 then
    select * into v_row
    from public.booking_discounts d
    where d.code is not null
      and lower(d.code) = lower(btrim(p_code))
      and d.active
      and (d.valid_from  is null or d.valid_from  <= v_now)
      and (d.valid_until is null or d.valid_until >= v_now)
    limit 1;

    if not found then
      raise exception 'DISCOUNT_NOT_FOUND' using errcode = 'P0002';
    end if;
    if p_station_count < v_row.min_stations then
      raise exception 'DISCOUNT_MIN_STATIONS:%', v_row.min_stations using errcode = 'P0001';
    end if;
    return v_row;
  end if;

  select * into v_row
  from public.booking_discounts d
  where d.code is null
    and d.active
    and d.min_stations <= p_station_count
    and (d.valid_from  is null or d.valid_from  <= v_now)
    and (d.valid_until is null or d.valid_until >= v_now)
  order by d.min_stations desc, d.value desc
  limit 1;

  return v_row;
end;
$$;

create or replace function public.booking_validate_discount(
  p_code           text,
  p_station_count  int
)
returns table (
  id            uuid,
  code          text,
  title         text,
  kind          text,
  value         numeric,
  min_stations  int
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_row public.booking_discounts;
begin
  v_row := public.booking_resolve_discount(p_code, p_station_count);
  if v_row.id is null then
    return;
  end if;
  id := v_row.id; code := v_row.code; title := v_row.title;
  kind := v_row.kind; value := v_row.value; min_stations := v_row.min_stations;
  return next;
end;
$$;

-- Атомарное создание групповой брони. Пересечение по станции -> SQLSTATE 23P01.
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
  if p_minutes not in (60, 90, 120, 180) then
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

  -- Все станции существуют, активны и принадлежат выбранному клубу
  -- (могут быть из разных залов — это бронь на «весь клуб»).
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

-- =============================================================================
-- RLS и права
-- =============================================================================
alter table public.booking_clubs        enable row level security;
alter table public.booking_rooms        enable row level security;
alter table public.booking_stations     enable row level security;
alter table public.booking_prices       enable row level security;
alter table public.booking_discounts    enable row level security;
alter table public.booking_orders       enable row level security;
alter table public.booking_order_items  enable row level security;

drop policy if exists booking_clubs_public_read on public.booking_clubs;
create policy booking_clubs_public_read on public.booking_clubs
  for select to anon, authenticated using (is_active);

drop policy if exists booking_rooms_public_read on public.booking_rooms;
create policy booking_rooms_public_read on public.booking_rooms
  for select to anon, authenticated using (
    exists (select 1 from public.booking_clubs c where c.id = club_id and c.is_active)
  );

drop policy if exists booking_stations_public_read on public.booking_stations;
create policy booking_stations_public_read on public.booking_stations
  for select to anon, authenticated using (is_active);

drop policy if exists booking_prices_public_read on public.booking_prices;
create policy booking_prices_public_read on public.booking_prices
  for select to anon, authenticated using (true);

-- Скидки напрямую не читаются — только через booking_validate_discount().

-- Анонимная вставка брони: статус confirmed, существующий активный клуб.
drop policy if exists booking_orders_anon_insert on public.booking_orders;
create policy booking_orders_anon_insert on public.booking_orders
  for insert to anon
  with check (
    status = 'confirmed'
    and exists (select 1 from public.booking_clubs c where c.id = club_id and c.is_active)
  );

-- Анонимная вставка позиции: только в будущее, длительность 60/90/120/180
-- и в рамках рабочих часов клуба.
drop policy if exists booking_order_items_anon_insert on public.booking_order_items;
create policy booking_order_items_anon_insert on public.booking_order_items
  for insert to anon
  with check (
    starts_at > now()
    and ends_at > starts_at
    and round(extract(epoch from (ends_at - starts_at)) / 60) in (60, 90, 120, 180)
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

grant usage on schema public to anon;
grant select on public.booking_clubs, public.booking_rooms,
                public.booking_stations, public.booking_prices to anon;
grant insert on public.booking_orders, public.booking_order_items to anon;

-- Внутренние helper-функции: только через SECURITY DEFINER RPC (как владелец), не напрямую.
revoke all on function public.booking_resolve_discount(text, int)            from public, anon, authenticated;
revoke all on function public.booking_station_price(uuid, timestamptz, int)  from public, anon, authenticated;
revoke all on function public.booking_day_kind(timestamptz, text)            from public, anon, authenticated;
revoke all on function public.booking_sync_item_activity()                   from public, anon, authenticated;
-- booking_quote пока не в публичном API (цена считается на клиенте от booking_prices).
revoke all on function public.booking_quote(uuid[], timestamptz, int)        from public, anon, authenticated;

grant execute on function public.booking_busy_intervals(uuid, date)          to anon, authenticated;
grant execute on function public.booking_validate_discount(text, int)        to anon, authenticated;
grant execute on function public.booking_create_order(uuid, text, text, uuid[], timestamptz, int, int, text, text, text) to anon, authenticated;

-- =============================================================================
-- Сид: клубы, залы, станции, тарифы
-- =============================================================================
insert into public.booking_clubs (slug, name, timezone, open_time, close_time, slot_gap_minutes, sort_order)
values
  ('effect_vr', 'Effect VR', 'Europe/Moscow', '11:00', '22:30', 10, 10),
  ('v_ray',     'V-Ray',     'Europe/Moscow', '11:00', '23:00', 0, 20)
on conflict (slug) do update
  set name = excluded.name, timezone = excluded.timezone,
      open_time = excluded.open_time, close_time = excluded.close_time,
      slot_gap_minutes = excluded.slot_gap_minutes, sort_order = excluded.sort_order;

-- Тарифы (₽/час): одинаковые для обоих клубов, редактируются позже.
insert into public.booking_prices (club_id, station_type, day_kind, price_per_hour)
select c.id, t.station_type, t.day_kind, t.price
from public.booking_clubs c,
     (values
        ('vr_headset', 'weekday', 600),
        ('vr_headset', 'weekend', 1000),
        ('ps5',        'weekday', 300),
        ('ps5',        'weekend', 400)
     ) as t(station_type, day_kind, price)
on conflict (club_id, station_type, day_kind) do update
  set price_per_hour = excluded.price_per_hour, updated_at = now();

-- Effect VR — «Зал»: ряд 0 = 4 VR (#1..#4), ряд 1 = 2 PS5 (PS5-1, PS5-2)
with club as (select id from public.booking_clubs where slug = 'effect_vr'),
     room as (
       insert into public.booking_rooms (club_id, name, sort_order)
       select id, 'Зал', 0 from club
       on conflict (club_id, name) do update set sort_order = excluded.sort_order
       returning id
     )
insert into public.booking_stations (room_id, type, label, row_index, position_in_row, sort_order)
select room.id, s.type, s.label, s.row_index, s.pos, s.sort
from room,
     (values
        ('vr_headset', '#1', 0, 0, 1), ('vr_headset', '#2', 0, 1, 2),
        ('vr_headset', '#3', 0, 2, 3), ('vr_headset', '#4', 0, 3, 4),
        ('ps5', 'PS5-1', 1, 0, 5), ('ps5', 'PS5-2', 1, 1, 6)
     ) as s(type, label, row_index, pos, sort)
on conflict (room_id, label) do nothing;

-- V-Ray — «Большой зал»: 12 VR в трёх рядах по 4 (#1..#12)
with club as (select id from public.booking_clubs where slug = 'v_ray'),
     room as (
       insert into public.booking_rooms (club_id, name, sort_order)
       select id, 'Большой зал', 0 from club
       on conflict (club_id, name) do update set sort_order = excluded.sort_order
       returning id
     )
insert into public.booking_stations (room_id, type, label, row_index, position_in_row, sort_order)
select room.id, 'vr_headset', '#' || g, (g - 1) / 4, (g - 1) % 4, g
from room, generate_series(1, 12) as g
on conflict (room_id, label) do nothing;

-- V-Ray — «Малый зал»: ряд 0 = 4 VR (#1..#4), ряд 1 = 2 PS5
with club as (select id from public.booking_clubs where slug = 'v_ray'),
     room as (
       insert into public.booking_rooms (club_id, name, sort_order)
       select id, 'Малый зал', 1 from club
       on conflict (club_id, name) do update set sort_order = excluded.sort_order
       returning id
     )
insert into public.booking_stations (room_id, type, label, row_index, position_in_row, sort_order)
select room.id, s.type, s.label, s.row_index, s.pos, s.sort
from room,
     (values
        ('vr_headset', '#1', 0, 0, 1), ('vr_headset', '#2', 0, 1, 2),
        ('vr_headset', '#3', 0, 2, 3), ('vr_headset', '#4', 0, 3, 4),
        ('ps5', 'PS5-1', 1, 0, 5), ('ps5', 'PS5-2', 1, 1, 6)
     ) as s(type, label, row_index, pos, sort)
on conflict (room_id, label) do nothing;
