@echo off
title Canvas Sync
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-sync.ps1"
echo.
echo Sincronizacao finalizada. Codigo: %ERRORLEVEL%
pause
