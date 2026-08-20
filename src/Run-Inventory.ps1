#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$DestinationRoot = $env:INVENTORY_DESTINO,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$base = 'C:\ProgramData\InventoryAgent'
$logDir = Join-Path $base 'logs'
$stateDir = Join-Path $base 'state'
$lastRun = Join-Path $stateDir 'last-success.txt'
$collector = Join-Path $base 'Collect-Inventory.ps1'

New-Item -ItemType Directory -Force -Path $logDir,$stateDir | Out-Null

function Write-InventoryLog {
    param([string]$Message,[string]$Level='INFO')
    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$Level,$Message
    Add-Content -Path $script:log -Value $line -Encoding UTF8
}

if([string]::IsNullOrWhiteSpace($DestinationRoot)){
    throw 'Defina INVENTORY_DESTINO com o caminho UNC do inventario.'
}

$today = (Get-Date).ToString('yyyy-MM-dd')
$log = Join-Path $logDir ("inventario-{0}-{1}.log" -f $env:COMPUTERNAME,(Get-Date).ToString('yyyyMMdd'))

Write-InventoryLog "Inicio Inventory Agent 8.2 - $env:COMPUTERNAME"
Write-InventoryLog "Destino: $DestinationRoot"

if(-not $Force -and (Test-Path $lastRun)){
    $lastSuccess = Get-Content $lastRun -ErrorAction SilentlyContinue | Select-Object -First 1
    if($lastSuccess -eq $today){
        Write-InventoryLog 'Coleta ja realizada com sucesso hoje. Encerrando.'
        exit 0
    }
}

if(-not (Test-Path $collector)){
    Write-InventoryLog "Coletor local nao encontrado: $collector" 'ERRO'
    exit 20
}

try {
    $available = $false
    for($i=1; $i -le 12; $i++){
        if(Test-Path -LiteralPath $DestinationRoot){
            $available = $true
            break
        }

        Write-InventoryLog "Rede/compartilhamento indisponivel. Tentativa $i/12."
        Start-Sleep -Seconds 10
    }

    if(-not $available){
        throw "Pasta de rede indisponivel apos 12 tentativas: $DestinationRoot"
    }

    Write-InventoryLog 'Compartilhamento acessivel. Iniciando coleta.'

    $collectorOutput = & $collector -DestinationRoot $DestinationRoot 2>&1
    foreach($item in @($collectorOutput)){
        if($null -ne $item){
            Write-InventoryLog ([string]$item)
        }
    }

    Set-Content -Path $lastRun -Value $today -Encoding ASCII
    Write-InventoryLog 'SUCESSO: coleta concluida e enviada.' 'OK'
    exit 0
}
catch {
    Write-InventoryLog ('Falha na coleta: ' + $_.Exception.Message) 'ERRO'
    exit 10
}
