@echo off
title Gerenciador ERP
cd /d "%~dp0"
echo Iniciando Gerenciador ERP...
powershell -ExecutionPolicy Bypass -File "%~dp0gerenciador-erp.ps1"
pause
