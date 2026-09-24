-- =============================================================================
-- Промокоды из админки: сотрудник заводит, выключает и удаляет записи
-- booking_discounts, каждое изменение попадает в журнал.
--
-- Раньше у таблицы был включён RLS без политик — доступ только через
-- booking_validate_discount(). Клиенту так и остаётся: анониму таблица
-- по-прежнему закрыта, код проверяется RPC.
--
-- Промокоды общие для всех клубов (club_id у таблицы нет).
--
-- Код сравнивается без учёта регистра (booking_resolve_discount ищет по
-- lower(code)), поэтому уникальность — тоже по lower(code): иначе «vrparty» и
-- «VRPARTY» жили бы как два разных промокода, а срабатывал бы случайный.
-- На момент написания в таблице 0 строк — индекс и проверка встанут без
-- конфликтов.
-- =============================================================================

drop policy if exists booking_discounts_staff_all on public.booking_discounts;
create policy booking_discounts_staff_all on public.booking_discounts
  for all to authenticated
  using (public.booking_is_staff())
  with check (public.booking_is_staff());

create unique index if not exists booking_discounts_code_ci_key
  on public.booking_discounts (lower(code))
  where code is not null;

-- Процент больше 100 увёл бы сумму в минус.
alter table public.booking_discounts
  drop constraint if exists booking_discounts_percent_range;
alter table public.booking_discounts
  add constraint booking_discounts_percent_range
  check (kind <> 'percent' or value <= 100);

-- Журнал: кто завёл, выключил или удалил промокод.
drop trigger if exists booking_discounts_audit on public.booking_discounts;
create trigger booking_discounts_audit
  after insert or update or delete on public.booking_discounts
  for each row execute function public.booking_write_audit();

comment on table public.booking_discounts is
  'code IS NOT NULL — промокод; code IS NULL — автоскидка. Клиент читает только '
  'через booking_validate_discount(); сотрудник правит из админки (RLS booking_is_staff).';
