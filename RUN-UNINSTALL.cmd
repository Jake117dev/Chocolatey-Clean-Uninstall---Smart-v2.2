@echo off
title Chocolatey Smart Uninstall (Live)
fltmc >nul 2>&1 || (powershell -c "Start-Process -Verb RunAs -FilePath '%~f0'" & exit /b)
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Unblock-File .\Uninstall-Chocolatey-Smart-v2.2.ps1; ^
   & .\Uninstall-Chocolatey-Smart-v2.2.ps1"
endlocal
pause
