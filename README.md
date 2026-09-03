# VR Booking Web

Публичный виджет онлайн-бронирования VR-клубов **Effect VR** и **V-Ray**.
Отдельное Flutter Web приложение, встраивается iframe'ом на сайт клуба и в VK Mini Apps.
Backend — Supabase (проект `cpjmirlujtfuzvdnysyx`).

📄 **Начни с [`HANDOFF.md`](HANDOFF.md)** — там полный контекст, решения заказчика и TODO.
🎨 Дизайн-эталон — в [`design/`](design/) (`DESIGN_SPEC.md` + разметка/логика прототипа).

## Архитектура

Фича `booking` по слоям Friflex (`data` / `domain` / `presentation`) в
`lib/features/booking/`. Стандарты — скилл `flutter-dev`.

```
lib/
  app/           конфиг, тема (Archivo, лайм/изумруд), корневой виджет
  di/            контейнер зависимостей (Supabase или mock — по флагу сборки)
  features/booking/
    data/        DTO + BookingRepository (Supabase) + BookingRepositoryMock
    domain/      сущности, IBookingRepository, сервисы (слоты/цены/TZ), BookingBloc
    presentation/ BookingScreen + BookingView + компоненты
```

## Backend

Миграция: [`supabase/migrations/20260903120000_online_booking_feature.sql`](supabase/migrations/20260903120000_online_booking_feature.sql)
— **не применена**, ждёт ревью. Таблицы с префиксом `booking_` в схеме `public`.

Применение: `supabase db push` (или через Supabase MCP `apply_migration`).

## Запуск

Демо на моковых данных (без БД):

```bash
flutter run -d chrome --dart-define=USE_MOCK=true
```

Продакшн:

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://cpjmirlujtfuzvdnysyx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable key>
```

## Встраивание

```html
<iframe src="https://booking.vrclub.example/" style="width:100%;border:0" title="Бронирование VR"></iframe>
```

`web/index.html` шлёт родителю `postMessage({type:'vr-booking:height', height})` —
хост может подгонять высоту iframe. Источник брони (`site` / `vk`) определяется
по query-параметрам (`vk_app_id` / `?source=vk`).
