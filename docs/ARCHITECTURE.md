# Arquitetura

1. A GPO aplica um Startup Script à OU/grupo de computadores.
2. `Deploy_GMInventory_GPO.cmd` copia os componentes do SYSVOL para `C:\ProgramData\GMInventory`.
3. `Install-InventoryTask.ps1` registra `GM - Inventario Diario` como `SYSTEM`.
4. `Run-Inventory.ps1` controla rede, logs e limite de uma coleta por dia.
5. `Collect-Inventory.ps1` faz a coleta e grava CSV/JSON no compartilhamento central.

A GPO fica responsável por **implantação/atualização**, e não por executar todo o inventário diretamente. Isso simplifica manutenção e reduz dependência do SYSVOL durante a coleta.
