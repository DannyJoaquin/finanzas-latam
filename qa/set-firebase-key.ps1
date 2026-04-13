# set-firebase-key.ps1
# Usage: .\qa\set-firebase-key.ps1 -KeyFile "C:\path\to\adminsdk.json"
# Writes Firebase credentials to backend/.env.firebase (loaded by docker-compose via env_file)

param(
  [Parameter(Mandatory)]
  [string]$KeyFile
)

if (-not (Test-Path $KeyFile)) {
  Write-Host "ERROR: File not found: $KeyFile" -ForegroundColor Red
  exit 1
}

$json = Get-Content $KeyFile -Raw
$minified = ($json | ConvertFrom-Json | ConvertTo-Json -Compress -Depth 20)
$projectId = ($json | ConvertFrom-Json).project_id

# Write to a dedicated .env file that docker-compose loads via env_file
# This avoids YAML quoting issues with multi-line private keys
$envPath = "$PSScriptRoot\..\backend\.env.firebase"
"FIREBASE_SERVICE_ACCOUNT=$minified" | Set-Content $envPath -Encoding UTF8 -NoNewline

Write-Host "Written: $envPath" -ForegroundColor Green
Write-Host "  Project: $projectId" -ForegroundColor Cyan
Write-Host ""
Write-Host "Restarting backend..." -ForegroundColor Yellow
Set-Location "$PSScriptRoot\.."
docker compose restart api
Write-Host ""
Write-Host "Done. Run: .\qa\trigger-insights.ps1 -TestPush" -ForegroundColor Green
