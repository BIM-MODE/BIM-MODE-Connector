@echo off
cd /d "%~dp0"
set /p YEAR=Revit year (2021-2027): 
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -RevitVersion "%YEAR%"
pause
