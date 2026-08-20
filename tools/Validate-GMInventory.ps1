#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$DestinationRoot = $env:INVENTORY_DESTINO
)

$Base = 'C:\ProgramData\InventoryAgent'
$TaskName = 'Inventory - Daily'
$Computer = $env:COMPUTERNAME
$results = @()

function Add-Check {
    param([string]$Item,[bool]$Ok,[string]$Detalhe)
    $script:results += [pscustomobject]@{
        Status = if($Ok){'OK'}else{'FALHA'}
        Item = $Item
        Detalhe = $Detalhe
    }
}

foreach($file in 'Collect-Inventory.ps1','Run-Inventory.ps1','Install-InventoryTask.ps1'){
    $p = Join-Path $Base $file
    Add-Check "Arquivo $file" (Test-Path $p) $p
}

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
Add-Check 'Tarefa agendada' ($null -ne $task) $(if($task){$task.State.ToString()}else{'Nao encontrada'})

if($task){
    $action = $task.Actions | Select-Object -First 1
    Add-Check 'Acao da tarefa' ($action.Arguments -match 'Run-Inventory\.ps1') ("$($action.Execute) $($action.Arguments)")
}

if([string]::IsNullOrWhiteSpace($DestinationRoot)){
    Add-Check 'Destino central' $false 'INVENTORY_DESTINO nao definido'
} else {
    $shareOk = Test-Path -LiteralPath $DestinationRoot
    Add-Check 'Compartilhamento central' $shareOk $DestinationRoot

    $machineFolder = Join-Path $DestinationRoot $Computer
    Add-Check 'Pasta da maquina' (Test-Path $machineFolder) $machineFolder

    $summaryPath = Join-Path $machineFolder ("resumo-{0}.csv" -f $Computer)
    if(Test-Path $summaryPath){
        $summary = Import-Csv $summaryPath | Select-Object -First 1
        Add-Check 'Versao do coletor central' ($summary.VersaoColetor -eq '8.2') $summary.VersaoColetor
        $hasApipa = ($summary.IPPrincipal -like '169.254.*') -or ($summary.IPv4Adicionais -match '(^|;\s*)169\.254\.')
        Add-Check 'Resumo sem APIPA' (-not $hasApipa) ("Principal=$($summary.IPPrincipal); Adicionais=$($summary.IPv4Adicionais)")
    } else {
        Add-Check 'Resumo central' $false $summaryPath
    }
}

$lastSuccess = Join-Path $Base 'state\last-success.txt'
Add-Check 'Marcador ultima coleta' (Test-Path $lastSuccess) $(if(Test-Path $lastSuccess){Get-Content $lastSuccess | Select-Object -First 1}else{'Ainda sem coleta bem-sucedida'})

$deployLog = Join-Path $Base 'logs\gpo-deploy.log'
Add-Check 'Log de deploy' (Test-Path $deployLog) $deployLog

$results | Format-Table -AutoSize

if($results.Status -contains 'FALHA'){
    exit 1
}
exit 0
