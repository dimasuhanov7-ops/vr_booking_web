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

cp web/_redirects web/_headers build/web/
echo "OK: build/web готов к деплою (Cloudflare Pages)."
