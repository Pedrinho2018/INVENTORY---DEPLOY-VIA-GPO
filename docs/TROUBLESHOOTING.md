# Troubleshooting

## A GPO aparece no gpresult, mas o agente não foi instalado

```powershell
gpresult /r /scope computer
```

Verifique se os quatro arquivos estão diretamente na pasta aberta por **Startup > Show Files**.

Depois consulte:

```powershell
Get-WinEvent -LogName "Microsoft-Windows-GroupPolicy/Operational" -MaxEvents 100 |
Where-Object Message -match 'Startup|script' |
Select-Object TimeCreated,Id,Message
```

## gpo-deploy.log não existe

Se a GPO estiver aplicada mas o arquivo não existir:

```text
C:\ProgramData\GMInventory\logs\gpo-deploy.log
```

confirme o registro do Startup Script:

```powershell
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup" /s
```

`Deploy_GMInventory_GPO.cmd` deve aparecer.

## Destino não configurado

Confira:

```powershell
[Environment]::GetEnvironmentVariable('INVENTORY_DESTINO','Machine')
```

Configure:

```powershell
[Environment]::SetEnvironmentVariable(
  'INVENTORY_DESTINO',
  '\\FILESERVER\InventoryShare\Inventory',
  'Machine'
)
```

## Compartilhamento funciona para o usuário, mas falha como SYSTEM

O acesso do usuário e o acesso da tarefa usam identidades diferentes. A tarefa usa a conta do computador no acesso remoto.

Confira associação da conta de computador ao grupo autorizado, NTFS, SMB, DNS, rota e firewall entre a estação e o file server.

## LastTaskResult = 267009

`267009` é `0x41301`: a tarefa está **executando**.

Espere:

```powershell
while ((Get-ScheduledTask -TaskName "GM - Inventario Diario").State -eq "Running") {
    Start-Sleep -Seconds 3
}
```

Depois:

```powershell
Get-ScheduledTaskInfo -TaskName "GM - Inventario Diario" |
Format-List LastRunTime,LastTaskResult
```

Sucesso:

```text
LastTaskResult : 0
```

## A coleta não roda novamente no mesmo dia

Comportamento esperado. O marcador é:

```text
C:\ProgramData\GMInventory\state\last-success.txt
```

Para teste somente:

```powershell
Remove-Item "C:\ProgramData\GMInventory\state\last-success.txt" -Force
Start-ScheduledTask -TaskName "GM - Inventario Diario"
```

## O resumo contém IPs 169.254.x.x

Na v8.2-GM, APIPA não deve aparecer em `IPPrincipal` ou `IPv4Adicionais`.

```powershell
Import-Csv "\\FILESERVER\InventoryShare\Inventory\PC01\resumo-PC01.csv" |
Select-Object VersaoColetor,IPPrincipal,IPv4Adicionais
```

Se estiver usando versão anterior, atualize os quatro arquivos do SYSVOL e reinicie a estação.

## VPN e IP virtual sumiram do resumo

Isso é intencional na v8.2-GM. Eles continuam disponíveis em:

```text
interfaces-<PC>.csv
rede-<PC>.csv
```

O resumo exibe somente IPs físicos ativos relevantes.

## Ver o log mais recente

```powershell
Get-Content (
  Get-ChildItem "C:\ProgramData\GMInventory\logs\inventario-*.log" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1
).FullName -Tail 40
```

## Remover o agente de uma estação

Primeiro tire a máquina do escopo da GPO. Depois:

```powershell
.\tools\Remove-GMInventory.ps1
```

Caso contrário, o Startup Script poderá reinstalar o agente no boot seguinte.
