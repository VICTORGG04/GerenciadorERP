@echo off
title ERP Gerenciador de Estoque
cd /d "%~dp0"

echo.
echo  ==========================================
echo   ERP Gerenciador de Estoque
echo  ==========================================
echo.
echo  Iniciando servidor...
echo.

start "" http://localhost:4567
bundle exec ruby app.rb

pause
