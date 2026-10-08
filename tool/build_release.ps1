param(
  [string]$SupabaseUrl = "",
  [string]$SupabaseAnonKey = "",
  [string]$PublicBaseUrl = "",
  [switch]$ApkOnly,
  [switch]$WebOnly,
  [switch]$Local
)

<#
  Build release APK + WEB sekaligus dengan konfigurasi cloud (Supabase).

  Contoh pemakaian (dijalankan dari folder proyek):
    powershell -ExecutionPolicy Bypass -File tool\build_release.ps1 `
      -SupabaseUrl "https://xxxx.supabase.co" `
      -SupabaseAnonKey "eyJhbGciOi..." `
      -PublicBaseUrl "https://nama-proyek.netlify.app"

  - Tanpa -Local, jika URL/Key kosong aplikasi tetap dibangun tetapi masuk
    mode LOKAL (data tidak tersinkron antar perangkat).
  - -Local: sengaja membangun tanpa cloud (mode lokal).
  - -ApkOnly / -WebOnly: bangun salah satu saja.
#>

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path "pubspec.yaml")) {
  Write-Host "Jalankan dari folder proyek Flutter (Data Spek Computer)."
  exit 1
}

if ($Local) {
  $SupabaseUrl = ""
  $SupabaseAnonKey = ""
  $PublicBaseUrl = ""
}

function New-Defines {
  $defines = @()
  if ($SupabaseUrl)  { $defines += "--dart-define=SUPABASE_URL=$SupabaseUrl" }
  if ($SupabaseAnonKey) { $defines += "--dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey" }
  if ($PublicBaseUrl) { $defines += "--dart-define=PUBLIC_BASE_URL=$PublicBaseUrl" }
  if ($defines.Count -eq 0) {
    Write-Host "Peringatan: SUPABASE_URL / ANON KEY kosong -> mode LOKAL (tanpa sinkron)." -ForegroundColor Yellow
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
  Write-Host "WEB : deploy folder build\web (Netlify/GitHub Pages/dll)" -ForegroundColor Green
}

Write-Host "Selesai." -ForegroundColor Green