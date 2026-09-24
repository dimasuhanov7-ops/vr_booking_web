-- =============================================================================
-- Сотрудник видит список сотрудников (имена) — для вкладки «Журнал» в админке:
-- в booking_audit_log лежит только actor_id, имя берётся из booking_staff.
--
-- Раньше каждый видел только свою строку (booking_staff_self_read) — она
-- остаётся для проверки доступа при входе. Анониму таблица по-прежнему закрыта.
-- =============================================================================

drop policy if exists booking_staff_staff_read_all on public.booking_staff;
create policy booking_staff_staff_read_all on public.booking_staff
  for select to authenticated using (public.booking_is_staff());
