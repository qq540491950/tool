#!/usr/bin/env bash
#
# update-ai.sh — AI CLI 一键升级工具（npm 全局包）
#
# 读取 packages.conf，启动期 schema 校验，按 type 分发到对应包管理器。
# 支持动作：update（默认）/ list / validate
#
# Windows 用户可经 WSL 运行：wsl -e bash ./update-ai.sh
#
# 注意：刻意不使用 set -e —— 单个包安装失败不应中断整轮升级，
#       失败会被计入 fail_count 并在结尾列出。

set -uo pipefail

ALLOWED_TYPES='npm'

# ---------- 通用工具 ----------
trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

die() {
    printf '[错误] %s\n' "$1" >&2
    exit 1
}

usage() {
    cat <<'USAGE'
用法：
  ./update-ai.sh                     升级全部已配置包
  ./update-ai.sh list                列出配置中的包
  ./update-ai.sh validate            仅校验配置，不做任何安装
  ./update-ai.sh update -Name xxx    只处理单个包

Windows 用户可经 WSL 运行：wsl -e bash ./update-ai.sh
USAGE
}

# ---------- 参数解析 ----------
ACTION='update'
TARGET_NAME=''

while [ $# -gt 0 ]; do
    case "$1" in
        update|list|validate)
            ACTION="$1"
            shift
            ;;
        -Name|--name)
            [ $# -ge 2 ] || die "缺少 -Name 的参数值"
            TARGET_NAME="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "未知参数: $1（用 --help 查看用法）"
            ;;
    esac
done

# ---------- 路径与前置检查 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH="$SCRIPT_DIR/packages.conf"

if [ ! -f "$CONFIG_PATH" ]; then
    die "未找到 $CONFIG_PATH"
fi

if ! command -v npm >/dev/null 2>&1; then
    die "未检测到 npm，请先安装 Node.js：https://nodejs.org"
fi

# ---------- 读取并解析配置 ----------
PKG_NAMES=()
PKG_TYPES=()
PKG_INSTALL=()
PKG_UPDATE=()
PKG_CHECK=()

row=0
while IFS= read -r raw || [ -n "$raw" ]; do
    raw="${raw%$'\r'}"                 # 兼容 CRLF 配置文件
    line="${raw%%#*}"                  # 去掉行尾注释
    line="$(trim "$line")"
    [ -z "$line" ] && continue

    row=$((row + 1))
    IFS='|' read -r f_name f_type f_install f_update f_check <<< "$line"

    PKG_NAMES+=("$(trim "$f_name")")
    PKG_TYPES+=("$(trim "$f_type")")
    PKG_INSTALL+=("$(trim "$f_install")")
    PKG_UPDATE+=("$(trim "$f_update")")
    PKG_CHECK+=("$(trim "$f_check")")
done < "$CONFIG_PATH"

if [ "${#PKG_NAMES[@]}" -eq 0 ]; then
    die "$CONFIG_PATH 未配置任何包"
fi

# ---------- Schema 校验 ----------
# 配置正确性的最后一道闸：漏字段、错 type、包名重复 —— 一律在执行任何安装前 exit 1。
SCHEMA_ERRORS=()

for (( i = 0; i < ${#PKG_NAMES[@]}; i++ )); do
    n="${PKG_NAMES[$i]}"
    t="${PKG_TYPES[$i]}"

    if [ -z "$n" ]; then
        label="row $((i + 1)) (匿名)"
    else
        label="row $((i + 1)) ($n)"
    fi

    if [ -z "$n" ]; then
        SCHEMA_ERRORS+=("$label : 缺少必填字段 'name'")
    fi

    case "$t" in
        npm)
            ;;
        '')
            SCHEMA_ERRORS+=("$label : 缺少必填字段 'type'")
            ;;
        *)
            SCHEMA_ERRORS+=("$label : type '$t' 不在合法列表 [$ALLOWED_TYPES]")
            ;;
    esac
done

# 包名重复检查（O(n^2)，包数量级下完全够用）
for (( j = 0; j < ${#PKG_NAMES[@]}; j++ )); do
    a="${PKG_NAMES[$j]}"
    [ -z "$a" ] && continue
    for (( k = j + 1; k < ${#PKG_NAMES[@]}; k++ )); do
        if [ "$a" = "${PKG_NAMES[$k]}" ]; then
            SCHEMA_ERRORS+=("重复的包名: '$a' 出现多次")
        fi
    done
done

if [ "${#SCHEMA_ERRORS[@]}" -gt 0 ]; then
    printf '[错误] packages.conf schema 校验失败：\n' >&2
    for (( m = 0; m < ${#SCHEMA_ERRORS[@]}; m++ )); do
        printf '  - %s\n' "${SCHEMA_ERRORS[$m]}" >&2
    done
    exit 1
fi

# ---------- npm 默认命令与 check ----------
npm_check() {
    local n="$1" remote line ver

    remote="$(npm view "$n" version 2>/dev/null | tr -d '\r' | tr -d '[:space:]')"
    # 查不到远端版本（网络异常 / 包名不存在 / registry 不可达）时返回空 status，
    # 调用方会走「直接 install」路径。此路径下不会出现「已是最新版」的跳过。
    [ -z "$remote" ] && return 0

    # 末尾的 '@' 保证 '@scope/pkg' 不会误匹配 '@scope/pkg-sub'
    line="$(npm list -g --depth=0 2>/dev/null | grep -F -- "$n@" | head -n 1)"
    if [ -n "$line" ]; then
        ver="${line##*"$n"@}"
        ver="${ver//[[:space:]]/}"
    else
        ver=''
    fi

    if [ -z "$ver" ]; then
        printf 'not-installed;remote=%s\n' "$remote"
    elif [ "$ver" = "$remote" ]; then
        printf 'up-to-date;%s\n' "$ver"
    else
        printf 'outdated;local=%s;remote=%s\n' "$ver" "$remote"
    fi
}

# 返回 status 字符串：up-to-date;X.Y.Z | outdated;local=A;remote=B | not-installed;remote=C | ''
resolve_check_status() {
    local type="$1" name="$2" custom="$3" out

    # 1) 配置中自定义的 check —— 按 shell 命令执行，把输出包成「近似 status」
    if [ -n "$custom" ]; then
        out="$(eval "$custom" 2>/dev/null | tr -d '\r')"
        out="$(trim "$out")"
        if [ -n "$out" ]; then
            printf 'outdated;local=%s;remote=%s\n' "$out" "$out"
        else
            printf 'not-installed;remote=\n'
        fi
        return 0
    fi

    # 2) 内置 check —— 直接调用，绝不 eval（内置 check 返回的是 status 字符串，
    #    不是命令；eval 会把它当成命令执行而永远失败）
    case "$type" in
        npm) npm_check "$name" ;;
    esac
}

# 返回命令字符串；显式配置优先，空则取 type 默认。
resolve_command() {
    local type="$1" name="$2" phase="$3" custom="$4"

    if [ -n "$custom" ]; then
        printf '%s' "$custom"
        return 0
    fi

    case "$type:$phase" in
        npm:install|npm:update)
            printf 'npm install -g %s' "$name"
            ;;
    esac
}

# 返回码：0 = 成功，1 = 失败，2 = 跳过（无可用命令）
run_command() {
    local cmd="$1" phase="$2" pkg="$3" rc

    if [ -z "$cmd" ]; then
        printf '    [%s] %s : 无可用命令（跳过）\n' "$phase" "$pkg"
        return 2
    fi

    printf '    [%s] %s : %s\n' "$phase" "$pkg" "$cmd"
    eval "$cmd"
    rc=$?

    if [ "$rc" -ne 0 ]; then
        printf '    [失败] %s (%s 退出码 %s)\n' "$pkg" "$phase" "$rc"
        return 1
    fi
    return 0
}

# 返回码：0 = 成功，1 = 失败，2 = 跳过（已是最新）
update_one() {
    local name="$1" type="$2" c_install="$3" c_update="$4" c_check="$5"
    local status cmd rc

    printf -- '----------------------------------------\n'
    printf '[检查中] %s [%s]\n' "$name" "$type"

    status="$(resolve_check_status "$type" "$name" "$c_check")"

    if [ -z "$status" ]; then
        printf '    [未安装/未检出] %s\n' "$name"
        cmd="$(resolve_command "$type" "$name" 'install' "$c_install")"
        run_command "$cmd" 'install' "$name"
        rc=$?
        [ "$rc" -eq 1 ] && return 1
        return 0
    fi

    case "$status" in
        up-to-date*)
            printf '    [跳过] %s - %s\n' "$name" "$status"
            return 2
            ;;
    esac

    printf '    [需更新] %s - %s\n' "$name" "$status"
    cmd="$(resolve_command "$type" "$name" 'update' "$c_update")"
    run_command "$cmd" 'update' "$name"
    rc=$?
    [ "$rc" -eq 1 ] && return 1
    return 0
}

update_all() {
    local success=0 skip=0 fail=0
    local failed=()
    local i rc

    for (( i = 0; i < ${#PKG_NAMES[@]}; i++ )); do
        if [ -n "$TARGET_NAME" ] && [ "${PKG_NAMES[$i]}" != "$TARGET_NAME" ]; then
            continue
        fi

        update_one "${PKG_NAMES[$i]}" "${PKG_TYPES[$i]}" \
                   "${PKG_INSTALL[$i]}" "${PKG_UPDATE[$i]}" "${PKG_CHECK[$i]}"
        rc=$?

        case "$rc" in
            0) success=$((success + 1)) ;;
            2) skip=$((skip + 1)) ;;
            *)
                fail=$((fail + 1))
                failed+=("${PKG_NAMES[$i]}")
                ;;
        esac
    done

    printf -- '============================================\n'
    printf '完成：成功 %d 个，跳过 %d 个，失败 %d 个\n' "$success" "$skip" "$fail"

    if [ "$fail" -gt 0 ]; then
        printf '失败列表：\n'
        for (( i = 0; i < ${#failed[@]}; i++ )); do
            printf '  - %s\n' "${failed[$i]}"
        done
    fi

    [ "$fail" -gt 0 ] && return 1
    return 0
}

# ---------- 调度 ----------
case "$ACTION" in
    validate)
        printf '[OK] packages.conf schema 校验通过，共 %d 个条目\n' "${#PKG_NAMES[@]}"
        ;;

    list)
        printf '配置中的包（共 %d 个）：\n' "${#PKG_NAMES[@]}"
        for (( i = 0; i < ${#PKG_NAMES[@]}; i++ )); do
            printf '  - %s [%s]\n' "${PKG_NAMES[$i]}" "${PKG_TYPES[$i]}"
        done
        ;;

    update)
        if [ -n "$TARGET_NAME" ]; then
            found=0
            for (( i = 0; i < ${#PKG_NAMES[@]}; i++ )); do
                if [ "${PKG_NAMES[$i]}" = "$TARGET_NAME" ]; then
                    found=1
                    break
                fi
            done
            [ "$found" -eq 1 ] || die "未找到: $TARGET_NAME"
        fi
        update_all
        ;;
esac