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

"$FLUTTER" build web --release --no-tree-shake-icons \
  --dart-define=BOOKING_BACKEND=api \
  --dart-define=BOOKING_API_BASE="$API_BASE"

# flutter build web не переносит файлы с префиксом `_` и `.` из web/
cp web/_redirects web/_headers web/.htaccess build/web/

# Архив для передачи тому, кто заливает сайт клуба (zip нет в git bash -> python)
rm -f build/vr_booking_web.zip
if command -v zip >/dev/null 2>&1; then
  ( cd build/web && zip -qr ../vr_booking_web.zip . )
else
  python -c "import shutil; shutil.make_archive('build/vr_booking_web', 'zip', 'build/web')"
fi

echo "OK: build/web готов. Архив: build/vr_booking_web.zip"
