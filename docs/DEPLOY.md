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

types { application/wasm wasm; }
gzip on;
gzip_types text/css application/javascript application/json image/svg+xml;
```

## 4. HTTPS

Поддомен должен быть на HTTPS (иначе iframe с https-сайта клуба и из ВК не
загрузится). На большинстве панелей — Let's Encrypt в один клик при создании
поддомена.

## 5. После первого деплоя

1. **CORS** на функции сейчас `*` — можно сузить на боевой домен:
   ```bash
   supabase secrets set --project-ref cpjmirlujtfuzvdnysyx \
     BOOKING_CORS_ORIGIN=https://booking.<клуб>.ru
   ```
   ⚠️ Если виджет открывается ещё и из ВК (Mini App) или с других origin —
   оставить `*` либо доработать функцию под список доменов. Пока безопаснее `*`.
2. **Встраивание** на сайт клуба и во ВК:
   ```html
   <iframe src="https://booking.<клуб>.ru/?source=site"
           style="width:100%;max-width:480px;height:900px;border:0"
           loading="lazy"></iframe>
   ```
   `?source=vk` — для ВК. `_headers`/`.htaccess` не ставят `X-Frame-Options`,
   так что iframe с любого origin разрешён.
3. **Админка** — тот же бандл, `https://booking.<клуб>.ru/?admin=1`
   (пока на моках, без авторизации — см. HANDOFF).

## Обновление (каждый релиз)

Пересобрать (`tool/build_web.sh`) → перезалить содержимое `build/web`.
`.htaccess`/nginx уже стоят `no-cache` на `main.dart.js` и `index.html`, так что
у пользователей подхватится сразу.

## Файлы

- `web/_redirects`, `web/_headers` — для Cloudflare-совместимых хостингов
  (не используются на Apache/nginx, но и не мешают).
- `web/.htaccess` — Apache: SPA-fallback + кэш.
- `tool/build_web.{sh,ps1}` — сборка + копирование конфигов + zip.
