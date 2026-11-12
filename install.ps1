param([ValidateRange(2021,2027)][int]$RevitVersion = 2026, [switch]$NoPyRevitRoute)
$ErrorActionPreference = "Stop"
$dist = Join-Path $PSScriptRoot "dist/$RevitVersion"
if (-not (Test-Path "$dist/BIM-MODE/BimMode.Addin.dll")) { throw "Build Revit $RevitVersion first." }
foreach ($runtimeFile in 'BimMode.Python.dll','IronPython.dll','IronPython.Modules.dll','Microsoft.Scripting.dll','Microsoft.Dynamic.dll') {
 if (-not (Test-Path (Join-Path "$dist/BIM-MODE" $runtimeFile))) { throw "Incomplete integrated runtime: missing $runtimeFile. Build again before installing." }
}
$addins = Join-Path $env:APPDATA "Autodesk/Revit/Addins/$RevitVersion"
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
# One fixed folder: Revit trusts an add-in by its path, so a new folder per update would bring back the
# "Unsigned Add-In" security prompt every time. Only while Revit is running (files locked) is a dated folder used.
$folder = "BIM-MODE"
New-Item -ItemType Directory -Force $addins | Out-Null
$target = Join-Path $addins $folder
try {
  if (Test-Path $target) { Remove-Item $target -Recurse -Force -ErrorAction Stop }
  Copy-Item "$dist/BIM-MODE" $target -Recurse -ErrorAction Stop
} catch {
  $folder = "BIM-MODE-$stamp"
  Copy-Item "$dist/BIM-MODE" (Join-Path $addins $folder) -Recurse
  Write-Host "Revit is running, so this update went to $folder. Close Revit and run INSTALL again to use the fixed folder."
}
$manifestPath = Join-Path $addins 'BIM-MODE.addin'
if (Test-Path $manifestPath) { Copy-Item $manifestPath "$manifestPath.backup-$stamp" }
[xml]$manifest = Get-Content "$dist/BIM-MODE.addin"
$manifest.RevitAddIns.AddIn.Assembly = "$folder\BimMode.Addin.dll"
$manifest.Save($manifestPath)
# No pyRevit route is installed: execution is bundled in the Revit add-in.
# NoPyRevitRoute remains accepted for compatibility with existing install scripts.
$legacyRoot = [IO.Path]::GetFullPath((Join-Path $env:APPDATA 'pyRevit/Extensions'))
$legacyRoute = [IO.Path]::GetFullPath((Join-Path $legacyRoot 'BIM-MODE.extension'))
if ((Split-Path $legacyRoute -Parent) -ne $legacyRoot) { throw 'Unexpected legacy route path' }
if (Test-Path -LiteralPath $legacyRoute) {
 $backupRoot = [IO.Path]::GetFullPath((Join-Path $env:APPDATA 'BIM-MODE/legacy-route-backups'))
 New-Item -ItemType Directory -Force $backupRoot | Out-Null
 $backupPath = [IO.Path]::GetFullPath((Join-Path $backupRoot "BIM-MODE.extension-$stamp"))
 if ((Split-Path $backupPath -Parent) -ne $backupRoot) { throw 'Unexpected backup path' }
 Move-Item -LiteralPath $legacyRoute -Destination $backupPath
 Write-Host "Archived obsolete BIM-MODE pyRevit route to $backupPath."
}
Write-Host "Installed Revit $RevitVersion into $addins/$folder. Open a NEW Revit session to load it."
