# AGENTS.md

本仓库是一个用于升级全局安装的 AI CLI 工具的小型跨平台脚本集合。

## 仓库用途

本仓库是一个单文件 bash 工具，用于升级全局安装的 AI CLI 工具。唯一入口是 `update-ai.sh`，它读取 `packages.conf`，在启动期做 schema 校验，然后按包类型分发到对应的包管理器命令。

支持 3 个动作：`update`（默认）/ `list` / `validate`。

## 仓库结构

- `AGENTS.md` — 本文件，其他 AI 编码代理的入口
- `packages.conf` — 唯一包列表源（管道分隔的纯文本配置）
- `update-ai.sh` — 唯一脚本（bash），承载全部逻辑
- `.gitignore` — 排除本地工具目录、日志、环境文件
- `.gitattributes` — 强制换行符：`*.sh` 必须为 LF

## 配置格式 `packages.conf`

每行一个包，字段用 ` | ` 分隔：

```
name | type | install | update | check
```

- **必填**：`name`、`type`
- **可选**：`install`、`update`、`check` —— 留空则走 type 内置默认
- `#` 之后为注释，空行忽略，字段两侧空格自动去除，兼容 CRLF 文件

自定义 `check` 按 shell 命令执行，其输出视为本地版本。

## 支持的包类型（type）

当前**仅支持 `npm`**。

| type | install / update 默认 | check 默认 | 说明 |
|---|---|---|---|
| `npm` | `npm install -g X` | 比对 `npm view X version` 与 `npm list -g --depth=0` | 标准 npm 全局包 |

配置中若出现 `npm` 以外的 type，启动期 schema 校验会直接 `exit 1`。

> 历史说明：仓库早期是 PowerShell 实现，支持 `pwsh-module` / `pwsh-script` / `binary` / `scoop` / `winget` / `cargo` 七种 type。这两类 PowerShell 专属 type 与 bash 不兼容，已在纯 bash 重写时移除。

## 常用命令

```bash
# 升级全部已配置包
./update-ai.sh

# 仅校验配置，不做任何安装
./update-ai.sh validate

# 列出所有配置包
./update-ai.sh list

# 升级单个包
./update-ai.sh update -Name @minimax-ai/code
```

需要时为脚本添加可执行权限：

```bash
chmod +x update-ai.sh
```

## 在 Windows 上运行

本仓库是纯 bash 实现，Windows 用户需要 bash 环境，二选一：

- **WSL**（推荐）：`wsl -e bash ./update-ai.sh`
- **Git Bash**：`bash ./update-ai.sh`

WSL 下 npm 可正常使用，且操作的就是 Windows 侧那套全局包（WSL 通过 interop 调用 Windows 的 `node.exe`，全局前缀与 Windows 完全重合），因此经 WSL 运行可以正常升级 Windows 上已安装的 CLI 工具。

早前版本提供过 `update-ai.bat`（Windows 薄 wrapper），随 PowerShell 实现一并移除。

## 添加新包的工作流

1. 在 `packages.conf` 中追加一行 `name | type`。
2. `type` 填 `npm`，install / update 走内置默认，只需 `name` + `type` 两项。
3. 可选字段：`install` / `update` 覆盖内置默认命令；`check` 覆盖内置版本检查。
4. 运行 `./update-ai.sh validate` 验证配置无误后再实际升级。
5. 命名时避免前缀重叠（如 `@scope/pkg` 与 `@scope/pkg-sub`），否则 npm check 的 substring 匹配可能误识别版本。

示例：

```
@minimax-ai/code           | npm
@scope/foo                | npm
some-pkg | npm | npm install -g some-pkg@next | npm install -g some-pkg@next | npm list -g --depth=0 | grep some-pkg
```

## 架构说明

- `packages.conf` 是**唯一**包列表源。脚本是流程，配置是数据，互不混用。
- `update-ai.sh` 是**唯一**带业务逻辑的文件，不存在 wrapper，不存在逻辑重复。
- 启动期 schema 校验是配置正确性的最后一道闸：漏字段、错 type、包名重复——一律在执行任何安装/升级前 `exit 1`。
- 修改允许的 type 列表改脚本顶部的 `ALLOWED_TYPES`，同时更新 `resolve_command` / `resolve_check_status` 里的 `case` 分支。
- **不使用 `set -e`**。单个包安装失败不应中断整轮升级；失败会被计入 `fail_count` 并在结尾列出。脚本只开 `set -uo pipefail`。
- **`check` 走独立的 `resolve_check_status`，不要和 install/update 复用同一条 `eval` 路径**。内置 check 返回的是 status 字符串（如 `up-to-date;0.144.9`），不是命令；若直接 `eval` 会被当作命令执行，永远失败。`resolve_check_status` 区分两条路径：1) 配置中自定义 check 按 shell 命令执行后把输出包成「近似 status」；2) 内置 check 直接调用函数并捕获输出。
- `update_one` 用返回码区分结果：`0` = 成功，`1` = 失败，`2` = 跳过（已是最新）。`update_all` 据此统计三个计数。
- 配置解析全程用下标遍历数组而非 `"${ARR[@]}"` 展开。配合 `set -u` 时，旧版 bash（macOS 自带 bash 3.2）在空数组上展开会直接报错。

## 已知行为与陷阱

- **`npm view` 失败会走「直接 install」路径**。网络异常、镜像不可达、包名拼错等情况下 `npm view <pkg> version` 无输出，内置 check 返回空 status，脚本判定为「未安装」并直接执行 install。此路径下不会出现「已是最新版」的跳过，失败也会被计入 `fail_count`。所以一次网络抖动可能表现为「重装」而非「跳过」，不会静默漏包。
- **自定义 `check` 永远返回 `outdated`**。`resolve_check_status` 的自定义分支只要拿到非空输出就包成 `outdated;local=X;remote=X`，因此这类包每次运行都会执行一次 update。内置 npm check 有真正的版本比对，不受此影响。
- **scoped 包的匹配依赖末尾 `@`**。npm check 用 `grep -F -- "$n@"`（即 `@scope/pkg@`）定位版本行，结尾的 `@` 要求紧跟版本号，因此 `@scope/pkg` 不会误匹配 `@scope/pkg-sub`。
- **`.gitattributes` 强制 `*.sh` 为 LF**。如果 Git 提示 `LF will be replaced by CRLF`，配 `git config core.autocrlf false`，否则 bash 可能报 `cannot execute binary file` 之类的错误。`update-ai.sh` 首字节必须是 `#!/usr/bin/env bash`，文件**不能带 UTF-8 BOM**（BOM 会破坏 shebang）。
- 脚本内含中文注释，文件编码保持 UTF-8 无 BOM 即可，bash 按字节透传不受影响。
- `.gitignore` 排除了本地日志、环境文件以及 OS/editor 临时文件。