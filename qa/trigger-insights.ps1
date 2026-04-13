# trigger-insights.ps1
# Clears insight cooldowns, calls regenerate, and shows what was created.
# With -TestPush, also sends a test push notification to the device.
# Usage:
#   .\qa\trigger-insights.ps1 -Password "your_password"
#   .\qa\trigger-insights.ps1 -TestPush
#   .\qa\trigger-insights.ps1   <-- prompts for password

param(
  [string]$Email    = "insight_test@finanzas.app",
  [string]$Password = "Test1234!",
  [string]$Base     = "http://localhost:3000/api/v1",
  [switch]$TestPush   # Add -TestPush flag to also fire a test push notification
)

if (-not $Password) {
  $sec = Read-Host "Password for $Email" -AsSecureString
  $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  )
}

function req($method, $path, $body = $null, $tok = $null) {
  $headers = @{ "Content-Type" = "application/json" }
  if ($tok) { $headers["Authorization"] = "Bearer $tok" }
  $params = @{ Uri = "$Base$path"; Method = $method; Headers = $headers; ErrorAction = "SilentlyContinue" }
  if ($body) { $params["Body"] = ($body | ConvertTo-Json -Compress) }
  try {
    $r = Invoke-RestMethod @params
    # Unwrap {data: ...} envelope
    if ($r.PSObject.Properties.Name -contains 'data') { return $r.data }
    return $r
  } catch {
    $s = $_.Exception.Response.StatusCode.value__
    return @{ __error = $true; status = $s; msg = $_.Exception.Message }
  }
}

Write-Host ""
Write-Host "=== Insight Trigger Script ===" -ForegroundColor Cyan
Write-Host ""

# 1. Login
Write-Host "[1] Logging in as $Email..."
$auth = req POST "/auth/login" @{ email = $Email; password = $Password }
if (-not $auth.accessToken) {
  Write-Host "  ERROR: Login failed. Check email/password." -ForegroundColor Red
  exit 1
}
$token = $auth.accessToken
Write-Host "  OK - token obtained" -ForegroundColor Green

# 2. Dismiss all existing insights (reset cooldowns)
Write-Host ""
Write-Host "[2] Clearing existing insights (reset cooldowns)..."
req DELETE "/insights/dismiss-all" -tok $token | Out-Null
Write-Host "  OK - all dismissed" -ForegroundColor Green

# 3. Trigger regenerate
Write-Host ""
Write-Host "[3] Triggering insight regeneration..."
req POST "/insights/regenerate" -tok $token | Out-Null
Write-Host "  OK - regenerate called" -ForegroundColor Green

# 4. Fetch and display results
Start-Sleep -Milliseconds 800
Write-Host ""
Write-Host "[4] Fetching generated insights..."
$insights = req GET "/insights" -tok $token

if ($insights -is [Array] -and $insights.Count -gt 0) {
  Write-Host ""
  Write-Host "  Generated $($insights.Count) insight(s):" -ForegroundColor Green
  Write-Host ""
  foreach ($i in $insights) {
    $color = switch ($i.priority) {
      "critical" { "Red" }
      "high"     { "Yellow" }
      default    { "White" }
    }
    Write-Host "  [$($i.type.PadRight(18))] $($i.title)" -ForegroundColor $color
    Write-Host "  $(' ' * 22)$($i.body.Substring(0, [Math]::Min(80, $i.body.Length)))..." -ForegroundColor Gray
    Write-Host ""
  }
} elseif ($insights -is [Array]) {
  Write-Host "  No insights were generated." -ForegroundColor Yellow
  Write-Host "  This may mean the analytics data does not meet the thresholds yet." -ForegroundColor Gray
  Write-Host "  Check that the insight-test seed ran successfully." -ForegroundColor Gray
} else {
  Write-Host "  Unexpected response: $($insights | ConvertTo-Json)" -ForegroundColor Red
}

# 5. Achievements
$ach = req GET "/insights/achievements" -tok $token
$achCount = if ($ach -is [Array]) { $ach.Count } else { 0 }
if ($achCount -gt 0) {
  Write-Host "  Achievements: $achCount" -ForegroundColor Cyan
  $ach | ForEach-Object { Write-Host "    - $($_.title)" -ForegroundColor Cyan }
}

Write-Host ""
Write-Host "=== Done. Open the app and pull-to-refresh the Insights screen ===" -ForegroundColor Cyan

# Optional: test push notification
if ($TestPush) {
  Write-Host ""
  Write-Host "[push] Sending test push notification..." -ForegroundColor Cyan
  try {
    $pushResult = req POST "/insights/test-push" @{ title = "Prueba push"; body = "Si lees esto, FCM funciona!" } $token
    if ($pushResult.sent) {
      Write-Host "  OK - push sent to device" -ForegroundColor Green
    } else {
      Write-Host "  WARN - Firebase not ready or no FCM token registered" -ForegroundColor Yellow
      Write-Host "         Open the app once (logged in) to register the device token, then retry." -ForegroundColor Gray
    }
  } catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
  }
}

Write-Host ""
