#requires -Version 5.1
<#
.SYNOPSIS
  Construye la imagen Docker `onlyoffice-fork:local` desde fuente.
.PARAMETER NoCache
  Fuerza rebuild sin usar cache de capas.
.PARAMETER Tag
  Tag adicional para la imagen (ej. "1.0.0"). Default: solo "local".
#>
[CmdletBinding()]
param(
  [switch]$NoCache,
  [string]$Tag = "local"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$dockerfile = Join-Path $root "docker\Dockerfile.full"

if (-not (Test-Path $dockerfile)) {
  Write-Host "No se encuentra $dockerfile" -ForegroundColor Red
  exit 1
}

# Comprobaciones
try { docker version | Out-Null } catch {
  Write-Host "Docker no está disponible. Instala Docker Desktop o arráncalo." -ForegroundColor Red
  exit 1
}

$buildArgs = @(
  "buildx", "build",
  "--load",
  "-f", "docker/Dockerfile.full",
  "-t", "onlyoffice-fork:$Tag"
)
if ($NoCache) { $buildArgs += "--no-cache" }
$buildArgs += "."

Write-Host "Build context: $root" -ForegroundColor Cyan
Write-Host "Comando: docker $($buildArgs -join ' ')" -ForegroundColor DarkGray
$start = Get-Date

Push-Location $root
try {
  & docker @buildArgs
  if ($LASTEXITCODE -ne 0) { throw "docker build exit $LASTEXITCODE" }
} finally {
  Pop-Location
}

$elapsed = (Get-Date) - $start
Write-Host ""
Write-Host "Build OK en $($elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor Green
docker images "onlyoffice-fork:$Tag" --format "  {{.Repository}}:{{.Tag}}  {{.Size}}  ({{.CreatedSince}})"
