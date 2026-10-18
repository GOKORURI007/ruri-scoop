#Requires -Version 5.1
param([Parameter(Mandatory = $true)][string] $InstallDir)
$ErrorActionPreference = 'Stop'
$sourceDir = Join-Path $InstallDir 'appx'
$packages = @(Get-ChildItem -LiteralPath $sourceDir -Filter 'code_*.appx')
if ($packages.Count -ne 1) { throw 'Expected one native VS Code context-menu package.' }
$package = $packages[0]
$arch = $package.BaseName.Substring('code_'.Length)
$dll = Join-Path $sourceDir "code_explorer_command_$arch.dll"
if (!(Test-Path -LiteralPath $dll)) { throw "Missing context-menu library: $dll" }
# Preserve the handler's required directory depth without a version-dependent name.
$externalDir = Join-Path $InstallDir 'shell\appx'
New-Item -ItemType Directory -Path $externalDir -Force | Out-Null
foreach ($source in @($package.FullName, $dll)) {
    $destination = Join-Path $externalDir (Split-Path $source -Leaf)
    # Explorer may have the DLL loaded. Do not overwrite identical content.
    if (!(Test-Path -LiteralPath $destination) -or
        (Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath $destination).Hash) {
        Copy-Item -LiteralPath $source -Destination $destination -Force
    }
}
[pscustomobject]@{
    ExternalLocation = $externalDir
    PackagePath = Join-Path $externalDir $package.Name
    LibraryPath = Join-Path $externalDir (Split-Path $dll -Leaf)
}
