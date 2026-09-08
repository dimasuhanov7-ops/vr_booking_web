-- =============================================================================
-- Отмена брони клиентом.
--
-- Сейчас бронь можно только создать: чтобы отменить, клиент звонит в клуб, а
-- если не дозвонился — просто не приходит. Это прямой источник no-show и
-- занятых впустую станций.
--
-- Доступ по паре (id брони, телефон): id клиент знает из чека и localStorage,
-- телефон — свой. Перебор id нереален (uuid v4), а телефон отсекает случайное
-- совпадение. Отдельная авторизация клиента по ТЗ не предусмотрена.
--
-- Срок: отменить можно, пока сеанс не начался. Если клуб захочет запретить
-- отмену «впритык» (например, за 2 часа), достаточно поменять интервал ниже.
-- =============================================================================

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
  v_order  public.booking_orders;
  v_phone  text;
  v_starts timestamptz;
begin
  v_phone := regexp_replace(coalesce(p_client_phone, ''), '\D', '', 'g');
  if length(v_phone) < 10 then
    raise exception 'BAD_PHONE' using errcode = 'P0001';
  end if;

  select * into v_order from public.booking_orders where id = p_order_id;

  -- Чужую бронь и несуществующую различать нельзя: иначе по коду ответа
  -- можно проверять, существует ли заказ с таким id.
  if not found
     or regexp_replace(v_order.client_phone, '\D', '', 'g') <> v_phone then
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

  -- Триггер booking_orders_status_sync снимет is_active с позиций, и станции
  -- сразу освободятся для других клиентов.
  update public.booking_orders
     set status = 'cancelled'
   where id = p_order_id;

  return true;
end;
$fn$;

comment on function public.booking_cancel_order is
  'Отмена брони клиентом по паре (id, телефон), пока сеанс не начался. '
  'Чужая и несуществующая бронь неразличимы: обе дают ORDER_NOT_FOUND.';

revoke all on function public.booking_cancel_order(uuid, text) from public;
grant execute on function public.booking_cancel_order(uuid, text) to anon, authenticated;
