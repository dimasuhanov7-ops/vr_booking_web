# vr_booking_web — хэндофф для следующего агента

> Прочитай этот файл целиком перед работой. Затем открой `design/DESIGN_SPEC.md`
> и вызови скилл `flutter-dev` (стандарты Friflex — им следует весь код).
>
> **Раздел «Админка»** (`?admin=1`) — работает на реальной БД (Supabase Auth +
> `booking_staff`). Контекст: [`docs/ADMIN_TASK.md`](docs/ADMIN_TASK.md),
> [`design/ADMIN_DESIGN_SPEC.md`](design/ADMIN_DESIGN_SPEC.md).

## ⚡ Состояние на 2026-09-24 — читать первым

**Источник истины — прод `cpjmirlujtfuzvdnysyx`.** Работа 10–18 сентября
(часть миграций и функций) была применена к проду, но в GitHub не попала.
24.09 недостающее выгружено с прода в репозиторий:

- **Миграции.** Все 23 миграции `online_booking_*` из журнала прода есть в
  `supabase/migrations/`, **имя файла = версия и имя на проде** (выровнено
  24.09). Восемь файлов, выгруженных с прода, совпадают с ним побайтно (md5
  по `supabase_migrations.schema_migrations`); остальные по коду совпадают с
  применёнными, расходятся только комментарии. `…_feature` правили после
  применения (там уже `btree_gist` в `extensions`, `sort_order`, revoke) —
  итоговое состояние то же. В SQL-комментариях старых файлов остались прежние
  имена соседних миграций — это история, содержимое не трогали.

  **`supabase db push` здесь не работает и не нужен:** база общая с
  приложением менеджера `vr_club_app`, его миграции (смены, пуши и т. п.) тоже
  в журнале, а в этой папке их нет — CLI откажется. Новую миграцию применять
  через Supabase MCP `apply_migration` (или SQL-редактор); сервер присвоит ей
  версию-время применения — после этого **переименуйте файл под эту версию**
  (`list_migrations`), чтобы репозиторий и журнал не разъезжались снова.
- **Edge Functions.** `booking-intake` в репозитории = задеплоенная v11 (без
  Telegram). `booking-mirror` (v9) добавлена — уведомления в Telegram и Google
  Таблица по триггеру, см. [`docs/MIRROR.md`](docs/MIRROR.md). Apps Script
  таблицы в репозиторий так и не попал — выгрузить из таблицы.
- **Таймзона — Пермь** (`Asia/Yekaterinburg`, UTC+5) у обоих клубов. Клиент
  берёт её из `booking_clubs.timezone`; админка тоже (раньше была зашита
  Москва +3, и все брони в ней съезжали на 2 часа).
- **Запись закрывается за 30 минут** до начала (кроме персонала):
  `TOO_LATE_TO_BOOK` в RPC, виджет такие слоты не показывает.
- **Ступени цен** (`booking_prices.min_qty`): «до N станций одна цена, дальше
  другая». Виджет считает так же, как `booking_station_price`; админка правит
  только базовую ступень `min_qty = 1`. Сейчас на проде ступеней нет.
- **Арена V-Ray** — два ряда по 6 шлемов.
- **Предоплата** — `booking_orders.prepay`.

Админка (сделано 24.09): «Новая запись» создаёт бронь в БД через
`booking_create_order` (от сотрудника: без лимитов и паузы, `source=staff`);
карточка брони сохраняет имя/телефон/предоплату/комментарий по «Сохранить»;
время и состав брони в боевой сборке не редактируются — позиции брони
сотруднику по RLS только читаются (нужна RPC, если это понадобится); вход
проверяет `booking_is_staff()`; ошибка загрузки — экран с «Повторить»/«Выйти»;
пакет с бронями выключается вместо удаления.

Не восстановлено: Flutter-код после 09.09, если он менялся (с прода его не
достать — там только собранный бандл). Например, под миграцию `admin_realtime`
в админке нет подписки на Realtime — данные обновляются только при загрузке
страницы.

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
| Длительности сеанса | **60 / 120 / 180 / 240** мин (1,5 ч нет, есть 4 ч). Шаг сетки = длительность + пауза клуба (Effect 10 мин, V-Ray 0). Зашито в RLS/RPC — миграция `20260908191029_online_booking_durations`. |
| Цены | В БД (`booking_prices`), редактируются из админки. На проде (24.09): VR **800 ₽/ч** будни / **1200 ₽/ч** выходные; PS5 **300** / **400**. Одинаково для обоих клубов. Возможны ступени «от N станций» (`min_qty`). Оплата на месте, суммы в виджете справочные. |
| Залы V-Ray | «Большой зал» (12 VR), «Малый зал» (4 VR + 2 PS5) + вариант **«Весь клуб»** — одна бронь на станции из обоих залов. Effect VR — один зал «Зал» (4 VR + 2 PS5). |
| Часы | Effect **11:00–22:30**, V-Ray **11:00–23:00**, TZ **Asia/Yekaterinburg** (Пермь, UTC+5). |
| Скидки | **Пока без UI.** Инфраструктура в БД (`booking_discounts`, RPC `booking_validate_discount`) оставлена на будущее, данных нет, поле промокода в виджете не показывается. |
| Выходные | сб + вс (по дате брони в TZ клуба). |

## Состояние (что сделано)

### Backend
**Миграции ПРИМЕНЕНЫ к проекту `cpjmirlujtfuzvdnysyx` (продакшн) 2026-09-04:**
`20260904081507_online_booking_feature` + `..._harden_privileges` + `..._unexpose_quote`
+ `20260904083849_online_booking_clubs_sort_order`.

✅ **Применены 2026-09-09** (через MCP `apply_migration`, см. раздел
«Состояние прода» выше): `20260908191029_online_booking_durations`,
`20260908191137_online_booking_packages`, `20260908191216_online_booking_staff_auth`,
`20260908191300_online_booking_hourly_segments`,
`20260908191400_online_booking_lockdown`,
`20260908191609_online_booking_revoke_is_staff_anon`.
Edge Function `booking-intake` передеплоена (v3).

- ⚠️ **Цены пакетов из макета не бьются с тарифами в БД.** Макет: VR 1400 ₽/ч,
  пакет «Компания» 10000 (дешевле почасовой 11200). БД: VR 600 ₽/ч → почасовая
  4800, пакет 10000 — вдвое дороже. Нужно решение: поднять тарифы, снизить цены
  пакетов или редактировать их в админке. Виджет технически работает: выбор пакета
  фиксирует итог его ценой (скидка показывается только если пакет дешевле).
Таблицы `booking_*` в схеме `public` (не конфликтуют с `public.bookings` — зеркало Bukza).
Сид: 2 клуба, 3 зала, 24 станции, 8 тарифов, 0 скидок. Проверено сквозным тестом
(бронь, конфликт 23P01, отмена освобождает слот, рабочие часы, расчёт цены).

Правки после ревью: `btree_gist` → схема `extensions`; `is_active` на
`booking_order_items` + триггер (отменённая бронь освобождает слот, EXCLUDE частичный);
`source` расширен на `tg`/`app`; helper-функции и `booking_quote` сняты с публичного
API (revoke); FK-индексы. `get_advisors` — на объектах фичи остаётся только намеренное:
RLS-без-политик на `booking_discounts` (INFO) и SECURITY DEFINER на 3 публичных RPC (WARN).

Дальше: убрать `--dart-define=USE_MOCK=true`, собрать с боевыми ключами, проверить
виджет на реальной БД. Деплой Edge Function `booking-intake` (см. INTEGRATION.md).

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
  `ClubClock` (TZ-перевод, фикс. смещение по таймзоне клуба, Пермь +5); `BookingBloc` — один
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

## Редизайн виджета (Claude Design 2026-09-07) — статус

Слои `data/domain/presentation` перекроены под новый макет
([`design/DESIGN_SPEC.md §0`](design/DESIGN_SPEC.md)):
1. ✅ Десктоп 2 колонки (≥860px), `_frameWide` 1000px, заглушка правой колонки.
2. ✅ Карточки-поля (`FieldCard`) для даты/длительности + строки тарифа.
3. ✅ Пакеты (`booking_packages`; `PackageCards`).
4. ✅ Аккаунт по телефону (`AccountBlock` + localStorage).
5. ✅ Чек с пунктирными разделителями (`DashedDivider` в `success_view`).
Слоты/план зала уже были по макету.

## Встраивание в `<iframe>` — [`docs/EMBED.md`](docs/EMBED.md)

Публичный контракт для сайтов клубов (`effectvr.ru`, `vrayarena.ru`) и VK.
Разбор query — `lib/app/embed/launch_params.dart`; общение с родителем —
`lib/app/embed/embed_channel.dart` + `web/index.html`.

- **URL-параметры:** `?club=effect|vray` (фикс. клуб, мастер из 3 шагов),
  `?source=site|vk`, `?date=YYYY-MM-DD`, `?duration=60|120|180|240`, `?admin=1`.
- **Сообщения родителю** (`postMessage`, префикс `vr-booking:`): `ready`,
  `height` (авто-высота iframe, дебаунс), `step`, `success`
  (`{orderId, club, stationCount, minutes, amount}` — для целей в Метрике).
- Модель: iframe тянется по контенту, скроллит родительская страница.

## Раздел «Админка» (`?admin=1`)

`lib/features/admin/` — та же слоёная структура. Полноширинная панель персонала:
вкладки **Цены · Пакеты · Доступность · Брони · Записи**, переключатель клуба,
все расчёты («по часам», KPI, суммы) реактивны от вкладки «Цены». Данные —
`AdminRepositoryMock` в демо-сборке, `AdminRepository` (Supabase) в боевой.
Роутинг — `BookingApp._isAdmin` по query `?admin=1` (без пакета роутинга).

### Авторизация (сделано)
`?admin=1` за `AdminAuthGate`: в `USE_MOCK` — открывается сразу (демо), иначе —
экран входа `AdminLoginScreen` (Supabase Auth email+пароль). Кнопка «Выйти» в
шапке. `Injection.init(adminMode:)` поднимает Supabase SDK и в api-сборке.
Миграция `20260908191216_online_booking_staff_auth` (применена):
таблица `booking_staff` (allowlist по `auth.users.id`), функция
`booking_is_staff()`, RLS-политики write для персонала на `booking_prices`,
`booking_packages`, `booking_clubs` (update), `booking_orders` (read+update),
`booking_order_items` (read). Аккаунты создаются вручную в Supabase → строка в
`booking_staff`.

### Реальный AdminRepository (сделано, требует применённых миграций)
`AdminRepository` (Supabase) — при входе сотрудника вместо `AdminRepositoryMock`
(`Injection`: mock только в `USE_MOCK`). Читает `booking_clubs`/`rooms`/`stations`
/`prices`/`packages`/`orders`+`order_items`. Пишет:
- **цены** — `AdminPriceChanged` → update `booking_prices` (по клубу; правка
  одного зала распространяется на все залы клуба, т.к. в БД цены клубовые);
- **пакеты** — создание / правка полей / вкл-выкл / удаление → CRUD `booking_packages`;
- **отмена брони** — `AdminRowCancelToggled` → `booking_orders.status`
  (`cancelled`/`confirmed`), триггер освобождает слот.
Ошибка записи → плашка `state.saveError` в шапке вкладки.

Доступность (пауза приёма, закрытые залы и окна) пишется в `booking_clubs.intake_open`
и `booking_availability`. Новая запись, карточка брони, проверка сотрудника — см.
«Состояние на 2026-09-24» вверху. **Осталось:** редактирование часов работы
клуба; перенос/смена состава существующей брони (нужна RPC).

## Слой интеграции (виджет ↔ бэкенд)

Виджет **backend-агностик**: домен знает только `IBookingRepository`. Реализации:
- `BookingRepositoryMock` — `--dart-define=USE_MOCK=true`
- `BookingRepository` — Supabase PostgREST/RPC напрямую (по умолчанию)
- `BookingRepositoryApi` — HTTP-контракт «приёма брони», `--dart-define=BOOKING_BACKEND=api`
  + `BOOKING_API_BASE=<url>` + `BOOKING_API_KEY=<key>`

Точка развода — Supabase Edge Function [`supabase/functions/booking-intake/index.ts`](supabase/functions/booking-intake/index.ts)
— **задеплоена** на `cpjmirlujtfuzvdnysyx` (v11, `verify_jwt=true`), URL
`https://cpjmirlujtfuzvdnysyx.functions.supabase.co/booking-intake`. Принимает
бронь и вызывает `booking_create_order`. Telegram-бот = ещё один клиент того же
контракта. Описание — [`docs/INTEGRATION.md`](docs/INTEGRATION.md).

Уведомления в Telegram и Google Таблица — отдельная функция `booking-mirror` по
триггеру на `booking_orders`, для всех источников: [`docs/MIRROR.md`](docs/MIRROR.md).
Чтобы переключить виджет на функцию: собрать с `--dart-define=BOOKING_BACKEND=api`.

## Как запустить (демо без БД)

```bash
cd C:\Sait\vr_booking_web
flutter run -d chrome --dart-define=USE_MOCK=true
# виджет бронирования: обычный URL; админка: добавить ?admin=1
```

Или превью-сервер (для агента): в `C:\Sait\.claude\launch.json` есть конфиг
`booking-web-mock` (python http.server раздаёт `build/web`). Перед превью:
`flutter build web --dart-define=USE_MOCK=true --no-tree-shake-icons`.
⚠️ Браузер агрессивно кэширует `main.dart.js` — после ребилда делай hard-reload.

Продакшн-сборка и деплой — [`docs/DEPLOY.md`](docs/DEPLOY.md). Кратко:
```bash
FLUTTER=/c/vr_club_app/flutter/bin/flutter tool/build_web.sh
# -> build/web + build/vr_booking_web.zip ; залить содержимое на поддомен booking.<клуб>.ru
```
Хостинг — поддомен на инфраструктуре сайта клуба (**не Cloudflare** — РКН).
Виджет собирается в **api-режиме** (`BOOKING_BACKEND=api`) — ходит только в
Edge Function `booking-intake` напрямую (`supabase.co` доступен из РФ),
Supabase SDK не инициализируется.

## Разное число станций по часам (2026-09-10)

Одна бронь может держать разный состав в разные часы (12 шлемов в первый час,
6 во второй).

- **Виджет:** при сеансе > 1 ч под планом зала — вкладки «1-й час / 2-й час / …»,
  в каждой свой выбор станций, «как в 1-м часе». Модель — `BookingState.pickedByHour`
  (Map<час, Set<станция>> с наследованием). Цена — по суммарному времени каждой станции.
- **Админка:** в сетке «Занятость по часам» бронь «сужается» по столбцам;
  drawer «Новая запись» — состав на каждый час.
- **Бэкенд:** бронь уходит «отрезками» — `ReservationSegmentEntity` →
  `p_segments jsonb` в `booking_create_order`. Миграция
  **`20260908191300_online_booking_hourly_segments.sql` — НЕ ПРИМЕНЕНА**;
  после неё передеплоить `booking-intake` (Edge Function уже обновлена, принимает
  и `segments`, и старый плоский формат).
- **Осталось:** правка состава по часам в карточке брони (`booking_detail_drawer`)
  сейчас упрощена — правит состав сразу на весь сеанс.

## ⚠️ Состояние прода на 2026-09-09

**Все миграции применены, Edge Function задеплоена (v3).** База
`cpjmirlujtfuzvdnysyx` содержит полную схему бронирования.

> **Версии в удалённой истории не совпадают с именами файлов.** Миграции
> применялись через MCP `apply_migration`, который присваивает версию по дате
> применения: файл `20260908191029_online_booking_durations.sql` записан как
> `20260908191029_online_booking_durations`. **`supabase db push` использовать
> нельзя** — он посчитает локальные файлы неприменёнными и попытается накатить
> их повторно. Новые миграции применять через MCP или SQL Editor.

Проверено на проде живыми запросами:

| Проверка | Результат |
|---|---|
| `GET /clubs`, `GET /packages` | 200, сид на месте |
| Прямой `INSERT` анонимом в `booking_orders` | `42501 permission denied` |
| Прямой `INSERT` в `booking_order_items` | `42501 permission denied` |
| `booking_is_staff()` анонимом | `42501 permission denied` |
| Чтение ФИО/телефонов анонимом | `[]` — пусто |
| Телефон короче 10 цифр | `BAD_PHONE` 422 |
| Больше 5 отрезков в брони | `BAD_DURATION` 422 |
| Пустой `segments` | `NO_STATIONS` 422 |

**Сквозной сценарий проверен на реальной базе 2026-09-09** (сборка
`--dart-define=BOOKING_BACKEND=api`, без моков): V-Ray → Большой зал →
2 ч → слот 19:00 → 4 шлема в первый час, 2 во второй → бронь создана.
В БД легли два отрезка (19:00–20:00 на #1–#4 и 20:00–21:00 на #1–#2),
чек показал 3 600 ₽ с правильной разбивкой. Тестовая бронь отменена,
триггер снял `is_active` — слот освободился. Проверены также `?club=vray`
и `?duration=120`, пакеты и тарифы приходят из БД.

**Осталось сделать руками в панели Supabase:**

1. Секреты функции: `BOOKING_INTAKE_KEY` (иначе точку приёма дёргает любой
   anon-ключ) и `BOOKING_CORS_ORIGIN` (список доменов вместо `*`).
   При задании `BOOKING_INTAKE_KEY` — пересобрать виджет с
   `--dart-define=BOOKING_API_KEY=<тот же ключ>`.
2. Аккаунты персонала: Auth → Users, затем строка в `booking_staff`.
3. Auth → Policies: включить проверку утёкших паролей (линтер WARN).
4. `get_push_token_diagnostics()` — функция **менеджера**, доступна любому
   `authenticated`. После заведения сотрудников бронирования они тоже смогут её
   вызывать. Сузить грант на стороне репозитория менеджера, не отсюда.

## ⚠️ Персональные данные — [`docs/PRIVACY.md`](docs/PRIVACY.md)

Виджет собирает имя и телефон. Два вопроса, которые надо закрыть **до запуска**:

1. **Политика конфиденциальности.** Черновик написан, нужны реквизиты
   оператора и проверка юристом. Разместить на сайте и указать адрес в сборке:
   `--dart-define=PRIVACY_URL=https://…`. Без этого RuStore не пропустит
   приложение. Уведомление под формой контактов уже показывается.
2. **Место хранения.** Проект Supabase в регионе `eu-north-1` (Стокгольм),
   а ч. 5 ст. 18 152-ФЗ требует хранить ПДн граждан РФ в базах на территории
   России. Решение за владельцем: перенос проекта либо отдельное хранилище ПДн
   в РФ с обезличенными бронями в Supabase.

## Каналы доставки — [`docs/CHANNELS.md`](docs/CHANNELS.md)

Домены клубов подтверждены: **effectvr.ru** и **vrayarena.ru** (уже в
`frame-ancestors`). Три канала из одного кода:

1. **Сайты** — iframe с одного поддомена, готовые сниппеты в CHANNELS.md.
2. **ВК** — ссылка из сообщества работает сразу (`?source=vk`); Mini App
   требует регистрации приложения, VK Bridge — отдельная работа.
3. **RuStore** — платформа Android добавлена, release-сборка проходит (18,2 МБ).
   Осталось: иконка, финальный `applicationId`, ключ подписи, аккаунт
   разработчика (ИП/юрлицо), модерация.

## Аудит 2026-09-08 — [`docs/AUDIT.md`](docs/AUDIT.md)

Полный разбор: безопасность (RLS/RPC/Edge Function/заголовки), баги,
адаптивность, дизайн, план по 5 спринтам. **Читать перед следующей задачей** —
там же критичные пункты C1–C4.

Сделано по итогам аудита:
- убраны несуществующие `p_starts_at`/`p_minutes` из `BookingRepository`;
- адаптив: три брейкпоинта (600 / 900) вместо одного, рамка 460 / 680 / 1000,
  плитка станции считается от доступной ширины, сетка слотов не переполняется
  при системном увеличении шрифта;
- `manifest.json` и `theme-color` приведены под проект;
- **спринт 1 (безопасность)** — миграция
  `20260908191400_online_booking_lockdown` (применена): единственный
  вход для брони — RPC (прямой insert анониму закрыт), лимиты 3 брони/час и
  5 активных на номер, валидация отрезков; Edge Function отдаёт 429 на лимиты
  и понимает список CORS-origin; CSP + `frame-ancestors` + `Referrer-Policy`;
  чек-лист выкладки в `docs/DEPLOY.md`.

- **спринт 3 (корректность данных)**: разбор заказа вынесен в `BookingRowDto`
  (`admin/data/dto/`) — админка правильно восстанавливает состав по часам из
  отрезков, 6 тестов; поля контактов синхронизируются с состоянием;
  `sessionDurations` стал единым списком длительностей для обеих фич, горизонты
  клиента (30 дн.) и персонала (120 дн.) разведены явно; состав клубов на первом
  шаге считается из данных, а не из хардкода; ошибки админки различают
  протухшую сессию и обрыв связи; `ErrorWidget.builder` вместо серого экрана.

⚠️ Найдено при внедрении CSP: **CanvasKit тянет Noto Sans с `fonts.gstatic.com`**
(fallback для глифов вне Archivo). Из РФ домен доступен не всегда. Интерфейс без
него отрисовывается корректно, но зависимость лишняя — см. AUDIT § 1.6.

## TODO / полировка (по убыванию важности)

1. **Держать репозиторий = прод.** Каждую миграцию/функцию, применённую к проду,
   сразу коммитить и пушить (24.09 пришлось восстанавливать с прода).
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
