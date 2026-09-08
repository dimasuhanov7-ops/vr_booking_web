-- =============================================================================
-- Доступность: пауза приёма заявок, закрытие залов и отдельных окон.
--
-- До этой миграции правки на вкладке «Доступность» жили только в памяти
-- AdminBloc: сотрудник «закрывал» зал, видел это на экране, а публичный виджет
-- продолжал принимать туда брони. Это опаснее, чем отсутствие функции.
--
-- Модель:
--   * booking_clubs.intake_open — приём заявок клуба целиком (пауза);
--   * booking_availability — строка = «здесь закрыто»:
--       room_id  null → все залы клуба, иначе конкретный зал;
--       day      null → бессрочно (зал закрыт совсем), иначе конкретная дата;
--       from_minutes/to_minutes null → весь рабочий день, иначе окно.
--
-- Ключевое решение: закрытия отдаются виджету через booking_busy_intervals —
-- то есть выглядят для него как обычная занятость станций. Клиентский код
-- менять не нужно, слот просто станет недоступным.
-- =============================================================================

-- ---- 1. Пауза приёма заявок -------------------------------------------------
alter table public.booking_clubs
  add column if not exists intake_open boolean not null default true;

comment on column public.booking_clubs.intake_open is
  'false — клуб временно не принимает онлайн-брони (пауза из админки)';

-- ---- 2. Закрытия ------------------------------------------------------------
create table if not exists public.booking_availability (
  id            uuid primary key default gen_random_uuid(),
  club_id       uuid not null references public.booking_clubs(id) on delete cascade,
  room_id       uuid references public.booking_rooms(id) on delete cascade,
  day           date,
  from_minutes  int check (from_minutes is null or from_minutes between 0 and 1440),
  to_minutes    int check (to_minutes   is null or to_minutes   between 0 and 1440),
  note          text,
  created_at    timestamptz not null default now(),
  -- Окно задаётся целиком или не задаётся вовсе.
  check ((from_minutes is null) = (to_minutes is null)),
  check (from_minutes is null or to_minutes > from_minutes)
);

comment on table public.booking_availability is
  'Закрытые залы и окна. Строка = «здесь нельзя бронировать». '
  'Отдаётся виджету через booking_busy_intervals как занятость.';

create index if not exists booking_availability_club_day_idx
  on public.booking_availability (club_id, day);

alter table public.booking_availability enable row level security;

-- Читать закрытия публично не нужно: они приезжают внутри busy_intervals
-- (SECURITY DEFINER), а сотруднику нужен полный доступ для редактирования.
drop policy if exists booking_availability_staff_all on public.booking_availability;
create policy booking_availability_staff_all on public.booking_availability
  for all to authenticated
  using (public.booking_is_staff())
  with check (public.booking_is_staff());

-- ---- 3. Занятость с учётом закрытий ----------------------------------------
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
  -- Реальные брони.
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
        )

  union all

  -- Закрытия из админки: разворачиваем в интервалы по станциям.
  select s.id, s.room_id,
         ((p_day::timestamp) + make_interval(mins => coalesce(a.from_minutes,
            extract(hour from c.open_time)::int * 60
            + extract(minute from c.open_time)::int))) at time zone c.timezone,
         ((p_day::timestamp) + make_interval(mins => coalesce(a.to_minutes,
            extract(hour from c.close_time)::int * 60
            + extract(minute from c.close_time)::int))) at time zone c.timezone
  from public.booking_availability a
  join public.booking_clubs    c on c.id = a.club_id
  join public.booking_rooms    r on r.club_id = a.club_id
                                and (a.room_id is null or r.id = a.room_id)
  join public.booking_stations s on s.room_id = r.id and s.is_active
  where a.club_id = p_club_id
    and (a.day is null or a.day = p_day)

  union all

  -- Пауза приёма: клуб закрыт целиком на весь день.
  select s.id, s.room_id,
         (p_day::timestamp at time zone c.timezone),
         ((p_day + 1)::timestamp at time zone c.timezone)
  from public.booking_clubs    c
  join public.booking_rooms    r on r.club_id = c.id
  join public.booking_stations s on s.room_id = r.id and s.is_active
  where c.id = p_club_id and not c.intake_open;
$$;

comment on function public.booking_busy_intervals is
  'Занятость станций клуба на дату: брони + закрытия из админки + пауза приёма '
  '(без персональных данных)';

-- ---- 4. Приём брони уважает паузу ------------------------------------------
-- Полагаться только на busy_intervals нельзя: это подсказка для UI, а запрет
-- должен стоять на записи.
create or replace function public.booking_intake_open(p_club_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select c.intake_open from public.booking_clubs c
                    where c.id = p_club_id), false);
$$;

revoke all on function public.booking_intake_open(uuid) from public, anon, authenticated;

comment on function public.booking_intake_open is
  'Принимает ли клуб онлайн-брони. Внутренняя — вызывается из booking_create_order.';
