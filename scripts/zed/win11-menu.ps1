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
$registryKey = 'HKEY_CURRENT_USER\Software\Classes\ZedContextMenu'
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$stateDir = Join-Path $InstallDir "ruri-win11-menu\$sid"
$enabledFile = Join-Path $stateDir 'enabled'
$rollbackFile = Join-Path $stateDir 'uninstall-win11-context.reg'

function Import-MenuRegistry([string] $Path) {
    & reg.exe import $Path
    if ($LASTEXITCODE -ne 0) { throw "Could not import registry file: $Path" }
}

if ($Action -eq 'Uninstall') {
    if (!(Test-Path -LiteralPath $rollbackFile)) {
        Write-Output 'No menu state managed by this bucket exists for the current user.'
        return
    }
    Get-AppxPackage -Name $packageName | Remove-AppxPackage -ErrorAction Stop
    Import-MenuRegistry $rollbackFile
    # Keep the rollback file available next to the install file for manual use.
    Copy-Item -LiteralPath $rollbackFile -Destination (Join-Path $InstallDir 'uninstall-win11-context.reg') -Force
    if (Test-Path -LiteralPath $enabledFile) { Remove-Item -LiteralPath $enabledFile }
    Remove-Item -LiteralPath $rollbackFile
    Write-Output 'Windows 11 menu registration removed; previous registry state restored.'
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

New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
if (!(Test-Path -LiteralPath $rollbackFile)) {
    $rollback = "Windows Registry Editor Version 5.00`r`n`r`n[-$registryKey]`r`n"
    if (Test-Path -LiteralPath "Registry::$registryKey") {
        $backup = Join-Path $stateDir 'previous-context.reg'
        & reg.exe export $registryKey $backup /y
        if ($LASTEXITCODE -ne 0) { throw 'Could not back up the existing menu registry key.' }
        $previous = Get-Content -LiteralPath $backup -Raw
        $rollback += ($previous -replace '^Windows Registry Editor Version 5\.00\s*', "`r`n")
    }
    $rollback | Set-Content -LiteralPath $rollbackFile -Encoding Unicode
}
Copy-Item -LiteralPath $rollbackFile -Destination (Join-Path $InstallDir 'uninstall-win11-context.reg') -Force
Import-MenuRegistry (Join-Path $InstallDir 'install-win11-context.reg')
try {
    Get-AppxPackage -Name $packageName | Remove-AppxPackage -ErrorAction Stop
    Add-AppxPackage -Path $packagePath -ExternalLocation $externalDir -ErrorAction Stop
    $installed = Get-AppxPackage -Name $packageName
    if (!$installed -or $installed.Status -ne 'Ok') { throw 'Menu package registration did not complete successfully.' }
    Set-Content -LiteralPath $enabledFile -Value $InstallDir -Encoding UTF8
} catch {
    Import-MenuRegistry $rollbackFile
    throw
}
Write-Output 'Windows 11 Open with Zed enabled for the current user. Reopen the menu; if needed, restart Windows Explorer.'
