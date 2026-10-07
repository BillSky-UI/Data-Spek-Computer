param(
  [string]$MysqlApiUrl = "",
  [string]$MysqlApiKey = "",
  [string]$PublicBaseUrl = "",
  [switch]$ApkOnly,
  [switch]$WebOnly,
  [switch]$Local
)

<#
  Build release APK + WEB sekaligus dengan konfigurasi cloud (MySQL + backend/api.php).

  Contoh pemakaian (dijalankan dari folder proyek):
    powershell -ExecutionPolicy Bypass -File tool\build_release.ps1 `
      -MysqlApiUrl "https://domain.com/backend" `
      -MysqlApiKey "rahasia-api-anda" `
      -PublicBaseUrl "https://domain.com/app"

  - Tanpa -Local, jika URL/Key kosong aplikasi tetap dibangun tetapi masuk
    mode LOKAL (data tidak tersinkron antar perangkat).
  - Di APK, URL API wajib lewat -MysqlApiUrl (atau di-set via build web).
  - Di WEB, URL API bisa relatif (default 'backend') terhadap folder deploy,
    atau ditimpa runtime lewat file web/config.json — tidak perlu build ulang.
  - -Local: sengaja membangun tanpa cloud (mode lokal).
  - -ApkOnly / -WebOnly: bangun salah satu saja.

  Backend (backend/) harus di-upload ke hosting bersama folder web:
    - impor backend/schema.sql di phpMyAdmin (atau biarkan auto-migrate)
    - buat backend/config.php dari config.example.php (isi kredensial + api_key)
    - jaga agar backend/config.php tidak bisa diunduh (sudah diblokir .htaccess)
#>

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path "pubspec.yaml")) {
  Write-Host "Jalankan dari folder proyek Flutter (Data Spek Computer)."
  exit 1
}

if ($Local) {
  $MysqlApiUrl = ""
  $MysqlApiKey = ""
  $PublicBaseUrl = ""
}

function New-Defines {
  $defines = @()
  if ($MysqlApiUrl) { $defines += "--dart-define=MYSQL_API_URL=$MysqlApiUrl" }
  if ($MysqlApiKey) { $defines += "--dart-define=MYSQL_API_KEY=$MysqlApiKey" }
  if ($PublicBaseUrl) { $defines += "--dart-define=PUBLIC_BASE_URL=$PublicBaseUrl" }
  if ($defines.Count -eq 0) {
    Write-Host "Peringatan: MYSQL_API_URL / KEY kosong -> mode LOKAL (tanpa sinkron)." -ForegroundColor Yellow
  }
  return ,$defines
}

$defines = New-Defines

if (-not $WebOnly) {
  Write-Host "==> Build APK release ..." -ForegroundColor Cyan
  flutter build apk --release @defines
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  Write-Host "APK : build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
}

if (-not $ApkOnly) {
  Write-Host "==> Build WEB release ..." -ForegroundColor Cyan
  flutter build web --release @defines
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  Write-Host "WEB : deploy folder build\web (hosting statis / bersama backend/)" -ForegroundColor Green
}

Write-Host "Selesai." -ForegroundColor Green