# Starts RepDuel frontend with Doppler-injected env vars (Windows/PowerShell)
$ErrorActionPreference = "Stop"
Write-Host "--- Starting RepDuel Frontend (Doppler) ---"
Set-Location $PSScriptRoot

function Get-SecretOrDefault {
    param(
        [string]$Name,
        [string]$Default = ""
    )

    if ($env:$Name) {
        return $env:$Name
    }

    $result = $(doppler secrets get $Name --project repduel --config dev_frontend --plain 2>$null)
    if ($LASTEXITCODE -eq 0 -and $null -ne $result -and $result.Trim().Length -gt 0) {
        return $result.Trim()
    }

    return $Default
}

$backendUrl = Get-SecretOrDefault -Name "BACKEND_URL" -Default "http://127.0.0.1:8000"
$publicBaseUrl = Get-SecretOrDefault -Name "PUBLIC_BASE_URL" -Default "http://localhost:5000"
$merchantDisplayName = Get-SecretOrDefault -Name "MERCHANT_DISPLAY_NAME" -Default "RepDuel"
$revenueCatAppleKey = Get-SecretOrDefault -Name "REVENUE_CAT_APPLE_KEY"
$stripeCancelUrl = Get-SecretOrDefault -Name "STRIPE_CANCEL_URL"
$stripePremiumPlanId = Get-SecretOrDefault -Name "STRIPE_PREMIUM_PLAN_ID"
$stripePublishableKey = Get-SecretOrDefault -Name "STRIPE_PUBLISHABLE_KEY"
$stripeSuccessUrl = Get-SecretOrDefault -Name "STRIPE_SUCCESS_URL"
$paymentsEnabled = Get-SecretOrDefault -Name "PAYMENTS_ENABLED" -Default "false"

doppler run --project repduel --config dev_frontend -- `
  flutter run -d chrome --web-port=5000 `
    --dart-define=BACKEND_URL="$backendUrl" `
    --dart-define=PUBLIC_BASE_URL="$publicBaseUrl" `
    --dart-define=MERCHANT_DISPLAY_NAME="$merchantDisplayName" `
    --dart-define=REVENUE_CAT_APPLE_KEY="$revenueCatAppleKey" `
    --dart-define=STRIPE_CANCEL_URL="$stripeCancelUrl" `
    --dart-define=STRIPE_PREMIUM_PLAN_ID="$stripePremiumPlanId" `
    --dart-define=STRIPE_PUBLISHABLE_KEY="$stripePublishableKey" `
    --dart-define=STRIPE_SUCCESS_URL="$stripeSuccessUrl" `
    --dart-define=PAYMENTS_ENABLED="$paymentsEnabled"
