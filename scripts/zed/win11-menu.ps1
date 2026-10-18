#Requires -Version 5.1
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateSet('Install', 'Uninstall')]
    [string] $Action,
    [Parameter(Mandatory = $true)]
    [string] $InstallDir
)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') {
    throw 'Run this script with Windows PowerShell (powershell.exe), not pwsh.exe.'
}
$packageName = 'ZedIndustries.Zed'

function Import-MenuRegistry([string] $Path) {
    & reg.exe import $Path
    if ($LASTEXITCODE -ne 0) { throw "Could not import registry file: $Path" }
}

if ($Action -eq 'Uninstall') {
    Get-AppxPackage -Name $packageName | Remove-AppxPackage -ErrorAction Stop
    Import-MenuRegistry (Join-Path $InstallDir 'uninstall-win11-context.reg')
    Write-Output 'Windows 11 menu package and registry entry removed.'
    return
}

if ([Environment]::OSVersion.Version.Build -lt 22000) {
    throw 'The modern context menu requires Windows 11 (build 22000 or newer).'
}
if (!(Test-Path -LiteralPath (Join-Path $InstallDir 'Zed.exe'))) {
    throw 'Zed.exe was not found in the installation directory.'
}
# Zed resolves its executable relative to the root appx directory.
$externalDir = Join-Path $InstallDir 'appx'
$packagePath = Join-Path $externalDir 'zed_explorer_command_injector.appx'
$dll = Join-Path $externalDir 'zed_explorer_command_injector.dll'
foreach ($path in @($packagePath, $dll)) {
    if (!(Test-Path -LiteralPath $path)) { throw "Missing context-menu component: $path" }
}
if ((Get-AuthenticodeSignature -LiteralPath $dll).Status -ne 'Valid') {
    throw 'The context-menu library does not have a valid signature.'
}

Import-MenuRegistry (Join-Path $InstallDir 'install-win11-context.reg')
try {
    Get-AppxPackage -Name $packageName | Remove-AppxPackage -ErrorAction Stop
    Add-AppxPackage -Path $packagePath -ExternalLocation $externalDir -ErrorAction Stop
    $installed = Get-AppxPackage -Name $packageName
    if (!$installed -or $installed.Status -ne 'Ok') { throw 'Menu package registration did not complete successfully.' }
} catch {
    Import-MenuRegistry (Join-Path $InstallDir 'uninstall-win11-context.reg')
    throw
}
Write-Output 'Windows 11 Open with Zed enabled for the current user. Reopen the menu; if needed, restart Windows Explorer.'
