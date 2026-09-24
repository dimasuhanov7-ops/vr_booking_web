alter table public.booking_orders
  add column if not exists prepay integer not null default 0
  check (prepay >= 0);

alter function public.booking_phone_key(text) set search_path = '';
