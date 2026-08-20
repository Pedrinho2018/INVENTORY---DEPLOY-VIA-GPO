# Inventory — Deploy via GPO

Projeto de inventário automatizado para estações Windows, distribuído por **Group Policy (GPO)** e executado como **Local System**.

> A versão pública foi sanitizada: IPs, domínio, nomes de servidores e compartilhamentos do ambiente real não são publicados.

## Arquitetura

```mermaid
flowchart LR
    AD[Active Directory] --> GPO[GPO de computadores]
    GPO --> SYSVOL[Startup Script / SYSVOL]
    SYSVOL --> DEPLOY[Deploy local]
    DEPLOY --> TASK[Tarefa agendada / SYSTEM]
    TASK --> COLLECT[Coleta PowerShell]
    COLLECT --> SHARE[Compartilhamento SMB]
```

## Principais recursos

- implantação centralizada por GPO;
- execução como `SYSTEM`, sem senha armazenada;
- tarefa no boot + fallback no logon;
- uma coleta bem-sucedida por dia;
- retry quando a rede ainda não está disponível;
- logs locais de deploy e coleta;
- pasta individual por computador;
- CSVs detalhados + JSON atual + histórico de 30 dias;
- inventário de hardware, rede, Windows, segurança, softwares, Office, impressoras, serviços e atualizações;
- ferramentas para criação do grupo de computadores, ACL NTFS e GPO.

## Estrutura

```text
src/
  Collect-Inventory.ps1
  Run-Inventory.ps1
deploy/
  Deploy_GMInventory_GPO.cmd
  Install-InventoryTask.ps1
tools/
  Configure-ADInventoryAccess.ps1
  Create-InventoryGPO.ps1
docs/
  ARCHITECTURE.md
  DEPLOYMENT.md
  TROUBLESHOOTING.md
```

## Configuração

Defina nas estações a variável de ambiente `INVENTORY_DESTINO` com o UNC central. Exemplo público:

```powershell
[Environment]::SetEnvironmentVariable(
  'INVENTORY_DESTINO',
  '\\FILESERVER\InventoryShare\Inventory',
  'Machine'
)
```

Em produção, distribua essa variável por GPO Preferences ou adapte `Run-Inventory.ps1` ao seu padrão de configuração.

## SYSVOL

Em `Computer Configuration > Policies > Windows Settings > Scripts (Startup/Shutdown) > Startup > Show Files`, coloque os quatro arquivos no mesmo diretório:

```text
Deploy_GMInventory_GPO.cmd
Install-InventoryTask.ps1
Collect-Inventory.ps1
Run-Inventory.ps1
```

Na lista de Startup Scripts adicione **somente** `Deploy_GMInventory_GPO.cmd`.

## Teste piloto

```powershell
gpupdate /force
Restart-Computer
```

Depois:

```powershell
gpresult /r /scope computer
Get-ScheduledTask -TaskName 'GM - Inventario Diario'
Get-Content 'C:\ProgramData\GMInventory\logs\gpo-deploy.log' -Tail 30
```

Valide primeiro uma máquina limpa e só depois amplie o Security Filtering para o grupo de computadores.

## Segurança

A tarefa roda como `SYSTEM`. Ao acessar um compartilhamento SMB remoto, a estação usa sua conta de computador. Use um grupo de segurança dedicado e conceda apenas o necessário (tipicamente `Modify`) no diretório de inventário. Revise permissões SMB e NTFS separadamente.

## Documentação

- [Arquitetura](docs/ARCHITECTURE.md)
- [Implantação](docs/DEPLOYMENT.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
