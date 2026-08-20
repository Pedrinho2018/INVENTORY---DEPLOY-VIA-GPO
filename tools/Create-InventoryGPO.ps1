#requires -RunAsAdministrator
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$TargetOU,

    [string]$GpoName = 'GPO - Inventory - Workstations'
)

$ErrorActionPreference = 'Stop'
Import-Module GroupPolicy -ErrorAction Stop

$gpo = Get-GPO -Name $GpoName -ErrorAction SilentlyContinue
if (-not $gpo) {
    $gpo = New-GPO -Name $GpoName -Comment 'Distribuicao do agente de inventario via Startup Script.'
    Write-Host "[OK] GPO criada: $GpoName" -ForegroundColor Green
} else {
    Write-Host "[OK] GPO ja existe: $GpoName" -ForegroundColor Green
}

$inheritance = Get-GPInheritance -Target $TargetOU
$link = $inheritance.GpoLinks | Where-Object DisplayName -eq $GpoName
if (-not $link) {
    New-GPLink -Name $GpoName -Target $TargetOU -LinkEnabled Yes | Out-Null
    Write-Host "[OK] GPO vinculada em: $TargetOU" -ForegroundColor Green
} else {
    Write-Host '[OK] GPO ja esta vinculada nessa OU.' -ForegroundColor Green
}

Write-Host ''
Write-Host 'Proximo passo na GPMC:' -ForegroundColor Cyan
Write-Host 'Computer Configuration > Policies > Windows Settings > Scripts (Startup/Shutdown) > Startup'
Write-Host 'Adicione somente Deploy-Inventory-GPO.cmd e mantenha os componentes do agente ao lado no SYSVOL.'
