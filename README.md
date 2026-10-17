# AI CLI 工具升级脚本 (update-ai)

一个轻量、高效、跨平台的自动化升级工具，用于批量检查与升级全局安装的 AI CLI 工具（如 Minimax Code、CodeBuddy、OpenCode、CodeGraph 等）。

基于纯 **Bash** 实现，配置驱动，单入口运行，无多余第三方依赖。

---

## ✨ 核心特性

- ⚡ **智能比对与跳过**：自动比对远端版本（`npm view`）与本地全局版本（`npm list -g --depth=0`）。若本地已是最新版则自动跳过，避免无谓的重复下载与编译。
- 🛡️ **健壮容错机制**：单个包升级失败（如网络抖动或包名失效）不会中断后续任务；运行结束前输出详细统计，并完整列出失败清单。
- 🔍 **启动期 Schema 校验**：严格校验 `packages.conf` 的格式、必填字段、支持类型与重复包名，在执行任何实际安装前杜绝配置错误。
- 🎯 **灵活调度**：支持升级全量配置包、升级指定单个包、列出已配置清单以及仅执行配置校验。
- 🌐 **跨平台支持**：支持 Linux、macOS 以及 Windows（WSL / Git Bash）。在 Windows 下通过 WSL 运行还可直接更新 Windows 宿主机侧的全局 npm 包。
- 🧩 **配置与逻辑解耦**：所有包列表均在 `packages.conf` 中维护，支持自定义 install / update / check 命令扩展。

---

## 📋 快速开始

### 1. 环境准备

- **Bash**：4.0+ 或 macOS 自带 Bash 3.2+
- **Node.js & npm**：已安装并加入系统 `PATH`

### 2. 赋予执行权限

在 Linux / macOS / WSL / Git Bash 中：

```bash
chmod +x update-ai.sh
```

### 3. 常用命令

```bash
# 1. 批量升级全部已配置的包（默认动作）
./update-ai.sh

# 2. 仅升级指定的单个包
./update-ai.sh update -Name @minimax-ai/code

# 3. 列出当前配置中的全部包
./update-ai.sh list

# 4. 仅校验配置文件有效性（不执行任何安装）
./update-ai.sh validate
```

---

## 🪟 Windows 用户使用指南

本工具为纯 Bash 实现，Windows 环境下可通过以下两种方式直接运行：

### 方式一：WSL（推荐）

在 PowerShell 或 CMD 中执行：

```powershell
wsl -e bash ./update-ai.sh
```

> **提示**：WSL 通过 Windows Interop 默认可调用 Windows 侧的 `node.exe` 与 `npm`，其全局包安装目录与 Windows 共享，因此在 WSL 中执行此脚本即可直接升级 Windows 上安装的全局 CLI 工具。

### 方式二：Git Bash

打开 Git Bash 终端，直接运行：

```bash
bash ./update-ai.sh
```

---

## ⚙️ 配置说明 (`packages.conf`)

`packages.conf` 是唯一的包列表源。每行配置一个包，各字段之间使用 ` | ` 分隔：

```conf
name | type | install | update | check
```

### 字段说明

| 字段 | 必填 | 默认值 (type=npm) | 说明 |
|---|---|---|---|
| `name` | **是** | 无 | 包名，支持 scoped 包（例如 `@minimax-ai/code`） |
| `type` | **是** | 无 | 包管理器类型，当前支持 `npm` |
| `install` | 否 | `npm install -g <name>` | 自定义安装命令 |
| `update` | 否 | `npm install -g <name>` | 自定义更新命令 |
| `check` | 否 | 内置版本比对逻辑 | 自定义版本检测命令（按 shell 命令执行，其输出视为本地版本） |

### 配置语法规范

- **注释**：支持 `#` 及其之后的行尾注释。
- **空行**：自动忽略。
- **空白符**：字段两侧空格自动修剪（trim）。
- **换行符**：天然兼容 CRLF 与 LF。

### 示例

```conf
# 1. 基础配置（推荐）：只需填写 name 与 type，走内置默认检查与安装
@minimax-ai/code           | npm
@tencent-ai/codebuddy-code | npm
opencode-ai                | npm
ui-ux-pro-max-cli          | npm

# 2. 自定义安装/更新/检测命令（按需指定特定 tag 或参数）
some-pkg | npm | npm install -g some-pkg@next | npm install -g some-pkg@next | npm list -g --depth=0 | grep some-pkg
```

---

## 📂 仓库结构

```
.
├── packages.conf    # 唯一包列表配置源
├── update-ai.sh     # 核心逻辑脚本（纯 Bash 实现）
├── README.md        # 项目说明与使用文档
├── AGENTS.md        # 面向 AI 编码代理的架构规范与陷阱备忘
├── .gitattributes   # 强制脚本与配置文件保持 LF 换行
└── .gitignore       # Git 忽略配置
```

---

## 💡 运行机制与常见问题 (FAQ)

### 1. 为什么某些包在网络异常时会走安装流程？
内置的 npm 检查逻辑依赖 `npm view <pkg> version` 获取远端最新版本。如果遇到网络波动、镜像源无响应或包名错误导致无法取得远端版本，脚本会将状态归类为“未检出”并尝试执行安装。这样可以保证错误被捕获进末尾的 `失败列表`，防止静默漏更。

### 2. Windows 下提示 `\r: command not found` 或语法报错？
这是由于脚本被转成了 Windows CRLF 换行符导致的。仓库已通过 `.gitattributes` 强制 `*.sh`、`*.conf`、`*.md` 使用 LF 换行。若在 Windows 上被自动转换，可执行：
```bash
git config core.autocrlf false
git checkout-index --force --all
```

### 3. 如何增加支持其他类型的包？
当前版本专注支持全局 `npm` 工具。若需扩展其他包管理器类型，请在 `update-ai.sh` 顶部的 `ALLOWED_TYPES` 中追加新类型，并在 `resolve_command` 与 `resolve_check_status` 中实现相应的命令分发分支。