-- booking_quote не используется ни виджетом, ни Edge Function (цена считается на
-- клиенте от booking_prices). Снимаем с публичного API; вернуть grant, когда
-- появится клиент, которому нужен серверный расчёт.
revoke all on function public.booking_quote(uuid[], timestamptz, int) from anon, authenticated, public;

comment on function public.booking_quote is
  'Стоимость каждой станции за сеанс. НЕ в публичном API (revoked); grant при необходимости.';
