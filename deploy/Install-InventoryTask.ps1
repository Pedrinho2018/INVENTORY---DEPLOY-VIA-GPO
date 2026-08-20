#requires -RunAsAdministrator
[CmdletBinding()]
param([switch]$StartNow)

$ErrorActionPreference='Stop'
$taskName='GM - Inventario Diario'
$runner='C:\ProgramData\GMInventory\Run-Inventory.ps1'

$action=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$runner`""
$startup=New-ScheduledTaskTrigger -AtStartup
$startup.Delay='PT2M'
$logon=New-ScheduledTaskTrigger -AtLogOn
$logon.Delay='PT1M'
$settings=New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 10)
$principal=New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($startup,$logon) -Settings $settings -Principal $principal -Description 'Inventario diario via GPO' -Force | Out-Null
if($StartNow){Start-ScheduledTask -TaskName $taskName}
Write-Host "[OK] Tarefa registrada: $taskName"
