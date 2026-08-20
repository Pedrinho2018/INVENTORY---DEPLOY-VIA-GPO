# Troubleshooting

## GPO não aparece no `gpresult`

```powershell
gpresult /r /scope computer
```

Verifique:

- vínculo da GPO;
- filtragem de segurança;
- associação da estação ao grupo autorizado;
- OU correta;
- replicação de AD/SYSVOL;
- processamento de política de computador.

## Script de Startup não executou

Confirme os arquivos no SYSVOL e consulte:

```powershell
Get-WinEvent -LogName "Microsoft-Windows-GroupPolicy/Operational" -MaxEvents 200 |
Where-Object Message -match 'script|startup|inicializa' |
Select-Object TimeCreated,Id,LevelDisplayName,Message
```

## Deploy não criou os arquivos locais

Confira:

```text
C:\ProgramData\InventoryAgent\logs\gpo-deploy.log
```

E valide se estes arquivos existem localmente:

```text
Collect-Inventory.ps1
Run-Inventory.ps1
Install-InventoryTask.ps1
```

## Tarefa não existe

```powershell
Get-ScheduledTask -TaskName "Inventory - Daily"
```

Se necessário, execute o instalador local como administrador:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "C:\ProgramData\InventoryAgent\Install-InventoryTask.ps1"
```

## `LastTaskResult = 267009`

Esse valor (`0x41301`) normalmente significa que a tarefa **ainda está executando**. Aguarde até sair do estado `Running` e consulte novamente:

```powershell
while ((Get-ScheduledTask -TaskName "Inventory - Daily").State -eq 'Running') {
    Start-Sleep -Seconds 3
}
Get-ScheduledTaskInfo -TaskName "Inventory - Daily" |
Format-List LastRunTime,LastTaskResult
```

## Compartilhamento não acessível como SYSTEM

Valide SMB e NTFS separadamente. Acesso interativo do usuário não comprova que a conta de computador possua permissão.

## Coleta já executada hoje

O runner mantém:

```text
C:\ProgramData\InventoryAgent\state\last-success.txt
```

Para um teste controlado, remova o marcador e inicie a tarefa novamente.

## Logs

Deploy:

```text
C:\ProgramData\InventoryAgent\logs\gpo-deploy.log
```

Coleta:

```text
C:\ProgramData\InventoryAgent\logs\inventario-<PC>-<DATA>.log
```
