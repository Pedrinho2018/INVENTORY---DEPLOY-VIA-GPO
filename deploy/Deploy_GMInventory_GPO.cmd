@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "BASE=C:\ProgramData\GMInventory"
set "LOG=%BASE%\logs\gpo-deploy.log"
if not exist "%BASE%\logs" mkdir "%BASE%\logs" >nul 2>&1
if not exist "%BASE%\state" mkdir "%BASE%\state" >nul 2>&1

echo =========================================================>>"%LOG%"
echo [%date% %time%] Inicio deploy GPO - %COMPUTERNAME%>>"%LOG%"

for %%F in (Collect-Inventory.ps1 Run-Inventory.ps1 Install-InventoryTask.ps1) do (
  if not exist "%~dp0%%F" (
    echo [ERRO] Arquivo ausente no SYSVOL: %%F>>"%LOG%"
    exit /b 10
  )
  copy /Y "%~dp0%%F" "%BASE%\%%F" >nul 2>&1
  if errorlevel 1 (
    echo [ERRO] Falha copiando %%F>>"%LOG%"
    exit /b 20
  )
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%BASE%\Install-InventoryTask.ps1" >>"%LOG%" 2>&1
if errorlevel 1 (
  echo [ERRO] Falha ao registrar tarefa.>>"%LOG%"
  exit /b 30
)
echo [%date% %time%] Deploy GPO concluido com sucesso.>>"%LOG%"
exit /b 0
