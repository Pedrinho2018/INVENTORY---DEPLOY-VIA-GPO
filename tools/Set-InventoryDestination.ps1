#requires -RunAsAdministrator
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^\\\\')]
    [string]$DestinationRoot
)

[Environment]::SetEnvironmentVariable(
    'INVENTORY_DESTINO',
    $DestinationRoot,
    'Machine'
)

Write-Host "[OK] INVENTORY_DESTINO configurado para: $DestinationRoot" -ForegroundColor Green
Write-Host "[INFO] Novos processos do Windows passarao a enxergar a configuracao." -ForegroundColor Cyan
