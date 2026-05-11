#requires -Version 5.1
<#
.SYNOPSIS
  Clona todos los repos de OnlyOffice en la tag estable definida.
.DESCRIPTION
  Repos planos (no submódulos). Idempotente: si un repo ya existe, lo salta.
.PARAMETER Tag
  Tag git a clonar (default: v9.3.1.11). Debe existir en TODOS los repos.
.PARAMETER Force
  Borra y re-clona los repos existentes.
#>
[CmdletBinding()]
param(
  [string]$Tag = "v9.3.1.11",
  [switch]$Force
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

Write-Host "Configurando git para Windows..." -ForegroundColor Cyan
git config --global core.longpaths true
git config --global core.autocrlf input

$repos = @(
  "core","web-apps","sdkjs","dictionaries",
  "core-fonts","document-templates","build_tools","Docker-DocumentServer"
)

# 1) Server: si ya existe lo movemos a la tag, si no lo clonamos
$serverPath = Join-Path $root "server"
if (Test-Path "$serverPath\.git") {
  Write-Host "[server] ya clonado — fetch + checkout $Tag" -ForegroundColor Cyan
  git -C $serverPath fetch --tags --depth 1 origin tag $Tag
  git -C $serverPath checkout $Tag
} else {
  Write-Host "[server] cloning $Tag..." -ForegroundColor Cyan
  git clone --depth 1 --branch $Tag "https://github.com/ONLYOFFICE/server.git" $serverPath
}

# 2) Resto de repos en paralelo (jobs)
$jobs = @()
foreach ($r in $repos) {
  $path = Join-Path $root $r
  if (Test-Path "$path\.git") {
    if ($Force) {
      Write-Host "[$r] -Force: borrando..." -ForegroundColor Yellow
      Remove-Item -Recurse -Force $path
    } else {
      Write-Host "[$r] SKIP (existe)" -ForegroundColor DarkGray
      continue
    }
  }
  Write-Host "[$r] cloning $Tag (background)..." -ForegroundColor Cyan
  $jobs += Start-Job -Name $r -ScriptBlock {
    param($repo,$tag,$dest)
    git clone --depth 1 --branch $tag "https://github.com/ONLYOFFICE/$repo.git" $dest 2>&1
  } -ArgumentList $r, $Tag, $path
}

if ($jobs.Count -gt 0) {
  Write-Host "`nEsperando $($jobs.Count) clones en paralelo..." -ForegroundColor Cyan
  $jobs | Wait-Job | Out-Null
  foreach ($j in $jobs) {
    $exitOk = (Test-Path (Join-Path (Join-Path $root $j.Name) ".git"))
    $color = if ($exitOk) { "Green" } else { "Red" }
    $tag2 = if ($exitOk) { "OK" } else { "FAIL" }
    Write-Host "[$($j.Name)] $tag2" -ForegroundColor $color
    Remove-Job $j
  }
}

Write-Host "`nResumen final:" -ForegroundColor Cyan
foreach ($d in @("server") + $repos) {
  $p = Join-Path $root $d
  if (Test-Path "$p\.git") {
    $head = git -C $p rev-parse --short HEAD 2>$null
    Write-Host "  $d : $head" -ForegroundColor Green
  } else {
    Write-Host "  $d : MISSING" -ForegroundColor Red
  }
}
