#requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$RemoveData
)

$TaskName = 'GM - Inventario Diario'
$Base = 'C:\ProgramData\GMInventory'

if(Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue){
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "[OK] Tarefa removida: $TaskName"
}

foreach($file in 'Collect-Inventory.ps1','Run-Inventory.ps1','Install-InventoryTask.ps1'){
    $p = Join-Path $Base $file
    Remove-Item $p -Force -ErrorAction SilentlyContinue
}

if($RemoveData){
    Remove-Item $Base -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "[OK] Pasta local removida: $Base"
} else {
    Write-Host "[INFO] Logs/state mantidos em $Base"
}
