-- =============================================================================
-- Единый ключ телефона: последние 10 цифр.
--
-- Найдено проверкой отмены: «+7 900 555-01-99» и «8 900 555-01-99» — один и тот
-- же номер, но после удаления нецифр дают разные строки (79005550199 против
-- 89005550199). Последствия были в двух местах:
--
--   * клиент, набравший номер в другом формате, не мог отменить свою бронь;
--   * лимит «3 брони в час на номер» обходился сменой формата ввода —
--     то есть антиспам из 20260911120000 обходился тривиально.
--
-- Сравниваем по последним 10 цифрам: это национальный номер без кода страны,
-- одинаковый для +7…, 8… и 7… .
-- =============================================================================

create or replace function public.booking_phone_key(p_phone text)
returns text
language sql
immutable
as $$
  select right(regexp_replace(coalesce(p_phone, ''), '\D', '', 'g'), 10);
$$;

comment on function public.booking_phone_key is
  'Ключ телефона для сравнения: последние 10 цифр (+7…, 8… и 7… дают одно значение)';

-- Индекс под лимиты — на новом ключе.
drop index if exists public.booking_orders_phone_digits_created_idx;
create index if not exists booking_orders_phone_key_created_idx
  on public.booking_orders (public.booking_phone_key(client_phone), created_at desc);

-- ---- Отмена: сравнение по ключу --------------------------------------------
create or replace function public.booking_cancel_order(
  p_order_id     uuid,
  p_client_phone text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_order public.booking_orders;
  v_key   text;
  v_starts timestamptz;
begin
  v_key := public.booking_phone_key(p_client_phone);
  if length(v_key) < 10 then
    raise exception 'BAD_PHONE' using errcode = 'P0001';
  end if;

  select * into v_order from public.booking_orders where id = p_order_id;

  if not found or public.booking_phone_key(v_order.client_phone) <> v_key then
    raise exception 'ORDER_NOT_FOUND' using errcode = 'P0002';
  end if;

  if v_order.status = 'cancelled' then
    return true;
  end if;

  select min(i.starts_at) into v_starts
  from public.booking_order_items i where i.order_id = p_order_id;

  if v_starts is null or v_starts <= now() then
    raise exception 'TOO_LATE_TO_CANCEL' using errcode = 'P0001';
  end if;

  update public.booking_orders set status = 'cancelled' where id = p_order_id;
  return true;
end;
$fn$;

revoke all on function public.booking_cancel_order(uuid, text) from public;
grant execute on function public.booking_cancel_order(uuid, text) to anon, authenticated;
