#requires -Version 5.1
<#
.SYNOPSIS
  Para el stack de OnlyOffice fork.
.PARAMETER Clean
  Borra también los volúmenes nombrados (datos, postgres, logs).
#>
[CmdletBinding()]
param([switch]$Clean)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$composeFile = Join-Path $root "docker\docker-compose.yml"

$args = @("compose", "-f", $composeFile, "down")
if ($Clean) {
  Write-Host "Modo -Clean: se borrarán los volúmenes (datos perdidos)" -ForegroundColor Yellow
  $args += "-v"
}

& docker @args
