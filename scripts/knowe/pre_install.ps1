# 创建包含 $PLUGINSDIR 的目录（必须转义 $）
New-Item -ItemType Directory -Force "$dir\_nsis\`$PLUGINSDIR" -ErrorAction SilentlyContinue | Out-Null

# 静默解压 setup.exe（重定向所有输出到 null）
& 7z x "$dir\setup.exe" "-o$dir\_nsis" -tNsis -y | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Extract setup.exe failed" }

# 静默解压 app-64.7z
& 7z x "$dir\_nsis\`$PLUGINSDIR\app-64.7z" "-o$dir" -y | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Extract app-64.7z failed" }

# 清理临时文件
Remove-Item "$dir\_nsis", "$dir\setup.exe" -Recurse -Force
