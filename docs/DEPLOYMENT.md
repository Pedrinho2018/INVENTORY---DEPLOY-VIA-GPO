# Implantação da v8.2-GM

Este documento descreve o fluxo recomendado para implantar o Inventory — Deploy via GPO em estações Windows de domínio.

## Pré-requisitos

- Active Directory Domain Services;
- GPMC/Group Policy Management;
- Windows PowerShell 5.1 ou superior nas estações;
- compartilhamento SMB acessível pelas contas de computador;
- permissão NTFS de gravação/modificação no diretório central;
- computadores dentro de uma OU gerenciada pela GPO.

## 1. Preparar o grupo de computadores

Use um grupo de segurança dedicado.

```powershell
.\tools\Configure-ADInventoryAccess.ps1 `
  -ComputerOU "OU=Workstations,DC=example,DC=local" `
  -GroupOU "OU=Groups,DC=example,DC=local" `
  -GroupName "Inventory-GPO-Computers" `
  -InventoryPath "\\FILESERVER\InventoryShare\Inventory"
```

O script valida as OUs, cria o grupo caso não exista, adiciona computadores habilitados da OU e aplica `Modify` no NTFS sem remover as ACLs existentes.

Confira separadamente a ACL do compartilhamento SMB.

## 2. Definir INVENTORY_DESTINO

Configure a variável de ambiente de máquina:

```text
Nome: INVENTORY_DESTINO
Valor: \\FILESERVER\InventoryShare\Inventory
Tipo: Machine/System
```

Preferencialmente via:

```text
Computer Configuration
└─ Preferences
   └─ Windows Settings
      └─ Environment
```

Para teste manual:

```powershell
[Environment]::SetEnvironmentVariable(
  'INVENTORY_DESTINO',
  '\\FILESERVER\InventoryShare\Inventory',
  'Machine'
)
```

## 3. Criar a GPO

```powershell
.\tools\Create-InventoryGPO.ps1 `
  -TargetOU "OU=Workstations,DC=example,DC=local"
```

O script cria e vincula a GPO. A configuração do Startup Script continua sendo feita na GPMC para que os arquivos fiquem no diretório correto do SYSVOL.

## 4. SYSVOL

Na GPMC, abra:

```text
Computer Configuration > Policies > Windows Settings
> Scripts (Startup/Shutdown) > Startup > Show Files
```

Copie:

```text
Deploy_GMInventory_GPO.cmd
Collect-Inventory.ps1
Run-Inventory.ps1
Install-InventoryTask.ps1
```

Na lista de Startup Scripts, cadastre somente:

```text
Deploy_GMInventory_GPO.cmd
```

## 5. Security Filtering

Comece com uma estação piloto. Depois valide uma segunda estação limpa. Somente então altere a filtragem para o grupo dedicado de computadores.

## 6. O que acontece no boot

`Deploy_GMInventory_GPO.cmd` cria `C:\ProgramData\GMInventory`, copia componentes ausentes, compara arquivos existentes com `fc /b`, atualiza o que mudou, registra/atualiza a tarefa e grava `gpo-deploy.log`.

A tarefa roda como `SYSTEM` e possui trigger de Startup, fallback de Logon, atraso calculado pelo nome do computador, `StartWhenAvailable`, bloqueio de múltiplas instâncias, timeout de 30 minutos e até 3 tentativas em caso de falha.

## 7. Coleta diária

`Run-Inventory.ps1` lê `INVENTORY_DESTINO`, verifica se já houve sucesso no dia, aguarda a rede, executa `Collect-Inventory.ps1` e grava `last-success.txt` somente após sucesso.

Assim, vários boots no mesmo dia não provocam múltiplas coletas completas.

## 8. Validação

```powershell
gpresult /r /scope computer
Get-ScheduledTask -TaskName "GM - Inventario Diario"
Get-Content "C:\ProgramData\GMInventory\logs\gpo-deploy.log" -Tail 30
```

Forçar um teste:

```powershell
Remove-Item "C:\ProgramData\GMInventory\state\last-success.txt" -Force -ErrorAction SilentlyContinue
Start-ScheduledTask -TaskName "GM - Inventario Diario"
```

Enquanto a tarefa estiver em execução, `LastTaskResult` pode aparecer como `267009` (`0x41301`). Espere o estado sair de `Running` e confirme `LastTaskResult = 0`.

## 9. Rollout

Depois de dois pilotos bem-sucedidos:

1. mantenha a GPO vinculada somente na OU desejada;
2. aplique o Security Filtering ao grupo de computadores;
3. deixe as estações receberem a política nos boots seguintes;
4. acompanhe a pasta central e os logs locais;
5. use o consolidado/relatório central para identificar máquinas que ainda não reportaram.
