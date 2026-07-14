#!/bin/bash
# update-ai.sh - Linux/macOS 薄 wrapper，转发给 update-ai.ps1

set -e

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v pwsh >/dev/null 2>&1; then
    echo "[错误] 未检测到 PowerShell (pwsh)，请先安装：https://aka.ms/powershell"
    exit 1
fi

pwsh -NoProfile -File "$script_dir/update-ai.ps1" "$@"
