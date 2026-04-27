#!/bin/bash

# AI CLI 一键升级工具 (Linux/macOS 版本)

echo "============================================"
echo "       AI CLI 一键升级工具"
echo "============================================"
echo ""

# 前置检查
if ! command -v npm &> /dev/null; then
    echo "[错误] 未检测到 npm，请先安装 Node.js！"
    echo "下载地址：https://nodejs.org/"
    exit 1
fi

# 读取要安装的包列表
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
packages_file="$script_dir/packages.txt"

if [ ! -f "$packages_file" ]; then
    echo "[错误] 未找到 packages.txt！"
    exit 1
fi

packages=()
while IFS= read -r pkg || [ -n "$pkg" ]; do
    [ -z "$pkg" ] && continue
    packages+=("$pkg")
done < "$packages_file"

echo "即将检查/升级以下工具："
for pkg in "${packages[@]}"; do
    echo "  - $pkg"
done
echo ""

# 逐个检查并安装
fail_count=0
success_count=0
skip_count=0
failed_list=()

for pkg in "${packages[@]}"; do
    echo "----------------------------------------"
    echo "[检查中] $pkg ..."
    echo ""

    # 获取本地已安装版本（sed 'x.*@' 贪婪匹配到最后一个 @，取版本号）
    local_ver=$(npm list -g --depth=0 2>/dev/null | grep -F "$pkg@" | sed 's/.*@//')

    # 获取远程最新版本（失败时返回空字符串）
    remote_ver=$(npm view "$pkg" version 2>/dev/null || true)

    # 版本比较
    if [ -z "$remote_ver" ]; then
        # npm view 失败，直接安装
        echo "  [安装中] $pkg (无法获取远程版本，直接安装)"
        if npm install -g "$pkg"; then
            echo "  [成功] $pkg"
            ((success_count++))
        else
            echo "  [失败] $pkg"
            ((fail_count++))
            failed_list+=("$pkg")
        fi
    elif [ -n "$local_ver" ] && [ "$local_ver" = "$remote_ver" ]; then
        echo "  [跳过] $pkg 已是最新版 ($local_ver)"
        ((skip_count++))
    else
        if [ -z "$local_ver" ]; then
            echo "  [安装中] $pkg (未安装，最新版: $remote_ver)"
        else
            echo "  [安装中] $pkg (本地: $local_ver → 最新: $remote_ver)"
        fi
        if npm install -g "$pkg"; then
            echo "  [成功] $pkg"
            ((success_count++))
        else
            echo "  [失败] $pkg"
            ((fail_count++))
            failed_list+=("$pkg")
        fi
    fi
    echo ""
done

# 汇总结果
echo "============================================"
echo "  完成！成功: $success_count 个, 跳过: $skip_count 个, 失败: $fail_count 个"
echo "============================================"

if [ $fail_count -gt 0 ]; then
    echo ""
    echo "以下包安装失败，请检查网络或 npm 配置："
    for pkg in "${failed_list[@]}"; do
        echo "  - $pkg"
    done
fi

echo ""
read -p "按回车键继续..."
