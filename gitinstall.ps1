<#
  BIM-MODE Connector - GitHub installer (gitinstall).
  Usage:
    powershell -NoProfile -ExecutionPolicy Bypass -File gitinstall.ps1 -RevitVersion 2026
  Or one-line from GitHub:
    irm https://raw.githubusercontent.com/BIM-MODE/BIM-MODE-Connector/main/gitinstall.ps1 | iex
#>
param(
    [ValidateRange(2021, 2027)][int]$RevitVersion = 0,
    [string]$Repo = "BIM-MODE/BIM-MODE-Connector",
    [string]$Tag = ""
)

$ErrorActionPreference = "Stop"

if ($RevitVersion -eq 0) {
    $entered = Read-Host "Revit year (2021-2027) [2026]"
    if ([string]::IsNullOrWhiteSpace($entered)) { $RevitVersion = 2026 }
    else { $RevitVersion = [int]$entered }
}
if ($RevitVersion -lt 2021 -or $RevitVersion -gt 2027) {
    throw "Unsupported Revit version: $RevitVersion. Supported range: 2021-2027."
}

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$localAddin = Join-Path $scriptRoot "dist\$RevitVersion\BIM-MODE\BimMode.Addin.dll"
$localInstaller = Join-Path $scriptRoot "install.ps1"

if ((Test-Path $localAddin) -and (Test-Path $localInstaller)) {
    Write-Host "Installing BIM-MODE Connector for Revit $RevitVersion from local files..." -ForegroundColor Cyan
    & $localInstaller -RevitVersion $RevitVersion
    exit $LASTEXITCODE
}

$apiUrl = if ($Tag) {
    "https://api.github.com/repos/$Repo/releases/tags/$Tag"
} else {
    "https://api.github.com/repos/$Repo/releases/latest"
}

Write-Host "Checking GitHub Releases ($Repo)..." -ForegroundColor Cyan
$headers = @{ "User-Agent" = "BIM-MODE-gitinstall"; "Accept" = "application/vnd.github+json" }
try {
    $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -UseBasicParsing
} catch {
    throw "No release found at https://github.com/$Repo/releases ($($_.Exception.Message))."
}

$asset = $release.assets | Where-Object { $_.name -match '^BIM-MODE-Revit.*\.zip$' } | Select-Object -First 1
if (-not $asset) {
    throw "Release '$($release.tag_name)' does not contain a BIM-MODE-Revit*.zip asset."
}

$stage = Join-Path $env:TEMP ("bimmode-gitinstall-" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
$zipPath = Join-Path $stage $asset.name
$extractDir = Join-Path $stage "pkg"
New-Item -ItemType Directory -Force -Path $extractDir | Out-Null

try {
    Write-Host "Downloading $($asset.name) ($($release.tag_name))..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -Headers $headers -UseBasicParsing
    Write-Host "Extracting package..." -ForegroundColor Cyan
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

    $installer = Get-ChildItem -Path $extractDir -Filter "install.ps1" -Recurse | Select-Object -First 1
    if (-not $installer) {
        throw "install.ps1 was not found inside $($asset.name)."
    }
    & powershell -NoProfile -ExecutionPolicy Bypass -File $installer.FullName -RevitVersion $RevitVersion
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
    Remove-Item -Path $stage -Recurse -Force -ErrorAction SilentlyContinue
}
