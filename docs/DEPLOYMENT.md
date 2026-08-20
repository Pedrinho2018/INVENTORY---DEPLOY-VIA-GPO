# Implantação

## Pré-requisitos

- domínio Active Directory;
- estações Windows 10/11;
- PowerShell 5.1+;
- compartilhamento SMB acessível pelas contas de computador;
- GPO vinculada à OU das estações;
- grupo de segurança dedicado para limitar o escopo.

## Destino central

Configure a variável de ambiente de máquina:

```text
INVENTORY_DESTINO=\\FILESERVER\InventoryShare\Inventory
```

Você pode distribuí-la por **Group Policy Preferences > Environment** ou usar:

```powershell
.\tools\Set-InventoryDestination.ps1 -Path "\\FILESERVER\InventoryShare\Inventory"
```

## Permissões

O agente executa como `SYSTEM`. No acesso SMB remoto, a estação usa sua conta de computador.

Recomendação:

- grupo de segurança dedicado, por exemplo `Inventory-GPO-Computers`;
- NTFS `Modify` no diretório de inventário;
- revisar separadamente as permissões do compartilhamento SMB;
- não usar `Full Control` sem necessidade.

## Arquivos do SYSVOL

Copie para a pasta de Startup da GPO:

```text
Deploy-Inventory-GPO.cmd
Collect-Inventory.ps1
Run-Inventory.ps1
Install-InventoryTask.ps1
```

Na lista de scripts de inicialização, adicione somente:

```text
Deploy-Inventory-GPO.cmd
```

## Piloto

Comece com uma única estação na filtragem de segurança.

```powershell
gpupdate /force
Restart-Computer
```

Depois confirme:

```powershell
gpresult /r /scope computer
Get-ScheduledTask -TaskName "Inventory - Daily"
Get-Content "C:\ProgramData\InventoryAgent\logs\gpo-deploy.log" -Tail 30
```

## Teste imediato

```powershell
.\tools\Test-Now.ps1
```

Ou manualmente:

```powershell
Remove-Item "C:\ProgramData\InventoryAgent\state\last-success.txt" -Force -ErrorAction SilentlyContinue
Start-ScheduledTask -TaskName "Inventory - Daily"
```

Aguarde a tarefa sair do estado `Running` e confira `LastTaskResult`. O valor `0` indica sucesso.

## Produção

Depois de testar uma estação limpa:

1. substitua filtros individuais pelo grupo de computadores;
2. mantenha o vínculo da GPO habilitado;
3. não use `Enforced` sem necessidade;
4. monitore logs e a quantidade de estações reportando;
5. mantenha o destino e detalhes internos fora do repositório público.
