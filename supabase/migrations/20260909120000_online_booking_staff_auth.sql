-- =============================================================================
-- Персонал админки: booking_staff (allowlist) + право записи в справочники
--
-- Аккаунты создаются вручную в Supabase (Auth → Users), затем их user_id
-- добавляется в booking_staff. Публичный виджет (anon) не затрагивается —
-- у него уже свои узкие политики insert. Здесь добавляем политики write
-- для authenticated-персонала на редактируемые справочники.
-- =============================================================================

create table if not exists public.booking_staff (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  name        text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

comment on table public.booking_staff is
  'Allowlist сотрудников админки бронирования (user_id из auth.users)';

alter table public.booking_staff enable row level security;

-- Сотрудник видит только свою запись (чтобы фронт мог проверить доступ).
drop policy if exists booking_staff_self_read on public.booking_staff;
create policy booking_staff_self_read on public.booking_staff
  for select to authenticated using (user_id = auth.uid());

-- Текущий пользователь — активный сотрудник?
create or replace function public.booking_is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.booking_staff s
    where s.user_id = auth.uid() and s.is_active
  );
$$;

comment on function public.booking_is_staff is
  'true, если auth.uid() — активный сотрудник (для RLS админки)';

revoke all on function public.booking_is_staff() from public;
grant execute on function public.booking_is_staff() to authenticated;

-- ---- Право записи персоналу на редактируемые справочники --------------------
alter table public.booking_prices   enable row level security;
alter table public.booking_packages enable row level security;
alter table public.booking_clubs    enable row level security;
alter table public.booking_orders   enable row level security;

-- booking_prices: staff может менять цены.
drop policy if exists booking_prices_staff_write on public.booking_prices;
create policy booking_prices_staff_write on public.booking_prices
  for all to authenticated
  using (public.booking_is_staff())
  with check (public.booking_is_staff());

-- booking_packages: staff может менять пакеты.
drop policy if exists booking_packages_staff_write on public.booking_packages;
create policy booking_packages_staff_write on public.booking_packages
  for all to authenticated
  using (public.booking_is_staff())
  with check (public.booking_is_staff());

-- booking_clubs: staff может менять часы работы / приём заявок.
drop policy if exists booking_clubs_staff_write on public.booking_clubs;
create policy booking_clubs_staff_write on public.booking_clubs
  for update to authenticated
  using (public.booking_is_staff())
  with check (public.booking_is_staff());

-- booking_orders: staff видит все брони и меняет их статус (отмена).
drop policy if exists booking_orders_staff_read on public.booking_orders;
create policy booking_orders_staff_read on public.booking_orders
  for select to authenticated using (public.booking_is_staff());

drop policy if exists booking_orders_staff_update on public.booking_orders;
create policy booking_orders_staff_update on public.booking_orders
  for update to authenticated
  using (public.booking_is_staff())
  with check (public.booking_is_staff());

-- Персоналу нужно читать позиции броней (для списка записей).
alter table public.booking_order_items enable row level security;
drop policy if exists booking_order_items_staff_read on public.booking_order_items;
create policy booking_order_items_staff_read on public.booking_order_items
  for select to authenticated using (public.booking_is_staff());
