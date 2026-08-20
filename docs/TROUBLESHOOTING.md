# Troubleshooting

## GPO aplicada, mas deploy ausente

```powershell
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup" /s
Get-WinEvent -LogName 'Microsoft-Windows-GroupPolicy/Operational' -MaxEvents 200 |
  Where-Object Message -match 'script|startup|inicializa' |
  Select-Object TimeCreated,Id,Message
```

## Verificar SYSVOL

Os quatro arquivos precisam estar juntos em `Startup > Show Files`.

## Usuário acessa o compartilhamento, mas SYSTEM não

Verifique a conta de computador, o grupo de segurança, a ACL NTFS, a permissão SMB e a disponibilidade de rede no boot.

## Tarefa

```powershell
Get-ScheduledTask -TaskName 'GM - Inventario Diario'
(Get-ScheduledTask -TaskName 'GM - Inventario Diario').Actions | Format-List Execute,Arguments
```

## Logs

```text
C:\ProgramData\GMInventory\logs\gpo-deploy.log
C:\ProgramData\GMInventory\logs\inventario-<HOST>-<DATA>.log
```

## Forçar teste no mesmo dia

```powershell
Remove-Item 'C:\ProgramData\GMInventory\state\last-success.txt' -Force -ErrorAction SilentlyContinue
Start-ScheduledTask -TaskName 'GM - Inventario Diario'
```
