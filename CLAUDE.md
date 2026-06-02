# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 仓库用途

本仓库是一个用于升级全局安装的 AI CLI 工具的小型跨平台脚本集合。Windows 实现是 `update-ai.bat`，Linux/macOS 实现是 `update-ai.sh`，共享包列表位于 `packages.txt`。

两个脚本都会：
- 在执行任何安装操作前检查 `npm` 是否可用。
- 从 `packages.txt` 读取同一组包列表。
- 使用 `npm view <package> version` 对比远程最新版本与全局已安装版本。
- 跳过已是最新版的包，使用 `npm install -g` 安装缺失或过期的包，并在结束时报告成功、跳过和失败数量。

## 仓库结构

- `AGENTS.md` — 其他 AI 编码代理的入口，引导至本文件
- `packages.txt` — 要升级的 npm 包列表（每行一个），添加新工具时只需编辑此文件
- `update-ai.bat` — Windows 升级脚本
- `update-ai.sh` — Linux/macOS 升级脚本
- `.gitignore` — 排除本地工具目录、日志、环境文件

## 常用命令

本仓库没有 package manifest、构建系统、linter 或测试套件；开发方式以脚本为主。

在 Windows 上运行升级工具：

```bat
update-ai.bat
```

在 Linux/macOS 上运行升级工具：

```bash
bash update-ai.sh
```

需要时为 shell 脚本添加可执行权限：

```bash
chmod +x update-ai.sh
./update-ai.sh
```

只检查 shell 脚本语法，不执行 npm 安装：

```bash
bash -n update-ai.sh
```

在 Windows 的 `cmd.exe` 中手动检查批处理脚本解析：

```bat
cmd /c update-ai.bat
```

提交前检查仓库变更：

```bash
git status
git diff
```

## 架构说明

- `packages.txt` 是唯一包列表来源。修改要升级的工具时优先编辑该文件，而不是在脚本中重复维护包名。
- 保持 `update-ai.bat` 与 `update-ai.sh` 的行为一致。修改版本检查逻辑、计数器或最终报告时，应在同一次变更中同步更新两个脚本。
- `update-ai.bat` 在循环中使用 `setlocal enabledelayedexpansion` 和 `!VAR!`；编辑循环逻辑时需要保留 delayed expansion 语义。
- `update-ai.bat` 头部执行 `chcp 65001 >nul` 切换到 UTF-8 代码页，确保在中文 Windows 控制台正确显示 `[成功]`、`[跳过]`、`[失败]` 等中文标签；移除该行会导致输出乱码。
- `update-ai.sh` 使用 Bash 数组和 `while read` 读取 `packages.txt`，并调用 `npm list -g --depth=0`、`npm view` 和 `npm install -g`；它面向 Bash，而不是 POSIX `sh`。
- Windows 脚本通过匹配 `package@version` 并移除包名前缀来解析已安装版本，可处理 scoped 与 unscoped npm 包。
- shell 脚本先通过 `grep -F "$pkg@"` 过滤 `npm list -g` 输出的行，再用 `sed 's/.*@//'` 取最后一个 `@` 之后的文本，从而提取已安装版本；该链路可处理 scoped 与 unscoped npm 包行。
- `.gitignore` 排除了本地日志、环境文件以及 OS/editor 临时文件。
- `.gitattributes` 强制换行符：`*.sh` 与 `packages.txt` 必须为 LF，`*.bat` 必须为 CRLF。跨平台编辑时若 Git 提示 "LF will be replaced by CRLF"，应使用 `git config core.autocrlf false` 或在编辑器中显式指定 EOL，否则 `bash update-ai.sh` 可能在第一行报 `bash: ./update-ai.sh: /bin/bash^M: cannot execute binary file` 之类的错误。
- Windows 脚本使用 `findstr /C:"%%p@"` 匹配本地包行，若包名存在包含关系（如 `@scope/pkg` 与 `@scope/pkg-sub`），substring 匹配可能导致错误识别版本，需注意包命名避免此类前缀重叠。
- 当 `npm view <package> version` 失败（网络异常、镜像不可达、临时超时等）时，两个脚本都会跳过版本比较直接 `npm install -g`；此路径下不会出现"已是最新版"的跳过，失败也会被计入 `fail_count`。

## 添加新包的工作流

1. 在 `packages.txt` 末尾追加一行（scoped 形式如 `@scope/name`）。
2. 本地执行 `update-ai.bat`（Windows）或 `bash update-ai.sh`（Linux/macOS）验证：应看到 `[安装中] ...` 转为 `[成功] ...`。
3. 命名时避免前缀重叠（如 `@scope/pkg` 与 `@scope/pkg-sub`），否则 Windows 脚本可能误识别版本。
4. 仅提交 `packages.txt` 的变更；不要把 npm 全局缓存或日志一并提交（受 `.gitignore` 保护）。
