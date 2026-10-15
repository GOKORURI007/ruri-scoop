---
name: create-scoop-manifest
description: 为 Windows 应用生成 Scoop bucket manifest(bucket/<appname>.json),让它可以通过 Scoop 包管理器安装。当用户说「生成 scoop manifest」「加到 scoop」「给 scoop bucket 打包」「提交 PR 到 scoop-extras / scoop-cn / ScoopInstaller/Extras」,或者任何需要为 Windows 安装包(NSIS .exe、MSI、便携式 .zip)写 JSON manifest 的场景,都触发本技能。常见触发词包括「scoop manifest」「scoop bucket」「scoop 安装 manifest」,以及明确要把应用加进某个 Scoop bucket 的请求。项目必须发布带稳定 URL 的 Windows 资源(通常是 GitHub Releases)。如果项目只发 macOS / Linux 包,Scoop 不适用,不要触发。
---

# 创建 Scoop Manifest

Scoop 从「bucket」仓库里的 JSON manifest 安装 Windows 应用。本技能负责写出版本化的 `bucket/<appname>.json`,并把 `checkver` + `autoupdate` 配好,让 Scoop 自动跟踪新版本。

## 适用场景

- 项目发布 Windows 二进制(NSIS `.exe`、MSI、便携式 `.zip` 内含 `.exe`)
- 这些二进制在稳定的 URL 后面(通常是 GitHub Releases)
- 用户想让 Scoop 装它(本地使用,或者要 PR 到 `ScoopInstaller/Extras`、`ScoopInstaller/CN`、`ScoopInstaller/Versions` 等公共 bucket)

如果项目只发 macOS / Linux 包,Scoop 不是合适工具——说清楚然后停。

## 工作流

1. **识别应用和它的发布资源**
   - Node / Electron 项目读 `package.json`。需要拿到:`version`、`description`、`license`、`build.productName`、`build.win.executableName`,以及 `build.win.artifactName` 里的文件名模板(一般是 `${productName}-${version}-Windows-${arch}.${ext}`)。
   - 其它生态看 `Cargo.toml`、`pyproject.toml`、`*.spec`、`installer/` 等——字段名不同,含义一致。
   - 确认 Windows 包真的在发:看 `dist:win` 脚本、`.github/workflows/` 里的 Actions、或者已经存在的 releases 页。

2. **拿到版本、URL 和 sha256——不下安装包**
   - 调 GitHub Release API:
     - `GET https://api.github.com/repos/<owner>/<repo>/releases/latest`
     - 或者指定版本:`GET /repos/<owner>/<repo>/releases/tags/v<version>`
   - 返回 JSON 里每个 asset 都有 `digest` 字段,格式是 `sha256:<hex>`。**这就是 Scoop 要的 hash。** 不要为了算它而下载 500 MB 的安装包。
   - 筛选出 Windows 资源(文件名匹配 `/windows.*\.(exe|zip|msi|7z)$/i`)。
   - 如果项目不在 GitHub(SourceForge、自建 CDN 等),API 不给 digest——用 `curl` 下载一次,`sha256sum` 算一下,再写 manifest。

   ```bash
   node ~/.agents/skills/create-scoop-manifest/scripts/fetch-windows-assets.mjs <owner>/<repo> [tag]
   ```
   
   会打印 tag、剥掉 `v` 的版本号、每个 Windows 资源的 URL、大小和 sha256。

3. **写 `bucket/<appname>.json`**
   - `bucket/` 放在仓库根目录;`<appname>` 是 Scoop 的 app id(小写、连字符,通常是 `productName` 的小写形式)。
   - 必填字段:`version`、`description`、`homepage`、`license`、`url`、`hash`。
   - NSIS 安装包(electron-builder 默认):安装器是自解压的,可执行文件就在安装根目录,所以 `"bin": "<executableName>.exe"` 直接用相对路径就行。**前提是 NSIS 静默安装能跑通(`oneClick: true` 或确认 `/S` 不弹窗);不然走下面「NSIS 静默安装失败」那一节的 `pre_install` + 7z 解压方案。**
   - `shortcuts`:如果应用装了开始菜单快捷方式,这里写 `[exe, 名称, 描述]` 三元组(NSIS 一般都装)。
   - `checkver.github`:仓库 URL。如果 tag 带 `v` 前缀,加 `regex: "v([\\d.]+)"`,让 Scoop 读出真正的版本号。
   - `autoupdate.url`:用 `$version` 重新拼资源 URL。注意这里的 version **不带** `v` 前缀——和步骤 1 里的 artifact-name 模板对齐。

4. **校验**
   - 把本地目录加成一个测试 bucket:`scoop bucket add test <仓库绝对路径>/bucket`。
   - `scoop info <appname>`——确认 manifest 能解析,会打印 license / bin / shortcuts。
   - `scoop cat <appname>`——打印解析后的 JSON。
   - 如果没装 Scoop,至少跑 `node -e "require('./bucket/<appname>.json')"` 检查 JSON 语法,再 `curl -I` 一下 `url` 字段确认 200。

## 模板:electron-builder NSIS

覆盖大部分用 Electron / Tauri / Wails 写的现代桌面应用。

```json
{
  "version": "0.450.0",
  "description": "HanaAgent - a personal AI agent with memory and soul",
  "homepage": "https://github.com/liliMozi/openhanako",
  "license": {
    "identifier": "Apache-2.0",
    "url": "https://github.com/liliMozi/openhanako/blob/main/LICENSE"
  },
  "url": "https://github.com/liliMozi/openhanako/releases/download/v0.450.0/HanaAgent-0.450.0-Windows-x64.exe",
  "hash": "54fabf3778685680cf97ba9fd4e84ea54f5c3ac72c54e740f9e9a12fd7dce480",
  "bin": "HanaAgent.exe",
  "shortcuts": [
    ["HanaAgent.exe", "HanaAgent", "HanaAgent - a personal AI agent with memory and soul"]
  ],
  "checkver": {
    "github": "https://github.com/liliMozi/openhanako",
    "regex": "v([\\d.]+)"
  },
  "autoupdate": {
    "url": "https://github.com/liliMozi/openhanako/releases/download/v$version/HanaAgent-$version-Windows-x64.exe"
  }
}
```

## 踩过的坑

- **用 GitHub Release API 的 `digest` 字段,不要手算。** 500 MB 的安装包在慢速网络下要几分钟,而 GitHub 上传时已经算好 sha256 了。这一条是整个工作流里最省时间的。
- **electron-builder 的 `latest.yml` 里是 `sha512`,不是 `sha256`。** 它只能当交叉验证用,不能替代。Scoop 的 `hash` 字段必须填 sha256。
- **用 `checkver.regex` 剥掉 `v` 前缀。** tag 一般长这样 `v0.450.0`,但源码里的 `version` 常量是 `0.450.0`。忘了这一步,`scoop update` 永远不会匹配上 asset 名。
- **早用 `scoop info` 验证。** 它在不下任何东西的情况下就能发现 manifest 拼写错误(缺字段、shortcuts 格式错等),而且能确认 `license` 的 SPDX 标识合法。
- **不要加 VC++ 运行时的 `depends`。** 现代 NSIS 自带,加了反而在精简系统上装不上。
- **永远带上 `autoupdate`。** 没它的话每次发版都要手改 `version`、`url`、`hash` 三个字段。有了它,新版本一发布,`scoop update <app>` 就能自动更新。
- **`license` 接受两种形式:** 字符串 SPDX(`"Apache-2.0"`),或对象(`{identifier, url}`)。想让 bucket 页面能链到上游 LICENSE 文件时用对象形式。

## NSIS 静默安装失败怎么办 —— 用 `pre_install` + 7z 直接解压

Scoop 处理 `.exe` 的逻辑(看 `lib/decompress.ps1` 的 `Invoke-Extraction`):

- 文件名以 `.msi` 结尾 → `Expand-MsiArchive`
- 文件名以 `.exe` 结尾 且 `manifest.innosetup = true` → `Expand-InnoArchive`
- 其它情况 → 视为「安装器」,走 `run_installer`,会用 `Invoke-ExternalCommand <progName>` 启动它

NSIS 不在自动解压白名单里。Scoop 试图跑 `oh-my-ppt-2.4.2-win.exe /S`,但是 electron-builder 的 NSIS 配置 `oneClick: false`、`perMachine: false`、`allowToChangeInstallationDirectory: true` 配合交互式组件页,会卡在 GUI 弹窗,extract 没完成、`bin` 指向的文件不存在,后面 `create_shims` 报 `Can't shim 'xxx.exe': File doesn't exist`。

**判断要不要走这条路:**
1. 拿一份目标 `.exe`,用 7z 试着解压:
   ```
   7z x -y -o/tmp/nsis oh-my-ppt-2.4.2-win.exe
   ```
2. 如果出来 `$PLUGINSDIR/app-64.7z` 和 `$R0/Uninstall xxx.exe` 这种结构,就是 electron-builder / NSIS-3 Unicode 的标准 wrapper。真正的应用包在 `$PLUGINSDIR/app-64.7z` 里。
3. 如果 7z 报 `Unknown Error` 或文件根本不是 7z,说明是 MSI / InnoSetup / 别的格式,另想办法。

**manifest 写法:** 跳过 installer 字段,用 `pre_install` 数组让 7z 做两段解压。`depends` 字段拉进 `7zip`(Scoop 会自动用内置的 7zip helper)。

```json
{
  "version": "2.4.2",
  "description": "Oh My PPT - Local-first AI presentation workbench",
  "homepage": "https://github.com/arcsin1/oh-my-ppt",
  "license": { "identifier": "Apache-2.0", "url": "https://github.com/arcsin1/oh-my-ppt/blob/main/LICENSE" },
  "url": "https://github.com/arcsin1/oh-my-ppt/releases/download/v2.4.2/oh-my-ppt-2.4.2-win.exe",
  "hash": "bca4930d53e2d2a9c75ede781216c4efa83ba6465a579dc2998f8e397bb5c13d",
  "depends": "7zip",
  "pre_install": [
    "$nsis = Get-Item \"$dir\\$fname\"",
    "$stage = Join-Path $env:TEMP (\"ohmyppt-extract-\" + $PID)",
    "if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }",
    "New-Item -ItemType Directory -Path $stage | Out-Null",
    "Push-Location $stage",
    "& 7z x -y -o\"$stage\" \"$nsis\" '$PLUGINSDIR\\app-64.7z' | Out-Null",
    "& 7z x -y -o\"$dir\" (Join-Path $stage '$PLUGINSDIR\\app-64.7z') | Out-Null",
    "Pop-Location",
    "Remove-Item -Recurse -Force $stage",
    "Remove-Item -Force \"$nsis\""
  ],
  "bin": "ohmyppt.exe",
  "shortcuts": [
    ["ohmyppt.exe", "OhMyPPT", "Oh My PPT - Local-first AI presentation workbench"]
  ],
  "checkver": {
    "github": "https://github.com/arcsin1/oh-my-ppt",
    "regex": "v([\\d.]+)"
  },
  "autoupdate": {
    "url": "https://github.com/arcsin1/oh-my-ppt/releases/download/v$version/oh-my-ppt-$version-win.exe"
  }
}
```

**这段脚本里最容易写错的两个引号问题:**

- **`$PLUGINSDIR` 必须用单引号。** 双引号会让 PowerShell 把 `$PLUGINSDIR` 当成变量求值,结果是空字符串,7z 找不到路径。第二行特意改成 `(Join-Path $stage '$PLUGINSDIR\\app-64.7z')` 而不是 `"$stage\$PLUGINSDIR\app-64.7z"`,就是为了不踩这个坑。
- **`$dir` 和 `$fname` 必须用双引号。** 这俩是 Scoop 通过动态作用域暴露给 `pre_install` 的本地变量,单引号就拿不到值了。

**Scoop 调用方式(看 `lib/install.ps1` 的 `Invoke-HookScript`):**

```
Invoke-Command ([scriptblock]::Create($script -join "`r`n"))
```

`pre_install` 数组会被 `\r\n` 连成一个脚本块,然后 `Invoke-Command` 跑它。变量是通过 PowerShell 动态作用域从 `install_app` 函数传进来的 — 模拟的时候必须保证 `$dir` / `$fname` 在外层函数里有定义,不然拿到的是空。

**测试方法(不上 bucket 也能验):**

```powershell
function Invoke-HookScript {
    param([string]$HookType, [string[]]$Script)
    if ($Script) {
        Invoke-Command ([scriptblock]::Create($Script -join "`r`n"))
    }
}

$dir = 'D:\ScoopApps\apps\oh-my-ppt\2.4.2'   # 任意目标
$fname = 'oh-my-ppt-2.4.2-win.exe'           # 目标文件名
$manifest = Get-Content 'bucket\oh-my-ppt.json' -Raw | ConvertFrom-Json
# 把下载到的 exe 放进 $dir
Invoke-HookScript -HookType 'pre_install' -Script $manifest.pre_install
# 验
Test-Path (Join-Path $dir 'ohmyppt.exe')
```

跑完应该看到 `ohmyppt.exe` 在 `$dir` 里,原 `.exe` 被删掉,中间临时目录清理掉。这一步过了再去做 `scoop install`。

**适用边界:**
- electron-builder NSIS(目标包叫 `app-64.7z` 或 `app-32.7z`)
- 其它 NSIS 工具链产生的、能在外层用 7z 抽出内嵌 7z 的,原理一样,只要把 `'$PLUGINSDIR\app-64.7z'` 换成实际的内层路径
- 不是 NSIS 的(MFC、WinRAR SFX、InnoSetup 但 `innosetup: true` 漏写的)——先 `7z l xxx.exe` 看结构,再决定脚本