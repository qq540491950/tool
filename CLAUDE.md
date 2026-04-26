# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 仓库用途

本仓库是一个用于升级全局安装的 AI CLI 工具的小型跨平台脚本集合。Windows 实现是 `update-ai.bat`，Linux/macOS 实现是 `update-ai.sh`，共享包列表位于 `packages.txt`。

两个脚本都会：
- 在执行任何安装操作前检查 `npm` 是否可用。
- 从 `packages.txt` 读取同一组包列表。
- 使用 `npm view <package> version` 对比远程最新版本与全局已安装版本。
- 跳过已是最新版的包，使用 `npm install -g` 安装缺失或过期的包，并在结束时报告成功、跳过和失败数量。

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
- `update-ai.sh` 使用 Bash 数组和 `while read` 读取 `packages.txt`，并调用 `npm list -g --depth=0`、`npm view` 和 `npm install -g`；它面向 Bash，而不是 POSIX `sh`。
- Windows 脚本通过匹配 `package@version` 并移除包名前缀来解析已安装版本，可处理 scoped 与 unscoped npm 包。
- shell 脚本通过 `sed 's/.*@//'` 提取已安装版本，可处理 scoped 与 unscoped npm 包行，因为它取最后一个 `@` 之后的文本。
- `.gitignore` 排除了本地 OMC 状态、日志、环境文件以及 OS/editor 临时文件。
