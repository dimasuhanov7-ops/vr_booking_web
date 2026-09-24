-- Админка броней обновляется сразу, а не раз в минуту: изменения броней,
-- закрытий и паузы приёма рассылаются через Supabase Realtime.
--
-- Доставка postgres_changes идёт с учётом RLS: события booking_orders,
-- booking_order_items и booking_availability получают только сотрудники
-- (политики с booking_is_staff), анонимным клиентам не приходит ничего.
-- booking_clubs и так читается публично (названия, часы, пауза приёма).
do $$
declare
  t text;
begin
  foreach t in array array[
    'booking_orders', 'booking_order_items', 'booking_availability', 'booking_clubs'
  ]
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end
$$;
