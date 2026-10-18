# Ruri Scoop Bucket

[![Tests](https://github.com/GOKORURI007/ruri-scoop/actions/workflows/ci.yml/badge.svg)](https://github.com/GOKORURI007/ruri-scoop/actions/workflows/ci.yml)

我的个人 Scoop bucket，用于 Windows 命令行包管理。

## 已收录的应用

<!-- APPS_TABLE_START -->
| 应用 | 描述 |
|------|------|
| capptivo | Free and open-source screen recorder and editor with smart follow-cursor zoom, click-based auto zooms, editor presets, and on-device captions. |
| Knowe | Knowe - AI multi-agent group chat application |
| lan-mouse-latest | A software KVM switch for sharing mouse and keyboard between multiple computers over the network. |
| openless-no-ime | An open-source, privacy-focused voice-input application |
| sync-clipboard-gui | Synchronizing the clipboard between different OS. (GUI version) |
| sync-clipboard | Synchronizing the clipboard between different OS. |
| vscode | Lightweight but powerful source code editor |
| zed | High-performance, multiplayer code editor with Windows 11 context menu integration. |
<!-- APPS_TABLE_END -->

## 安装

```pwsh
scoop bucket add ruri-scoop https://github.com/GOKORURI007/ruri-scoop
scoop install ruri-scoop/<app-name>
```

## VS Code 与 Windows 11 右键菜单

`vscode` 基于 `ScoopInstaller/Extras` 的 manifest，保留 x64 / ARM64 下载、自动更新、便携数据及文件关联功能，配套脚本位于本 bucket 的 `scripts/vscode`，无需安装 extras bucket。

```powershell
scoop install ruri-scoop/vscode
$codeDir = scoop prefix vscode
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$codeDir\install-win11-menu.ps1"
```

在普通、非管理员终端运行菜单脚本。脚本注册 VS Code 自带的微软签名扩展，将其放到正确的版本资源目录下，并启用当前用户的 `VSCodeContextMenu` 注册表项，使文件、文件夹及文件夹空白处的 **Open with Code** 出现在 Win11 一级菜单。首次安装应用不会自动启用菜单；用户启用后，普通 Scoop 安装在升级时自动重新注册。

撤销一级菜单：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$codeDir\uninstall-win11-menu.ps1"
```

安装目录保留 `install-win11-context.reg` 和 `uninstall-win11-context.reg`。首次启用时备份已有注册表项，生成可恢复原状态的 uninstall 文件；升级保留备份。`.reg` 只控制标题和显示开关，完整安装/撤销必须使用 `.ps1`，以同时处理 Appx 扩展。备份与启用状态按用户保存在便携数据目录 `data/ruri-win11-menu/<SID>`。直接导入 uninstall 注册表不会关闭自动注册状态，请使用撤销脚本。

正常卸载会清理当前用户通过脚本启用的菜单。全局安装的菜单仍属于各个用户：每个用户需在升级后手动重新运行安装脚本，并在全局卸载前运行撤销脚本。不要同时用其他发行方式的 VS Code 注册同名菜单扩展；撤销脚本不恢复其他发行方式的 Appx 注册。

传统菜单仍可通过 `reg import "$codeDir\install-context.reg"` 添加、通过 `uninstall-context.reg` 撤销，在 Win11 中位于“显示更多选项”。原生菜单暂未刷新时，可重启 Windows 资源管理器，无需改成传统右键菜单。

上游同步基线：extras 的 VS Code `1.142.0`（manifest 提交 `1bc779eb22`）。后续自动更新沿用上游版本和 SHA-256 检查规则；如上游调整扩展布局，脚本会报错而非注册错误路径。

## Zed 与 Windows 11 右键菜单

`zed` 同步自 `ScoopInstaller/Extras` 的 `1.24.2` manifest，保留 x64 / ARM64 下载、校验及自动更新规则。

```powershell
scoop install ruri-scoop/zed
$zedDir = scoop prefix zed
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$zedDir\install-win11-menu.ps1"
```

在普通、非管理员终端中启用菜单。脚本将 Zed 自带的签名扩展绑定到 Scoop 的 `current\appx`，并设置当前用户的 `ZedContextMenu` 注册表项，使 **Open with Zed** 用于文件、文件夹和文件夹空白处。它可以替换旧安装路径遗留的失效菜单。

首次安装应用不自动启用菜单；手动启用后，普通 Scoop 安装在升级时自动重新注册。菜单状态和注册表备份按用户保存在持久目录 `ruri-win11-menu/<SID>`，不改变 Zed 原有的配置存储位置。请关闭 Zed 内置自动更新，使用 Scoop 更新，避免重新安装到其他目录后导致菜单失效。

撤销菜单：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$zedDir\uninstall-win11-menu.ps1"
```

安装目录保留成对的 `install-win11-context.reg` 和 `uninstall-win11-context.reg`；后者在首次启用时生成，恢复原来的注册表状态，升级时保留原始备份。仅导入 `.reg` 不会完整撤销 Appx 注册或关闭自动注册，请使用 `.ps1`。撤销不会恢复此前其他安装方式的 Appx 绑定。

正常卸载会清理当前用户通过本脚本启用的菜单。全局安装时，每个用户应在升级后手动重新注册，并在卸载应用前撤销菜单。避免多个 Zed 安装同时争用同名菜单扩展。若菜单未刷新，可重新启动 Windows 资源管理器。

## 贡献

欢迎提交新的 manifest。请先阅读 [Scoop 贡献指南](https://github.com/ScoopInstaller/.github/blob/main/.github/CONTRIBUTING.md) 和 [App Manifests](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests)。
