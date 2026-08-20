#requires -RunAsAdministrator
[CmdletBinding()]
param(
    [switch]$StartNow
)

$ErrorActionPreference = 'Stop'

$taskName = 'Inventory - Daily'
$runner = 'C:\ProgramData\InventoryAgent\Run-Inventory.ps1'

if(-not (Test-Path $runner)){
    throw "Runner nao encontrado: $runner"
}

$sum = 0
foreach($c in $env:COMPUTERNAME.ToCharArray()){
    $sum += [int]$c
}

$startupDelayMinutes = 2 + ($sum % 9)
$logonDelayMinutes = 1 + ($sum % 5)

$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$runner`""

$startup = New-ScheduledTaskTrigger -AtStartup
$startup.Delay = "PT${startupDelayMinutes}M"

$logon = New-ScheduledTaskTrigger -AtLogOn
$logon.Delay = "PT${logonDelayMinutes}M"

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 10)

$principal = New-ScheduledTaskPrincipal `
    -UserId 'NT AUTHORITY\SYSTEM' `
    -LogonType ServiceAccount `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger @($startup,$logon) `
    -Settings $settings `
    -Principal $principal `
    -Description 'Inventory Agent 8.2 - coleta diaria via GPO' `
    -Force | Out-Null

if($StartNow){
    Start-ScheduledTask -TaskName $taskName
}

Write-Host "[OK] Tarefa registrada: $taskName"
Write-Host "[OK] Delay Startup: $startupDelayMinutes minuto(s)"
Write-Host "[OK] Delay Logon: $logonDelayMinutes minuto(s)"
