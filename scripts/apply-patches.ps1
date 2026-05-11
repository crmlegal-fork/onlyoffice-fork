#requires -Version 5.1
<#
.SYNOPSIS
  Aplica los patches del directorio patches/ a los repos correspondientes.
.DESCRIPTION
  Idempotente: detecta si el commit ya está aplicado y salta.
  Mapping repo → patch se infiere del primer "diff --git" del .patch.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$patchesDir = Join-Path $root "patches"

if (-not (Test-Path $patchesDir)) {
  Write-Host "No hay directorio patches/. Nada que aplicar." -ForegroundColor Yellow
  exit 0
}

$patches = Get-ChildItem -Path $patchesDir -Filter "*.patch" | Sort-Object Name
if ($patches.Count -eq 0) {
  Write-Host "No hay archivos .patch en $patchesDir" -ForegroundColor Yellow
  exit 0
}

# Diccionario: prefijo de path del primer "diff --git" → repo destino
# Ej: "diff --git a/Common/sources/constants.js" → repo "server"
$patchMap = @{
  "Common/"        = "server"
  "DocService/"    = "server"
  "FileConverter/" = "server"
  "Metrics/"       = "server"
  "SpellChecker/"  = "server"
  "license/"       = "server"
  "Gruntfile.js"   = "server"
  "package.json"   = "server"
  "apps/"          = "web-apps"
  "DocumentEditor/" = "web-apps"
  "sdkjs/"         = "sdkjs"
}

foreach ($patch in $patches) {
  $content = Get-Content $patch.FullName -TotalCount 50
  $diffLine = $content | Where-Object { $_ -match '^diff --git a/(\S+)' } | Select-Object -First 1
  if (-not $diffLine) {
    Write-Host "[$($patch.Name)] no se puede determinar repo destino — SKIP" -ForegroundColor Yellow
    continue
  }
  $diffLine -match '^diff --git a/(\S+)' | Out-Null
  $firstPath = $Matches[1]

  $targetRepo = $null
  foreach ($prefix in $patchMap.Keys) {
    if ($firstPath.StartsWith($prefix) -or $firstPath -eq $prefix.TrimEnd('/')) {
      $targetRepo = $patchMap[$prefix]
      break
    }
  }
  if (-not $targetRepo) {
    Write-Host "[$($patch.Name)] prefix '$firstPath' no mapea a ningún repo — SKIP" -ForegroundColor Yellow
    continue
  }

  $repoPath = Join-Path $root $targetRepo
  if (-not (Test-Path "$repoPath\.git")) {
    Write-Host "[$($patch.Name)] repo $targetRepo no existe — SKIP" -ForegroundColor Yellow
    continue
  }

  # Idempotencia: ¿ya está aplicado?
  $subjectLine = $content | Where-Object { $_ -match '^Subject: \[PATCH\] (.+)$' } | Select-Object -First 1
  if ($subjectLine -and $subjectLine -match '^Subject: \[PATCH\] (.+)$') {
    $subject = $Matches[1]
    $existing = git -C $repoPath log --grep="$subject" --oneline 2>$null
    if ($existing) {
      Write-Host "[$($patch.Name)] ya aplicado en $targetRepo (commit $($existing.Split(' ')[0])) — SKIP" -ForegroundColor DarkGray
      continue
    }
  }

  Write-Host "[$($patch.Name)] aplicando a $targetRepo..." -ForegroundColor Cyan
  $output = git -C $repoPath am --3way --keep-cr $patch.FullName 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: $output" -ForegroundColor Red
    git -C $repoPath am --abort 2>$null
    exit 1
  } else {
    Write-Host "  OK" -ForegroundColor Green
  }
}

Write-Host "`nPatches aplicados." -ForegroundColor Green
