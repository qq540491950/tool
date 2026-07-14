# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 仓库用途

本仓库是一个用于升级全局安装的 AI CLI 工具的小型跨平台脚本集合。Windows 实现是 `update-ai.bat`，Linux/macOS 实现是 `update-ai.sh`，二者均为薄 wrapper，统一委托给主体脚本 `update-ai.ps1`。所有包（npm、PowerShell Gallery、自维护二进制、scoop、winget、cargo）在 `packages.psd1` 中结构化登记。

主体脚本 `update-ai.ps1` 会：
- 启动期调用 `Import-PowerShellDataFile` 解析 `packages.psd1`，并执行 schema 校验（必填字段、合法 type、字段类型、包名重复）。校验失败立刻 `exit 1`，**不会触发任何 install/update**。
- 按 `type` 分发到对应包管理器的 install / update 命令；标准 type（npm / pwsh-module / pwsh-script / scoop / winget / cargo）使用内置默认命令，`binary` 类型要求显式写 install / update。
- 支持 3 个动作：`update`（默认）/ `list` / `validate`。
- 比较本地版本与远端最新版本，跳过已是最新版的包，使用对应命令安装缺失或过期的包，并在结束时报告成功、跳过和失败数量。

## 仓库结构

- `AGENTS.md` — 其他 AI 编码代理的入口，引导至本文件
- `packages.psd1` — 唯一包列表源（PowerShell 数据文件）。所有包在此统一登记，支持 npm / pwsh-module / pwsh-script / binary / scoop / winget / cargo 七种 type
- `update-ai.ps1` — 主体脚本（启动期 schema 校验 + update / list / validate 三动作 + type 默认命令表）
- `update-ai.bat` — Windows 薄 wrapper（仅做 `powershell -File` 调用）
- `update-ai.sh` — Linux/macOS 薄 wrapper（仅做 `pwsh -File` 调用）
- `.gitignore` — 排除本地工具目录、日志、环境文件
- `.gitattributes` — 强制换行符：`*.sh` / `*.ps1` / `*.psd1` 必须为 LF，`*.bat` 必须为 CRLF

## 支持的包类型（type）

| type | install / update 默认 | 说明 |
|---|---|---|
| `npm` | `npm install -g X` / `npm install -g X` | 标准 npm 全局包 |
| `pwsh-module` | `Install-Module X -Scope CurrentUser -Force` / `Update-Module X -Force` | PowerShell Gallery 模块 |
| `pwsh-script` | `Install-Script X -Force` / `Update-Script X -Force` | PowerShell Gallery 脚本 |
| `binary` | **必填**（无默认） | 自维护二进制（如 oh-my-posh），install / update 必须显式写 |
| `scoop` | `scoop install X` / `scoop update X` | scoop 包 |
| `winget` | `winget install --name X --accept-source-agreements --accept-package-agreements` / `winget upgrade --name X --accept-source-agreements --accept-package-agreements` | winget 包 |
| `cargo` | `cargo install X` / `cargo install --locked X` | cargo crate |

## 常用命令

本仓库没有 package manifest、构建系统、linter 或测试套件；开发方式以脚本为主。

在 Windows 上运行升级工具：

```bat
update-ai.bat
```

在 Linux/macOS 上运行升级工具：

```bash
./update-ai.sh
```

需要时为 shell 脚本添加可执行权限：

```bash
chmod +x update-ai.sh
./update-ai.sh
```

仅校验配置（不安装）：

```bat
update-ai.bat validate
```

列出所有配置包：

```bat
update-ai.bat list
```

更新单个包：

```bat
update-ai.bat update -Name Terminal-Icons
```

壳语法自检（不动 npm / PowerShell）：

```powershell
# PowerShell 语法解析
powershell -NoProfile -Command "$null = [System.Management.Automation.Language.Parser]::ParseFile('.\update-ai.ps1', [ref]$null, [ref]$null)"

# 配置解析
powershell -NoProfile -Command "Import-PowerShellDataFile .\packages.psd1 | Out-Null"
```

只检查 shell 脚本语法，不执行 npm 安装：

```bash
bash -n update-ai.sh
```

提交前检查仓库变更：

```bash
git status
git diff
```

## 添加新包的工作流

1. 在 `packages.psd1` 的 `@(...)` 数组中追加一个 `@{...}` 块。
2. 标准 type（`npm` / `pwsh-module` / `pwsh-script` / `scoop` / `winget` / `cargo`）：只填 `name` 和 `type` 两项，install / update 走内置默认。
3. `binary` 类型：必须额外填 `install` / `update`，缺一会 schema 校验在启动期拦截。
4. 可选字段：`check`（自定义版本检查，覆盖 type 默认）/ `latest`（自定义远端查询）。
5. 运行 `update-ai.bat validate` 验证配置无误后再实际升级。
6. 命名时避免前缀重叠（如 `@scope/pkg` 与 `@scope/pkg-sub`），否则 npm check 的 substring 匹配可能误识别版本。

示例（追加新行）：

```powershell
@{ name = '@scope/foo'; type = 'npm' }
@{ name = 'posh-git';   type = 'pwsh-module' }
@{
    name    = 'rustup'
    type    = 'binary'
    install = 'irm https://win.rustup.rs/x86_64 | iex'
    update  = 'rustup update'
}
```

## 架构说明

- `packages.psd1` 是**唯一**包列表源。脚本是流程，配置是数据，互不混用。
- `update-ai.ps1` 是**唯一**带业务逻辑的脚本。`.bat` 和 `.sh` 各 ~10 行薄 wrapper，逻辑零重复。修改 bug 只改 `update-ai.ps1` 一处。
- 启动期 `Import-PowerShellDataFile` + `Test-PackageSchema` 是配置正确性的最后一道闸：漏字段、错 type、字段类型不对、包名重复——四类手写错误一律在执行任何安装/升级前 `exit 1`。
- 修改默认命令表时改 `update-ai.ps1` 里的 `$typeDefaults`；修改已支持 type 时改 `$allowedTypes`。两处都改才完整。
- `update-ai.ps1` 在循环中使用 `Invoke-Expression` 运行用户提供的命令；保持 `Run-Command` 的 try/catch + `$LASTEXITCODE` 双判断语义。
- 当 `npm view <package> version` 失败（网络异常、镜像不可达、临时超时等）时，npm 类型包走"直接 install"路径；其他 type 的 check 失败则按"未安装"处理，触发对应 install 命令。此路径下不会出现"已是最新版"的跳过，失败也会被计入 `fail_count`。
- `.gitignore` 排除了本地日志、环境文件以及 OS/editor 临时文件。
- 平台入口差异：`.bat` 用 `where.exe powershell` 探测；`.sh` 用 `command -v pwsh` 探测。两者均把退出码透传给上层。
- **Resolve-Command 用 `$pkg.$phase` 直接索引，不绕 `PSObject.Properties`**。`Import-PowerShellDataFile` 返回的 hashtable 在 PSObject 适配器下不暴露 NoteProperty，`$pkg.PSObject.Properties['install']` 返回 $null，会让 packages.psd1 中显式写的 `install` / `update` / `check` 字段被漏掉，退化到 `typeDefaults` fallback；对 `binary` 这种没有内置命令的 type 来说就是"无 install 命令"假报。`$pkg.$phase` 对 hashtable 和 PSCustomObject 都通用。
- **check 函数走独立的 `Resolve-CheckStatus`，不要和 install/update 复用 `Invoke-Expression`**。`typeDefaults` 内置的 check 是 scriptblock，返回 status 字符串（如 `up-to-date;0.144.4`），不能 `Invoke-Expression` 当命令执行——会被 PS 解析为"把 `up-to-date` 当 cmdlet 名"，永远失败。`Resolve-CheckStatus` 区分两条路径：1) `packages.psd1` 中用户自定义 check 当 shell 命令执行后把输出包成"近似 status"字符串；2) `typeDefaults` 内置 check 是 scriptblock 直接 `&` 调用并捕获输出。

## PS 5.1 兼容性

- **UTF-8 BOM 是 PS 5.1 解析含中文 `.ps1` 文件的必要条件**。脚本首 3 字节必须是 `EF BB BF`（UTF-8 BOM），否则 Windows PowerShell 5.1 会按系统 ANSI 代码页（中文 Windows = GBK / CP936）解析，UTF-8 中文字节被识别为非法 token，报"表达式或语句中包含意外的标记"等 ParserError。
- BOM 是文件首部的 3 字节，与 `.gitattributes` 强制 LF 不冲突——LF 约束的是换行符，BOM 在文件最前面独立存在。
- 重新编辑 `.ps1` 时**不要**用 PowerShell 6+ 默认的 UTF-8（无 BOM）或 VSCode 的 "Save with Encoding → UTF-8"（无 BOM），应当用 `File.WriteAllBytes` 手动加 BOM，或用 PowerShell 5.1 的 `Set-Content -Encoding UTF8`（该编码模式默认带 BOM）。
- 修复示例：把无 BOM 的 UTF-8 `.ps1` 升级到 PS 5.1 可解析：

  ```powershell
  $p = 'update-ai.ps1'
  $b = [IO.File]::ReadAllBytes($p)
  [IO.File]::WriteAllBytes($p, (byte[])+$b)
  ```

- 脚本头部的 `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8` 只解决**控制台输出**编码问题，不能替代 BOM——解析层仍然按 BOM 决定。
- **`Import-PowerShellDataFile` 在某些 PowerShell host 中不会自动加载**。该 cmdlet 住在 `Microsoft.PowerShell.Utility` 模块里，PS 5.1 一般会自动加载，但 PowerShell ISE、VSCode 集成终端偶发情况、或 module cache 受损的 session 会报"无法识别为 cmdlet"。`update-ai.ps1` 采用**三层 fallback**：
  1. 全限定名 `Microsoft.PowerShell.Utility\Import-PowerShellDataFile`（标准路径）
  2. cmdlet 不可用时，用 `[scriptblock]::Create((Get-Content -Raw -Path $configPath))` 把 `.psd1` 当脚本块执行（这是 `Import-PowerShellDataFile` 内部的核心机制，不依赖该 cmdlet）
  3. `.psd1` 文件本身有语法错误时透传 PowerShell 异常
  手动修复：先在 PowerShell 里跑 `Import-Module Microsoft.PowerShell.Utility` 再重试。

## PowerShell 调用注意事项

- **PowerShell 默认不能直接调用 `.bat`**。在 PowerShell 控制台里跑 `update-ai.bat validate` 会报"无法识别 update-ai.bat 为 cmdlet"。正确姿势：
  - **cmd / cmd 终端**：`update-ai.bat validate`
  - **PowerShell 终端**：`cmd /c "update-ai.bat validate"`
  - **PowerShell 终端直接调主体脚本**（绕过 wrapper）：`powershell -NoProfile -ExecutionPolicy Bypass -File .\update-ai.ps1 -Action validate`
- `.bat` wrapper 内已自带 `-ExecutionPolicy Bypass`，无需额外配置。
- 跨平台编辑时注意 `.gitattributes` 强制换行符：`.sh` / `.ps1` / `.psd1` = LF，`.bat` = CRLF。如果 Git 提示 "LF will be replaced by CRLF"，配 `git config core.autocrlf false` 或在编辑器中显式指定 EOL，否则 `bash update-ai.sh` 可能在第一行报 `bash: ./update-ai.sh: /bin/bash^M: cannot execute binary file` 之类的错误。