$BASE  = "http://localhost:3000/api/v1"
$RUN   = [System.DateTime]::Now.ToString("mmssff")

function rq2([string]$method,[string]$path,$body=$null,[string]$token=""){
    $headers = @{"Content-Type"="application/json"}
    if($token){ $headers["Authorization"]="Bearer $token" }
    $params = @{Method=$method;Uri="$BASE$path";Headers=$headers;TimeoutSec=15}
    if($body){ $params["Body"]=($body|ConvertTo-Json -Depth 10) }
    try {
        $r = Invoke-RestMethod @params -UseBasicParsing -ErrorAction Stop
        if($null -ne $r.data){ return $r.data }
        return $r
    } catch {
        $st=$null; try{$st=[int]$_.Exception.Response.StatusCode}catch{}
        return @{__error=$true;status=$st;exType=$_.Exception.GetType().Name;msg=$_.Exception.Message}
    }
}

$emailA = "bs_${RUN}@test.com"
$emailB = "bsB_${RUN}@test.com"

# -- Test each step one at a time, checking categories after each
function testCategories([string]$tok, [string]$label){
    $c = rq2 GET "/categories" -token $tok
    if($c.__error){ Write-Host "  $label -> FAIL status=$($c.status) ex=$($c.exType) msg=$($c.msg)" }
    else {
        $n = if($c -is [array]){$c.Count}else{1}
        Write-Host "  $label -> OK count=$n"
    }
}

Write-Host "=== BINARY SEARCH for categories failure ==="

# Step 1: Register A
$ra = rq2 POST "/auth/register" @{fullName="BS A";email=$emailA;password="Segura123!"}
$tokA = $ra.accessToken; $refA = $ra.refreshToken
Write-Host "STEP 1: registered A"
testCategories $tokA "after register A"

# Step 2: Register B
$rb = rq2 POST "/auth/register" @{fullName="BS B";email=$emailB;password="Segura123!"}
testCategories $tokA "after register B"

# Step 3: Duplicate (409)
rq2 POST "/auth/register" @{fullName="Dup";email=$emailA;password="Segura123!"} | Out-Null
Write-Host "STEP 3: duplicate registration done (409)"
testCategories $tokA "after dup 409"

# Step 4: Weak password (400)
rq2 POST "/auth/register" @{fullName="Weak";email="weak_bs$RUN@test.com";password="123"} | Out-Null
Write-Host "STEP 4: weak password done (400)"
testCategories $tokA "after weak 400"

# Step 5: No password (400)
rq2 POST "/auth/register" @{fullName="NP";email="np_bs$RUN@test.com"} | Out-Null
Write-Host "STEP 5: no password done (400)"
testCategories $tokA "after no-pwd 400"

# Step 6: Login valid
$login = rq2 POST "/auth/login" @{email=$emailA;password="Segura123!"}
$tokA = $login.accessToken; $refA = $login.refreshToken
Write-Host "STEP 6: valid login done"
testCategories $tokA "after login"

# Step 7: Bad login (401)
rq2 POST "/auth/login" @{email=$emailA;password="Wrong!"} | Out-Null
Write-Host "STEP 7: bad login done (401)"
testCategories $tokA "after bad login 401"

# Step 8: No auth GET
rq2 GET "/users/me" | Out-Null
Write-Host "STEP 8: no-auth GET done (401)"
testCategories $tokA "after no-auth GET 401"

# Step 9: Fake token GET
rq2 GET "/users/me" -token "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJmYWtlIn0.INVALIDSIGNATURE" | Out-Null
Write-Host "STEP 9: fake token done (401)"
testCategories $tokA "after fake token 401"

# Step 10: Refresh
$rr = rq2 POST "/auth/refresh" @{refreshToken=$refA}
$tokA = $rr.accessToken; $refA = $rr.refreshToken
Write-Host "STEP 10: refresh done"
testCategories $tokA "after refresh"

# Step 11: Logout
rq2 POST "/auth/logout" @{refreshToken=$refA} -token $tokA | Out-Null
Write-Host "STEP 11: logout done"
# Re-login
$rl = rq2 POST "/auth/login" @{email=$emailA;password="Segura123!"}
$tokA = $rl.accessToken
Write-Host "STEP 11b: re-login done"
testCategories $tokA "after logout+relogin"
