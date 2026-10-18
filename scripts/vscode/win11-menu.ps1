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
$packageName = 'Microsoft.VisualStudioCode'

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
if (!(Test-Path -LiteralPath (Join-Path $InstallDir 'Code.exe'))) {
    throw 'Code.exe was not found in the installation directory.'
}
$layout = & "$PSScriptRoot\prepare-win11-menu.ps1" -InstallDir $InstallDir
if ((Get-AuthenticodeSignature -LiteralPath $layout.LibraryPath).Status -ne 'Valid') {
    throw 'The context-menu library does not have a valid signature.'
}
Import-MenuRegistry (Join-Path $InstallDir 'install-win11-context.reg')
try {
    Get-AppxPackage -Name $packageName | Remove-AppxPackage -ErrorAction Stop
    Add-AppxPackage -Path $layout.PackagePath -ExternalLocation $layout.ExternalLocation -ErrorAction Stop
    $installed = Get-AppxPackage -Name $packageName
    if (!$installed -or $installed.Status -ne 'Ok') { throw 'Menu package registration did not complete successfully.' }
} catch {
    Import-MenuRegistry (Join-Path $InstallDir 'uninstall-win11-context.reg')
    throw
}
Write-Output 'Windows 11 Open with Code enabled for the current user. Reopen the menu; if needed, restart Windows Explorer.'
