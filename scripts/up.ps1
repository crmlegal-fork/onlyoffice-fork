#requires -Version 5.1
<#
.SYNOPSIS
  Levanta el stack de OnlyOffice fork con docker compose.
.DESCRIPTION
  - Construye la imagen si no existe
  - Genera JWT_SECRET si no hay .env.local
  - Streamea logs hasta que el contenedor esté `healthy`
.PARAMETER Logs
  Sigue logs después del up (Ctrl+C para salir).
#>
[CmdletBinding()]
param([switch]$Logs)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$composeFile = Join-Path $root "docker\docker-compose.yml"
$envFile = Join-Path $root "docker\.env.local"

# Comprobar Docker
try { docker version | Out-Null } catch {
  Write-Host "Docker no está disponible. Instala Docker Desktop o arráncalo." -ForegroundColor Red
  exit 1
}

# Generar .env.local con JWT_SECRET si no existe
if (-not (Test-Path $envFile)) {
  Write-Host "Generando docker\.env.local con JWT_SECRET aleatorio..." -ForegroundColor Cyan
  $jwt = -join ((1..96) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })
  "JWT_SECRET=$jwt" | Out-File -FilePath $envFile -Encoding utf8 -NoNewline
  Write-Host "  Creado: $envFile" -ForegroundColor Green
}

# Build si no hay imagen local
$image = docker images -q onlyoffice-fork:local 2>$null
if (-not $image) {
  Write-Host "Imagen onlyoffice-fork:local no existe — construyendo..." -ForegroundColor Cyan
  & (Join-Path $PSScriptRoot "build-image.ps1")
  if ($LASTEXITCODE -ne 0) { exit 1 }
}

# Up
Write-Host "`nLevantando stack..." -ForegroundColor Cyan
docker compose -f $composeFile --env-file $envFile up -d
if ($LASTEXITCODE -ne 0) { exit 1 }

# Esperar healthy
Write-Host "`nEsperando healthcheck (puede tardar ~2 min en el primer arranque)..." -ForegroundColor Cyan
$timeout = 300
$start = Get-Date
do {
  Start-Sleep -Seconds 5
  $status = (docker inspect --format '{{.State.Health.Status}}' onlyoffice-ds 2>$null)
  $elapsed = ((Get-Date) - $start).TotalSeconds
  Write-Host "  status=$status ($([int]$elapsed)s)" -ForegroundColor DarkGray
  if ($elapsed -gt $timeout) {
    Write-Host "Timeout esperando healthy. Revisa: docker logs onlyoffice-ds" -ForegroundColor Red
    exit 1
  }
} while ($status -ne "healthy")

Write-Host "`nStack arriba y healthy." -ForegroundColor Green
Write-Host "  Editor:    http://localhost/" -ForegroundColor White
Write-Host "  Health:    http://localhost/healthcheck" -ForegroundColor White
Write-Host "  API JS:    http://localhost/web-apps/apps/api/documents/api.js" -ForegroundColor White

if ($Logs) {
  docker compose -f $composeFile logs -f documentserver
}
