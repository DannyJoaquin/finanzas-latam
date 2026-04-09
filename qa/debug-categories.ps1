$BASE = "http://localhost:3000/api/v1"
$ra = Invoke-RestMethod -Uri "$BASE/auth/register" -Method POST -ContentType "application/json" -Body '{"fullName":"DbgFull","email":"dbgfull_x9@test.com","password":"Segura123!"}' -UseBasicParsing
$tok = $ra.data.accessToken
Write-Host "Token acquired"

# 7 warmup requests
for($i=0;$i -lt 7;$i++){
    try{ Invoke-RestMethod -Uri "$BASE/users/me" -Headers @{Authorization="Bearer $tok";"Content-Type"="application/json"} -UseBasicParsing -ErrorAction Stop | Out-Null }catch{}
}
Write-Host "Warmup done"

# Categories with full exception details
$hdr = @{"Content-Type"="application/json"; "Authorization"="Bearer $tok"}
$p = @{Method="GET"; Uri="$BASE/categories"; Headers=$hdr; TimeoutSec=15}
try {
    $r = Invoke-RestMethod @p -UseBasicParsing -ErrorAction Stop
    Write-Host "SUCCESS: dataCount=$($r.data.Count)"
} catch {
    Write-Host "FAIL: exType=$($_.Exception.GetType().FullName)"
    Write-Host "FAIL: msg=$($_.Exception.Message)"
    $st = $null
    try { $st = [int]$_.Exception.Response.StatusCode } catch { Write-Host "StatusCast THREW: $($_.Exception.Message)" }
    Write-Host "FAIL: status=$st"
    $errBody = ""
    try { $errBody = $_.ErrorDetails.Message } catch {}
    Write-Host "FAIL: body=$errBody"
}
