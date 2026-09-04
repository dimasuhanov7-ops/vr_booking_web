-- Ужесточение прав после ревью security-advisor'ом.
-- (Основная миграция 20260903120000 уже содержит эти revoke; файл повторяет их
--  для совпадения с журналом миграций прод-БД. Все операции идемпотентны.)

-- Триггерная функция не должна быть вызываемой через RPC.
revoke all on function public.booking_sync_item_activity() from public, anon, authenticated;

-- Внутренние helper-функции: только через SECURITY DEFINER RPC (владелец), не напрямую.
revoke all on function public.booking_resolve_discount(text, int)            from public, anon, authenticated;
revoke all on function public.booking_station_price(uuid, timestamptz, int)  from public, anon, authenticated;
revoke all on function public.booking_day_kind(timestamptz, text)            from public, anon, authenticated;

comment on table public.booking_discounts is
  'code IS NOT NULL — промокод; code IS NULL — автоскидка. RLS без политик намеренно: доступ только через booking_validate_discount().';
