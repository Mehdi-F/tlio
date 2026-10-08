<#
.SYNOPSIS
  Builds or runs TLIO with the Google Books API key injected.

.DESCRIPTION
  GoogleBooksConfig.apiKey comes from
  String.fromEnvironment('GOOGLE_BOOKS_API_KEY'), so the key is baked in at
  compile time. A build launched without it still works at first — the app
  falls back to unauthenticated Google Books calls — but those share a tiny
  anonymous quota, so book search and the Explorer start failing with 429s
  ("la recherche a échoué") under ordinary use. Nothing at runtime says why.

  CI passes the key from a GitHub secret. This script is the local equivalent,
  reading it from dart_define.json (gitignored) so a hand-run build can't
  silently omit it.

.PARAMETER Target
  apk   release APK          (build\app\outputs\flutter-apk\app-release.apk)
  web   release web bundle   (build\web, base href /tlio/)
  run   flutter run on the connected device

.PARAMETER Install
  With -Target apk, adb install -r the result onto the connected device.

.EXAMPLE
  .\scripts\build.ps1 -Target apk -Install
  .\scripts\build.ps1 -Target web
#>
[CmdletBinding()]
param(
    [ValidateSet('apk', 'web', 'run')]
    [string]$Target = 'apk',

    [switch]$Install
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$defines = Join-Path $repoRoot 'dart_define.json'
$example = Join-Path $repoRoot 'dart_define.example.json'

if (-not (Test-Path $defines)) {
    Write-Host ''
    Write-Host 'dart_define.json not found.' -ForegroundColor Red
    Write-Host "Copy $example to dart_define.json and put your Google Books API key in it."
    Write-Host 'The same key is stored as the GOOGLE_BOOKS_API_KEY secret on the GitHub repo.'
    Write-Host ''
    exit 1
}

# Catch a file that exists but was never filled in — that fails exactly like
# having no file at all, only later and much less obviously.
$config = Get-Content $defines -Raw | ConvertFrom-Json
$key = $config.GOOGLE_BOOKS_API_KEY
if ([string]::IsNullOrWhiteSpace($key) -or $key -eq 'your_google_books_api_key_here') {
    Write-Host ''
    Write-Host 'GOOGLE_BOOKS_API_KEY is missing or still the placeholder in dart_define.json.' -ForegroundColor Red
    Write-Host ''
    exit 1
}

Push-Location $repoRoot
try {
    switch ($Target) {
        'apk' {
            flutter build apk --release --dart-define-from-file=dart_define.json
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

            $apk = Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-release.apk'
            Write-Host ''
            Write-Host "APK: $apk" -ForegroundColor Green

            if ($Install) {
                $adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
                if (-not (Test-Path $adb)) { $adb = 'adb' }
                & $adb install -r $apk
                if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
            }
        }

        'web' {
            # Mirrors .github/workflows/deploy.yml so a local build behaves
            # like the deployed one: /tlio/ is the GitHub Pages subpath,
            # and offline-first lets the service worker precache the shell.
            flutter build web --release `
                --base-href /tlio/ `
                --pwa-strategy=offline-first `
                --dart-define-from-file=dart_define.json
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

            Write-Host ''
            Write-Host "Web bundle: $(Join-Path $repoRoot 'build\web')" -ForegroundColor Green
        }

        'run' {
            flutter run --dart-define-from-file=dart_define.json
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        }
    }
}
finally {
    Pop-Location
}
