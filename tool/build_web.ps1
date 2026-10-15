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
  & $Flutter build web --release `
    --dart-define=BOOKING_BACKEND=api `
    --dart-define=BOOKING_API_BASE=$ApiBase
  if ($LASTEXITCODE -ne 0) { throw "flutter build web failed ($LASTEXITCODE)" }

  # flutter build web не переносит файлы с префиксом `_` и `.` из web/
  Copy-Item web/_redirects, web/_headers, web/.htaccess build/web/ -Force

  # Движок — в папку с ревизией в имени (engine-<12 знаков>/), путь — в
  # flutter_bootstrap.js и boot.js. Новый Flutter = новый адрес, поэтому
  # хостинг может кэшировать движок на год без риска отдать старый.
  # Берём только то, что грузит dart2js-сборка: canvaskit.{js,wasm} и chromium/.
  # Читаем и пишем явно в UTF-8: PowerShell 5 по умолчанию читает файл без BOM
  # в кодировке ANSI и портит русский текст в boot.js.
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  $boot = [IO.File]::ReadAllText((Resolve-Path build/web/flutter_bootstrap.js), $utf8)
  if ($boot -notmatch '"engineRevision":"([0-9a-f]{12})') { throw "engineRevision не найден" }
  $engine = "engine-$($Matches[1])"
  $dst = "build/web/$engine"
  # flutter build web не чистит build/web: убираем движок прошлой сборки.
  Get-ChildItem build/web -Directory -Filter 'engine-*' | Remove-Item -Recurse -Force
  New-Item -ItemType Directory -Force $dst | Out-Null
  Move-Item build/web/canvaskit/canvaskit.js, build/web/canvaskit/canvaskit.wasm $dst -Force
  Move-Item build/web/canvaskit/chromium $dst -Force
  Remove-Item build/web/canvaskit -Recurse -Force
  # Отладочные символы движку в браузере не нужны.
  Get-ChildItem $dst -Recurse -Filter *.symbols | Remove-Item -Force
  foreach ($f in 'build/web/flutter_bootstrap.js', 'build/web/boot.js') {
    $t = [IO.File]::ReadAllText((Resolve-Path $f), $utf8)
    if (-not $t.Contains("'canvaskit/'")) { throw "в $f нет 'canvaskit/'" }
    [IO.File]::WriteAllText((Resolve-Path $f), $t.Replace("'canvaskit/'", "'$engine/'"), $utf8)
  }

  # Архив для передачи тому, кто заливает сайт клуба
  if (Test-Path build/vr_booking_web.zip) { Remove-Item build/vr_booking_web.zip }
  # -Force чтобы .htaccess попал в архив
  Get-ChildItem build/web -Force | Compress-Archive -DestinationPath build/vr_booking_web.zip

  Write-Host "OK: build/web готов. Архив: build/vr_booking_web.zip" -ForegroundColor Green
} finally {
  Pop-Location
}
