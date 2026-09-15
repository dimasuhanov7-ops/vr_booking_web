-- Предоплата брони — отдельным полем.
--
-- Сотрудник вносит предоплату в админке. Раньше она жила только на экране
-- (а при создании брони — текстом в комментарии) и терялась при перезапуске.
alter table public.booking_orders
  add column if not exists prepay integer not null default 0
  check (prepay >= 0);

-- Линтер Supabase: у функции не зафиксирован search_path. Внутри только
-- встроенные функции pg_catalog, так что пустой путь безопасен.
alter function public.booking_phone_key(text) set search_path = '';
