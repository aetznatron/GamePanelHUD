# Building GamePanelHUD against a local SPT installation

The projects are legacy (non-SDK) .NET Framework 4.7.2 class libraries compiled
against the managed assemblies of the game client and BepInEx, plus the
`KmyTarkovApi` framework. None of those binaries are shipped with this repository.

## Requirements

* Windows with MSBuild (Visual Studio 2022 Build Tools, workload
  `.NET desktop build tools`, plus the .NET Framework 4.7.2 targeting pack)
* SPT installation with BepInEx 5 (client 0.16.9.x / SPT 4.1.x is what the
  current sources target)
* A built `KmyTarkovApi` checkout next to this repository

## Path configuration

`Directory.Build.props` holds both path knobs:

```xml
<SPTGamePath>D:\Games\SPT 4.1.6 essential</SPTGamePath>
<SptManagedDir>$(SPTGamePath)\EscapeFromTarkov_Data\Managed</SptManagedDir>
<SptBepInExCoreDir>$(SPTGamePath)\BepInEx\core</SptBepInExCoreDir>

<KmyTarkovApiBuildDir>..\..\KmyTarkovApi\Build\bin\Current</KmyTarkovApiBuildDir>
```

Override either per build:

```
msbuild GamePanelHUD.sln /p:SPTGamePath="D:\Games\SPT 4.1.6 essential" `
                        /p:KmyTarkovApiBuildDir="D:\build\KmyTarkovApi\Build\bin\Current"
```

`KmyTarkovApiBuildDir` must contain `KmyTarkovApi.dll`, `KmyTarkovReflection.dll`
and `KmyTarkovUtils.dll`.

## Signing

The strong-name key `kmyuhkyuk.pfx` is not part of the repository. When it is
missing next to a project file, `Directory.Build.targets` sets
`SignAssembly=false`, so unsigned builds work out of the box.

## Build

```
powershell -ExecutionPolicy Bypass -File build-spt.ps1
```

Optional: `-SptGamePath "D:\…"`, `-KmyTarkovApiBuildDir "…"`,
`-BundlesDir "<release>\BepInEx\plugins\kmyuhkyuk-GamePanelHUD\bundles"`,
`-SkipDeploy`.

Only the shipped modules are built: `GamePanelHUDCore` plus Compass, Grenade,
Health, Hit, Kill and Weapon. `GamePanelHUDMap` and `GamePanelHUDDebug` still
reference `GamePanelHUDCorePlugin.HUDCoreClass` / `HUDClass<>`, which were removed
with the EFTApi → KmyTarkovApi migration, and they are not part of any release
archive either — treat them as dead code.

`Build/Build.csproj` is the author's release packer (7-Zip, LibGit2Sharp,
hardcoded paths); `build-spt.ps1` replaces it for local builds.

## AssetBundles

The HUD prefabs live in `bundles\gamepanel*hud.bundle`, loaded from
`BepInEx\plugins\kmyuhkyuk-GamePanelHUD\bundles\`. They are Unity Editor
artifacts, are not in the repository, and cannot be generated from it: take them
from an official release archive (`BepInEx/plugins/kmyuhkyuk-GamePanelHUD/bundles/`).
Without them `HUDCoreModel.LoadHUD` fails and no HUD element appears.

## Installing

```
BepInEx\plugins\kmyuhkyuk-GamePanelHUD\
├── GamePanelHUDCompass.dll, …Grenade, …Health, …Hit, …Kill, …Weapon
├── core\GamePanelHUDCore.dll          (own BepInEx plugin, loaded from the subfolder)
├── bundles\gamepanel*hud.bundle
└── localized\<module>\en.json, zh.json
```

`KmyTarkovApi` (2.0.0) must be installed as well — `GamePanelHUDCore` declares a
`BepInDependency` on it.
