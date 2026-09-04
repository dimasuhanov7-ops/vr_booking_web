# Сборка виджета под продакшн (api-режим: виджет ходит только в Edge Function
# booking-intake) + копирование _redirects/_headers, которые `flutter build web`
# из web/ не переносит (файлы с префиксом `_` игнорируются).
#
# Использование:
#   pwsh tool/build_web.ps1
#   pwsh tool/build_web.ps1 -Flutter "C:\vr_club_app\flutter\bin\flutter.bat"
param(
  [string]$Flutter = "flutter",
  [string]$ApiBase = "https://cpjmirlujtfuzvdnysyx.functions.supabase.co/booking-intake"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
  & $Flutter build web --release --no-tree-shake-icons `
    --dart-define=BOOKING_BACKEND=api `
    --dart-define=BOOKING_API_BASE=$ApiBase
  if ($LASTEXITCODE -ne 0) { throw "flutter build web failed ($LASTEXITCODE)" }

  # flutter build web не переносит файлы с префиксом `_` и `.` из web/
  Copy-Item web/_redirects, web/_headers, web/.htaccess build/web/ -Force

  # Архив для передачи тому, кто заливает сайт клуба
  if (Test-Path build/vr_booking_web.zip) { Remove-Item build/vr_booking_web.zip }
  # -Force чтобы .htaccess попал в архив
  Get-ChildItem build/web -Force | Compress-Archive -DestinationPath build/vr_booking_web.zip

  Write-Host "OK: build/web готов. Архив: build/vr_booking_web.zip" -ForegroundColor Green
} finally {
  Pop-Location
}
