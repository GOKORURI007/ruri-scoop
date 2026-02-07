# 删除 $persist_dir 目录
Write-Host "" -ForegroundColor Blue
Write-Host "Delete $persist_dir" -ForegroundColor Blue
Remove-Item -Path $persist_dir -Recurse -Force