# Scoop Bucket 项目说明

## 项目概述

这是一个 **Scoop 软件包管理器的第三方 Bucket**（软件包仓库），名为 `ruri-scoop`。

Scoop 是 Windows 平台的命令行软件包管理器，类似于 macOS 的 Homebrew。Bucket 是 Scoop 用来存储软件包定义（manifest）的仓库。

## 项目结构

```
.
├── bucket/                     # 软件包 manifest 文件目录（.json）
│   └── (当前为空，等待添加 manifest)
├── bin/                        # 维护脚本目录
│   ├── archive_cache.py        # 缓存归档处理脚本
│   ├── auto-pr.ps1             # 自动更新并创建 Pull Request
│   ├── checkAndPush.ps1        # 检查并推送更新
│   ├── checkhashes.ps1         # 检查文件哈希
│   ├── checkNoVersionVariables.ps1  # 检查无版本变量的 manifest
│   ├── checkurls.ps1           # 检查 URL 有效性
│   ├── checkver.ps1            # 检查 manifest 版本更新
│   ├── convert.ps1             # 格式转换脚本
│   ├── createHooks.ps1         # 创建 Git hooks
│   ├── describe.ps1            # 描述 manifest 信息
│   ├── format.ps1              # 格式化 manifest
│   ├── Get-DumplingsVersion.ps1  # 获取 Dumplings 版本
│   ├── Helpers.ps1             # 辅助函数库
│   ├── makeindex.ps1           # 生成 README 应用索引表格
│   ├── missing-checkver.ps1    # 检查缺失 checkver 的 manifest
│   ├── sordum.ps1              # Sordum 相关工具脚本
│   └── test.ps1                # 测试脚本
├── .github/workflows/          # GitHub Actions CI/CD 工作流
│   ├── schedule.yml            # Excavator - 定时检查更新（每3小时）
│   ├── make_index.yml          # 定时生成应用索引（每天）
│   ├── pull_request.yml        # PR 处理工作流
│   ├── test_manifests.yml      # 测试 manifest
│   ├── issue_comment.yml       # Issue 评论处理
│   ├── issues.yml              # Issue 处理
│   ├── quickinstall_request.yml # 快速安装请求处理
│   └── sync_mirror.yml         # 同步镜像
├── .vscode/                    # VS Code 配置
│   ├── extensions.json         # 推荐扩展
│   ├── settings.json           # 设置
│   ├── tasks.json              # 任务配置
│   ├── json.code-snippets      # JSON 代码片段
│   ├── markdown.code-snippets  # Markdown 代码片段
│   └── yaml.code-snippets      # YAML 代码片段
├── deprecated/                 # 废弃的 manifest（空目录）
├── scripts/                    # 额外的脚本目录（空）
├── Bucket.Tests.ps1            # Bucket 测试脚本
├── Scoop-Bucket.Tests.Local.ps1  # 本地测试脚本
├── schema.intellij.json        # Scoop manifest JSON Schema
├── README.md                   # 项目说明（包含应用索引表格）
├── LICENSE                     # 许可证
└── AGENTS.md                   # 本文件
```

## 核心文件说明

### Manifest 文件

- **位置**: `bucket/*.json`
- **格式**: JSON 格式，遵循 Scoop manifest 规范
- **作用**: 定义软件包的元数据、下载地址、安装方式等

### 关键脚本

| 脚本 | 功能 |
|------|------|
| `bin/makeindex.ps1` | 扫描 bucket 目录下的 manifest，生成 README.md 中的应用索引表格 |
| `bin/checkver.ps1` | 检查 manifest 是否有新版本可用，支持 `-u` 参数自动更新 |
| `bin/auto-pr.ps1` | 自动更新 manifest 并创建 Pull Request 或推送到 master |
| `bin/checkNoVersionVariables.ps1` | 检查 autoupdate 中没有版本变量（`$version`）的 manifest |
| `bin/checkhashes.ps1` | 验证 manifest 中文件的哈希值 |
| `bin/checkurls.ps1` | 检查 manifest 中的下载 URL 是否可访问 |
| `bin/format.ps1` | 格式化 manifest 文件，统一代码风格 |

### CI/CD 工作流

| 工作流 | 触发条件 | 功能 |
|--------|----------|------|
| `schedule.yml` (Excavator) | 每3小时定时 | 自动检查 manifest 更新，更新版本和哈希 |
| `make_index.yml` | 每天定时 | 运行 `makeindex.ps1` 更新 README 中的应用列表 |
| `pull_request.yml` | PR 创建时 | 处理 Pull Request，运行测试 |
| `test_manifests.yml` | 手动/定时 | 测试 manifest 的完整性和正确性 |
| `sync_mirror.yml` | 手动 | 同步到镜像仓库 |

## 开发规范

### Manifest 编写规范

参见 `.github/CONTRIBUTING.md`：

1. **命名规范**: 使用 `PascalCase`，首字母大写（编程相关工具除外）
2. **格式**: 优先使用 YAML 格式（支持时），文件扩展名用 `.yml`
3. **属性命名**: 
   - 使用 `regex` 而非 `re`
   - 使用 `jsonpath` 而非 `jp`
4. **Description**: 以应用名开头，以句号结尾，如 `"App name. Meaningful description."`
5. **脚本块** (`installer.script`, `post_install`, `pre_install`):
   - 使用 literal 块 (`|`) 而非 folded 块 (`>`)
   - 转义路径
   - 正常缩进代码
6. **YAML 风格**:
   - 使用单引号
   - 属性名不加引号
   - 字符串不加引号（除非版本是数字）
7. **Bins 和 Shortcuts**:
   - 使用反斜杠
   - 不包含 `$dir`
   - GUI 应用不创建 bin（除非支持参数）
8. **Persisting**:
   - 不包含 `$dir`
   - 如果持久化文件不存在，在 `pre_install` 中创建

### 提交信息规范

- 更新 manifest: `(chore): update <app> to <version>`
- 修复: `(fix): fix <app> ...`
- 新增: `(feat): add <app>`

## 常用操作

### 添加新的软件包

1. 在 `bucket/` 目录下创建 `<app-name>.json`
2. 运行测试: `bin/test.ps1 <app-name>`
3. 提交更改

### 更新软件包版本

```powershell
# 检查所有 manifest 的更新
bin/checkver.ps1

# 检查特定 manifest 并自动更新
bin/checkver.ps1 <app-name> -u

# 强制更新（用于哈希更新）
bin/checkver.ps1 <app-name> -f
```

### 生成索引

```powershell
# 更新 README.md 中的应用索引表格
bin/makeindex.ps1
```

### 格式化 manifest

```powershell
# 格式化所有 manifest
bin/format.ps1

# 格式化特定 manifest
bin/format.ps1 <app-name>
```

## 依赖要求

- **PowerShell**: 5.1 或更高版本（推荐 7.x）
- **Scoop**: 需要安装 Scoop 包管理器
- **Git**: 用于版本控制
- **Python 3**: 部分脚本需要（如 `archive_cache.py`）

## 项目状态

- **当前状态**: Bucket 目录为空，等待添加 manifest 文件
- **原始来源**: 基于 `hoilc/scoop-lemon` bucket 修改
- **GitHub 地址**: https://github.com/gokoruri007/ruri-scoop

## 相关链接

- [Scoop 官网](https://scoop.sh/)
- [Scoop Wiki](https://github.com/ScoopInstaller/Scoop/wiki)
- [Scoop 应用清单格式](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests)
