# Деплой виджета

Виджет — статический Flutter Web бандл (`build/web`), раздаётся как SPA.
Бэкенд — Edge Function `booking-intake` на Supabase (см. [`INTEGRATION.md`](INTEGRATION.md));
`supabase.co` доступен из РФ без VPN, поэтому виджет собирается в **api-режиме**
и ходит в функцию напрямую, без прокси.

> **Cloudflare Pages не используем** — домен и CDN Cloudflare нестабильны из РФ
> (РКН). Хостинг — на инфраструктуре сайта клуба.

## Цель: поддомен `booking.<клуб>.ru`

Отдельный поддомен, виджет в корне. Сборка с `--base-href /` (по умолчанию).

## 1. Сборка

```bash
# из корня репозитория
FLUTTER=/c/vr_club_app/flutter/bin/flutter tool/build_web.sh
#   или PowerShell:
# pwsh tool/build_web.ps1 -Flutter C:\vr_club_app\flutter\bin\flutter.bat
```

Скрипт:
1. `flutter build web --release --dart-define=BOOKING_BACKEND=api`;
2. копирует `web/_redirects`, `web/_headers`, `web/.htaccess` в `build/web/`
   (`flutter build web` сам не переносит файлы с префиксом `_` и `.`);
3. пакует `build/vr_booking_web.zip` — его отдать тому, кто заливает сайт.

Ключи API зашиты по умолчанию (`lib/app/config/booking_config.dart`):
`BOOKING_API_BASE` → прод-функция, `BOOKING_API_KEY` → публичный anon-JWT
(он публичный по замыслу, шлюз Supabase требует его для `verify_jwt`).

### ⚠️ Чек-лист перед выкладкой

- [ ] **`USE_MOCK` не задан.** В mock-сборке `AdminAuthGate` пропускает без
      авторизации — админка окажется открыта миру. `tool/build_web.sh` флаг не
      ставит, но при ручной сборке легко забыть. Проверить:
      `grep -c 'USE_MOCK' build/web/main.dart.js` не показатель — надёжнее
      открыть `build/web/index.html?admin=1` и убедиться, что просят email и пароль.
- [ ] `BOOKING_BACKEND=api` (иначе виджет пойдёт в PostgREST напрямую).
- [ ] Задан `BOOKING_INTAKE_KEY` и сборка идёт с тем же `BOOKING_API_KEY` —
      иначе точку приёма брони можно дёргать любым anon-ключом (см. ниже).
- [ ] `ADMIN_GATE` изменён с дефолтного `vr2026`.
- [ ] `.htaccess` (Apache) или блок заголовков (nginx) доехали до корня —
      без них не работают `frame-ancestors` и кэш-политика.
- [ ] В `web/_headers` / `web/.htaccess` в `frame-ancestors` перечислены
      реальные домены клубов.

## 1a. Скорость загрузки (проверить на хостинге)

Виджет — это движок Flutter: на первый заход браузер качает ~3,3 МБ в сжатом
виде (CanvasKit ~2,2 МБ + приложение ~1,1 МБ). Повторные заходы берут всё из
кэша. Поэтому решают три настройки сервера, а не размер бандла:

1. **Сжатие для `.wasm`, `.js` и шрифтов.** Это главное: несжатый
   `canvaskit.wasm` — 7,2 МБ вместо 2,2 МБ. В `web/.htaccess` фильтры уже
   перечислены (`mod_deflate` + `mod_brotli`), но модуль должен быть включён
   на хостинге. Проверка:

   ```bash
   curl -sI -H 'Accept-Encoding: br, gzip' https://<адрес>/canvaskit/chromium/canvaskit.wasm | grep -i 'content-encoding\|content-length'
   ```

   Должно быть `content-encoding: br` (или `gzip`). Если заголовка нет —
   попросить хостинг включить сжатие для этих типов.

2. **HTTP/2 или HTTP/3.** На HTTP/1.1 десяток файлов грузится в очередь.
   Проверка: `curl -sI --http2 https://<адрес>/ | head -1` — ожидается `HTTP/2`.

3. **Кэш.** `canvaskit/*` — на год (`immutable`), входные файлы — `no-cache`.
   Задано в `.htaccess`; проверить `cache-control` у `canvaskit.wasm`.

Что уже сделано в самом бандле (2026-09-16): иконки вырезаются при сборке
(−1,9 МБ), шрифт заменён на урезанный Inter с кириллицей (−340 КБ и больше
никаких обращений к `fonts.gstatic.com`), CanvasKit качается параллельно с
`main.dart.js`, на время загрузки показывается заставка вместо тёмного пятна.

## 2. Заливка на хостинг

Скопировать **содержимое** `build/web/` (не саму папку) в корень поддомена
`booking.<клуб>.ru`. Способ зависит от хостинга:

- **FTP/SFTP** (FileZilla): подключиться, зайти в директорию поддомена
  (обычно `~/booking.<клуб>.ru/` или `~/domains/booking.<клуб>.ru/public_html/`),
  залить всё из `build/web` включая скрытый `.htaccess`
  (в FileZilla: _Сервер → Принудительно отображать скрытые файлы_).
- **Панель хостинга** (ISPmanager/cPanel): создать поддомен, в файловом
  менеджере открыть его корень, загрузить `vr_booking_web.zip`, распаковать
  на месте, zip удалить.
- **SSH**: `scp -r build/web/* build/web/.htaccess user@host:/path/to/booking-subdomain/`

После заливки проверить:
- `https://booking.<клуб>.ru/` — открывается шаг «Куда идём играть?»,
  два клуба в порядке Effect VR → V-Ray;
- DevTools → Network: запрос к `…functions.supabase.co/booking-intake/clubs` = 200.

## 3. Конфиг сервера

### Apache
`web/.htaccess` уже включает SPA-fallback, кэш и сжатие — достаточно, чтобы он
попал в корень поддомена (скрипт сборки кладёт его в `build/web`).

### nginx
`.htaccess` не работает — добавить в `server {}` поддомена:
```nginx
root /var/www/booking.<клуб>.ru;
index index.html;

location / {
    try_files $uri $uri/ /index.html;
}

# входные файлы — не кэшировать
location ~* ^/(index\.html|flutter_bootstrap\.js|flutter_service_worker\.js|main\.dart\.js|version\.json)$ {
    add_header Cache-Control "no-cache";
}
# ресурсы с хэшем — надолго
location ~* \.(js|wasm|json|otf|ttf|png|jpg|jpeg|gif|svg|bin|symbols)$ {
    add_header Cache-Control "public, max-age=31536000, immutable";
}

# ассеты Flutter без хэша в имени — сутки, не год
location ~* ^/assets/ {
    add_header Cache-Control "public, max-age=86400";
}

# заголовки безопасности (аналог web/_headers и web/.htaccess).
# X-Frame-Options не ставим — виджет живёт в iframe; ограничиваем frame-ancestors.
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "geolocation=(), microphone=(), camera=(), payment=(), usb=()" always;
add_header Content-Security-Policy "frame-ancestors 'self' https://effectvr.ru https://*.effectvr.ru https://vrayarena.ru https://*.vrayarena.ru https://*.vk.com https://*.vk.ru https://*.vk-apps.com" always;

types { application/wasm wasm; }
gzip on;
gzip_types text/css application/javascript application/json image/svg+xml;
```

> В nginx `add_header` внутри `location` **отменяет** заголовки из родительского
> блока. Если добавляете `add_header` в `location`, продублируйте там же и
> заголовки безопасности.

## 4. HTTPS

Поддомен должен быть на HTTPS (иначе iframe с https-сайта клуба и из ВК не
загрузится). На большинстве панелей — Let's Encrypt в один клик при создании
поддомена.

## 5. После первого деплоя

1. **CORS** на функции по умолчанию `*`. Функция понимает список origin через
   запятую и отражает Origin запроса, так что ВК и сайт клуба уживаются:
   ```bash
   supabase secrets set --project-ref cpjmirlujtfuzvdnysyx \
     BOOKING_CORS_ORIGIN=https://booking.<клуб>.ru,https://vk.com
   ```
2. **Ключ точки приёма.** Без `BOOKING_INTAKE_KEY` функция принимает любой
   непустой Bearer, а шлюзу достаточно публичного anon-ключа — то есть эндпоинт
   открыт всему интернету:
   ```bash
   supabase secrets set --project-ref cpjmirlujtfuzvdnysyx BOOKING_INTAKE_KEY=<длинная случайная строка>
   ```
   и собрать виджет с `--dart-define=BOOKING_API_KEY=<та же строка>`.
   Ключ всё равно окажется в бандле (клиент публичный) — но это отсекает
   автоматический перебор по чужим Supabase-проектам.
3. **Встраивание** на сайт клуба и во ВК — контракт и пример слушателя
   в [`EMBED.md`](EMBED.md). Коротко:
   ```html
   <iframe src="https://book.effectvr.ru/?club=effect&source=site"
           style="width:100%;max-width:480px;height:680px;border:0;display:block"
           loading="lazy"></iframe>
   ```
   Высоту iframe родитель подгоняет по сообщению `vr-booking:height`.
   `?club=` фиксирует клуб, `?source=vk` — для ВК. `X-Frame-Options` не ставится
   намеренно, но список разрешённых родителей задан в `frame-ancestors`
   (`web/_headers`, `web/.htaccess`) — **добавьте туда домен клуба**, иначе
   iframe не отрисуется.
4. **Админка** — тот же бандл, `https://booking.<клуб>.ru/?admin=1`,
   вход через Supabase Auth (аккаунт + строка в `booking_staff`).

## Обновление (каждый релиз)

Пересобрать (`tool/build_web.sh`) → перезалить содержимое `build/web`.
`.htaccess`/nginx уже стоят `no-cache` на `main.dart.js` и `index.html`, так что
у пользователей подхватится сразу.

## Файлы

- `web/_redirects`, `web/_headers` — для Cloudflare-совместимых хостингов
  (не используются на Apache/nginx, но и не мешают).
- `web/.htaccess` — Apache: SPA-fallback + кэш.
- `tool/build_web.{sh,ps1}` — сборка + копирование конфигов + zip.
