#Requires -Version 5.1
param([ValidateSet('vscode', 'zed')][string] $App)
# All registry and Appx calls are mocked; this test never changes Windows settings.
$ErrorActionPreference = 'Stop'
$menuDir = Join-Path $PSScriptRoot $App
$repo = Split-Path $PSScriptRoot -Parent
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('ruri-menu-test-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $testRoot | Out-Null
$global:RuriMenuTestState = @{}
function Assert($Condition, [string] $Message) { if (!$Condition) { throw $Message } }
function reg.exe {
    if ($args[0] -ne 'import') { throw 'Registry export/backup is no longer allowed.' }
    $global:RuriMenuTestState.LastImport = Get-Content -LiteralPath $args[1] -Raw
    $global:LASTEXITCODE = 0
}
function reg { reg.exe @args }
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
    Assert (Test-Path -LiteralPath $Path) 'Package missing at registration path.'
    Assert ($ExternalLocation -eq $global:RuriMenuTestState.ExpectedLocation) 'Wrong registration directory.'
    $global:RuriMenuTestState.Registered = $true
}
try {
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    foreach ($arch in @('x64', 'arm64')) {
        $fixture = Join-Path $testRoot $arch
        New-Item -ItemType Directory -Path "$fixture\appx" -Force | Out-Null
        $files = if ($App -eq 'vscode') {
            New-Item -ItemType Directory -Path "$fixture\abcdef1234\resources\app" -Force | Out-Null
            $global:RuriMenuTestState.ExpectedLocation = "$fixture\shell\appx"
            @('Code.exe', "appx\code_$arch.appx", "appx\code_explorer_command_$arch.dll", 'abcdef1234\resources\app\product.json')
        } else {
            $global:RuriMenuTestState.ExpectedLocation = "$fixture\appx"
            @('Zed.exe', 'appx\zed_explorer_command_injector.appx', 'appx\zed_explorer_command_injector.dll')
        }
        foreach ($file in $files) { New-Item -ItemType File -Path (Join-Path $fixture $file) | Out-Null }
        Copy-Item -LiteralPath "$menuDir\install-win11-context.reg", "$menuDir\uninstall-win11-context.reg" -Destination $fixture
        $deleteReg = Get-Content -LiteralPath "$fixture\uninstall-win11-context.reg" -Raw
        $global:RuriMenuTestState.Registered = $false
        $global:RuriMenuTestState.FailRegistration = $false
        & "$menuDir\win11-menu.ps1" -Action Install -InstallDir $fixture
        & "$menuDir\win11-menu.ps1" -Action Install -InstallDir $fixture
        Assert $global:RuriMenuTestState.Registered 'Menu was not registered.'
        Assert ((Get-Content "$fixture\uninstall-win11-context.reg" -Raw) -eq $deleteReg) 'Static uninstall registry was overwritten.'
        Assert (!(Test-Path "$fixture\data\ruri-win11-menu")) 'VS Code created persistent menu state.'
        Assert (!(Test-Path "$fixture\ruri-win11-menu")) 'Zed created persistent menu state.'
        & "$menuDir\win11-menu.ps1" -Action Uninstall -InstallDir $fixture
        & "$menuDir\win11-menu.ps1" -Action Uninstall -InstallDir $fixture
        Assert (!$global:RuriMenuTestState.Registered) 'Package was not removed.'
        Assert ($global:RuriMenuTestState.LastImport -eq $deleteReg) 'Uninstall did not delete the menu key.'
        $global:RuriMenuTestState.FailRegistration = $true
        $failed = $false
        try { & "$menuDir\win11-menu.ps1" -Action Install -InstallDir $fixture } catch { $failed = $true }
        Assert $failed 'Registration error was swallowed.'
        Assert ($global:RuriMenuTestState.LastImport -eq $deleteReg) 'Failed registration did not clean up the menu key.'
    }

    $manifest = Get-Content "$repo\bucket\$App.json" -Raw | ConvertFrom-Json
    $bucketsdir = Split-Path $repo -Parent
    $bucket = Split-Path $repo -Leaf
    $dir = Join-Path $testRoot 'hook fixture with spaces'
    New-Item -ItemType Directory -Path "$dir\data\extensions", "$dir\data\user-data" -Force | Out-Null
    if ($App -eq 'vscode') {
        New-Item -ItemType Directory -Path "$dir\appx" -Force | Out-Null
        New-Item -ItemType File -Path "$dir\appx\code_x64.appx", "$dir\appx\code_explorer_command_x64.dll" | Out-Null
    }
    $global = $false
    $global:RuriMenuTestState.HookCalls = @()
    function info { param($Message) }
    function Get-ItemPropertyValue { param($Path, $Name, $ErrorAction) return $null }
    function Invoke-MenuHookProbe {
        $global:RuriMenuTestState.HookCalls += ($args -join ' ')
        $global:LASTEXITCODE = 0
    }
    $launcher = '& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"'
    $post = [scriptblock]::Create(($manifest.post_install -join "`n").Replace($launcher, 'Invoke-MenuHookProbe'))
    $uninstall = [scriptblock]::Create(($manifest.uninstaller.script -join "`n").Replace($launcher, 'Invoke-MenuHookProbe'))
    & $post
    Assert ($global:RuriMenuTestState.HookCalls.Count -eq 0) 'Fresh installation unexpectedly registered a menu.'
    if ($App -eq 'zed') { Assert (!$manifest.persist) 'Zed manifest still declares menu persistence.' }
    & $post
    if ($App -eq 'vscode') {
        Assert (Test-Path "$dir\shell\appx\code_explorer_command_x64.dll") 'Upgrade did not prepare the fixed extension directory.'
        Set-Content "$dir\appx\code_explorer_command_x64.dll" 'new extension version'
        & $post
        Assert ((Get-FileHash "$dir\appx\code_explorer_command_x64.dll").Hash -eq (Get-FileHash "$dir\shell\appx\code_explorer_command_x64.dll").Hash) 'Upgrade did not refresh extension contents.'
    }
    $expected = 0
    Assert ($global:RuriMenuTestState.HookCalls.Count -eq $expected) 'Incorrect upgrade registration behavior.'
    $global = $true
    & $post
    Assert ($global:RuriMenuTestState.HookCalls.Count -eq $expected) 'Global upgrade unexpectedly registered a menu.'
    $cmd = 'update'
    & $uninstall
    Assert ($global:RuriMenuTestState.HookCalls.Count -eq $expected) 'Update removed the menu.'
    $cmd = 'uninstall'
    & $uninstall
    Assert ($global:RuriMenuTestState.HookCalls.Count -eq ($expected + 1)) 'Application uninstall did not remove the menu.'
    Write-Output "PASS: $App registration, removal, failure cleanup, persistence and upgrade/uninstall hooks."
} finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($resolved.StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -and
        ([IO.Path]::GetFileName($resolved) -like 'ruri-menu-test-*')) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    Remove-Variable -Name RuriMenuTestState -Scope Global
}
