#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$DestinationRoot
)

$ErrorActionPreference = 'Stop'
$now = Get-Date
$computer = $env:COMPUTERNAME
$target = Join-Path $DestinationRoot $computer
New-Item -ItemType Directory -Force -Path $target | Out-Null

function Try-Value {
    param([scriptblock]$Script,[object]$Default=$null)
    try { & $Script } catch { $Default }
}

function Export-InventoryCsv {
    param([string]$Name,[object]$Data)
    $path = Join-Path $target ("{0}-{1}.csv" -f $Name,$computer)
    @($Data) | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
}

function Clean-Text([object]$Value) {
    if ($null -eq $Value) { return $null }
    $s=[string]$Value
    $s=$s.Replace([char]0x00A0,' ').Replace([char]0x00FF,' ')
    [regex]::Replace($s,'\s+',' ').Trim()
}

$cs = Get-CimInstance Win32_ComputerSystem
$os = Get-CimInstance Win32_OperatingSystem
$bios = Get-CimInstance Win32_BIOS
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$board = Get-CimInstance Win32_BaseBoard | Select-Object -First 1

$ram = @(Get-CimInstance Win32_PhysicalMemory | ForEach-Object {
    [pscustomobject]@{
        Fabricante=Clean-Text $_.Manufacturer
        CapacidadeGB=[math]::Round($_.Capacity/1GB,2)
        VelocidadeMHz=$_.Speed
        Serial=Clean-Text $_.SerialNumber
        PartNumber=Clean-Text $_.PartNumber
        Slot=Clean-Text $_.DeviceLocator
    }
})

$gpus = @(Get-CimInstance Win32_VideoController | ForEach-Object {
    [pscustomobject]@{
        Nome=Clean-Text $_.Name
        Driver=$_.DriverVersion
        VRAM_GB=if($_.AdapterRAM){[math]::Round($_.AdapterRAM/1GB,2)}else{$null}
        Resolucao=if($_.CurrentHorizontalResolution){"$($_.CurrentHorizontalResolution)x$($_.CurrentVerticalResolution)"}else{$null}
    }
})

$monitors = @(Try-Value {
    Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction Stop | ForEach-Object {
        $decode = { param($a) if($a){ -join ($a | Where-Object {$_ -ne 0} | ForEach-Object {[char]$_}) } }
        [pscustomobject]@{
            Fabricante=&$decode $_.ManufacturerName
            Modelo=&$decode $_.UserFriendlyName
            Serial=&$decode $_.SerialNumberID
            Ativo=$_.Active
        }
    }
} @())

$disks = @(Try-Value {
    Get-PhysicalDisk | ForEach-Object {
        [pscustomobject]@{
            Modelo=Clean-Text $_.FriendlyName
            Tipo=$_.MediaType
            Bus=$_.BusType
            TamanhoGB=[math]::Round($_.Size/1GB,2)
            Serial=Clean-Text $_.SerialNumber
            Status=$_.OperationalStatus -join ','
            Saude=$_.HealthStatus
        }
    }
} @())

$volumes = @(Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    $freePct = if($_.Size){[math]::Round(($_.FreeSpace/$_.Size)*100,1)}else{0}
    [pscustomobject]@{
        Unidade=$_.DeviceID
        Rotulo=$_.VolumeName
        SistemaArquivos=$_.FileSystem
        TotalGB=[math]::Round($_.Size/1GB,2)
        LivreGB=[math]::Round($_.FreeSpace/1GB,2)
        LivrePercentual=$freePct
        AlertaEspaco=if($freePct -lt 15){'SIM'}else{'NAO'}
    }
})

$adapters = @(Get-NetAdapter -ErrorAction SilentlyContinue)
$interfaces = @()
$networkRows = @()
foreach($a in $adapters){
    $cfg = Try-Value { Get-NetIPConfiguration -InterfaceIndex $a.ifIndex -ErrorAction Stop } $null
    $v4 = @($cfg.IPv4Address.IPAddress)
    $v6 = @($cfg.IPv6Address.IPAddress)
    $type = if($a.InterfaceDescription -match 'VPN|Forti|TAP|WireGuard|OpenVPN'){'VPN'}elseif($a.Virtual){'Virtual'}else{'Physical'}
    $interfaces += [pscustomobject]@{
        Interface=$a.Name
        Descricao=Clean-Text $a.InterfaceDescription
        Tipo=$type
        Status=$a.Status
        MAC=$a.MacAddress
        LinkSpeed=$a.LinkSpeed
        IPv4=$v4 -join '; '
        IPv6=$v6 -join '; '
        Gateway=@($cfg.IPv4DefaultGateway.NextHop) -join '; '
        DNS=@($cfg.DNSServer.ServerAddresses) -join '; '
        DHCP=Try-Value { (Get-NetIPInterface -InterfaceIndex $a.ifIndex -AddressFamily IPv4).Dhcp } $null
    }
    foreach($ip in $v4){
        $addr=Try-Value { Get-NetIPAddress -InterfaceIndex $a.ifIndex -IPAddress $ip -AddressFamily IPv4 } $null
        $networkRows += [pscustomobject]@{
            Interface=$a.Name
            Tipo=$type
            IPv4=$ip
            PrefixLength=$addr.PrefixLength
            Gateway=@($cfg.IPv4DefaultGateway.NextHop) -join '; '
            DNS=@($cfg.DNSServer.ServerAddresses) -join '; '
            MAC=$a.MacAddress
            Status=$a.Status
        }
    }
}

$primaryIp = Try-Value { (Find-NetRoute -RemoteIPAddress '1.1.1.1' -ErrorAction Stop | Where-Object IPAddress | Select-Object -First 1).IPAddress } $null
if(-not $primaryIp){
    $primaryIp = @($networkRows | Where-Object {$_.Tipo -eq 'Physical' -and $_.IPv4 -notlike '169.254*'} | Select-Object -ExpandProperty IPv4 -First 1)[0]
}
$additionalIps = @($networkRows.IPv4 | Where-Object {$_ -and $_ -ne $primaryIp} | Select-Object -Unique)

$windowsLicense = Try-Value {
    Get-CimInstance SoftwareLicensingProduct |
        Where-Object {$_.Name -like 'Windows*' -and $_.PartialProductKey} |
        Sort-Object LicenseStatus -Descending |
        Select-Object -First 1
} $null

$licenseStatus = switch($windowsLicense.LicenseStatus){
    1{'Licenciado'}
    2{'OOBGrace'}
    3{'OOTGrace'}
    4{'NonGenuineGrace'}
    5{'Notificacao'}
    6{'ExtendedGrace'}
    default{'Desconhecido'}
}

$fwProfiles = @(Try-Value {
    Get-NetFirewallProfile | ForEach-Object {
        [pscustomobject]@{
            Perfil=$_.Name
            Habilitado=if($_.Enabled){'SIM'}else{'NAO'}
            EntradaPadrao=$_.DefaultInboundAction
            SaidaPadrao=$_.DefaultOutboundAction
        }
    }
} @())

$thirdPartyFw = @(Try-Value {
    Get-CimInstance -Namespace root\SecurityCenter2 -Class FirewallProduct | ForEach-Object {
        [pscustomobject]@{
            Nome=Clean-Text $_.displayName
            ProductState=$_.productState
            Caminho=Clean-Text $_.pathToSignedProductExe
        }
    }
} @())

$antivirus = @(Try-Value {
    Get-CimInstance -Namespace root\SecurityCenter2 -Class AntiVirusProduct |
        Group-Object displayName |
        ForEach-Object {
            $x=$_.Group|Select-Object -First 1
            [pscustomobject]@{
                Nome=Clean-Text $x.displayName
                Registros=$_.Count
                ProductState=$x.productState
                Caminho=Clean-Text $x.pathToSignedProductExe
            }
        }
} @())

$defender = Try-Value { Get-MpComputerStatus } $null
$bitlocker = @(Try-Value {
    Get-BitLockerVolume | ForEach-Object {
        [pscustomobject]@{
            Unidade=$_.MountPoint
            VolumeStatus=$_.VolumeStatus
            ProtectionStatus=$_.ProtectionStatus
            Metodo=($_.EncryptionMethod -join ',')
        }
    }
} @())

$tpm = Try-Value { Get-Tpm } $null
$secureBoot = Try-Value { if(Confirm-SecureBootUEFI){'ATIVADO'}else{'DESATIVADO'} } 'NAO_SUPORTADO'

$programs = @()
$uninstall = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
foreach($key in $uninstall){
    $programs += @(Get-ItemProperty $key -ErrorAction SilentlyContinue | Where-Object DisplayName | ForEach-Object {
        [pscustomobject]@{
            Nome=Clean-Text $_.DisplayName
            Versao=Clean-Text $_.DisplayVersion
            Fabricante=Clean-Text $_.Publisher
            InstallDate=$_.InstallDate
        }
    })
}
$programs = @($programs | Sort-Object Nome,Versao -Unique)
$office = @($programs | Where-Object {$_.Nome -match 'Microsoft (365|Office)'})
$printers = @(Try-Value {
    Get-Printer | ForEach-Object {
        [pscustomobject]@{Nome=$_.Name;Driver=$_.DriverName;Porta=$_.PortName;Compartilhada=$_.Shared}
    }
} @())
$services = @(Get-Service | Where-Object {$_.Name -match 'WinRM|wuauserv|BITS|LanmanServer|EventLog|TermService'} | ForEach-Object {
    [pscustomobject]@{Nome=$_.Name;Status=$_.Status;Inicio=$_.StartType}
})
$admins = @(Try-Value {
    $adminGroup=(Get-LocalGroup -SID 'S-1-5-32-544').Name
    Get-LocalGroupMember -Group $adminGroup | ForEach-Object {
        [pscustomobject]@{Nome=$_.Name;Tipo=$_.ObjectClass;Origem=$_.PrincipalSource}
    }
} @())
$hotfixes = @(Get-HotFix -ErrorAction SilentlyContinue | Sort-Object InstalledOn -Descending)
$latestHotfix = $hotfixes | Select-Object -First 1
$rebootPending = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')

$summary = [pscustomobject]@{
    DataHora=$now.ToString('yyyy-MM-dd HH:mm:ss')
    VersaoColetor='8.0'
    Computador=$computer
    FQDN=Try-Value {[System.Net.Dns]::GetHostEntry($computer).HostName} $computer
    Usuario=$cs.UserName
    Dominio=$cs.Domain
    Fabricante=Clean-Text $cs.Manufacturer
    Modelo=Clean-Text $cs.Model
    Serial=Clean-Text $bios.SerialNumber
    PlacaMae=Clean-Text $board.Product
    CPU=Clean-Text $cpu.Name
    Cores=$cpu.NumberOfCores
    Threads=$cpu.NumberOfLogicalProcessors
    RAM_GB=[math]::Round($cs.TotalPhysicalMemory/1GB,2)
    Windows=$os.Caption
    Versao=$os.Version
    Build=$os.BuildNumber
    Arquitetura=$os.OSArchitecture
    WindowsAtivado=if($windowsLicense.LicenseStatus -eq 1){'SIM'}else{'NAO'}
    StatusAtivacao=$licenseStatus
    ChaveParcial=$windowsLicense.PartialProductKey
    IPPrincipal=$primaryIp
    IPv4Adicionais=$additionalIps -join '; '
    Gateway=@($interfaces.Gateway | Where-Object {$_} | Select-Object -Unique) -join '; '
    AntivirusPrincipal=($antivirus | Select-Object -First 1).Nome
    Defender=if($defender){'SIM'}else{'NAO'}
    SecureBoot=$secureBoot
    TPMReady=if($tpm.TpmReady){'SIM'}else{'NAO'}
    RebootPendente=if($rebootPending){'SIM'}else{'NAO'}
    AlertaDisco=if($volumes.AlertaEspaco -contains 'SIM'){'SIM'}else{'NAO'}
    UptimeDias=[math]::Round(((Get-Date)-$os.LastBootUpTime).TotalDays,2)
}

$security = [pscustomobject]@{
    Computador=$computer
    SecureBoot=$secureBoot
    TPMPresente=$tpm.TpmPresent
    TPMReady=$tpm.TpmReady
    DefenderRealtime=$defender.RealTimeProtectionEnabled
    DefenderAntivirus=$defender.AntivirusEnabled
    RebootPendente=$rebootPending
}

$updates = [pscustomobject]@{
    Computador=$computer
    WindowsUpdate=(Get-Service wuauserv -ErrorAction SilentlyContinue).Status
    BITS=(Get-Service BITS -ErrorAction SilentlyContinue).Status
    UltimoKB=$latestHotfix.HotFixID
    DataUltimoKB=$latestHotfix.InstalledOn
    RebootPendente=if($rebootPending){'SIM'}else{'NAO'}
}

Export-InventoryCsv 'resumo' $summary
Export-InventoryCsv 'seguranca' $security
Export-InventoryCsv 'interfaces' $interfaces
Export-InventoryCsv 'rede' $networkRows
Export-InventoryCsv 'discos' $disks
Export-InventoryCsv 'volumes' $volumes
Export-InventoryCsv 'gpu' $gpus
Export-InventoryCsv 'monitores' $monitors
Export-InventoryCsv 'firewall-windows' $fwProfiles
Export-InventoryCsv 'firewall-terceiros' $thirdPartyFw
Export-InventoryCsv 'bitlocker' $bitlocker
Export-InventoryCsv 'antivirus' $antivirus
Export-InventoryCsv 'impressoras' $printers
Export-InventoryCsv 'servicos' $services
Export-InventoryCsv 'admins-locais' $admins
Export-InventoryCsv 'atualizacoes' $updates
Export-InventoryCsv 'office' $office
Export-InventoryCsv 'programas' $programs

$complete=[ordered]@{
    Resumo=$summary
    Seguranca=$security
    RAM=$ram
    GPUs=$gpus
    Monitores=$monitors
    Discos=$disks
    Volumes=$volumes
    Interfaces=$interfaces
    Rede=$networkRows
    FirewallWindows=$fwProfiles
    FirewallTerceiros=$thirdPartyFw
    BitLocker=$bitlocker
    Antivirus=$antivirus
    Defender=$defender
    Programas=$programs
    Office=$office
    Impressoras=$printers
    Servicos=$services
    Administradores=$admins
    Hotfixes=$hotfixes
}

$complete | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $target "inventario-atual-$computer.json") -Encoding UTF8

$history=Join-Path $target 'Historico'
New-Item -ItemType Directory -Force -Path $history | Out-Null
$complete | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $history ("inventario-{0}-{1}.json" -f $computer,$now.ToString('yyyyMMdd'))) -Encoding UTF8
Get-ChildItem $history -Filter "inventario-$computer-*.json" -File -ErrorAction SilentlyContinue |
    Where-Object LastWriteTime -lt $now.AddDays(-30) |
    Remove-Item -Force -ErrorAction SilentlyContinue

$summary
