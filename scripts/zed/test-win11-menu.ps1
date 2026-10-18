#Requires -Version 5.1
# Offline regression checks: no real registry or Appx operations are performed.
$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('ruri-zed-test-' + [guid]::NewGuid())
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

[HKEY_CURRENT_USER\Software\Classes\ZedContextMenu]
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
    Assert ($ExternalLocation -like '*\appx') 'Wrong external location.'
    $global:RuriMenuTestState.Registered = $true
}

try {
    foreach ($arch in @('x64', 'arm64')) {
        foreach ($existing in @($false, $true)) {
            $global:RuriMenuTestState.ExistingKey = $existing
            $global:RuriMenuTestState.Registered = $false
            $global:RuriMenuTestState.FailRegistration = $false
            $fixture = Join-Path $testRoot "$arch-$existing"
            New-Item -ItemType Directory -Path "$fixture\appx" -Force | Out-Null
            foreach ($file in @('Zed.exe', 'appx\zed_explorer_command_injector.appx', 'appx\zed_explorer_command_injector.dll')) {
                New-Item -ItemType File -Path (Join-Path $fixture $file) | Out-Null
            }
            Copy-Item -LiteralPath "$PSScriptRoot\install-win11-context.reg" -Destination $fixture
            & "$PSScriptRoot\win11-menu.ps1" -Action Install -InstallDir $fixture
            $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
            $state = "$fixture\ruri-win11-menu\$sid"
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
            Assert ($global:RuriMenuTestState.LastImport.Contains('[-HKEY_CURRENT_USER\Software\Classes\ZedContextMenu]')) 'Failure did not roll back registry changes.'
        }
    }
    # Exercise the actual manifest hooks without launching a second PowerShell
    # process, which would escape the registry/Appx mocks above.
    $repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $manifest = Get-Content -LiteralPath "$repo\bucket\zed.json" -Raw | ConvertFrom-Json
    $bucketsdir = Split-Path $repo -Parent
    $bucket = Split-Path $repo -Leaf
    $dir = Join-Path $testRoot 'hook fixture with spaces'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $global = $false
    $global:RuriMenuTestState.HookCalls = @()
    function info { param($Message) }
    function Invoke-MenuHookProbe {
        $global:RuriMenuTestState.HookCalls += ($args -join ' ')
        $global:LASTEXITCODE = 0
    }
    $launcher = '& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"'
    $post = [scriptblock]::Create(($manifest.post_install -join "`n").Replace($launcher, 'Invoke-MenuHookProbe'))
    $uninstall = [scriptblock]::Create(($manifest.uninstaller.script -join "`n").Replace($launcher, 'Invoke-MenuHookProbe'))
    & $post
    Assert ($global:RuriMenuTestState.HookCalls.Count -eq 0) 'Fresh install unexpectedly enabled the menu.'
    foreach ($name in @('install-win11-context.reg', 'uninstall-win11-context.reg', 'install-win11-menu.ps1', 'uninstall-win11-menu.ps1', 'win11-menu.ps1')) {
        Assert (Test-Path -LiteralPath "$dir\$name") "Missing companion file: $name"
    }
    $state = "$dir\ruri-win11-menu\$sid"
    New-Item -ItemType Directory -Path $state -Force | Out-Null
    New-Item -ItemType File -Path "$state\enabled", "$state\uninstall-win11-context.reg" | Out-Null
    & $post
    Assert ($global:RuriMenuTestState.HookCalls.Count -eq 1) 'Upgrade did not re-register an enabled menu.'
    Assert ($global:RuriMenuTestState.HookCalls[0].Contains('install-win11-menu.ps1')) 'Wrong upgrade script.'
    $global = $true
    & $post
    Assert ($global:RuriMenuTestState.HookCalls.Count -eq 1) 'Global upgrade unexpectedly registered for the elevated user.'
    $cmd = 'update'
    & $uninstall
    Assert ($global:RuriMenuTestState.HookCalls.Count -eq 1) 'Update unexpectedly removed the menu.'
    $cmd = 'uninstall'
    & $uninstall
    Assert ($global:RuriMenuTestState.HookCalls.Count -eq 2) 'Uninstall did not clean up menu state.'
    Assert ($global:RuriMenuTestState.HookCalls[1].Contains('uninstall-win11-menu.ps1')) 'Wrong cleanup script.'
    Write-Output 'PASS: menu lifecycle, registry rollback, companion files, upgrade opt-in, global install guard, and uninstall hooks.'
} finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
        ([IO.Path]::GetFileName($resolved) -like 'ruri-zed-test-*')) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    Remove-Variable -Name RuriMenuTestState -Scope Global
}
