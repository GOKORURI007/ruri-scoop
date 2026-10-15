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
   - **决定安装方式**:见下面的「NSIS 当 portable 用」段落。
   - `bin`:可执行文件相对路径。
   - `shortcuts`:如果应用装了开始菜单快捷方式,这里写 `[exe, 名称, 描述]` 三元组。
   - `checkver.github`:仓库 URL。如果 tag 带 `v` 前缀,加 `regex: "v([\\d.]+)"`,让 Scoop 读出真正的版本号。
   - `autoupdate.url`:用 `$version` 重新拼资源 URL。注意这里的 version **不带** `v` 前缀。

4. **校验**
   - 把本地目录加成一个测试 bucket:`scoop bucket add test <仓库绝对路径>/bucket`。
   - `scoop info <appname>`——确认 manifest 能解析,会打印 license / bin / shortcuts。
   - `scoop cat <appname>`——打印解析后的 JSON。
   - 如果没装 Scoop,至少跑 `node -e "require('./bucket/<appname>.json')"` 检查 JSON 语法,再 `curl -I` 一下 `url` 字段确认 200。

## 模板 A:便携式安装(优先用这个)

如果项目同时发 NSIS `.exe` 和便携式 `.zip` / `.7z`,优先用便携式版本:

```json
{
  "version": "0.450.0",
  "description": "App description",
  "homepage": "https://github.com/owner/repo",
  "license": { "identifier": "Apache-2.0", "url": "https://github.com/owner/repo/blob/main/LICENSE" },
  "url": "https://github.com/owner/repo/releases/download/v0.450.0/App-0.450.0-Windows-x64.zip",
  "hash": "<sha256>",
  "extract_dir": "App-0.450.0",
  "bin": "App.exe",
  "shortcuts": [["App.exe", "App", "App description"]],
  "checkver": { "github": "https://github.com/owner/repo", "regex": "v([\\d.]+)" },
  "autoupdate": { "url": "https://github.com/owner/repo/releases/download/v$version/App-$version-Windows-x64.zip" }
}
```

## 模板 B:NSIS 当 portable 用(只发 NSIS `.exe` 时)

如果项目只发 NSIS `.exe`,又想用 Scoop portable 安装(不弹 NSIS 安装界面),需要绕开 scoop 默认会运行 NSIS 二进制的行为。

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
  "installer": {
    "script": "7z x \"-o$dir\\.cache\" \"$dir\\$fname\" -y | Out-Null; $inner = Get-ChildItem -Path \"$dir\\.cache\" -Recurse -Filter \"app-64.7z\" | Select-Object -First 1; if ($null -eq $inner) { throw \"Inner app archive (app-64.7z) not found inside NSIS payload\" }; 7z x \"-o$dir\" $inner.FullName -y | Out-Null; Remove-Item -Recurse -Force \"$dir\\.cache\", \"$dir\\$fname\""
  },
  "bin": "HanaAgent.exe",
  "shortcuts": [["HanaAgent.exe", "HanaAgent", "HanaAgent - a personal AI agent with memory and soul"]],
  "checkver": {
    "github": "https://github.com/liliMozi/openhanako",
    "regex": "v([\\d.]+)"
  },
  "autoupdate": {
    "url": "https://github.com/liliMozi/openhanako/releases/download/v$version/HanaAgent-$version-Windows-x64.exe"
  }
}
```

### 为什么这么写

electron-builder 的 NSIS 安装包内部是这样的:

```
HanaAgent-x.y.z-Windows-x64.exe  (NSIS 包装)
└── $PLUGINSDIR\app-64.7z       (真正的应用,7z 格式)
    ├── HanaAgent.exe
    ├── *.dll
    └── resources/
        ├── app.asar
        └── seed/               (server-*.tar.gz、renderer-*.tar.gz 等)
```

7zip 能直接把 NSIS 当 7z 读出来,所以 portable 安装的思路是:

1. 先 `7z x` 解 NSIS 到一个缓存子目录(`$dir\.cache`),得到 `$PLUGINSDIR\app-64.7z`
2. 再 `7z x` 解那个内层 7z 到真正的安装目录
3. 清理缓存和原始 `.exe`

### 关键坑

- **`installer.file` 是陷阱。** 只要在 `installer` 块里写了 `file` 或 `args`,scoop 的 `Invoke-Installer` 就**先**启 NSIS 进程(`/S` 时静默,不带参数时会弹安装界面),**后**才跑 `installer.script` 钩子。要做 portable 安装,只能留 `installer.script`,把 `file` 和 `args` 都去掉。Invoke-Installer 在没有 `file`/`args` 时会跳过二进制执行,但仍然调用 Invoke-HookScript 跑你的脚本。
- **`Invoke-Extraction` 不会主动解 `.exe`。** 它只对 `.zip`、`.msi`、或者显式设了 `innosetup: true` 的 `.exe` 做提取。所以 NSIS `.exe` 不会自动展开,需要靠 `installer.script` 手动 7z。
- **`app-64.7z` 的内层文件名可能随版本变。** 用 `Get-ChildItem -Recurse -Filter "app-64.7z"` 而不是硬编码路径,更稳。
- **`$fname` 在脚本里指向下载下来的 `.exe` 完整路径**(`$dir\$fname`),`$dir` 是 scoop 的版本目录。两者都被 scoop 设到外层作用域,`Invoke-Command` 创建脚本块时能访问到。

## 踩过的坑

- **用 GitHub Release API 的 `digest` 字段,不要手算。** 500 MB 的安装包在慢速网络下要几分钟,而 GitHub 上传时已经算好 sha256 了。这一条是整个工作流里最省时间的。
- **electron-builder 的 `latest.yml` 里是 `sha512`,不是 `sha256`。** 它只能当交叉验证用,不能替代。Scoop 的 `hash` 字段必须填 sha256。
- **用 `checkver.regex` 剥掉 `v` 前缀。** tag 一般长这样 `v0.450.0`,但源码里的 `version` 常量是 `0.450.0`。忘了这一步,`scoop update` 永远不会匹配上 asset 名。
- **早用 `scoop info` 验证。** 它在不下任何东西的情况下就能发现 manifest 拼写错误(缺字段、shortcuts 格式错等),而且能确认 `license` 的 SPDX 标识合法。
- **不要加 VC++ 运行时的 `depends`。** 现代 NSIS 自带,加了反而在精简系统上装不上。
- **永远带上 `autoupdate`。** 没它的话每次发版都要手改 `version`、`url`、`hash` 三个字段。有了它,新版本一发布,`scoop update <app>` 就能自动更新。
- **`license` 接受两种形式:** 字符串 SPDX(`"Apache-2.0"`),或对象(`{identifier, url}`)。想让 bucket 页面能链到上游 LICENSE 文件时用对象形式。
- **想做 portable 安装时,`installer` 块里只留 `script`。** 加 `file` 或 `args` 都会让 scoop 去执行那个二进制,NSIS 就会弹安装界面。