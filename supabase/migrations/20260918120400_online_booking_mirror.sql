-- Зеркало броней: Google Таблица + уведомления в служебный Telegram-чат.
--
-- На каждую новую бронь, отмену и правку триггер асинхронно (pg_net) вызывает
-- Edge Function `booking-mirror`. Бронь клиента вызова не ждёт и не падает,
-- даже если Google или Telegram недоступны. Раз в сутки pg_cron просит функцию
-- досинхронизировать всё, что не доехало. Настройка — docs/MIRROR.md.

-- Что уже ушло наружу: о каком статусе написали в Telegram и когда строка
-- последний раз попала в таблицу. Нужно, чтобы повторы не давали дублей.
create table if not exists public.booking_mirror_state (
  order_id        uuid primary key references public.booking_orders(id) on delete cascade,
  notified_status text,
  synced_at       timestamptz
);
alter table public.booking_mirror_state enable row level security;
-- Политик нет намеренно: читает и пишет только функция с service role.
revoke all on public.booking_mirror_state from anon, authenticated;

-- Секрет вызова функции генерируется в базе и хранится в Vault — вводить его
-- руками никому не нужно.
select vault.create_secret(
  encode(extensions.gen_random_bytes(32), 'hex'),
  'booking_mirror_secret',
  'Подпись вызова Edge Function booking-mirror из базы'
)
where not exists (select 1 from vault.secrets where name = 'booking_mirror_secret');

-- Секрет для проверки на стороне функции — только service role.
create or replace function public.booking_mirror_secret()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select decrypted_secret from vault.decrypted_secrets
  where name = 'booking_mirror_secret'
  limit 1;
$$;
revoke all on function public.booking_mirror_secret() from public, anon, authenticated;
grant execute on function public.booking_mirror_secret() to service_role;

-- «Занять» отправку уведомления о статусе заказа. Возвращает прошлый
-- отправленный статус ('' — ещё ничего не отправляли) или null, если об этом
-- статусе уже написали. Атомарно: два одновременных вызова не отправят дважды.
create or replace function public.booking_mirror_claim_notice(p_order_id uuid, p_status text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_prev text;
begin
  select notified_status into v_prev
  from public.booking_mirror_state
  where order_id = p_order_id
  for update;

  if found then
    if v_prev is not distinct from p_status then
      return null;
    end if;
    update public.booking_mirror_state
    set notified_status = p_status
    where order_id = p_order_id;
    return coalesce(v_prev, '');
  end if;

  insert into public.booking_mirror_state (order_id, notified_status)
  values (p_order_id, p_status)
  on conflict (order_id) do nothing;
  if not found then
    -- Параллельный вызов успел раньше — он и отправит.
    return null;
  end if;
  return '';
end;
$$;
revoke all on function public.booking_mirror_claim_notice(uuid, text) from public, anon, authenticated;
grant execute on function public.booking_mirror_claim_notice(uuid, text) to service_role;

-- Асинхронный вызов функции. Без секрета в Vault молча ничего не делает.
create or replace function public.booking_mirror_call(p_body jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_secret text;
begin
  select decrypted_secret into v_secret
  from vault.decrypted_secrets
  where name = 'booking_mirror_secret'
  limit 1;
  if v_secret is null then
    return;
  end if;

  perform net.http_post(
    url := 'https://cpjmirlujtfuzvdnysyx.supabase.co/functions/v1/booking-mirror',
    body := p_body,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-mirror-secret', v_secret
    ),
    timeout_milliseconds := 10000
  );
end;
$$;
revoke all on function public.booking_mirror_call(jsonb) from public, anon, authenticated;

create or replace function public.booking_mirror_on_order()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.booking_mirror_call(jsonb_build_object('order_id', new.id));
  return null;
exception when others then
  -- Зеркало не должно ломать бронь ни при каких обстоятельствах.
  return null;
end;
$$;
revoke all on function public.booking_mirror_on_order() from public, anon, authenticated;

drop trigger if exists booking_orders_mirror on public.booking_orders;
create trigger booking_orders_mirror
  after insert or update of status, client_name, client_phone, comment, prepay, people_count
  on public.booking_orders
  for each row
  execute function public.booking_mirror_on_order();

-- Ночная досинхронизация: 22:00 UTC = 03:00 по Перми.
select cron.schedule(
  'booking-mirror-resync',
  '0 22 * * *',
  $cmd$select public.booking_mirror_call('{"mode":"resync"}'::jsonb);$cmd$
);
