#requires -RunAsAdministrator
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ComputerOU,

    [Parameter(Mandatory)]
    [string]$GroupOU,

    [string]$GroupName = "Inventory-GPO-Computers",

    [Parameter(Mandatory)]
    [string]$InventoryPath
)

$ErrorActionPreference = "Stop"
Import-Module ActiveDirectory -ErrorAction Stop

$domain = Get-ADDomain
$netbios = $domain.NetBIOSName

Write-Host "[INFO] Dominio: $($domain.DNSRoot)" -ForegroundColor Cyan
Write-Host "[INFO] OU computadores: $ComputerOU" -ForegroundColor Cyan
Write-Host "[INFO] OU grupos: $GroupOU" -ForegroundColor Cyan

Get-ADOrganizationalUnit -Identity $ComputerOU -ErrorAction Stop | Out-Null
Get-ADOrganizationalUnit -Identity $GroupOU -ErrorAction Stop | Out-Null

$group = Get-ADGroup -Filter "SamAccountName -eq '$GroupName'" -ErrorAction SilentlyContinue
if (-not $group) {
    New-ADGroup `
        -Name $GroupName `
        -SamAccountName $GroupName `
        -GroupCategory Security `
        -GroupScope Global `
        -Path $GroupOU `
        -Description "Computadores autorizados a gravar inventario via GPO"
    $group = Get-ADGroup -Identity $GroupName
    Write-Host "[OK] Grupo criado: $GroupName" -ForegroundColor Green
} else {
    Write-Host "[OK] Grupo ja existe: $GroupName" -ForegroundColor Green
}

$computers = @(
    Get-ADComputer -SearchBase $ComputerOU -SearchScope Subtree -Filter * -Properties Enabled |
    Where-Object Enabled
)

$current = @(
    Get-ADGroupMember -Identity $group -ErrorAction SilentlyContinue |
    Where-Object ObjectClass -eq 'computer' |
    Select-Object -ExpandProperty DistinguishedName
)

$toAdd = @($computers | Where-Object DistinguishedName -notin $current)
foreach ($computer in $toAdd) {
    Add-ADGroupMember -Identity $group -Members $computer
    Write-Host "  + $($computer.Name)$"
}

Write-Host "[OK] Computadores ativos encontrados: $($computers.Count)" -ForegroundColor Green
Write-Host "[OK] Novos membros adicionados: $($toAdd.Count)" -ForegroundColor Green

if (-not (Test-Path -LiteralPath $InventoryPath)) {
    throw "Caminho de inventario nao acessivel: $InventoryPath"
}

$identity = "$netbios\$GroupName"
$acl = Get-Acl -LiteralPath $InventoryPath
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $identity,
    [System.Security.AccessControl.FileSystemRights]::Modify,
    [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit',
    [System.Security.AccessControl.PropagationFlags]::None,
    [System.Security.AccessControl.AccessControlType]::Allow
)
$acl.SetAccessRule($rule)
Set-Acl -LiteralPath $InventoryPath -AclObject $acl

Write-Host "[OK] NTFS Modify aplicado para $identity" -ForegroundColor Green
Write-Host "[INFO] Confira tambem a permissao SMB do compartilhamento com Get-SmbShareAccess." -ForegroundColor Yellow
