# vr_booking_web — хэндофф для следующего агента

> Прочитай этот файл целиком перед работой. Затем открой `design/DESIGN_SPEC.md`
> и вызови скилл `flutter-dev` (стандарты Friflex — им следует весь код).
>
> **Следующая задача** — раздел «Админка» (`/admin`): подробный промт в
> [`docs/ADMIN_TASK.md`](docs/ADMIN_TASK.md).

## Что это

Отдельный **публичный Flutter Web виджет онлайн-бронирования** VR-клубов
**Effect VR** и **V-Ray**. Встраивается iframe'ом в сообщество ВК и на сайт клуба,
без авторизации персонала. Backend — тот же Supabase, что и у внутреннего
менеджера, но новые таблицы (см. ниже).

Это **не** внутренний менеджер персонала. Тот — отдельное приложение в
`C:\Users\User\Downloads\vr_club_app\vr_club_app` (плоская структура, не трогать).

## Источник истины по дизайну

Дизайн согласован и лежит в `design/`:
- `design/DESIGN_SPEC.md` — токены (цвета, шрифт Archivo, радиусы), структура
  экрана, все состояния, **таблица расхождений с ТЗ**;
- `design/booking-widget.template.html` — разметка макета ({{ }}-биндинги);
- `design/booking-widget.logic.js` — логика прототипа: цвета всех состояний
  (свободно/занято/выбрано), цены, конфликт брони, «Всё занято».

Оригинал в Claude Design: проект `8d5d5ffe-dca2-44b9-9385-3fac38fbaae5`,
файл «Виджет бронирования VR.dc.html» (у владельца — dima.suhanov7@gmail.com).

## Решения заказчика (зафиксированы)

| Тема | Решение |
|---|---|
| Длительности сеанса | **60 / 90 / 120 / 180** мин. Шаг сетки = длительность + пауза клуба (Effect 10 мин, V-Ray 0). |
| Цены | В БД (`booking_prices`), редактируются без миграций. Сейчас: VR **600 ₽/ч** будни / **1000 ₽/ч** выходные; PS5 **300** / **400**. Одинаково для обоих клубов. Оплата на месте, суммы в виджете справочные. |
| Залы V-Ray | «Большой зал» (12 VR), «Малый зал» (4 VR + 2 PS5) + вариант **«Весь клуб»** — одна бронь на станции из обоих залов. Effect VR — один зал «Зал» (4 VR + 2 PS5). |
| Часы | Effect **11:00–22:30**, V-Ray **11:00–23:00**, TZ Europe/Moscow. |
| Скидки | **Пока без UI.** Инфраструктура в БД (`booking_discounts`, RPC `booking_validate_discount`) оставлена на будущее, данных нет, поле промокода в виджете не показывается. |
| Выходные | сб + вс (по дате брони в TZ клуба). |

## Состояние (что сделано)

### Backend
`supabase/migrations/20260903120000_online_booking_feature.sql` — **НЕ ПРИМЕНЁН.**
Заказчик хочет ревью SQL перед применением. Таблицы с префиксом `booking_` в
схеме `public` (чтобы не конфликтовать с существующей `public.bookings` —
зеркало Bukza, на которое подписан realtime в менеджере).

Применить: `supabase db push` **или** MCP `apply_migration` в проект
`cpjmirlujtfuzvdnysyx` («Vray/Effect info», продакшн) — только после «ок» заказчика.
После применения: `get_advisors` (security + performance), затем убрать
`--dart-define=USE_MOCK=true` и проверить со всеми боевыми ключами.

Объекты миграции: `booking_clubs`, `booking_rooms`, `booking_stations`
(с `row_index`/`position_in_row`), `booking_prices`, `booking_discounts`,
`booking_orders` (с `people_count`), `booking_order_items` (с `price`,
EXCLUDE-констрейнт `booking_no_overlapping_items` → SQLSTATE `23P01`).
RPC: `booking_busy_intervals(club_id, day)`, `booking_quote(...)`,
`booking_validate_discount(...)`, `booking_create_order(...)`. RLS: публичное
чтение справочника + тарифов; анонимная вставка брони только в будущее,
60/90/120/180 мин и в рабочие часы.

### Flutter
Слои `data / domain / presentation` в `lib/features/booking/` по стандартам Friflex.
`flutter analyze` — чисто, `flutter test` — 3 теста проходят,
`flutter build web` собирается.

- **data**: DTO под таблицы/RPC, `BookingRepository` (Supabase) +
  `BookingRepositoryMock` (демо-данные = сид миграции).
- **domain**: сущности; `IBookingRepository`; сервисы `SlotGeneratorService`
  (шаг = длительность+пауза), `PricingService` (будни/выходные, per-hour),
  `ClubClock` (TZ-перевод, фикс. смещение Москвы +3); `BookingBloc` — один
  прокручиваемый экран, шаг 1..4 выводится из состояния (клуб / слот / станции).
- **presentation**: `BookingScreen` + `BookingView`; компоненты
  `ClubSelector`, `HallSelector` (+ пунктирный чип «Весь клуб»), `DateField` +
  `CalendarSheet` (месяц-сетка), `DurationSelector`, `SlotGrid` (время + точки),
  `HallPlan` (ряды станций, «Взять сразу», легенда), `ContactForm`
  (маска телефона), `BookingBottomBar` (липкий итог + CTA), `ConflictBanner`,
  `EmptyDayState`, `SuccessView` (чек).

Тема: `lib/app/theme/app_theme.dart` — `BookingColors` со всеми токенами,
акцент по клубу (`accentFor(slug)`: Effect лайм `#A9F04A`, V-Ray изумруд `#0FB981`).
Шрифт Archivo забандлен в `assets/fonts/`.

### Конфликт брони (23P01)
`BookingBloc._handleConflict`: при `SlotAlreadyTakenFailure` перезагружает
занятость, вычисляет какие выбранные станции заняли (`takenIds`), убирает их из
выбора, показывает `ConflictBanner` с заменой из того же зала. Остальной выбор
сохраняется.

## Как запустить (демо без БД)

```bash
cd C:\Sait\vr_booking_web
flutter run -d chrome --dart-define=USE_MOCK=true
```

Или превью-сервер (для агента): в `C:\Sait\.claude\launch.json` есть конфиг
`booking-web-mock` (python http.server раздаёт `build/web`). Перед превью:
`flutter build web --dart-define=USE_MOCK=true --no-tree-shake-icons`.
⚠️ Браузер агрессивно кэширует `main.dart.js` — после ребилда делай hard-reload.

Продакшн-сборка:
```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://cpjmirlujtfuzvdnysyx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable key>
```

## TODO / полировка (по убыванию важности)

1. **Ревью и применение миграции** (ждёт заказчика).
2. На выбранной (лаймовой) карточке клуба текст «Ежедневно 11:00–22:30» плохо
   читается — поднять контраст в `club_selector.dart`.
3. Проверить сквозной сценарий на реальной БД: выбор станций, конфликт (две
   вкладки), «Весь клуб» для V-Ray, цены будни/выходные.
4. Десктопная ширина: сейчас фрейм фиксирован `maxWidth: 460`
   (`booking_view.dart` `_Frame`). Макет: моб. 412 / десктоп 760 — при желании
   сделать адаптивным.
5. Липкость нижнего бара: сейчас это просто нижний элемент фрейма (не
   `position: sticky`). Для standalone-десктопа можно доработать.
6. Realtime-уведомление менеджера о новой брони: сейчас `main.dart` менеджера
   слушает `public.bookings` (Bukza). Новые брони пишутся в `booking_orders` —
   решить, добавлять ли триггер/подписку (вне текущего скоупа).
7. `booking_quote` RPC создан, но виджет считает цену на клиенте через
   `PricingService` + `fetchPrices`. RPC можно задействовать или удалить.
8. VK Mini App: `BookingApp._source` определяет `vk` по query `vk_app_id` /
   `?source=vk`. Реальную интеграцию VK Bridge не делали.
9. Коммиты — Conventional Commits на русском (стандарт Friflex).

## Что осталось за скоупом
Онлайн-оплата (по ТЗ не нужна); админка броней для персонала; реальная VK Bridge
интеграция; скидки в UI; локализация кроме ru.
