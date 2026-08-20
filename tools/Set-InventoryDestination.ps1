#requires -RunAsAdministrator
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path
)

if([string]::IsNullOrWhiteSpace($Path)){
    throw 'Informe um caminho UNC valido.'
}

[Environment]::SetEnvironmentVariable('INVENTORY_DESTINO',$Path,'Machine')
Write-Host '[OK] INVENTORY_DESTINO configurado para:' -ForegroundColor Green
Write-Host "     $Path"
Write-Host '[INFO] A nova variavel sera usada pelas proximas execucoes do agente.' -ForegroundColor Cyan
