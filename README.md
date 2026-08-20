# Inventory — Deploy via GPO

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)
![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-blue)
![Version](https://img.shields.io/badge/stable-8.2-success)

Inventário automatizado de estações Windows distribuído por **Group Policy (GPO)**, executado como **Local System** e enviado para um compartilhamento SMB central.

> **Versão estável: 8.2.** A implantação deve ser validada primeiro em uma estação piloto e depois em uma estação limpa antes da expansão do escopo.

> **Repositório público sanitizado.** Não publique IPs, domínios, nomes de servidores, OUs, nomes de empresas, usuários ou compartilhamentos reais. Use valores genéricos e configure o seu próprio ambiente.

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

## O que a versão 8.2 faz

- instala e atualiza o agente automaticamente pelo SYSVOL;
- executa como `NT AUTHORITY\SYSTEM`;
- cria uma tarefa agendada de inventário diário;
- inicia no boot e possui fallback no logon;
- distribui o início entre **2 e 10 minutos** para reduzir pico de acesso ao servidor;
- executa no máximo **uma coleta bem-sucedida por dia**;
- tenta acessar o compartilhamento várias vezes quando a rede ainda não está pronta;
- mantém logs locais de deploy e coleta;
- cria uma pasta individual por computador no destino central;
- grava CSVs detalhados e JSON;
- mantém histórico JSON diário por 30 dias;
- remove APIPA `169.254.x.x`, VPNs e interfaces virtuais do resumo de IPs;
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
├── Deploy-Inventory-GPO.cmd
└── Install-InventoryTask.ps1

tools/
├── Configure-ADInventoryAccess.ps1
├── Create-InventoryGPO.ps1
├── Set-InventoryDestination.ps1
├── Validate-Inventory.ps1
├── Test-Now.ps1
└── Remove-Inventory.ps1

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

Exemplo:

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

Exemplo:

```text
\\FILESERVER\InventoryShare\Inventory
```

Recomendado: distribuir por **Group Policy Preferences > Environment**.

Para teste local:

```powershell
.\tools\Set-InventoryDestination.ps1 -Path "\\FILESERVER\InventoryShare\Inventory"
```

## 3. Criar a GPO

Exemplo:

```powershell
.\tools\Create-InventoryGPO.ps1 `
  -TargetOU "OU=Workstations,DC=example,DC=local" `
  -GpoName "GPO - Inventory - Workstations"
```

## 4. Copiar arquivos para o SYSVOL

Em:

```text
Computer Configuration
> Policies
> Windows Settings
> Scripts (Startup/Shutdown)
> Startup
> Show Files...
```

coloque no mesmo diretório:

```text
Deploy-Inventory-GPO.cmd
Install-InventoryTask.ps1
Collect-Inventory.ps1
Run-Inventory.ps1
```

Na lista de Startup Scripts, adicione **somente**:

```text
Deploy-Inventory-GPO.cmd
```

## 5. Teste piloto

Comece com uma única máquina na filtragem de segurança da GPO.

```powershell
gpupdate /force
Restart-Computer
```

Depois valide:

```powershell
gpresult /r /scope computer
Get-ScheduledTask -TaskName "Inventory - Daily"
Get-Content "C:\ProgramData\InventoryAgent\logs\gpo-deploy.log" -Tail 30
```

## 6. Validar a coleta

```powershell
Import-Csv "\\FILESERVER\InventoryShare\Inventory\PC-001\resumo-PC-001.csv" |
Select-Object DataHora,VersaoColetor,Computador,IPPrincipal,IPv4Adicionais,AntivirusPrincipal
```

O resultado esperado é uma execução com código `0`, arquivos atualizados no destino central e sem APIPA ou interfaces virtuais no resumo.

## 7. Expandir para produção

Após validar uma máquina limpa:

1. remova filtros individuais de teste;
2. adicione o grupo de segurança de computadores;
3. mantenha a GPO vinculada à OU correta;
4. deixe o vínculo habilitado;
5. não use `Enforced` sem necessidade;
6. monitore os logs e a quantidade de máquinas reportando.

## Segurança

- não armazena senha de usuário;
- executa como `SYSTEM`;
- usa conta de computador no acesso SMB;
- recomenda grupo dedicado no AD;
- recomenda `Modify`, não `Full Control`, no diretório de inventário;
- não exige exposição direta à Internet;
- não publique infraestrutura real neste repositório.

## Documentação

- [Arquitetura](docs/ARCHITECTURE.md)
- [Implantação](docs/DEPLOYMENT.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Segurança](SECURITY.md)
- [Histórico de versões](CHANGELOG.md)
