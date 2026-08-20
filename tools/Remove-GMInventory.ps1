#requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$RemoveData
)

$TaskName = 'Inventory - Daily'
$Base = 'C:\ProgramData\InventoryAgent'

if(Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue){
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "[OK] Tarefa removida: $TaskName"
}

foreach($file in 'Collect-Inventory.ps1','Run-Inventory.ps1','Install-InventoryTask.ps1'){
    Remove-Item (Join-Path $Base $file) -Force -ErrorAction SilentlyContinue
}

if($RemoveData){
    Remove-Item $Base -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "[OK] Pasta local removida: $Base"
} else {
    Write-Host "[INFO] Logs/state mantidos em $Base"
}
