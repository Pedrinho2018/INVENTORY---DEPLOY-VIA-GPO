#requires -RunAsAdministrator
[CmdletBinding()]
param()

$TaskName = 'Inventory - Daily'
$Base = 'C:\ProgramData\InventoryAgent'
$Marker = Join-Path $Base 'state\last-success.txt'

Write-Host '=== INVENTORY AGENT 8.2 - TESTE IMEDIATO ===' -ForegroundColor Cyan

Remove-Item $Marker -Force -ErrorAction SilentlyContinue
Write-Host '[OK] Marcador diario removido para este teste.' -ForegroundColor Green

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if(-not $task){
    throw "Tarefa nao encontrada: $TaskName"
}

Start-ScheduledTask -TaskName $TaskName
Write-Host '[...] Tarefa iniciada. Aguardando conclusao...' -ForegroundColor Yellow

$timeout = (Get-Date).AddMinutes(3)
do {
    Start-Sleep -Seconds 3
    $task = Get-ScheduledTask -TaskName $TaskName
} while($task.State -eq 'Running' -and (Get-Date) -lt $timeout)

$info = Get-ScheduledTaskInfo -TaskName $TaskName

Write-Host ''
$info | Select-Object LastRunTime,LastTaskResult,NextRunTime | Format-List

$log = Get-ChildItem (Join-Path $Base 'logs\inventario-*.log') -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if($log){
    Write-Host '=== ULTIMAS LINHAS DO LOG ===' -ForegroundColor Cyan
    Get-Content $log.FullName -Tail 25
}

if($info.LastTaskResult -ne 0){
    exit $info.LastTaskResult
}
exit 0
