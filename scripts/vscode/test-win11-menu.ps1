#Requires -Version 5.1
# Offline regression checks: no real registry or Appx operations are performed.
$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('ruri-vscode-test-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $testRoot | Out-Null
$global:RuriMenuTestState = @{}
function Assert($Condition, [string] $Message) {
    if (!$Condition) { throw $Message }
}
function Test-Path {
    param([string] $LiteralPath)
    if ($LiteralPath -like 'Registry::*') { return $global:RuriMenuTestState.ExistingKey }
    Microsoft.PowerShell.Management\Test-Path -LiteralPath $LiteralPath
}
function reg.exe {
    if ($args[0] -eq 'export') {
        @'
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Classes\VSCodeContextMenu]
"Title"="Previous title"
'@ | Set-Content -LiteralPath $args[2] -Encoding Unicode
    } elseif ($args[0] -eq 'import') {
        $global:RuriMenuTestState.LastImport = Get-Content -LiteralPath $args[1] -Raw
    } else { throw 'Unexpected registry operation' }
    $global:LASTEXITCODE = 0
}
function Get-AuthenticodeSignature { param($LiteralPath) [pscustomobject]@{ Status = 'Valid' } }
function Get-AppxPackage {
    param($Name)
    if ($global:RuriMenuTestState.Registered) { [pscustomobject]@{ Name = $Name; Status = 'Ok' } }
}
function Remove-AppxPackage {
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $true)] $Package)
    process { $global:RuriMenuTestState.Registered = $false }
}
function Add-AppxPackage {
    [CmdletBinding()]
    param($Path, $ExternalLocation)
    if ($global:RuriMenuTestState.FailRegistration) { throw 'Simulated registration failure' }
    Assert (Test-Path -LiteralPath $Path) 'Package was not copied to the registration location.'
    Assert ($ExternalLocation -like '*\abcdef1234\appx') 'Wrong external location.'
    $global:RuriMenuTestState.Registered = $true
}

try {
    foreach ($arch in @('x64', 'arm64')) {
        foreach ($existing in @($false, $true)) {
            $global:RuriMenuTestState.ExistingKey = $existing
            $global:RuriMenuTestState.Registered = $false
            $global:RuriMenuTestState.FailRegistration = $false
            $fixture = Join-Path $testRoot "$arch-$existing"
            New-Item -ItemType Directory -Path "$fixture\appx", "$fixture\abcdef1234\resources\app" -Force | Out-Null
            foreach ($file in @('Code.exe', "appx\code_$arch.appx", "appx\code_explorer_command_$arch.dll", 'abcdef1234\resources\app\product.json')) {
                New-Item -ItemType File -Path (Join-Path $fixture $file) | Out-Null
            }
            Copy-Item -LiteralPath "$PSScriptRoot\install-win11-context.reg" -Destination $fixture
            & "$PSScriptRoot\win11-menu.ps1" -Action Install -InstallDir $fixture
            $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
            $state = "$fixture\data\ruri-win11-menu\$sid"
            Assert (Test-Path -LiteralPath "$state\enabled") 'Enable marker was not written.'
            $rollback = Get-Content -LiteralPath "$fixture\uninstall-win11-context.reg" -Raw
            Assert ($rollback.Contains('Previous title') -eq $existing) 'Previous registry state was not preserved.'
            & "$PSScriptRoot\win11-menu.ps1" -Action Install -InstallDir $fixture
            Assert ((Get-Content -LiteralPath "$fixture\uninstall-win11-context.reg" -Raw) -eq $rollback) 'Upgrade changed the original rollback file.'
            & "$PSScriptRoot\win11-menu.ps1" -Action Uninstall -InstallDir $fixture
            Assert (!$global:RuriMenuTestState.Registered) 'Package was not unregistered.'
            Assert (!(Test-Path -LiteralPath "$state\enabled")) 'Enable marker was not removed.'
            Assert ($global:RuriMenuTestState.LastImport -eq $rollback) 'Uninstall did not restore the previous registry state.'
            & "$PSScriptRoot\win11-menu.ps1" -Action Uninstall -InstallDir $fixture

            $global:RuriMenuTestState.FailRegistration = $true
            $failed = $false
            try { & "$PSScriptRoot\win11-menu.ps1" -Action Install -InstallDir $fixture } catch { $failed = $true }
            Assert $failed 'Registration failure was swallowed.'
            Assert (!(Test-Path -LiteralPath "$state\enabled")) 'A failed installation was marked enabled.'
            Assert ($global:RuriMenuTestState.LastImport.Contains('[-HKEY_CURRENT_USER\Software\Classes\VSCodeContextMenu]')) 'Failure did not roll back registry changes.'
        }
    }
    Write-Output 'PASS: x64/ARM64 install, upgrade, uninstall, registry preservation, and registration failure rollback.'
} finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
        ([IO.Path]::GetFileName($resolved) -like 'ruri-vscode-test-*')) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    Remove-Variable -Name RuriMenuTestState -Scope Global
}
