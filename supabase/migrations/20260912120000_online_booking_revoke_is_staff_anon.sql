-- booking_is_staff() не должна быть доступна анониму.
--
-- В 20260909120000 стоял `revoke all ... from public`, но этого мало: Supabase
-- раздаёт EXECUTE ролям anon/authenticated через ALTER DEFAULT PRIVILEGES на
-- схему public, то есть грант выдаётся роли напрямую, а не через PUBLIC.
-- Отзываем явно у anon. Утечки не было (без auth.uid() функция возвращает
-- false), но публичный эндпоинт /rest/v1/rpc/booking_is_staff лишний.
--
-- Найдено линтером Supabase после применения миграций (аудит, docs/AUDIT.md).

revoke all on function public.booking_is_staff() from anon;

-- Право сотрудника подтверждаем ещё раз — на случай, если revoke зацепит лишнее.
grant execute on function public.booking_is_staff() to authenticated;
