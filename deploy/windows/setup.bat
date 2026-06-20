@echo off
title Gerenciador ERP - Setup Windows
cd /d "%~dp0"

echo ============================================
echo  Gerenciador ERP - Instalacao Windows
echo  Execute como ADMINISTRADOR
echo ============================================
echo.

REM Verificar Chocolatey
where choco >nul 2>nul
if %errorlevel% neq 0 (
    echo [1/4] Instalando Chocolatey...
    @"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "[System.Net.ServicePointManager]::SecurityProtocol = 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))" && SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
) else (
    echo [1/4] Chocolatey ja instalado.
)

echo [2/4] Instalando Ruby...
choco install ruby -y

echo [3/4] Instalando PostgreSQL...
choco install postgresql16 -y

echo [4/4] Configurando projeto...
echo.
echo O PowerShell vai baixar o repositorio e instalar as gems.
echo Clique OK na proxima janela.
echo.
pause

powershell -ExecutionPolicy Bypass -File "%~dp0gerenciador-erp.ps1"

echo.
echo ============================================
echo  Instalacao concluida!
echo ============================================
echo.
echo Proximos passos:
echo 1. Edite o arquivo .env (em C:\Program Files\GerenciadorERP\repo\.env)
echo 2. Execute novamente o start.bat para iniciar
echo.
pause
