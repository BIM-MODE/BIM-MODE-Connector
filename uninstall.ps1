<#  BIM-MODE Connector - uninstall. Close Revit first. Settings/logs are kept unless -All. #>
param([string]$RevitVersion = "2026", [switch]$All)
$addins = Join-Path $env:APPDATA "Autodesk\Revit\Addins\$RevitVersion"
Remove-Item "$addins\BIM-MODE.addin" -ErrorAction SilentlyContinue
Remove-Item "$addins\BIM-MODE" -Recurse -Force -ErrorAction SilentlyContinue
# folders and manifest backups that install.ps1 creates when it updates while Revit is running
Get-ChildItem $addins -Directory -Filter "BIM-MODE-*" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem $addins -File -Filter "BIM-MODE.addin.backup-*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $env:APPDATA "pyRevit\Extensions\BIM-MODE.extension") -Recurse -Force -ErrorAction SilentlyContinue
if ($All) {
    Remove-Item (Join-Path $env:APPDATA "BIM-MODE") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $env:LOCALAPPDATA "BIM-MODE") -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "Removed. AI app entries named 'bim-mode' can be removed from the Connect window before uninstalling, or by hand."
