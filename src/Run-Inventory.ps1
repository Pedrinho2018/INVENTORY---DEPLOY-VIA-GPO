#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$DestinationRoot = $env:INVENTORY_DESTINO,
    [switch]$Force
)

$ErrorActionPreference='Stop'
$base='C:\ProgramData\GMInventory'
$logDir=Join-Path $base 'logs'
$stateDir=Join-Path $base 'state'
$lastRun=Join-Path $stateDir 'last-success.txt'
$collector=Join-Path $base 'Collect-Inventory.ps1'
New-Item -ItemType Directory -Force -Path $logDir,$stateDir | Out-Null

if([string]::IsNullOrWhiteSpace($DestinationRoot)){
    throw 'Defina INVENTORY_DESTINO com o caminho UNC do inventario.'
}

$today=(Get-Date).ToString('yyyy-MM-dd')
if(-not $Force -and (Test-Path $lastRun) -and ((Get-Content $lastRun -ErrorAction SilentlyContinue | Select-Object -First 1) -eq $today)){ exit 0 }

$log=Join-Path $logDir ("inventario-{0}-{1}.log" -f $env:COMPUTERNAME,(Get-Date).ToString('yyyyMMdd'))
Start-Transcript -Path $log -Append | Out-Null
try {
    $available=$false
    1..12 | ForEach-Object {
        if(Test-Path -LiteralPath $DestinationRoot){$available=$true;return}
        Start-Sleep -Seconds 10
    }
    if(-not $available){throw "Pasta de rede indisponivel: $DestinationRoot"}
    & $collector -DestinationRoot $DestinationRoot
    Set-Content -Path $lastRun -Value $today -Encoding ASCII
    Write-Host '[OK] Coleta concluida e enviada.'
    exit 0
} catch {
    Write-Error $_
    exit 10
} finally {
    Stop-Transcript | Out-Null
}
