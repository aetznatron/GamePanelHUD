<#
.SYNOPSIS
    Builds GamePanelHUD against a local SPT installation and installs the HUD modules.

.DESCRIPTION
    Compiles the shipped modules (core + six HUD modules), then copies them into
    BepInEx\plugins\kmyuhkyuk-GamePanelHUD in the layout the release uses
    (modules in the plugin root, the core plugin in its own core\ folder).

.PARAMETER SptGamePath
    Root folder of the SPT installation (the one containing EscapeFromTarkov.exe).

.PARAMETER KmyTarkovApiBuildDir
    Folder containing KmyTarkovApi.dll, KmyTarkovReflection.dll and
    KmyTarkovUtils.dll. Defaults to the sibling checkout's Build\bin\Current.

.PARAMETER BundlesDir
    Folder with the Unity AssetBundles (gamepanel*hud.bundle). They are not part
    of the repository - see BUILDING.md.

.PARAMETER SkipDeploy
    Only build, do not copy anything into the game folder.
#>
[CmdletBinding()]
param(
    [string]$SptGamePath = 'D:\Games\SPT 4.1.6 essential',
    [string]$KmyTarkovApiBuildDir,
    [string]$BundlesDir,
    [string]$Configuration = 'Release',
    [switch]$SkipDeploy
)

$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
if (-not $KmyTarkovApiBuildDir) {
    $KmyTarkovApiBuildDir = Join-Path (Split-Path $repo -Parent) 'KmyTarkovApi\Build\bin\Current'
}

function Find-MSBuild {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $path = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' 2>$null | Select-Object -First 1
        if ($path) { return $path }
    }
    foreach ($c in @(
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe")) {
        if (Test-Path $c) { return $c }
    }
    throw 'MSBuild.exe not found. Install Visual Studio 2022 Build Tools with the ".NET desktop build tools" workload.'
}

if (-not (Test-Path (Join-Path $SptGamePath 'EscapeFromTarkov.exe'))) {
    throw "No SPT installation found at '$SptGamePath' (EscapeFromTarkov.exe missing)."
}
foreach ($n in 'KmyTarkovApi','KmyTarkovReflection','KmyTarkovUtils') {
    if (-not (Test-Path (Join-Path $KmyTarkovApiBuildDir "$n.dll"))) {
        throw "Missing $n.dll in '$KmyTarkovApiBuildDir'. Build KmyTarkovApi first, or pass -KmyTarkovApiBuildDir."
    }
}

$msbuild = Find-MSBuild
Write-Host "MSBuild  : $msbuild"
Write-Host "SPT path : $SptGamePath"
Write-Host "KmyApi   : $KmyTarkovApiBuildDir"

# GamePanelHUDMap and GamePanelHUDDebug are not built: they still reference the
# removed GamePanelHUDCorePlugin.HUDCoreClass / HUDClass<> types and are not part
# of any release archive.
$order = @('GamePanelHUDCore','GamePanelHUDCompass','GamePanelHUDGrenade','GamePanelHUDHealth','GamePanelHUDHit','GamePanelHUDKill','GamePanelHUDWeapon')
foreach ($name in $order) {
    Write-Host "=== $name ==="
    & $msbuild (Join-Path $repo "$name\$name.csproj") "/p:Configuration=$Configuration" /p:Platform=AnyCPU "/p:SPTGamePath=$SptGamePath" "/p:KmyTarkovApiBuildDir=$KmyTarkovApiBuildDir" /v:minimal /nologo /m
    if ($LASTEXITCODE -ne 0) { throw "Build failed for $name" }
}

if ($SkipDeploy) { Write-Host 'Built, deployment skipped.'; return }

$mod = Join-Path $SptGamePath 'BepInEx\plugins\kmyuhkyuk-GamePanelHUD'
New-Item -ItemType Directory -Force -Path $mod, (Join-Path $mod 'core'), (Join-Path $mod 'localized') | Out-Null

Copy-Item (Join-Path $repo "GamePanelHUDCore\bin\$Configuration\GamePanelHUDCore.dll") (Join-Path $mod 'core\GamePanelHUDCore.dll') -Force
foreach ($name in 'GamePanelHUDCompass','GamePanelHUDGrenade','GamePanelHUDHealth','GamePanelHUDHit','GamePanelHUDKill','GamePanelHUDWeapon') {
    Copy-Item (Join-Path $repo "$name\bin\$Configuration\$name.dll") (Join-Path $mod "$name.dll") -Force
}
Copy-Item (Join-Path $repo 'Build\localized\*') (Join-Path $mod 'localized\') -Recurse -Force

if ($BundlesDir -and (Test-Path $BundlesDir)) {
    New-Item -ItemType Directory -Force -Path (Join-Path $mod 'bundles') | Out-Null
    Copy-Item (Join-Path $BundlesDir '*.bundle') (Join-Path $mod 'bundles\') -Force
}
if (-not (Test-Path (Join-Path $mod 'bundles'))) {
    Write-Warning 'No bundles\ folder - the HUD cannot load its prefabs. Copy the *.bundle files from an official release archive, see BUILDING.md.'
}

Write-Host ''
Write-Host "Installed to: $mod"
Get-ChildItem $mod -Recurse -File | Select-Object @{n='file';e={$_.FullName.Substring($mod.Length)}},Length | Format-Table -AutoSize
