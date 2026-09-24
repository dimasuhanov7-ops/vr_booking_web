-- =============================================================================
-- Журнал действий персонала (booking_audit_log).
--
-- Сейчас нельзя ответить на вопрос «кто отменил эту бронь» или «кто поднял
-- цену»: правки идут от лица сотрудника, но следа не оставляют. Для клуба, где
-- админкой пользуются несколько человек, это ежедневный источник споров.
--
-- Пишем только изменения справочников и статусов — то, что делает персонал.
-- Создание брони клиентом не логируем: она и так видна в booking_orders.
-- =============================================================================

create table if not exists public.booking_audit_log (
  id          bigint generated always as identity primary key,
  actor_id    uuid references auth.users(id) on delete set null,
  entity      text not null,
  entity_id   uuid,
  action      text not null check (action in ('insert', 'update', 'delete')),
  before      jsonb,
  after       jsonb,
  created_at  timestamptz not null default now()
);

comment on table public.booking_audit_log is
  'Кто и что менял в админке бронирования. actor_id null — действие анонима '
  '(создание брони клиентом) или системный вызов.';

create index if not exists booking_audit_log_created_idx
  on public.booking_audit_log (created_at desc);
create index if not exists booking_audit_log_entity_idx
  on public.booking_audit_log (entity, entity_id);

alter table public.booking_audit_log enable row level security;

-- Сотрудник читает журнал; писать в него напрямую нельзя никому — только
-- триггером (SECURITY DEFINER), чтобы запись нельзя было подделать.
drop policy if exists booking_audit_log_staff_read on public.booking_audit_log;
create policy booking_audit_log_staff_read on public.booking_audit_log
  for select to authenticated using (public.booking_is_staff());

create or replace function public.booking_write_audit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_before jsonb;
  v_after  jsonb;
begin
  if tg_op = 'DELETE' then
    v_before := to_jsonb(old);
  elsif tg_op = 'INSERT' then
    v_after := to_jsonb(new);
  else
    v_before := to_jsonb(old);
    v_after  := to_jsonb(new);
    -- Ничего по сути не изменилось — не засоряем журнал.
    if v_before = v_after then
      return new;
    end if;
  end if;

  insert into public.booking_audit_log (
    actor_id, entity, entity_id, action, before, after
  )
  values (
    auth.uid(),
    tg_table_name,
    coalesce((v_after ->> 'id')::uuid, (v_before ->> 'id')::uuid),
    lower(tg_op),
    v_before,
    v_after
  );

  return coalesce(new, old);
end;
$$;

revoke all on function public.booking_write_audit() from public, anon, authenticated;

comment on function public.booking_write_audit is
  'Триггерная функция журнала. Вызывается только из триггеров, напрямую недоступна.';

-- ---- Триггеры ---------------------------------------------------------------
-- Цены и пакеты: любое изменение.
drop trigger if exists booking_prices_audit on public.booking_prices;
create trigger booking_prices_audit
  after insert or update or delete on public.booking_prices
  for each row execute function public.booking_write_audit();

drop trigger if exists booking_packages_audit on public.booking_packages;
create trigger booking_packages_audit
  after insert or update or delete on public.booking_packages
  for each row execute function public.booking_write_audit();

-- Доступность: закрытия залов и окон.
drop trigger if exists booking_availability_audit on public.booking_availability;
create trigger booking_availability_audit
  after insert or update or delete on public.booking_availability
  for each row execute function public.booking_write_audit();

-- Клуб: часы работы и пауза приёма.
drop trigger if exists booking_clubs_audit on public.booking_clubs;
create trigger booking_clubs_audit
  after update on public.booking_clubs
  for each row execute function public.booking_write_audit();

-- Брони: только смена статуса (отмена/возврат). Создание не логируем —
-- иначе журнал забьётся обычными бронями клиентов.
drop trigger if exists booking_orders_status_audit on public.booking_orders;
create trigger booking_orders_status_audit
  after update of status on public.booking_orders
  for each row execute function public.booking_write_audit();
