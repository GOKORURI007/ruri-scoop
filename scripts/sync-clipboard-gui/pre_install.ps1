$config_path = "$persist_dir\settings\config.json"
Write-Host "" -ForegroundColor Blue
Write-Host "config_path set as $config_path" -ForegroundColor Blue
Write-Host "Create $dir\sync-clipboard-gui.cmd" -ForegroundColor Blue

$content = @"
@echo off
set "SCRIPT_DIR=%~dp0"
set "CONFIG_PATH=$config_path"
start "" "%SCRIPT_DIR%sync-clipboard-gui-windows.exe" --config "%CONFIG_PATH%"
"@
$content | Set-Content -Path "$dir\sync-clipboard-gui.cmd" -Encoding ASCII
