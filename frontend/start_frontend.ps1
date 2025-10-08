# Starts RepDuel frontend with Doppler-injected env vars (Windows/PowerShell)
$ErrorActionPreference = "Stop"
Write-Host "--- Starting RepDuel Frontend (Doppler) ---"
Set-Location $PSScriptRoot

doppler run --project repduel --config dev_frontend -- `
  flutter run -d chrome --web-port=5000
