#!/usr/bin/env bash
# Сборка виджета под продакшн (api-режим: виджет ходит только в Edge Function
# booking-intake) + копирование _redirects/_headers, которые `flutter build web`
# из web/ не переносит (файлы с префиксом `_` игнорируются).
#
# Использование:
#   tool/build_web.sh
#   FLUTTER=/c/vr_club_app/flutter/bin/flutter tool/build_web.sh
set -euo pipefail

FLUTTER="${FLUTTER:-flutter}"
API_BASE="${BOOKING_API_BASE:-https://cpjmirlujtfuzvdnysyx.functions.supabase.co/booking-intake}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

"$FLUTTER" build web --release \
  --dart-define=BOOKING_BACKEND=api \
  --dart-define=BOOKING_API_BASE="$API_BASE"

# flutter build web не переносит файлы с префиксом `_` и `.` из web/
cp web/_redirects web/_headers web/.htaccess build/web/

# Движок — в папку с ревизией в имени (engine-<12 знаков>/), путь — в
# flutter_bootstrap.js и boot.js. Новый Flutter = новый адрес, поэтому
# хостинг может кэшировать движок на год без риска отдать старый.
REV="$(grep -o '"engineRevision":"[0-9a-f]\{12\}' build/web/flutter_bootstrap.js | cut -d'"' -f4)"
[ -n "$REV" ] || { echo "engineRevision не найден" >&2; exit 1; }
ENGINE="engine-$REV"
# flutter build web не чистит build/web: убираем движок прошлой сборки.
rm -rf build/web/engine-*
mkdir -p "build/web/$ENGINE"
mv build/web/canvaskit/canvaskit.js build/web/canvaskit/canvaskit.wasm    build/web/canvaskit/chromium "build/web/$ENGINE/"
rm -rf build/web/canvaskit
# Отладочные символы движку в браузере не нужны.
find "build/web/$ENGINE" -name '*.symbols' -delete
for f in build/web/flutter_bootstrap.js build/web/boot.js; do
  grep -q "'canvaskit/'" "$f" || { echo "в $f нет 'canvaskit/'" >&2; exit 1; }
  sed -i "s#'canvaskit/'#'$ENGINE/'#" "$f"
done

# Архив для передачи тому, кто заливает сайт клуба (zip нет в git bash -> python)
rm -f build/vr_booking_web.zip
if command -v zip >/dev/null 2>&1; then
  ( cd build/web && zip -qr ../vr_booking_web.zip . )
else
  python -c "import shutil; shutil.make_archive('build/vr_booking_web', 'zip', 'build/web')"
fi

echo "OK: build/web готов. Архив: build/vr_booking_web.zip"
