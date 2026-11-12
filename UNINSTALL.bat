@echo off
setlocal EnableExtensions
title BIM-MODE Connector - uninstall
cd /d "%~dp0"
set "REV=%~1"
if "%REV%"=="" set "REV=2026"

:checkrevit
tasklist /FI "IMAGENAME eq Revit.exe" 2>nul | find /I "Revit.exe" >nul
if not errorlevel 1 (
    echo  [!] Revit is running. CLOSE Revit first.
    choice /C RQ /N /M "      Press R to check again, or Q to quit: "
    if errorlevel 2 exit /b 1
    goto :checkrevit
)
echo  Removing BIM-MODE Connector from Revit %REV% ^(settings and token are kept^)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" -RevitVersion %REV%
echo.
echo  To also delete settings and the token, run in PowerShell:
echo     .\uninstall.ps1 -All
echo.
pause
