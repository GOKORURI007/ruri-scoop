# 仓库协作要求

## Manifest 的本地测试

- 新增或修改 `bucket/*.json` 后，必须在本地运行仓库测试，修复失败项后才能提交、推送或报告完成；不得只等待 GitHub Actions 验证。
- 在仓库根目录分别使用 Windows PowerShell 和 PowerShell 7 运行：

  ```powershell
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bin\test.ps1
  pwsh -NoProfile -File .\bin\test.ps1
  ```

- 测试依赖本地 Scoop、BuildHelpers 和 Pester。版本须满足 `bin/test.ps1` 以及当前 Scoop 的 `test/Import-Bucket-Tests.ps1` 中的 `#Requires` 要求；当前 Scoop 要求 Pester 6.0.0 或更高版本。缺少依赖时先安装，再运行测试。
- 必须确认测试实际执行并通过，不能仅以命令退出码为零判断成功。依赖缺失、测试发现失败或未执行测试均不算通过；无法运行时明确报告阻碍，不能宣称验证完成。
- `scoop info`、JSON/schema 校验、哈希校验和 `checkver` 只能作为补充，不能替代上述仓库测试。仓库测试同时检查文件末尾换行、行尾空格等格式问题。
- 新增或修改解压、安装脚本时，还须在隔离的临时目录实际验证解压或安装逻辑，确认主程序、快捷方式目标和必要资源存在，且中间文件已清理。
- 最终说明中列出执行过的测试及结果。所有新增或修改的文本文件须保留末尾换行，不含行尾空格，并遵守 `.editorconfig` 和 `.gitattributes`。
