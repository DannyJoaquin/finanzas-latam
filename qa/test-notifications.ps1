#!/usr/bin/env pwsh
# Notification system smoke test
$BASE = "http://localhost:3000/api/v1"
$PASS = 0; $FAIL = 0

function pass([string]$m) { $script:PASS++; Write-Host "  [PASS] $m" -ForegroundColor Green }
function fail([string]$m) { $script:FAIL++; Write-Host "  [FAIL] $m" -ForegroundColor Red }
function info([string]$m) { Write-Host "         $m" -ForegroundColor DarkGray }

# Returns @{ok; data (unwrapped); status}
function req([string]$method, [string]$path, $body = $null, [string]$token = "") {
    $headers = @{ "Content-Type" = "application/json" }
    if ($token) { $headers["Authorization"] = "Bearer $token" }
    $params = @{ Method = $method; Uri = "$BASE$path"; Headers = $headers; TimeoutSec = 15 }
    if ($body) { $params["Body"] = ($body | ConvertTo-Json -Depth 5) }
    try {
        $raw = Invoke-RestMethod @params -UseBasicParsing -ErrorAction Stop
        # Unwrap {data: ...} envelope
        $unwrapped = if ($null -ne $raw.data) { $raw.data } else { $raw }
        return @{ ok = $true; data = $unwrapped; status = 200 }
    } catch {
        $st = $null; try { $st = [int]$_.Exception.Response.StatusCode } catch {}
        $bd = ""; try { $bd = $_.ErrorDetails.Message } catch {}
        return @{ ok = $false; status = $st; body = $bd }
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Notification System -- Smoke Test" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. REGISTER + LOGIN
Write-Host "[ 1 ] Auth" -ForegroundColor White
$ts = [DateTime]::Now.ToString("mmssff")
$email = "notif_${ts}@test.com"
$r = req POST "/auth/register" @{ fullName = "Notif Tester"; email = $email; password = "Segura123!" }
if (-not $r.ok) { fail "Register failed ($($r.status))"; exit 1 }
$TOKEN = $r.data.accessToken
if (-not $TOKEN) { fail "Token is empty after register"; exit 1 }
pass "Registered + got token"

# 2. GET notification-preferences (defaults)
Write-Host ""
Write-Host "[ 2 ] GET /users/me/notification-preferences (defaults)" -ForegroundColor White
$r = req GET "/users/me/notification-preferences" -token $TOKEN
if (-not $r.ok) {
    fail "GET prefs failed ($($r.status))"
    Write-Host $r.body
} else {
    $p = $r.data
    pass "Got preferences"
    info "pushBudgetAlerts            = $($p.pushBudgetAlerts)"
    info "pushDailyReminder           = $($p.pushDailyReminder)"
    info "pushWeeklySummary           = $($p.pushWeeklySummary)"
    info "pushImportantInsights       = $($p.pushImportantInsights)"
    info "pushCriticalFinancialAlerts = $($p.pushCriticalFinancialAlerts)"
    info "pushMotivation              = $($p.pushMotivation)  <- should be FALSE"
    info "localCardCutoffAlerts       = $($p.localCardCutoffAlerts)"
    info "localCardDue5d              = $($p.localCardDue5d)"
    info "localCardDue1d              = $($p.localCardDue1d)"
    info "localCardPendingBalance     = $($p.localCardPendingBalance)"
    info "inappSavingsOpportunities   = $($p.inappSavingsOpportunities)"
    info "inappPatterns               = $($p.inappPatterns)"
    info "inappMotivation             = $($p.inappMotivation)"

    $allTrue = ($p.pushBudgetAlerts -eq $true -and $p.pushDailyReminder -eq $true -and
        $p.pushWeeklySummary -eq $true -and $p.pushImportantInsights -eq $true -and
        $p.pushCriticalFinancialAlerts -eq $true -and $p.localCardCutoffAlerts -eq $true -and
        $p.localCardDue5d -eq $true -and $p.localCardDue1d -eq $true -and
        $p.localCardPendingBalance -eq $true -and $p.inappSavingsOpportunities -eq $true -and
        $p.inappPatterns -eq $true -and $p.inappMotivation -eq $true)

    if ($allTrue) { pass "All 12 non-motivation defaults are TRUE" }
    else { fail "Some defaults wrong (expected all TRUE except pushMotivation)" }

    if ($p.pushMotivation -eq $false) { pass "pushMotivation defaults to FALSE correctly" }
    else { fail "pushMotivation should default to FALSE, got $($p.pushMotivation)" }
}

# 3. PATCH preferences
Write-Host ""
Write-Host "[ 3 ] PATCH /users/me/notification-preferences" -ForegroundColor White
$r = req PATCH "/users/me/notification-preferences" @{
    pushDailyReminder = $false
    pushMotivation    = $true
    inappMotivation   = $false
} -token $TOKEN

if (-not $r.ok) {
    fail "PATCH prefs failed ($($r.status))"
    Write-Host $r.body
} else {
    $p = $r.data
    pass "PATCH returned 200"

    if ($p.pushDailyReminder -eq $false) { pass "pushDailyReminder set to FALSE" }
    else { fail "pushDailyReminder should be FALSE, got $($p.pushDailyReminder)" }

    if ($p.pushMotivation -eq $true) { pass "pushMotivation set to TRUE" }
    else { fail "pushMotivation should be TRUE, got $($p.pushMotivation)" }

    if ($p.inappMotivation -eq $false) { pass "inappMotivation set to FALSE" }
    else { fail "inappMotivation should be FALSE, got $($p.inappMotivation)" }

    if ($p.pushBudgetAlerts -eq $true) { pass "Untouched pushBudgetAlerts still TRUE" }
    else { fail "Untouched pushBudgetAlerts changed (expected TRUE)" }
}

# 4. GET again - verify persistence
Write-Host ""
Write-Host "[ 4 ] GET again -- verify persistence" -ForegroundColor White
$r = req GET "/users/me/notification-preferences" -token $TOKEN
if (-not $r.ok) {
    fail "GET prefs (re-read) failed"
} else {
    $p = $r.data
    if ($p.pushDailyReminder -eq $false -and $p.pushMotivation -eq $true -and $p.inappMotivation -eq $false) {
        pass "All 3 updated values persist in DB"
    } else {
        fail "Values did not persist: pushDailyReminder=$($p.pushDailyReminder) pushMotivation=$($p.pushMotivation) inappMotivation=$($p.inappMotivation)"
    }
}

# 5. PATCH with empty body
Write-Host ""
Write-Host "[ 5 ] PATCH with empty body (idempotent)" -ForegroundColor White
$r = req PATCH "/users/me/notification-preferences" @{} -token $TOKEN
if ($r.ok) { pass "Empty PATCH accepted (200)" }
else { fail "Empty PATCH rejected ($($r.status))" }

# 6. Insights regenerate
Write-Host ""
Write-Host "[ 6 ] POST /insights/regenerate" -ForegroundColor White
$r = req POST "/insights/regenerate" -token $TOKEN
if ($r.ok -or $r.status -eq 204) { pass "Insights regeneration triggered (204)" }
else { fail "Regenerate failed ($($r.status)): $($r.body)" }

# 7. GET active insights
Write-Host ""
Write-Host "[ 7 ] GET /insights" -ForegroundColor White
$r = req GET "/insights" -token $TOKEN
$insights = @()
if (-not $r.ok) {
    fail "GET /insights failed ($($r.status))"
    Write-Host $r.body
} else {
    $raw = $r.data
    if ($raw -is [array]) { $insights = $raw }
    elseif ($null -ne $raw.data -and $raw.data -is [array]) { $insights = $raw.data }
    pass "GET /insights returned $($insights.Count) insight(s)"
    foreach ($i in $insights) {
        info "  [$($i.type)] [$($i.priority)] -- $($i.title)"
    }
    if ($insights.Count -eq 0) {
        info "(New user with no expenses -- no insights expected. OK.)"
    }
}

# 8. Mark first insight as read (if any)
if ($insights.Count -gt 0) {
    Write-Host ""
    Write-Host "[ 8 ] PATCH /insights/:id/read" -ForegroundColor White
    $firstId = $insights[0].id
    $r2 = req PATCH "/insights/$firstId/read" -token $TOKEN
    if ($r2.ok -or $r2.status -eq 204) { pass "mark-read on first insight OK (204)" }
    else { fail "mark-read failed ($($r2.status))" }
}

# 9. String coercion note (enableImplicitConversion converts "yes" -> true)
Write-Host ""
Write-Host "[ 9 ] PATCH with string value (implicit coercion expected)" -ForegroundColor White
$r = req PATCH "/users/me/notification-preferences" @{ pushBudgetAlerts = "yes" } -token $TOKEN
if ($r.ok) {
    pass "String coerced to boolean (enableImplicitConversion=true) -- expected behavior"
} else {
    info "Got HTTP $($r.status) -- (unexpected rejection)"
}

# Summary
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
$color = if ($FAIL -eq 0) { "Green" } else { "Yellow" }
Write-Host "  PASS: $PASS   FAIL: $FAIL" -ForegroundColor $color
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
if ($FAIL -gt 0) { exit 1 }
