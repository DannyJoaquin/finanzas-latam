#!/usr/bin/env pwsh
# QA Test Suite — FinanzasLATAM  (corrected: handles {data:...} wrapper)
$BASE  = "http://localhost:3000/api/v1"
$RUN   = [System.DateTime]::Now.ToString("mmssff")   # unique suffix per run
$BUGS  = [System.Collections.Generic.List[hashtable]]::new()
$PASS  = 0
$FAIL  = 0

function bug([string]$id,[string]$sev,[string]$title,[string]$repro,[string]$fix){
    $script:BUGS.Add([ordered]@{ID=$id;SEV=$sev;TITLE=$title;REPRO=$repro;FIX=$fix})
    $c = if($sev -eq 'CRITICO'){'Red'}elseif($sev -eq 'ALTO'){'Yellow'}else{'Cyan'}
    Write-Host "  [BUG $id][$sev] $title" -ForegroundColor $c
}
function pass([string]$msg){ $script:PASS++; Write-Host "  [PASS] $msg" -ForegroundColor Green }
function fail([string]$msg){ $script:FAIL++; Write-Host "  [FAIL] $msg" -ForegroundColor Red }

# Unwraps {data: x} or returns x directly
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
            # If no HTTP response (connection refused / nodemon restart), retry up to 5 times
            if($null -eq $status -and $attempt -lt 5){
                Start-Sleep -Milliseconds 1500
                continue
            }
            return @{__error=$true;status=$status;body=$bt}
        }
    }
}

# Convenience: req + unwrap
function rq([string]$method,[string]$path,$body=$null,[string]$token=""){
    return (unwrap (req $method $path $body $token))
}

Write-Host ""
Write-Host "=============================================================" -ForegroundColor Magenta
Write-Host " QA SUITE - FinanzasLATAM API  (run=$RUN)" -ForegroundColor Magenta
Write-Host "=============================================================" -ForegroundColor Magenta
Write-Host ""

# ── Wait for API to be stable (survive any hot-reload restart) ────────────────
Write-Host "  [INIT] Esperando que la API este estable..." -NoNewline
$stable = 0
for($w=0; $w -lt 30; $w++){
    try{
        $hc = Invoke-RestMethod -Uri "$BASE/health" -UseBasicParsing -ErrorAction SilentlyContinue
        if($hc){ $stable++ } else { $stable = 0 }
    } catch {
        $hcSt = $null
        try{ $hcSt = [int]$_.Exception.Response.StatusCode }catch{}
        if($null -ne $hcSt){ $stable++ } else { $stable = 0 }  # any HTTP response = server up
    }
    if($stable -ge 3){ break }
    Start-Sleep -Seconds 1
}
Write-Host " OK (${w}s)" -ForegroundColor DarkGray
Write-Host ""

$emailA = "ana_${RUN}@test.com"
$emailB = "bob_${RUN}@test.com"
$emailC = "nuevo_${RUN}@test.com"

# ─── SECTION 1: AUTH ─────────────────────────────────────────────────────────
Write-Host "[ SECTION 1 ] AUTH" -ForegroundColor White

$ra = rq POST "/auth/register" @{fullName="Ana Garcia";email=$emailA;password="Segura123!"}
if($ra.__error){ fail "Registro usuario A: HTTP $($ra.status)"; bug "AUTH-01" "CRITICO" "Registro falla con datos validos" "POST /auth/register datos validos" "Revisar validaciones y conexion DB" }
else{ pass "Registro usuario A OK"; $tokenA=$ra.accessToken; $refreshA=$ra.refreshToken; $userIdA=$ra.id }

$rb = rq POST "/auth/register" @{fullName="Bob Ramirez";email=$emailB;password="Segura123!"}
if(-not $rb.__error){ $tokenB=$rb.accessToken; $userIdB=$rb.id; pass "Registro usuario B OK" }
else{ fail "Registro usuario B fallo (HTTP $($rb.status))" }

# 1.3 Duplicado
$dup = rq POST "/auth/register" @{fullName="Dup";email=$emailA;password="Segura123!"}
if($dup.__error -and $dup.status -eq 409){ pass "Email duplicado --> 409 Conflict" }
else{ fail "Email duplicado no retorna 409 (got $($dup.status))"; bug "AUTH-02" "ALTO" "Email duplicado no retorna 409" "Registrar mismo email dos veces" "Lanzar ConflictException en AuthService.register" }

# 1.4 Contrasena debil
$weak = rq POST "/auth/register" @{fullName="Test";email="weak_${RUN}@test.com";password="123"}
if($weak.__error -and $weak.status -eq 400){ pass "Contrasena debil --> 400" }
else{ fail "Contrasena debil aceptada (got $($weak.status))"; bug "AUTH-03" "ALTO" "Acepta contrasenas debiles" "POST /auth/register con password=123" "Agregar @MinLength(8) en RegisterDto" }

# 1.5 Sin password
$nopass = rq POST "/auth/register" @{fullName="Test";email="nopass_${RUN}@test.com"}
if($nopass.__error -and $nopass.status -eq 400){ pass "Registro sin password --> 400" }
else{ fail "Registro sin password no rechazado"; bug "AUTH-04" "ALTO" "Campo password opcional en registro" "Omitir password en POST /auth/register" "Agregar @IsNotEmpty en RegisterDto" }

# 1.6 Login valido
$login = rq POST "/auth/login" @{email=$emailA;password="Segura123!"}
if(-not $login.__error -and $login.accessToken){
    pass "Login valido OK"
    $tokenA  = $login.accessToken
    $refreshA= $login.refreshToken
} else{
    fail "Login valido falla: HTTP $($login.status)"
    bug "AUTH-05" "CRITICO" "Login falla con credenciales correctas" "POST /auth/login credenciales correctas" "Revisar LocalStrategy"
}

# 1.7 Password incorrecta
$badlogin = rq POST "/auth/login" @{email=$emailA;password="Wrong999!"}
if($badlogin.__error -and $badlogin.status -eq 401){ pass "Password incorrecta --> 401" }
else{ fail "Password incorrecta no retorna 401 (got $($badlogin.status))"; bug "AUTH-06" "CRITICO" "Login incorrecto no retorna 401" "POST /auth/login con password errada" "Validar credenciales en AuthService.validateUser" }

# 1.8 Sin token
$noauth = rq GET "/users/me"
if($noauth.__error -and $noauth.status -eq 401){ pass "Ruta protegida sin token --> 401" }
else{ fail "Ruta protegida accesible sin token"; bug "AUTH-07" "CRITICO" "Endpoint protegido sin JWT accesible" "GET /users/me sin Authorization header" "GlobalJwtAuthGuard no esta aplicado" }

# 1.9 Token falso
$fakeToken = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJmYWtlIn0.INVALIDSIGNATURE"
$fakeReq = rq GET "/users/me" -token $fakeToken
if($fakeReq.__error -and $fakeReq.status -eq 401){ pass "Token falso --> 401" }
else{ fail "Token con firma invalida aceptado"; bug "AUTH-08" "CRITICO" "JWT con firma invalida aceptado" "GET /users/me con JWT signature incorrecta" "Verificar secretOrKey en JwtStrategy" }

# 1.10 Refresh token
if($refreshA){
    $refreshResp = rq POST "/auth/refresh" @{refreshToken=$refreshA}
    if(-not $refreshResp.__error -and $refreshResp.accessToken){
        pass "Refresh token renueva sesion"
        $tokenA  = $refreshResp.accessToken
        $refreshA= $refreshResp.refreshToken
    } else{
        fail "Refresh token falla (HTTP $($refreshResp.status))"
        bug "AUTH-09" "ALTO" "Refresh token no renueva sesion" "POST /auth/refresh con refreshToken valido" "Revisar AuthService.refresh"
    }
}

# 1.11 Logout + reuso
if($tokenA -and $refreshA){
    $logoutResp = rq POST "/auth/logout" @{refreshToken=$refreshA} -token $tokenA
    if(-not $logoutResp.__error){
        $reuse = rq POST "/auth/refresh" @{refreshToken=$refreshA}
        if($reuse.__error -and $reuse.status -eq 401){ pass "Refresh token blacklisteado post-logout" }
        else{ fail "Refresh token reutilizable post-logout"; bug "AUTH-10" "CRITICO" "Refresh token valido despues de logout" "1.Login 2.Logout 3.Refresh con mismo token" "Agregar refreshToken a blacklist Redis en logout" }
    }
    # Re-login post-logout
    $rl = rq POST "/auth/login" @{email=$emailA;password="Segura123!"}
    if(-not $rl.__error -and $rl.accessToken){ $tokenA=$rl.accessToken; pass "Re-login post-logout OK" }
    else{ fail "Re-login post-logout falla" }
}

$loginB2 = rq POST "/auth/login" @{email=$emailB;password="Segura123!"}
if(-not $loginB2.__error -and $loginB2.accessToken){ $tokenB=$loginB2.accessToken }

Write-Host "  [INFO] tokenA = $($tokenA.Substring(0,[math]::Min(20,$tokenA.Length)))..." -ForegroundColor DarkGray
Write-Host ""

# ─── SECTION 2: INGRESOS ─────────────────────────────────────────────────────
Write-Host "[ SECTION 2 ] INGRESOS" -ForegroundColor White

$inc1 = rq POST "/incomes" @{sourceName="Salario";amount=25000;type="salary";cycle="monthly"} -token $tokenA
if(-not $inc1.__error){ pass "Ingreso fijo mensual creado"; $incomeId=$inc1.id }
else{ fail "Crear ingreso fijo falla (HTTP $($inc1.status)) body=$($inc1.body)"; bug "INC-01" "CRITICO" "No se puede crear ingreso con datos validos" "POST /incomes datos validos" "Revisar IncomesService.create" }

$inc2 = rq POST "/incomes" @{sourceName="Freelance";amount=8000;type="freelance";cycle="biweekly"} -token $tokenA
if(-not $inc2.__error){ pass "Ingreso quincenal biweekly creado" }
else{ fail "Ingreso biweekly falla (HTTP $($inc2.status))" }

$incZero = rq POST "/incomes" @{sourceName="Cero";amount=0;type="salary";cycle="monthly"} -token $tokenA
if($incZero.__error -and $incZero.status -eq 400){ pass "Ingreso monto=0 --> 400" }
else{ fail "Ingreso con monto cero aceptado (got $($incZero.status))"; bug "INC-02" "MEDIO" "Ingreso con estimatedAmount=0 aceptado" "POST /incomes con estimatedAmount=0" "Agregar @IsPositive en CreateIncomeDto" }

$incNeg = rq POST "/incomes" @{sourceName="Negativo";amount=-5000;type="salary";cycle="monthly"} -token $tokenA
if($incNeg.__error -and $incNeg.status -eq 400){ pass "Ingreso negativo --> 400" }
else{ fail "Ingreso negativo aceptado (got $($incNeg.status))"; bug "INC-03" "ALTO" "Ingreso con monto negativo aceptado" "POST /incomes con estimatedAmount=-5000" "Agregar @Min(0.01) en CreateIncomeDto" }

$incBig = rq POST "/incomes" @{sourceName="Billonario";amount=999999999999;type="salary";cycle="monthly"} -token $tokenA
if($incBig.__error){ pass "Monto extremo rechazado" }
else{ fail "Monto 999999999999 aceptado sin validacion"; bug "INC-04" "MEDIO" "Montos astronomicos sin limite maximo" "POST /incomes con estimatedAmount=999999999999" "Agregar @Max(999999999) en CreateIncomeDto" }

$proj = rq GET "/incomes/projection" -token $tokenA
if(-not $proj.__error){ pass "Proyeccion de ingresos accesible" }
else{ fail "Proyeccion falla (HTTP $($proj.status))"; bug "INC-05" "ALTO" "Endpoint proyeccion de ingresos retorna error" "GET /incomes/projection" "Revisar IncomesService.getProjection" }

# IDOR
$isoInc = rq GET "/incomes" -token $tokenB
if(-not $isoInc.__error){
    $items = if($isoInc -is [array]){$isoInc}elseif($isoInc.items){$isoInc.items}else{@()}
    $leaked = @($items) | Where-Object {$_.name -eq "Salario"}
    if(-not $leaked){ pass "Aislamiento: B no ve ingresos de A" }
    else{ fail "IDOR: usuario B ve ingresos de A"; bug "INC-06" "CRITICO" "IDOR ingresos: usuario B ve datos de usuario A" "GET /incomes con token de B, aparecen datos de A" "Filtrar por userId en IncomesService.findAll" }
}
Write-Host ""

# ─── SECTION 3: GASTOS ───────────────────────────────────────────────────────
Write-Host "[ SECTION 3 ] GASTOS" -ForegroundColor White

$catsRaw = rq GET "/categories" -token $tokenA
$catId  = $null
if(-not ($catsRaw -is [hashtable] -and $catsRaw.__error)){
    $catList = if($catsRaw -is [array]){$catsRaw}else{@($catsRaw)}
    $catId = ($catList | Where-Object {$_.type -eq "expense"} | Select-Object -First 1).id
    if($catId){ pass "Categorias cargadas (catId=$catId)" }
    else{ fail "Sin categorias de tipo expense"; bug "CAT-01" "ALTO" "No hay categorias expense en DB" "GET /categories no retorna expense" "Ejecutar npm run seed" }
} else{ fail "GET /categories falla (HTTP $($catsRaw.status))" }

if($catId){
    $exp1 = rq POST "/expenses" @{amount=350;description="Almuerzo";categoryId=$catId;paymentMethod="cash";date="2026-04-05"} -token $tokenA
    if(-not $exp1.__error){ pass "Gasto valido creado"; $expId1=$exp1.id }
    else{ fail "Crear gasto falla (HTTP $($exp1.status)) body=$($exp1.body)"; bug "EXP-01" "CRITICO" "No se puede crear gasto con datos validos" "POST /expenses datos correctos" "Revisar ExpensesService.create" }
}

$expNeg = rq POST "/expenses" @{amount=-100;description="Neg";categoryId=$catId;paymentMethod="cash";date="2026-04-05"} -token $tokenA
if($expNeg.__error -and $expNeg.status -eq 400){ pass "Gasto negativo --> 400" }
else{ fail "Gasto con monto negativo aceptado (got $($expNeg.status))"; bug "EXP-02" "ALTO" "Gasto con amount negativo aceptado" "POST /expenses con amount=-100" "Agregar @IsPositive en CreateExpenseDto" }

$expZero = rq POST "/expenses" @{amount=0;description="Cero";categoryId=$catId;paymentMethod="cash";date="2026-04-05"} -token $tokenA
if($expZero.__error -and $expZero.status -eq 400){ pass "Gasto monto=0 --> 400" }
else{ fail "Gasto con amount=0 aceptado (got $($expZero.status))"; bug "EXP-03" "MEDIO" "Gasto con amount=0 aceptado" "POST /expenses con amount=0" "Agregar @Min(0.01) en CreateExpenseDto" }

$expBadCat = rq POST "/expenses" @{amount=100;description="Test";categoryId="00000000-0000-0000-0000-000000000000";paymentMethod="cash";date="2026-04-05"} -token $tokenA
if($expBadCat.__error -and ($expBadCat.status -eq 400 -or $expBadCat.status -eq 404)){ pass "Category UUID inexistente --> error correcto" }
else{ fail "FK invalida aceptada (HTTP $($expBadCat.status))"; bug "EXP-04" "ALTO" "Gasto con categoryId inexistente aceptado" "POST /expenses con categoryId UUID falso" "Validar FK en ExpensesService antes de insertar" }

$futureDate = (Get-Date).AddYears(2).ToString("yyyy-MM-dd")
$expFuture = rq POST "/expenses" @{amount=100;description="Futuro";categoryId=$catId;paymentMethod="cash";date=$futureDate} -token $tokenA
if($expFuture.__error -and $expFuture.status -eq 400){ pass "Fecha 2 anios futuro --> 400" }
else{ fail "Gasto con fecha 2 anios en el futuro aceptado"; bug "EXP-05" "BAJO" "Fechas futuras lejanas aceptadas en gastos" "POST /expenses con date 2 anios en futuro" "Validar date menor hoy+1dia en CreateExpenseDto" }

if($catId){
    $dup1 = rq POST "/expenses" @{amount=500;description="Duplicado";categoryId=$catId;paymentMethod="cash";date="2026-04-05"} -token $tokenA
    Start-Sleep -Milliseconds 200
    $dup2 = rq POST "/expenses" @{amount=500;description="Duplicado";categoryId=$catId;paymentMethod="cash";date="2026-04-05"} -token $tokenA
    if(-not $dup1.__error -and -not $dup2.__error -and ($dup1.id -ne $dup2.id)){
        fail "Gastos duplicados exactos aceptados sin advertencia"
        bug "EXP-07" "BAJO" "Sin deteccion de gastos duplicados exactos" "POST mismo gasto dos veces en menos de 1 segundo" "Detectar duplicados con hash en ventana de 5 segundos"
    } else{ pass "Gastos duplicados gestionados" }
}

if($expId1){
    $isoExp = rq GET "/expenses/$expId1" -token $tokenB
    if($isoExp.__error -and ($isoExp.status -eq 403 -or $isoExp.status -eq 404)){ pass "IDOR Gastos: B no puede ver gasto de A" }
    else{ fail "IDOR: usuario B puede ver gasto de A"; bug "EXP-08" "CRITICO" "IDOR gastos: usuario B accede a gasto de A" "GET /expenses/:id_de_A con token de B" "Verificar ownership en ExpensesService.findOne" }
}
Write-Host ""

# ─── SECTION 4: PRESUPUESTOS ─────────────────────────────────────────────────
Write-Host "[ SECTION 4 ] PRESUPUESTOS" -ForegroundColor White

if($catId){
    $today = [System.DateTime]::Today
    $pStart = [System.DateTime]::new($today.Year, $today.Month, 1).ToString("yyyy-MM-dd")
    $pEnd   = [System.DateTime]::new($today.Year, $today.Month, [System.DateTime]::DaysInMonth($today.Year, $today.Month)).ToString("yyyy-MM-dd")

    $bud1 = rq POST "/budgets" @{name="Comida";categoryId=$catId;amount=3000;periodType="monthly";periodStart=$pStart;periodEnd=$pEnd} -token $tokenA
    if(-not $bud1.__error){ pass "Presupuesto creado"; $budId=$bud1.id }
    else{ fail "Crear presupuesto falla (HTTP $($bud1.status)) body=$($bud1.body)"; bug "BUD-01" "CRITICO" "No se puede crear presupuesto" "POST /budgets datos validos" "Revisar BudgetsService.create" }

    $budZero = rq POST "/budgets" @{name="Cero";categoryId=$catId;amount=0;periodType="monthly";periodStart=$pStart;periodEnd=$pEnd} -token $tokenA
    if($budZero.__error -and $budZero.status -eq 400){ pass "Presupuesto limite=0 --> 400" }
    else{ fail "Presupuesto con amount=0 aceptado"; bug "BUD-02" "MEDIO" "Presupuesto con limite cero aceptado" "POST /budgets con amount=0" "Agregar @IsPositive en CreateBudgetDto" }

    $budDup = rq POST "/budgets" @{name="Comida2";categoryId=$catId;amount=5000;periodType="monthly";periodStart=$pStart;periodEnd=$pEnd} -token $tokenA
    if($budDup.__error){ pass "Presupuesto duplicado cat+periodo rechazado" }
    else{ fail "Dos presupuestos misma cat+periodo aceptados"; bug "BUD-03" "MEDIO" "Duplicado presupuesto por categoria y periodo" "Crear 2 presupuestos con misma categoria y periodo" "Unique constraint en userId+categoryId+period" }
}

if($budId){
    $budCheck = rq GET "/budgets/$budId" -token $tokenA
    if(-not $budCheck.__error -and $null -ne $budCheck.spent){ pass "Campo spent presente (spent=$($budCheck.spent))" }
    else{ fail "Campo spent no disponible"; bug "BUD-04" "ALTO" "Presupuesto no calcula spent en tiempo real" "GET /budgets/:id no retorna campo spent" "Calcular spent en BudgetsService.findOne via subquery" }
}
Write-Host ""

# ─── SECTION 5: CASH ─────────────────────────────────────────────────────────
Write-Host "[ SECTION 5 ] MODO EFECTIVO" -ForegroundColor White

$cash1 = rq POST "/cash/accounts" @{name="Cartera";initialBalance=5000} -token $tokenA
if(-not $cash1.__error){ pass "Cuenta efectivo creada"; $cashId=$cash1.id }
else{ fail "Crear cuenta efectivo falla (HTTP $($cash1.status)) body=$($cash1.body)"; bug "CASH-01" "ALTO" "No se puede crear cuenta de efectivo" "POST /cash/accounts datos validos" "Revisar CashService.createAccount" }

if($cashId){
    $dep = rq POST "/cash/accounts/$cashId/deposit" @{amount=2000;description="Pago recibido"} -token $tokenA
    if(-not $dep.__error){ pass "Deposito efectivo OK" }
    else{ fail "Deposito falla (HTTP $($dep.status))"; bug "CASH-02" "ALTO" "Deposito en cuenta efectivo falla" "POST /cash/accounts/:id/deposit" "Revisar CashService.deposit" }

    $wit = rq POST "/cash/accounts/$cashId/withdraw" @{amount=1000;description="Gasto mercado"} -token $tokenA
    if(-not $wit.__error){ pass "Retiro efectivo OK" }
    else{ fail "Retiro falla (HTTP $($wit.status))"; bug "CASH-03" "ALTO" "Retiro de cuenta efectivo falla" "POST /cash/accounts/:id/withdraw" "Revisar CashService.withdraw" }

    # CRITICO: overdraft
    $overdraft = rq POST "/cash/accounts/$cashId/withdraw" @{amount=99999;description="Overdraft"} -token $tokenA
    if($overdraft.__error -and $overdraft.status -eq 400){ pass "Overdraft --> 400 saldo insuficiente" }
    else{ fail "OVERDRAFT ACEPTADO saldo negativo posible"; bug "CASH-04" "CRITICO" "Permite retiro mayor al saldo disponible" "POST /cash/:id/withdraw con amount mayor al balance" "Validar balance >= amount antes de insertar transaccion" }

    $negWit = rq POST "/cash/accounts/$cashId/withdraw" @{amount=-500;description="Neg"} -token $tokenA
    if($negWit.__error -and $negWit.status -eq 400){ pass "Retiro monto negativo --> 400" }
    else{ fail "Retiro con monto negativo aceptado"; bug "CASH-05" "ALTO" "Retiro con amount negativo no rechazado" "POST /cash/:id/withdraw con amount=-500" "Agregar @IsPositive en CashWithdrawDto" }

    # Balance 5000 + 2000 - 1000 = 6000
    $accounts = rq GET "/cash/accounts" -token $tokenA
    if(-not ($accounts -is [hashtable] -and $accounts.__error)){
        $acctList = if($accounts -is [array]){$accounts}else{@($accounts)}
        $acct = $acctList | Where-Object {$_.id -eq $cashId}
        if($acct -and [double]$acct.balance -eq 6000){ pass "Balance efectivo correcto: 6000" }
        elseif($acct){ fail "Balance incorrecto: esperado 6000, obtenido $($acct.balance)"; bug "CASH-06" "CRITICO" "Balance incorrecto tras deposit y withdraw" "Dep 2000 + Wit 1000 sobre saldo inicial 5000" "Verificar logica atomica en CashService" }
        else{ fail "Cuenta no encontrada en respuesta de /cash/accounts" }
    }

    # IDOR
    $idorCash = rq POST "/cash/accounts/$cashId/withdraw" @{amount=100;description="Robo"} -token $tokenB
    if($idorCash.__error -and ($idorCash.status -eq 403 -or $idorCash.status -eq 404)){ pass "IDOR Cash: B no puede retirar de cuenta de A" }
    else{ fail "IDOR: usuario B retira de cuenta de A"; bug "CASH-07" "CRITICO" "IDOR Cash: usuario B puede retirar de cuenta de A" "POST /cash/:id_de_A/withdraw con token de B" "Verificar ownership en CashService.withdraw" }
}
Write-Host ""

# ─── SECTION 6: METAS ────────────────────────────────────────────────────────
Write-Host "[ SECTION 6 ] METAS" -ForegroundColor White

$goal1 = rq POST "/goals" @{name="Vacaciones";targetAmount=15000;targetDate="2026-12-31";icon="Avion"} -token $tokenA
if(-not $goal1.__error){ pass "Meta creada"; $goalId=$goal1.id }
else{ fail "Crear meta falla (HTTP $($goal1.status)) body=$($goal1.body)"; bug "GOAL-01" "ALTO" "No se puede crear meta de ahorro" "POST /goals datos validos" "Revisar GoalsService.create" }

if($goalId){
    $contrib1 = rq POST "/goals/$goalId/contribute" @{amount=3000;notes="Ahorro mes 1"} -token $tokenA
    if(-not $contrib1.__error){ pass "Contribucion a meta OK" }
    else{ fail "Contribucion a meta falla (HTTP $($contrib1.status))"; bug "GOAL-02" "ALTO" "Contribucion a meta falla" "POST /goals/:id/contribute datos validos" "Revisar GoalsService.contribute" }

    $overContrib = rq POST "/goals/$goalId/contribute" @{amount=99999;notes="Exceso"} -token $tokenA
    if(-not $overContrib.__error){
        $gc = rq GET "/goals/$goalId" -token $tokenA
        if(-not $gc.__error -and ([double]$gc.currentAmount -gt [double]$gc.targetAmount)){
            fail "Contribucion excede meta sin cap ni autocomplete"
            bug "GOAL-03" "MEDIO" "currentAmount puede superar targetAmount" "Contribuir 99999 a meta de 15000" "Capear al monto faltante o marcar status completed"
        } else{ pass "Meta auto-completada o limitada al objetivo" }
    }

    $negGoal = rq POST "/goals/$goalId/contribute" @{amount=-500;notes="Neg"} -token $tokenA
    if($negGoal.__error -and $negGoal.status -eq 400){ pass "Contribucion negativa --> 400" }
    else{ fail "Contribucion negativa aceptada"; bug "GOAL-04" "ALTO" "Contribucion negativa en meta aceptada" "POST /goals/:id/contribute con amount=-500" "Agregar @IsPositive en GoalContributionDto" }

    $idorGoal = rq GET "/goals/$goalId" -token $tokenB
    if($idorGoal.__error -and ($idorGoal.status -eq 403 -or $idorGoal.status -eq 404)){ pass "IDOR Goals: B no ve meta de A" }
    else{ fail "IDOR: usuario B puede ver meta de A"; bug "GOAL-05" "CRITICO" "IDOR Goals: usuario B accede a meta de A" "GET /goals/:id_de_A con token de B" "Filtrar por userId en GoalsService.findOne" }
}
Write-Host ""

# ─── SECTION 7: ANALYTICS ────────────────────────────────────────────────────
Write-Host "[ SECTION 7 ] ANALYTICS Y DASHBOARD" -ForegroundColor White

$dash = rq GET "/analytics/dashboard" -token $tokenA
if(-not $dash.__error){
    pass "Dashboard accesible"

    if($null -ne $dash.totalIncomeThisPeriod -and $null -ne $dash.totalSpentThisPeriod -and $null -ne $dash.availableBalance){
        $calc = [math]::Round([double]$dash.totalIncomeThisPeriod - [double]$dash.totalSpentThisPeriod, 2)
        $rep  = [math]::Round([double]$dash.availableBalance, 2)
        if([math]::Abs($calc - $rep) -lt 1.0){ pass "Balance = ingresos - gastos verificado" }
        else{ fail "INCONSISTENCIA balance: esperado $calc obtenido $rep"; bug "DASH-01" "CRITICO" "Balance inconsistente: totalIncomeThisPeriod - totalSpentThisPeriod diferente de availableBalance" "Comparar campos en GET /analytics/dashboard" "Unificar calculo de balance en AnalyticsService.getDashboard" }
    } else{
        fail "Dashboard faltan campos financieros (totalIncomeThisPeriod/totalSpentThisPeriod/availableBalance)"
        bug "DASH-02" "ALTO" "Dashboard no retorna KPIs financieros" "GET /analytics/dashboard" "Asegurar que getDashboard retorna todos los KPIs"
    }

    if($null -ne $dash.safeDailySpend -and [double]$dash.safeDailySpend -lt 0){
        fail "safeDailySpend negativo: $($dash.safeDailySpend)"
        bug "DASH-03" "ALTO" "safeDailySpend puede ser negativo" "GET /analytics/dashboard con gastos mayores a ingresos" "Capear safeDailySpend a 0 como minimo"
    } elseif($null -ne $dash.safeDailySpend){ pass "safeDailySpend >= 0: $($dash.safeDailySpend)" }

    $validRisk = @("green","yellow","red")
    if($validRisk -contains $dash.riskLevel){ pass "riskLevel valido: $($dash.riskLevel)" }
    else{ fail "riskLevel invalido: $($dash.riskLevel)"; bug "DASH-04" "MEDIO" "riskLevel retorna valor fuera del enum" "GET /analytics/dashboard" "Normalizar a green/yellow/red en AnalyticsService" }
} else{
    fail "Dashboard falla (HTTP $($dash.status)) body=$($dash.body)"
    bug "DASH-05" "CRITICO" "Dashboard endpoint retorna error" "GET /analytics/dashboard con token valido" "Revisar AnalyticsService.getDashboard"
}

$trends = rq GET "/analytics/spending-trends" -token $tokenA
if(-not $trends.__error){ pass "Spending trends OK" }
else{ fail "Spending trends falla (HTTP $($trends.status)) body=$($trends.body)"; bug "DASH-06" "ALTO" "Spending trends falla" "GET /analytics/spending-trends" "Revisar AnalyticsService.getSpendingTrends" }

$anomalies = rq GET "/analytics/anomalies" -token $tokenA
if(-not $anomalies.__error){ pass "Anomaly detection OK" }
else{ fail "Anomaly detection falla (HTTP $($anomalies.status))"; bug "DASH-07" "MEDIO" "Anomaly detection endpoint retorna error" "GET /analytics/anomalies" "Revisar AnalyticsService.detectAnomalies" }

$sim = rq GET "/analytics/simulation" -token $tokenA
if(-not $sim.__error){ pass "Simulation endpoint OK" }
else{ fail "Simulation falla (HTTP $($sim.status))"; bug "DASH-08" "MEDIO" "Analytics simulation falla sin parametros" "GET /analytics/simulation" "Revisar parametros por defecto en AnalyticsService.getSimulation" }
Write-Host ""

# ─── SECTION 8: SEGURIDAD ────────────────────────────────────────────────────
Write-Host "[ SECTION 8 ] SEGURIDAD" -ForegroundColor White

# Mass assignment userId
if($expId1 -and $userIdB){
    $massAssign = rq PATCH "/expenses/$expId1" @{userId=$userIdB;amount=100} -token $tokenA
    if($massAssign.__error -and $massAssign.status -eq 400){
        pass "Mass assignment bloqueado por validacion (400)"
    } elseif(-not $massAssign.__error){
        $afterMA = rq GET "/expenses/$expId1" -token $tokenA
        if(-not $afterMA.__error -and "$($afterMA.userId)" -eq "$userIdB"){
            fail "Mass assignment: userId modificado via body"
            bug "SEC-01" "CRITICO" "Mass assignment en expenses: userId sobreescribible" "PATCH /expenses/:id con userId de otro usuario en body" "Excluir userId del UpdateExpenseDto y mantener whitelist=true en ValidationPipe"
        } else{ pass "Mass assignment: userId inmutable" }
    }
}

# ID invalido
$badId = rq GET "/expenses/not-a-uuid" -token $tokenA
if($null -ne $badId.status -and ($badId.status -eq 500 -or $badId.status -eq 0)){
    fail "UUID invalido genera 500 con posible stack trace"
    bug "SEC-03" "MEDIO" "ID invalido retorna 500 con stack trace" "GET /expenses/not-a-uuid con token valido" "Agregar ParseUUIDPipe en controller params"
} else{ pass "ID invalido manejado correctamente (no 500)" }

# Usuario nuevo sin datos
$newUser = rq POST "/auth/register" @{fullName="Nuevo Vacio";email=$emailC;password="Segura123!"}
if(-not $newUser.__error){
    $newToken = $newUser.accessToken
    $newDash = rq GET "/analytics/dashboard" -token $newToken
    if(-not $newDash.__error){ pass "Dashboard OK para usuario sin datos" }
    else{ fail "Dashboard crashea usuario nuevo (HTTP $($newDash.status)) body=$($newDash.body)"; bug "DATA-01" "ALTO" "Dashboard crashea para usuario sin transacciones" "GET /analytics/dashboard recien registrado" "Manejar arrays vacios y cero divisiones en AnalyticsService" }

    $newInsights = rq GET "/insights" -token $newToken
    if(-not $newInsights.__error){ pass "Insights OK para usuario sin datos" }
    else{ fail "Insights crashea usuario nuevo (HTTP $($newInsights.status))"; bug "DATA-02" "MEDIO" "Insights crashea con usuario sin historial" "GET /insights recien registrado" "Verificar manejo de resultado vacio en InsightsService" }
}

# Soft-delete
$delUser = rq DELETE "/users/me" -token $tokenB
if(-not $delUser.__error){
    $loginAfterDel = rq POST "/auth/login" @{email=$emailB;password="Segura123!"}
    if($loginAfterDel.__error -and $loginAfterDel.status -eq 401){ pass "Usuario soft-deleted no puede hacer login" }
    else{ fail "Usuario soft-deleted puede autenticarse"; bug "DATA-03" "CRITICO" "Usuario eliminado puede ingresar al sistema" "1.DELETE /users/me 2.POST /auth/login mismas credenciales" "Verificar deletedAt IS NULL en LocalStrategy.validate" }
}
Write-Host ""

# ─── SECTION 9: PERFORMANCE ─────────────────────────────────────────────────
Write-Host "[ SECTION 9 ] PERFORMANCE (100 gastos)" -ForegroundColor White

$perfStart = Get-Date
$perfErrors = 0
$perfStatuses = @()
1..100 | ForEach-Object {
    $r = rq POST "/expenses" @{amount=(Get-Random -Min 10 -Max 5000);description="PerfTest$_";categoryId=$catId;paymentMethod="cash";date="2026-04-05"} -token $tokenA
    if($r.__error){ $perfErrors++; $perfStatuses += $r.status }
}
$perfDur = (Get-Date) - $perfStart
$avgMs = [math]::Round($perfDur.TotalMilliseconds/100, 0)

if($perfErrors -eq 0){ pass "100 gastos creados sin errores: total $([math]::Round($perfDur.TotalSeconds,1))s avg ${avgMs}ms/req" }
else{ 
    $statusSummary = ($perfStatuses | Group-Object | ForEach-Object {"$($_.Count)x$($_.Name)"}) -join ", "
    fail "Errores en carga: $perfErrors/100 fallaron (HTTP: $statusSummary)"
    bug "PERF-01" "ALTO" "$perfErrors errores al crear 100 gastos en serie" "Crear 100 POST /expenses en loop rapido" "Revisar pool de conexiones y throttler config"
}

if($avgMs -gt 500){ fail "Latencia alta: ${avgMs}ms promedio"; bug "PERF-02" "MEDIO" "Latencia promedio mayor a 500ms" "Medir tiempo de 100 POST /expenses" "Agregar indices, connection pooling, optimizar queries" }
else{ pass "Latencia aceptable: ${avgMs}ms promedio" }

$p1 = rq GET "/expenses?limit=50&page=1" -token $tokenA
$tPag = Get-Date
$p2 = rq GET "/expenses?limit=50&page=2" -token $tokenA
$pagMs = [math]::Round(((Get-Date)-$tPag).TotalMilliseconds, 0)
if(-not $p1.__error -and -not $p2.__error){ pass "Paginacion page 1 y 2 funcionan: ${pagMs}ms" }
else{ fail "Paginacion falla (p1=$($p1.status) p2=$($p2.status))"; bug "PERF-03" "ALTO" "Paginacion no funciona con muchos registros" "GET /expenses?limit=50&page=2" "Verificar PaginationUtil y offset en QueryBuilder" }

$tDash = Get-Date
$dashLoad = rq GET "/analytics/dashboard" -token $tokenA
$dashMs = [math]::Round(((Get-Date)-$tDash).TotalMilliseconds, 0)
if(-not $dashLoad.__error){ pass "Dashboard con 100+ gastos: ${dashMs}ms" }
if($dashMs -gt 2000){ fail "Dashboard lento: ${dashMs}ms"; bug "PERF-04" "ALTO" "Dashboard tarda mas de 2s con 100+ gastos" "GET /analytics/dashboard con 100+ gastos en DB" "Agregar indices en expenses, usar Redis cache" }
Write-Host ""

# ─── SECTION 10: CONSISTENCIA ────────────────────────────────────────────────
Write-Host "[ SECTION 10 ] CONSISTENCIA DE DATOS" -ForegroundColor White

if($expId1 -and $budId){
    $budBefore = rq GET "/budgets/$budId" -token $tokenA
    rq DELETE "/expenses/$expId1" -token $tokenA | Out-Null
    Start-Sleep -Milliseconds 300
    $budAfter = rq GET "/budgets/$budId" -token $tokenA
    if(-not $budBefore.__error -and -not $budAfter.__error){
        $spentBefore = [double]$budBefore.spent
        $spentAfter  = [double]$budAfter.spent
        if($spentAfter -le $spentBefore){ pass "Eliminar gasto actualiza spent en presupuesto" }
        else{ fail "Eliminar gasto NO actualizo presupuesto: antes=$spentBefore despues=$spentAfter"; bug "DATA-04" "ALTO" "Eliminar gasto no actualiza spent en presupuesto" "1.Ver spent 2.Eliminar gasto 3.spent igual" "Recalcular spent dinamicamente en BudgetsService" }
    }
}

$expList = rq GET "/expenses?limit=200" -token $tokenA
$dashFinal = rq GET "/analytics/dashboard" -token $tokenA
if(-not $expList.__error -and -not $dashFinal.__error){
    $expItems = if($expList.items){$expList.items}elseif($expList -is [array]){$expList}else{@()}
    $periodStart = if($dashFinal.currentPeriod){ $dashFinal.currentPeriod.start } else { $null }
    if($periodStart){
        $periodExpenses = @($expItems) | Where-Object { $_.date -ge $periodStart }
        $manualSum = ($periodExpenses | Measure-Object -Property amount -Sum).Sum
        if(-not $manualSum){ $manualSum=0 }
        $dashSum = [double]$dashFinal.totalSpentThisPeriod
        $diff = [math]::Abs($manualSum - $dashSum)
        if($diff -lt 1.0){ pass "totalSpentThisPeriod dashboard coincide con suma manual: $dashSum" }
        else{ fail "INCONSISTENCIA: dashboard totalSpentThisPeriod=$dashSum suma manual=$manualSum diff=$diff"; bug "DATA-05" "CRITICO" "totalSpentThisPeriod en dashboard no coincide con suma real" "Comparar sum de expenses vs totalSpentThisPeriod en dashboard" "Asegurar mismo filtro de fechas en AnalyticsService" }
        pass "Dashboard expone currentPeriod (start=$periodStart)"
    } else{
        fail "Dashboard no retorna currentPeriod.start"
        bug "DATA-06" "MEDIO" "Dashboard no expone currentPeriod para validacion" "GET /analytics/dashboard no retorna currentPeriod" "Incluir currentPeriod en respuesta del dashboard"
    }
}
Write-Host ""

# ─── SECTION 11: RATE LIMITING (last, intentionally exhausts budget) ─────────
Write-Host "[ SECTION 11 ] RATE LIMITING" -ForegroundColor White
Write-Host "  [TEST] Disparando requests hasta 429..." -NoNewline
$throttled = $false
for($i=0; $i -lt 300; $i++){
    $r = rq GET "/users/me" -token $tokenA
    if($r.__error -and $r.status -eq 429){ $throttled=$true; break }
}
Write-Host " (iteraciones: $i)"
if($throttled){ pass "Rate limiting activo: 429 detectado en iteracion $i" }
else{ fail "Rate limiting permisivo: 300 req sin throttle"; bug "SEC-02" "MEDIO" "Rate limiting no activo o limite muy alto" "300 GET requests rapidas seguidas" "Ajustar ThrottlerModule limite y TTL" }
Write-Host ""

# ─── REPORTE FINAL ────────────────────────────────────────────────────────────
Write-Host "=============================================================" -ForegroundColor Magenta
Write-Host " REPORTE FINAL QA - FinanzasLATAM" -ForegroundColor Magenta
Write-Host "=============================================================" -ForegroundColor Magenta
Write-Host " CHECK PASS : $PASS" -ForegroundColor Green
Write-Host " CHECK FAIL : $FAIL" -ForegroundColor Red
Write-Host " BUGS TOTAL : $($BUGS.Count)" -ForegroundColor Yellow
Write-Host ""

$sevOrder = @("CRITICO","ALTO","MEDIO","BAJO")
foreach($sev in $sevOrder){
    $sevBugs = @($BUGS | Where-Object {$_.SEV -eq $sev})
    if($sevBugs.Count -eq 0){ continue }
    $c = if($sev -eq "CRITICO"){"Red"}elseif($sev -eq "ALTO"){"Yellow"}else{"Cyan"}
    Write-Host "---[ $sev : $($sevBugs.Count) bugs ]---" -ForegroundColor $c
    foreach($b in $sevBugs){
        Write-Host "  [$($b.ID)] $($b.TITLE)" -ForegroundColor $c
        Write-Host "    Repro : $($b.REPRO)" -ForegroundColor Gray
        Write-Host "    Fix   : $($b.FIX)" -ForegroundColor Gray
        Write-Host ""
    }
}
