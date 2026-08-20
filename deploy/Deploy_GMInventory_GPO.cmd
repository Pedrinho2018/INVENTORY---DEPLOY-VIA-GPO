@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "VERSION=8.2-GM"
set "BASE=C:\ProgramData\GMInventory"
set "LOG=%BASE%\logs\gpo-deploy.log"

if not exist "%BASE%" mkdir "%BASE%" >nul 2>&1
if not exist "%BASE%\logs" mkdir "%BASE%\logs" >nul 2>&1
if not exist "%BASE%\state" mkdir "%BASE%\state" >nul 2>&1

echo =========================================================>>"%LOG%"
echo [%date% %time%] Inicio deploy GPO %VERSION% - %COMPUTERNAME%>>"%LOG%"
echo Origem: %~dp0>>"%LOG%"

for %%F in (Collect-Inventory.ps1 Run-Inventory.ps1 Install-InventoryTask.ps1) do (
    if not exist "%~dp0%%F" (
        echo [%date% %time%] [ERRO] Arquivo ausente no SYSVOL: %%F>>"%LOG%"
        exit /b 10
    )

    if not exist "%BASE%\%%F" (
        copy /Y "%~dp0%%F" "%BASE%\%%F" >nul 2>&1
        if errorlevel 1 (
            echo [%date% %time%] [ERRO] Falha copiando %%F>>"%LOG%"
            exit /b 20
        )
        echo [%date% %time%] Instalado: %%F>>"%LOG%"
    ) else (
        fc /b "%~dp0%%F" "%BASE%\%%F" >nul 2>&1
        if errorlevel 1 (
            copy /Y "%~dp0%%F" "%BASE%\%%F" >nul 2>&1
            if errorlevel 1 (
                echo [%date% %time%] [ERRO] Falha atualizando %%F>>"%LOG%"
                exit /b 21
            )
            echo [%date% %time%] Atualizado: %%F>>"%LOG%"
        ) else (
            echo [%date% %time%] Sem alteracao: %%F>>"%LOG%"
        )
    )
)

powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%BASE%\Install-InventoryTask.ps1" >>"%LOG%" 2>&1
if errorlevel 1 (
    echo [%date% %time%] [ERRO] Falha ao registrar/atualizar tarefa.>>"%LOG%"
    exit /b 30
)

echo [%date% %time%] Deploy GPO %VERSION% concluido com sucesso.>>"%LOG%"
exit /b 0
