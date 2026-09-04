# Интеграция: виджет ↔ бэкенд

Виджет бронирования — **backend-агностик**. Он не знает про Supabase, приложение
или Telegram — он говорит только с одним контрактом «приёма брони». Что стоит за
этим контрактом (Supabase напрямую, Edge Function, API приложения, n8n, бот) —
выбирается конфигом сборки и меняется без правок виджета.

```
КЛИЕНТЫ (сколько угодно, один контракт)
  ┌─ Flutter Web виджет      (BOOKING_BACKEND=api → HTTP на BOOKING_API_BASE)
  ├─ Telegram-бот / Mini App (тот же HTTP-контракт)
  └─ Экран в приложении      (тот же HTTP-контракт)
        │
        ▼
  ТОЧКА ИНТЕГРАЦИИ  —  Supabase Edge Function `booking-intake`
  • валидирует вход
  • вызывает RPC booking_create_order (атомарно, конфликт → 23P01)
  • на успех: уведомление в Telegram-группу персонала (fire-and-forget)
  • [потом] вебхук в приложение / Bukza / что угодно
        │
        ▼
  Supabase Postgres (таблицы booking_*)
```

## Режимы виджета (`--dart-define`)

| define | значения | по умолчанию |
|---|---|---|
| `BOOKING_BACKEND` | `supabase` \| `api` | `supabase` |
| `BOOKING_API_BASE` | URL точки интеграции | `https://<ref>.functions.supabase.co/booking-intake` |
| `BOOKING_API_KEY` | ключ для заголовка `Authorization: Bearer …` | значение `SUPABASE_ANON_KEY` |
| `USE_MOCK` | `true` — in-memory, без сети | — |

- `supabase` — виджет ходит в PostgREST/RPC напрямую (как сейчас). Простейший вариант.
- `api` — виджет ходит **только** на `BOOKING_API_BASE`. Supabase SDK не инициализируется.

Пример сборки под API-режим:
```bash
flutter build web --release \
  --dart-define=BOOKING_BACKEND=api \
  --dart-define=BOOKING_API_BASE=https://cpjmirlujtfuzvdnysyx.functions.supabase.co/booking-intake \
  --dart-define=BOOKING_API_KEY=<anon или отдельный ключ>
```

## HTTP-контракт (`BOOKING_API_BASE` + путь)

Все ответы — JSON. Заголовок `Authorization: Bearer <BOOKING_API_KEY>` обязателен.
CORS: функция отдаёт `Access-Control-Allow-Origin` (по умолчанию `*`) и обрабатывает `OPTIONS`.

### `GET /clubs`
Отсортированы по `sort_order` (меньше — выше).
```json
[{ "id","slug","name","timezone","open_time","close_time","slot_gap_minutes","sort_order" }]
```

### `GET /stations?club_id=<uuid>`
```json
[{ "id","room_id","room_name","type","label","row_index","position_in_row","sort_order","is_active" }]
```

### `GET /prices?club_id=<uuid>`
```json
[{ "station_type","day_kind","price_per_hour" }]
```

### `GET /availability?club_id=<uuid>&day=YYYY-MM-DD`
Занятые интервалы клуба на дату (без ФИО/телефонов):
```json
[{ "station_id","room_id","starts_at","ends_at" }]
```

### `POST /discount/validate`
```json
// body
{ "code": "VRPARTY" | null, "station_count": 6 }
// 200
{ "discount": { "id","code","title","kind","value","min_stations" } | null }
// 422
{ "error": "DISCOUNT_NOT_FOUND" }
{ "error": "DISCOUNT_MIN_STATIONS", "required_stations": 4 }
```

### `POST /reservations`
```json
// body
{
  "club_id": "<uuid>",
  "station_ids": ["<uuid>", ...],
  "starts_at": "2026-09-10T15:00:00Z",
  "minutes": 90,
  "client_name": "Иван",
  "client_phone": "+7 900 000-00-00",
  "people_count": 8,
  "discount_code": null,
  "comment": null,
  "source": "site" | "vk" | "tg" | "app"
}
// 201
{ "order_id": "<uuid>" }
// 409  — слот заняли (Postgres 23P01)
{ "error": "SLOT_TAKEN" }
// 422
{ "error": "OUTSIDE_WORKING_HOURS" | "STARTS_IN_PAST" | "BAD_DURATION" }
{ "error": "DISCOUNT_NOT_FOUND" | "DISCOUNT_MIN_STATIONS", "required_stations": 4 }
```

Маппинг ошибок в виджете (`BookingRepositoryApi`):
`SLOT_TAKEN` → `SlotAlreadyTakenFailure` · `DISCOUNT_NOT_FOUND` → `DiscountNotFoundFailure`
· `DISCOUNT_MIN_STATIONS` → `DiscountMinStationsFailure` · остальное → `BookingWindowFailure` / `BookingUnexpectedFailure`.

## Edge Function `booking-intake`

Код: [`supabase/functions/booking-intake/index.ts`](../supabase/functions/booking-intake/index.ts).
**Задеплоена** на `cpjmirlujtfuzvdnysyx` (2026-09-04, v1, `verify_jwt=true`).
URL: `https://cpjmirlujtfuzvdnysyx.functions.supabase.co/booking-intake`.
Проверены все эндпоинты (clubs/stations/prices/availability/discount/reservations,
конфликт → 409 SLOT_TAKEN, без токена → 401).

Переменные окружения функции:
| var | зачем |
|---|---|
| `SUPABASE_URL` | берётся автоматически |
| `SUPABASE_SERVICE_ROLE_KEY` | берётся автоматически; функция ходит в БД под ним |
| `BOOKING_INTAKE_KEY` | ожидаемый Bearer-ключ (если пусто — принимается любой валидный `anon`/`service`) |
| `BOOKING_CORS_ORIGIN` | `*` или конкретный origin сайта |
| `TELEGRAM_BOT_TOKEN` | токен бота для уведомлений (пусто — уведомления off) |
| `TELEGRAM_CHAT_ID` | id группы/чата персонала |

Деплой (после применения миграции `booking_*`):
```bash
supabase functions deploy booking-intake --project-ref cpjmirlujtfuzvdnysyx
supabase secrets set --project-ref cpjmirlujtfuzvdnysyx \
  TELEGRAM_BOT_TOKEN=... TELEGRAM_CHAT_ID=... BOOKING_CORS_ORIGIN=https://booking.vrclub.example
```

## Telegram

1. **Уведомления персоналу** — внутри `booking-intake` после успешного `POST /reservations`:
   `sendMessage` в `TELEGRAM_CHAT_ID`. Не блокирует бронь (ошибка Telegram → бронь всё равно создана).
   Альтернатива без функции: триггер в БД + `pg_net` → Bot API (см. миграцию, сейчас не включено).

2. **Бронирование через бота** — бот/Mini App это просто ещё один клиент:
   `GET /clubs|/stations|/prices|/availability` для показа, `POST /reservations` с `source: "tg"`.
   Контракт один, отдельная реализация в виджете не нужна.

## Что «независимо», что общее

- **Независимо:** репозиторий (`vr_booking_web`), бандл, деплой, домен. Виджет не
  импортирует ничего из `vr_club_app` и не требует его.
- **Общее (по желанию):** база данных `booking_*`. Приложение может читать брони
  оттуда напрямую — это слабая связь, отдельного API для чтения не нужно.
- **Точка развода:** `booking-intake`. Добавить получателя брони (приложение,
  Bukza, CRM) = дописать один вызов в функции, клиентов не трогать.
