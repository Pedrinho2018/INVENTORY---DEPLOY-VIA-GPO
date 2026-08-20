# Inventory — Deploy via GPO

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)
![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-blue)
![Version](https://img.shields.io/badge/stable-8.2--GM-success)

Inventário automatizado de estações Windows distribuído por **Group Policy (GPO)**, executado como **Local System** e enviado para um compartilhamento SMB central.

> **Versão estável: 8.2-GM.** A implantação foi validada primeiro em uma estação piloto e depois em uma estação limpa antes da expansão do escopo.

> **Repositório público sanitizado.** IPs, domínio, nomes de servidores, OUs e compartilhamentos do ambiente real não são publicados. Configure o seu próprio caminho UNC.

## Arquitetura

```mermaid
flowchart LR
    AD[Active Directory] --> GPO[GPO de Computadores]
    GPO --> SYSVOL[Startup Script / SYSVOL]
    SYSVOL --> DEPLOY[Deploy local]
    DEPLOY --> TASK[Tarefa agendada / SYSTEM]
    TASK --> RUNNER[Run-Inventory.ps1]
    RUNNER --> COLLECT[Collect-Inventory.ps1]
    COLLECT --> SHARE[Compartilhamento SMB]
```

## O que a v8.2-GM faz

- instala e atualiza o agente automaticamente pelo SYSVOL;
- executa como `NT AUTHORITY\SYSTEM`;
- cria a tarefa `GM - Inventario Diario`;
- inicia no boot e possui fallback no logon;
- distribui o início entre **2 e 10 minutos** para reduzir pico de acesso ao servidor;
- executa no máximo **uma coleta bem-sucedida por dia**;
- tenta acessar o compartilhamento até 12 vezes quando a rede ainda não está pronta;
- mantém logs locais de deploy e coleta;
- cria uma pasta individual por computador no destino central;
- grava CSVs detalhados e JSON;
- mantém histórico JSON diário por 30 dias;
- remove APIPA `169.254.x.x`, VPNs e interfaces virtuais do **resumo** de IPs;
- mantém todos os endereços no arquivo detalhado `rede-<PC>.csv`.

## Dados coletados

Hardware e sistema: fabricante, modelo, BIOS/serial, placa-mãe, CPU, RAM, GPU, monitores, discos, volumes, Windows, build e status de ativação.

Rede e segurança: interfaces, IPv4/IPv6, gateway, DNS, MAC, DHCP, firewall, antivírus, Defender, BitLocker, TPM, Secure Boot e reinicialização pendente.

Software e operação: programas instalados, Microsoft 365/Office, impressoras, serviços importantes, administradores locais e hotfixes.

## Estrutura do repositório

```text
src/
├── Collect-Inventory.ps1
└── Run-Inventory.ps1

deploy/
├── Deploy_GMInventory_GPO.cmd
└── Install-InventoryTask.ps1

tools/
├── Configure-ADInventoryAccess.ps1
├── Create-InventoryGPO.ps1
├── Set-InventoryDestination.ps1
├── Validate-GMInventory.ps1
├── Test-Now.ps1
└── Remove-GMInventory.ps1

docs/
├── ARCHITECTURE.md
├── DEPLOYMENT.md
└── TROUBLESHOOTING.md
```

# Implantação rápida

## 1. Preparar o compartilhamento

Crie um diretório central, por exemplo:

```text
\\FILESERVER\InventoryShare\Inventory
```

A tarefa roda como `SYSTEM`. Em acesso SMB remoto, a estação autentica usando a **conta do computador**. Use um grupo de segurança dedicado e conceda somente o necessário.

O utilitário abaixo pode criar o grupo, adicionar os computadores de uma OU e aplicar `Modify` no NTFS:

```powershell
.\tools\Configure-ADInventoryAccess.ps1 `
  -ComputerOU "OU=Workstations,DC=example,DC=local" `
  -GroupOU "OU=Groups,DC=example,DC=local" `
  -GroupName "Inventory-GPO-Computers" `
  -InventoryPath "\\FILESERVER\InventoryShare\Inventory"
```

Confira também a ACL do compartilhamento:

```powershell
Get-SmbShareAccess -Name "InventoryShare"
```

## 2. Configurar o destino

A versão pública lê o caminho central pela variável de ambiente de máquina:

```text
INVENTORY_DESTINO
```

Valor de exemplo:

```text
\\FILESERVER\InventoryShare\Inventory
```

Recomendado: distribuir por **Group Policy Preferences > Environment**.

Para teste local:

```powershell
.\tools\Set-InventoryDestination.ps1 `
  -DestinationRoot "\\FILESERVER\InventoryShare\Inventory"
```

## 3. Criar e vincular a GPO

```powershell
.\tools\Create-InventoryGPO.ps1 `
  -TargetOU "OU=Workstations,DC=example,DC=local" `
  -GpoName "GPO - Inventory - Workstations"
```

## 4. Colocar os arquivos no SYSVOL

Na GPMC:

```text
Computer Configuration
└─ Policies
   └─ Windows Settings
      └─ Scripts (Startup/Shutdown)
         └─ Startup
            └─ Show Files...
```

Copie **quatro arquivos para a mesma pasta**:

```text
Deploy_GMInventory_GPO.cmd
Collect-Inventory.ps1
Run-Inventory.ps1
Install-InventoryTask.ps1
```

Os dois arquivos de `src/` e os dois de `deploy/` devem ficar juntos nessa pasta do SYSVOL.

Na lista de **Startup Scripts**, adicione **somente**:

```text
Deploy_GMInventory_GPO.cmd
```

Não adicione os `.ps1` separadamente.

## 5. Fazer piloto

Use Security Filtering para aplicar a GPO primeiro em uma única conta de computador.

Na estação piloto:

```powershell
gpupdate /force
Restart-Computer
```

Depois do boot:

```powershell
gpresult /r /scope computer
Get-Content "C:\ProgramData\GMInventory\logs\gpo-deploy.log" -Tail 30
Get-ScheduledTask -TaskName "GM - Inventario Diario"
```

O log deve terminar com:

```text
Deploy GPO 8.2-GM concluido com sucesso.
```

## 6. Forçar uma coleta de teste

```powershell
Remove-Item "C:\ProgramData\GMInventory\state\last-success.txt" `
  -Force -ErrorAction SilentlyContinue

Start-ScheduledTask -TaskName "GM - Inventario Diario"
```

Enquanto estiver executando, o Scheduler pode mostrar `267009` (`0x41301`), que significa **Running**.

Espere terminar:

```powershell
while ((Get-ScheduledTask -TaskName "GM - Inventario Diario").State -eq "Running") {
    Start-Sleep -Seconds 3
}

Get-ScheduledTaskInfo -TaskName "GM - Inventario Diario" |
Format-List LastRunTime,LastTaskResult
```

Resultado esperado:

```text
LastTaskResult : 0
```

Log:

```powershell
Get-Content (
  Get-ChildItem "C:\ProgramData\GMInventory\logs\inventario-*.log" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1
).FullName -Tail 30
```

O final deve conter:

```text
[OK] SUCESSO: coleta concluida e enviada.
```

## 7. Validar o CSV central

```powershell
Import-Csv "\\FILESERVER\InventoryShare\Inventory\PC01\resumo-PC01.csv" |
Select-Object DataHora,VersaoColetor,Computador,Usuario,IPPrincipal,IPv4Adicionais,AntivirusPrincipal
```

Esperado:

```text
VersaoColetor : 8.2-GM
```

Na v8.2-GM, `IPv4Adicionais` não deve conter APIPA `169.254.x.x` nem endereços de VPN/interface virtual. Esses endereços continuam nos CSVs detalhados `rede-<PC>.csv` e `interfaces-<PC>.csv`.

## 8. Fazer um segundo piloto limpo

Antes do rollout geral, faça o mesmo teste em uma estação que **nunca recebeu o agente manualmente**. Isso valida o fluxo completo:

```text
GPO → SYSVOL → cópia local → tarefa SYSTEM → coleta → SMB
```

Só depois amplie o Security Filtering para o grupo de computadores.

# Operação diária

Arquivos locais:

```text
C:\ProgramData\GMInventory\
├── Collect-Inventory.ps1
├── Run-Inventory.ps1
├── Install-InventoryTask.ps1
├── logs\
└── state\
```

Tarefa:

```text
GM - Inventario Diario
```

Marcador diário:

```text
C:\ProgramData\GMInventory\state\last-success.txt
```

Destino central:

```text
<InventoryRoot>\<COMPUTERNAME>\
```

# Atualizações

Para atualizar o agente, substitua os quatro arquivos na pasta de Startup da GPO. No boot seguinte, o deploy compara os arquivos e atualiza somente o que mudou; a tarefa também é registrada novamente com a configuração atual.

# Rollback

Em uma estação:

```powershell
.\tools\Remove-GMInventory.ps1
```

Para remover também logs e `state`:

```powershell
.\tools\Remove-GMInventory.ps1 -RemoveData
```

Remover o agente local não remove a GPO. Se a máquina continuar no escopo, o agente poderá ser reinstalado no próximo boot.

## Documentação

- [Arquitetura](docs/ARCHITECTURE.md)
- [Implantação detalhada](docs/DEPLOYMENT.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Segurança](SECURITY.md)

## Segurança

O projeto não armazena senha de usuário ou conta administrativa. Para ambientes reais, use grupo de segurança dedicado, revise permissões SMB e NTFS e nunca publique IPs, nomes internos, OUs, credenciais ou caminhos reais em repositórios públicos.
