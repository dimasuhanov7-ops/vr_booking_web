# Зеркало броней: Telegram-уведомления и Google Таблица

Функция [`booking-mirror`](../supabase/functions/booking-mirror/index.ts) и миграция
[`20260918120500_online_booking_mirror`](../supabase/migrations/20260918120500_online_booking_mirror.sql).
Обе задеплоены на `cpjmirlujtfuzvdnysyx` (функция — v9, `verify_jwt=false`).

> Этот файл восстановлен по коду функции и миграции, выгруженным с прода
> 2026-09-24: исходные `docs/MIRROR.md` и Apps Script в репозиторий не попали.

## Как это работает

```
booking_orders (insert / update статуса, имени, телефона, комментария,
                предоплаты, числа людей)
   └─ триггер booking_orders_mirror
        └─ booking_mirror_call() → pg_net POST …/functions/v1/booking-mirror
             {"order_id": "…"}, заголовок x-mirror-secret
pg_cron «booking-mirror-resync», 22:00 UTC (03:00 по Перми)
   └─ booking_mirror_call({"mode": "resync"})
```

- Источник не важен: бронь из виджета, из админки или через `booking-intake`
  проходит через один и тот же триггер. Поэтому `booking-intake` сама больше
  ничего в Telegram не шлёт.
- Функция берёт из тела только `order_id` и сама перечитывает заказ из базы.
- Вызов подписан секретом `booking_mirror_secret` из Vault. Миграция создаёт его
  сама, функция читает его через `booking_mirror_secret()` (только `service_role`).
- Функция отвечает `202` сразу, а работу доделывает в фоне (`EdgeRuntime.waitUntil`),
  так что pg_net не ждёт ответа Google.

## Telegram

Сообщения приходят на смену статуса: «Новая бронь», «Бронь отменена»,
«Бронь возвращена». Повторы отсекает `booking_mirror_claim_notice()`: в таблице
`booking_mirror_state` хранится последний статус, о котором уже написали.
Имя, телефон и комментарий экранируются (`parse_mode: HTML`). Время выводится
в таймзоне клуба (`booking_clubs.timezone`, сейчас `Asia/Yekaterinburg`, то есть Пермь).

## Google Таблица

Строку по заказу пишет (upsert по ID) веб-приложение Apps Script внутри самой
таблицы, без Google Cloud и сервисного аккаунта. Раз в сутки идёт полная
пересинхронизация (`mode: "resync"`, до 5000 заказов).

Колонки в порядке `row()` в функции: дата, время, клуб, состав (+ пакет), имя,
телефон, людей, статус, источник, стоимость, предоплата, комментарий, создана,
синхронизирована, ID заказа.

⚠️ Код Apps Script (`tool/google_apps_script/booking_mirror.gs`) в репозитории
отсутствует. Его можно выгрузить из самой таблицы: «Расширения → Apps Script».
Положите его в `tool/google_apps_script/`, чтобы он не потерялся.

## Секреты функции

Supabase → Edge Functions → Secrets:

| Секрет | Зачем |
|---|---|
| `GOOGLE_SCRIPT_URL` | адрес веб-приложения Apps Script (`https://script.google.com/…/exec`) |
| `GOOGLE_SCRIPT_SECRET` | секрет из `setupSecret()` в скрипте |
| `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` | бот и служебный чат |
| `TELEGRAM_THREAD_ID` | необязательно: тема в группе с темами |

Без Google-секретов таблица не ведётся, без Telegram нет уведомлений. Одно работает
без другого.

## Зависимости базы

`pg_net`, `pg_cron`, `supabase_vault` и `pgcrypto` (`extensions.gen_random_bytes`)
на проде включены. Для нового окружения их нужно включить до миграции
`…_online_booking_mirror`. Адрес функции в `booking_mirror_call()` зашит под
проект `cpjmirlujtfuzvdnysyx`.
