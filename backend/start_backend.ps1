# start_backend.ps1
# Starts RepDuel backend with Doppler-injected env vars (Windows/PowerShell)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---- Config (override via env vars if you like) ----
$Project = if ($env:PROJECT) { $env:PROJECT } else { "repduel" }
$Config  = if ($env:CONFIG)  { $env:CONFIG }  else { "dev_backend" }

Write-Host "--- Starting RepDuel Backend (Doppler) ---"
Write-Host "Project: $Project  Config: $Config"

# ---- Self-checks ----

# doppler CLI present
if (-not (Get-Command doppler -ErrorAction SilentlyContinue)) {
  Write-Error "Doppler CLI not found. Install with: winget install Doppler.Doppler or brew install dopplerhq/cli/doppler"
  exit 1
}

# doppler auth (either DOPPLER_TOKEN set, or logged in)
if (-not $env:DOPPLER_TOKEN) {
  try {
    doppler whoami | Out-Null
  } catch {
    Write-Error "Not authenticated with Doppler. Run: doppler login"
    exit 1
  }
}

# venv present
$ScriptDir = $PSScriptRoot  # the folder this script lives in
$VenvActivate = Join-Path $ScriptDir ".venv\Scripts\Activate.ps1"
if (-not (Test-Path $VenvActivate)) {
  Write-Error "Virtual environment not found at $VenvActivate. Create it and install deps (python -m venv .venv; pip install -r backend/requirements.txt)."
  exit 1
}

# ---- Activate venv & launch ----
. $VenvActivate
Set-Location $ScriptDir

# Run uvicorn with Doppler-provided environment
# (If you use a factory callable, add --factory accordingly)
& doppler run `
  --project $Project `
  --config  $Config `
  -- `
  python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000 --log-level error
