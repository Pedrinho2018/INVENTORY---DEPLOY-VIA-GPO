# Implantação

## 1. Compartilhamento e AD

Crie um grupo de computadores dedicado e conceda `Modify` no diretório de inventário. O script `tools/Configure-ADInventoryAccess.ps1` pode automatizar a inclusão dos computadores ativos da OU e a ACL NTFS.

Confira também a camada SMB:

```powershell
Get-SmbShareAccess -Name 'InventoryShare'
```

## 2. Variável de destino

Configure `INVENTORY_DESTINO` como variável de máquina. Exemplo:

```powershell
[Environment]::SetEnvironmentVariable('INVENTORY_DESTINO','\\FILESERVER\InventoryShare\Inventory','Machine')
```

## 3. GPO

Crie/vincule a GPO à OU de estações. Use `tools/Create-InventoryGPO.ps1` ou a GPMC.

Em Startup > Show Files, copie:

```text
Deploy_GMInventory_GPO.cmd
Install-InventoryTask.ps1
Collect-Inventory.ps1
Run-Inventory.ps1
```

Cadastre somente `Deploy_GMInventory_GPO.cmd` como Startup Script.

## 4. Piloto

Aplique o Security Filtering a uma estação de teste, execute `gpupdate /force` e reinicie.

Valide:

```powershell
gpresult /r /scope computer
Get-ScheduledTask -TaskName 'GM - Inventario Diario'
Get-Content 'C:\ProgramData\GMInventory\logs\gpo-deploy.log' -Tail 30
```

## 5. Produção

Teste também uma segunda estação que nunca recebeu o agente manualmente. Só depois amplie o filtro para o grupo completo de computadores.
