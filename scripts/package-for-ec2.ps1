#requires -Version 5.1
<#
.SYNOPSIS
  Empaqueta el repo en un .tar.gz listo para subir a la EC2.
.DESCRIPTION
  Incluye SOLO lo esencial: server/ (con parche), docker/, scripts/, patches/,
  DEPLOY.md, README.md. Excluye node_modules, repos OnlyOffice clonados
  (la EC2 los clonará por sí misma) y archivos de IDE.
.PARAMETER Out
  Path de salida (default: $env:USERPROFILE\Desktop\onlyoffice-fork.tar.gz)
#>
[CmdletBinding()]
param(
  [string]$Out = "$env:USERPROFILE\Desktop\onlyoffice-fork.tar.gz"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

Write-Host "Empaquetando $root → $Out" -ForegroundColor Cyan

Push-Location $root
try {
  $items = @(
    "server", "docker", "scripts", "patches", "examples",
    "DEPLOY.md", "README.md", ".gitattributes", ".gitignore", ".dockerignore"
  )

  # tar viene incluido en Windows 10/11 (bsdtar). --exclude funciona.
  $args = @(
    "--exclude=server/node_modules",
    "--exclude=*/node_modules",
    "--exclude=*.log",
    "--exclude=examples/crm-integration/files/*.docx",
    "--exclude=examples/crm-mock/files/*.docx",
    "--exclude=docker/.env.local",
    "--exclude=docker/.env.prod",
    "-czf", "$Out"
  ) + $items

  & tar @args
  if ($LASTEXITCODE -ne 0) { throw "tar exit $LASTEXITCODE" }

  $size = (Get-Item $Out).Length / 1MB
  Write-Host ("Listo: {0} ({1:N1} MB)" -f $Out, $size) -ForegroundColor Green
  Write-Host ""
  Write-Host "Siguiente paso: subir a la EC2 con scp:" -ForegroundColor Cyan
  Write-Host "  scp -i C:\path\a\tu-key.pem `"$Out`" ubuntu@TU_IP_EC2:/home/ubuntu/" -ForegroundColor White
} finally {
  Pop-Location
}
