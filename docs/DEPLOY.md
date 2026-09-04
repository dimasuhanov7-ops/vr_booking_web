# Деплой виджета — Cloudflare Pages

Виджет собирается в статику (`build/web`) и раздаётся как SPA. Бэкенд —
Edge Function `booking-intake` (см. [`INTEGRATION.md`](INTEGRATION.md)),
виджет собирается в **api-режиме** и ходит только туда.

## 1. Сборка

```bash
# из корня репозитория
FLUTTER=/c/vr_club_app/flutter/bin/flutter tool/build_web.sh
#   или PowerShell:
# pwsh tool/build_web.ps1 -Flutter C:\vr_club_app\flutter\bin\flutter.bat
```

Скрипт делает `flutter build web --release --dart-define=BOOKING_BACKEND=api`
и копирует `web/_redirects` + `web/_headers` в `build/web/` — **`flutter build web`
их сам не переносит** (игнорирует файлы с префиксом `_`).

Ручками то же самое:
```bash
/c/vr_club_app/flutter/bin/flutter build web --release --no-tree-shake-icons \
  --dart-define=BOOKING_BACKEND=api
cp web/_redirects web/_headers build/web/
```

Ключи в бандле по умолчанию (`lib/app/config/booking_config.dart`):
`BOOKING_API_BASE` → прод-функция, `BOOKING_API_KEY` → публичный anon-JWT
(он и так публичный, шлюз Supabase требует его для `verify_jwt`).

## 2. Публикация

**Вариант А — Wrangler (CLI).** Нужен аккаунт Cloudflare.
```bash
npx wrangler login                       # один раз, откроется браузер
npx wrangler pages project create vr-booking-web   # один раз
npx wrangler pages deploy build/web --project-name=vr-booking-web
```
Последнюю команду повторять на каждый релиз. Preview-деплой ветки:
`--branch=<name>`.

**Вариант Б — дашборд.** Cloudflare Pages → Create → Upload assets →
перетащить содержимое `build/web`. На следующих релизах — «Create new deployment».

**Вариант В — Git-интеграция.** Подключить репозиторий, framework preset
«None», build command `flutter build web --release --dart-define=BOOKING_BACKEND=api`,
output `build/web`. Требует Flutter в CI (кастомный образ / `asdf`), плюс
отдельный шаг `cp web/_redirects web/_headers build/web`. Пока проще А/Б.

## 3. После первого деплоя

1. Записать выданный домен (`vr-booking-web.pages.dev` или свой).
2. **Сузить CORS** на функции — сейчас `*`:
   ```bash
   supabase secrets set --project-ref cpjmirlujtfuzvdnysyx \
     BOOKING_CORS_ORIGIN=https://<домен-виджета>
   ```
   Если виджет открывается с нескольких origin (свой домен + `*.pages.dev` +
   VK), оставить `*` или вынести проверку списком в код функции.
3. Кастомный домен: Pages → Custom domains → добавить `booking.<клуб>.ru`,
   CNAME по инструкции. Потом обновить `BOOKING_CORS_ORIGIN` на него.
4. Встраивание: `<iframe src="https://<домен>/?source=site" …>` на сайте,
   `?source=vk` — во ВК. `_headers` уже не ставит `X-Frame-Options`, так что
   iframe с любого origin разрешён.

## Файлы

- `web/_redirects` — `/* /index.html 200`, SPA-fallback.
- `web/_headers` — `no-cache` на входные файлы (`index.html`, `main.dart.js`,
  `flutter_bootstrap.js`, `flutter_service_worker.js`, `version.json`),
  годовой `immutable` на `/assets/*` и `/canvaskit/*`.
- `tool/build_web.{sh,ps1}` — сборка + копирование этих двух файлов.
