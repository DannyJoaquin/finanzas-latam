$BASE  = "http://localhost:3000/api/v1"
$RUN   = [System.DateTime]::Now.ToString("mmssff")

function unwrap($r){
    if($r -is [hashtable] -and $r.__error){ return $r }
    if($null -ne $r.data){ return $r.data }
    return $r
}

function req([string]$method,[string]$path,$body=$null,[string]$token=""){
    $headers = @{"Content-Type"="application/json"}
    if($token){ $headers["Authorization"]="Bearer $token" }
    $params = @{Method=$method;Uri="$BASE$path";Headers=$headers;TimeoutSec=15}
    if($body){ $params["Body"]=($body|ConvertTo-Json -Depth 10) }
    for($attempt=1; $attempt -le 5; $attempt++){
        try {
            return Invoke-RestMethod @params -UseBasicParsing -ErrorAction Stop
        } catch {
            $status = $null
            try{ $status = [int]$_.Exception.Response.StatusCode }catch{}
            $bt=""
            try{ $bt=$_.ErrorDetails.Message }catch{}
            if($null -eq $status -and $attempt -lt 5){
                Write-Host "  [RETRY $attempt] categories null status - waiting..."
                Start-Sleep -Milliseconds 1500
                continue
            }
            return @{__error=$true;status=$status;body=$bt}
        }
    }
}

function rq([string]$method,[string]$path,$body=$null,[string]$token=""){
    return (unwrap (req $method $path $body $token))
}

# Simulate the QA test auth flow exactly
$emailA = "dbgRq_${RUN}@test.com"
$emailB = "dbgRqB_${RUN}@test.com"

Write-Host "Registering A..."
$ra = rq POST "/auth/register" @{fullName="DbgRq A";email=$emailA;password="Segura123!"}
$tokenA = $ra.accessToken; $refreshA = $ra.refreshToken
Write-Host "A registered, tokenA=$($tokenA.Substring(0,15))..."

Write-Host "Registering B..."
$rb = rq POST "/auth/register" @{fullName="DbgRq B";email=$emailB;password="Segura123!"}
$tokenB = $rb.accessToken

# Duplicate
rq POST "/auth/register" @{fullName="Dup";email=$emailA;password="Segura123!"} | Out-Null
# Weak password
rq POST "/auth/register" @{fullName="Weak";email="weak_$RUN@test.com";password="123"} | Out-Null
# No password
rq POST "/auth/register" @{fullName="NP";email="np_$RUN@test.com"} | Out-Null
# Login valid
$login = rq POST "/auth/login" @{email=$emailA;password="Segura123!"}
$tokenA = $login.accessToken; $refreshA = $login.refreshToken
Write-Host "Login OK, new tokenA=$($tokenA.Substring(0,15))..."
# Bad login
rq POST "/auth/login" @{email=$emailA;password="Wrong!"} | Out-Null
# No token GET /users/me
rq GET "/users/me" | Out-Null
# Fake token
rq GET "/users/me" -token "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJmYWtlIn0.INVALIDSIGNATURE" | Out-Null
# Refresh
$refreshResp = rq POST "/auth/refresh" @{refreshToken=$refreshA}
$tokenA = $refreshResp.accessToken; $refreshA = $refreshResp.refreshToken
Write-Host "Refresh OK"
# Logout
rq POST "/auth/logout" @{refreshToken=$refreshA} -token $tokenA | Out-Null
# Reuse blacklisted refresh (should fail 401)
rq POST "/auth/refresh" @{refreshToken=$refreshA} | Out-Null
# Re-login
$rl = rq POST "/auth/login" @{email=$emailA;password="Segura123!"}
$tokenA = $rl.accessToken
Write-Host "Re-login OK, final tokenA=$($tokenA.Substring(0,15))..."

# loginB2
$loginB2 = rq POST "/auth/login" @{email=$emailB;password="Segura123!"}
$tokenB = $loginB2.accessToken

# Section 2: Incomes
Write-Host "Section 2 incomes..."
$i1 = rq POST "/incomes" @{sourceName="Salario";amount=25000;type="salary";cycle="monthly"} -token $tokenA
rq POST "/incomes" @{sourceName="Freelance";amount=8000;type="freelance";cycle="biweekly"} -token $tokenA | Out-Null
rq POST "/incomes" @{sourceName="Cero";amount=0;type="salary";cycle="monthly"} -token $tokenA | Out-Null
rq POST "/incomes" @{sourceName="Neg";amount=-5000;type="salary";cycle="monthly"} -token $tokenA | Out-Null
rq POST "/incomes" @{sourceName="Big";amount=999999999999;type="salary";cycle="monthly"} -token $tokenA | Out-Null
rq GET "/incomes/projection" -token $tokenA | Out-Null
rq GET "/incomes" -token $tokenB | Out-Null

# Section 3: Categories
Write-Host "Section 3: Requesting categories..."
$catsRaw = rq GET "/categories" -token $tokenA
if($catsRaw.__error){
    Write-Host "FAIL: error status=$($catsRaw.status) body=$($catsRaw.body)"
} else {
    $catList = if($catsRaw -is [array]){$catsRaw}else{@($catsRaw)}
    $catId = ($catList | Where-Object {$_.type -eq "expense"} | Select-Object -First 1).id
    Write-Host "SUCCESS: catCount=$($catList.Count) expense catId=$catId"
}
