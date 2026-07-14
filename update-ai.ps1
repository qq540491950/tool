#!/usr/bin/env pwsh
<#
.SYNOPSIS
    AI CLI 一键升级工具（统一入口）
.DESCRIPTION
    读取 packages.psd1，启动期 schema 校验，按 type 分发到对应包管理器。
    支持动作：update（默认）/ list / validate
#>

[CmdletBinding()]
param(
    [ValidateSet('update', 'list', 'validate')]
    [string]$Action = 'update',

    [string]$Name
)

# ---------- 强制 UTF-8（兼容 PS 5.1） ----------
if ($PSVersionTable.PSVersion.Major -le 5) {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
}

# ---------- 路径与前置检查 ----------
$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath  = Join-Path $scriptDir 'packages.psd1'

if (-not (Test-Path $configPath)) {
    Write-Host "[错误] 未找到 $configPath" -ForegroundColor Red
    exit 1
}

# ---------- 读取并解析配置 ----------
# 三层 fallback，确保任何 PowerShell session 都能解析 .psd1：
#   1. 全限定名调用 Microsoft.PowerShell.Utility\Import-PowerShellDataFile（标准路径）
#   2. cmdlet 不可用时（受损 session、module path 被改等）直接 [scriptblock]::Create 执行
#      .psd1（这是 Import-PowerShellDataFile 的核心机制）
#   3. .psd1 文件本身有语法错误时透传 PowerShell 异常
try {
    $config = & Microsoft.PowerShell.Utility\Import-PowerShellDataFile -Path $configPath
} catch [System.Management.Automation.CommandNotFoundException] {
    try {
        $sb      = [scriptblock]::Create((Get-Content -Raw -Path $configPath))
        $config  = & $sb
    } catch {
        Write-Host "[错误] packages.psd1 解析失败：$($_.Exception.Message)" -ForegroundColor Red
        Write-Host "提示：请先在 PowerShell 中执行 'Import-Module Microsoft.PowerShell.Utility' 后重试" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "[错误] packages.psd1 解析失败：$($_.Exception.Message)" -ForegroundColor Red
    Write-Host "提示：请先在 PowerShell 中执行 'Import-Module Microsoft.PowerShell.Utility' 后重试" -ForegroundColor Yellow
    exit 1
}
$packages = $config.packages
if ($null -eq $packages) {
    Write-Host "[错误] packages.psd1 必须包含 packages 数组" -ForegroundColor Red
    exit 1
}

# ---------- type 默认命令表 ----------
$typeDefaults = @{
    'npm' = @{
        install = { param($n) "npm install -g $n" }
        update  = { param($n) "npm install -g $n" }
        check   = { param($n)
            $remote = (npm view $n version 2>$null) -join ''
            $remote = $remote.Trim()
            if (-not $remote) { return '' }
            $localLine = (npm list -g --depth=0 2>$null) -split "`n" | Select-String -SimpleMatch "$n@"
            $localVer  = if ($localLine) { (($localLine -split '@')[-1] -replace '\s', '') } else { '' }
            if (-not $localVer)            { return "not-installed;remote=$remote" }
            if ($localVer -eq $remote)     { return "up-to-date;$localVer" }
            return "outdated;local=$localVer;remote=$remote"
        }
    }
    'pwsh-module' = @{
        install = { param($n) "Install-Module -Name $n -Scope CurrentUser -Force -AcceptLicense" }
        update  = { param($n) "Update-Module -Name $n -Force -AcceptLicense" }
        check   = { param($n)
            $remote = Find-Module -Name $n -Repository PSGallery -ErrorAction SilentlyContinue | Select-Object -First 1
            $local  = Get-InstalledModule -Name $n -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $remote)            { return '' }
            if (-not $local)             { return "not-installed;remote=$($remote.Version)" }
            if ($local.Version -eq $remote.Version) { return "up-to-date;$($local.Version)" }
            return "outdated;local=$($local.Version);remote=$($remote.Version)"
        }
    }
    'pwsh-script' = @{
        install   = { param($n) "Install-Script -Name $n -Force" }
        update    = { param($n) "Update-Script -Name $n -Force" }
        check     = { param($n)
            $remote = Find-Script -Name $n -Repository PSGallery -ErrorAction SilentlyContinue | Select-Object -First 1
            $local  = Get-InstalledScript -Name $n -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $remote)            { return '' }
            if (-not $local)             { return "not-installed;remote=$($remote.Version)" }
            if ($local.Version -eq $remote.Version) { return "up-to-date;$($local.Version)" }
            return "outdated;local=$($local.Version);remote=$($remote.Version)"
        }
    }
    'scoop' = @{
        install   = { param($n) "scoop install $n" }
        update    = { param($n) "scoop update $n" }
        check     = { param($n)
            $hit = (scoop list 2>$null) -join "`n" | Select-String -SimpleMatch $n
            if ($hit) { return "installed;$n" } else { return '' }
        }
    }
     'winget' = @{
        install = { param($n) "winget install --name $n --accept-source-agreements --accept-package-agreements" }
        update  = { param($n) "winget upgrade --name $n --accept-source-agreements --accept-package-agreements" }
        check   = { param($n)
            $hit = winget list --name $n --accept-source-agreements 2>$null | Select-String -SimpleMatch $n
            if ($hit) { return "installed;$n" } else { return '' }
        }
    }
    'cargo' = @{
        install = { param($n) "cargo install $n" }
        update  = { param($n) "cargo install --locked $n" }
        check   = { param($n)
            $hit = (cargo install --list 2>$null) -join "`n" | Select-String -SimpleMatch " $n "
            if ($hit) { return "installed;$n" } else { return '' }
        }
    }
}

$allowedTypes = @('npm', 'pwsh-module', 'pwsh-script', 'binary', 'scoop', 'winget', 'cargo')

# ---------- Schema 校验 ----------
function Test-PackageSchema {
    param($pkgs)
    $errors = @()
    for ($i = 0; $i -lt $pkgs.Count; $i++) {
        $pkg       = $pkgs[$i]
        $rowNum    = $i + 1
        $nameLabel = if ([string]::IsNullOrWhiteSpace($pkg.name)) { '(匿名)' } else { "($($pkg.name))" }
        $row       = "row $rowNum $nameLabel"

        if ([string]::IsNullOrWhiteSpace($pkg.name)) {
            $errors += "$row : 缺少必填字段 'name'"
        }
        if ([string]::IsNullOrWhiteSpace($pkg.type)) {
            $errors += "$row : 缺少必填字段 'type'"
        } elseif ($pkg.type -notin $allowedTypes) {
            $errors += "$row : type '$($pkg.type)' 不在合法列表 [$($allowedTypes -join ', ')]"
        }
        if ($pkg.type -eq 'binary') {
            foreach ($f in 'install', 'update') {
                if ([string]::IsNullOrWhiteSpace($pkg.$f)) {
                    $errors += "$row : type=binary 缺少必填字段 '$f'"
                }
            }
        }
        foreach ($f in 'check', 'install', 'update', 'latest') {
            $v = $pkg.$f
            if ($null -ne $v -and $v -isnot [string]) {
                $errors += "$row : 字段 '$f' 必须是字符串（当前类型：$($v.GetType().Name)）"
            }
        }
    }
    $names = $pkgs | ForEach-Object { $_.name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $dupes = $names | Group-Object | Where-Object { $_.Count -gt 1 }
    foreach ($d in $dupes) {
        $errors += "重复的包名: '$($d.Name)' 出现 $($d.Count) 次"
    }
    return $errors
}

$schemaErrors = Test-PackageSchema $packages
if ($schemaErrors.Count -gt 0) {
    Write-Host "[错误] packages.psd1 schema 校验失败：" -ForegroundColor Red
    foreach ($e in $schemaErrors) {
        Write-Host "  - $e" -ForegroundColor Red
    }
    exit 1
}

# ---------- 工具函数 ----------
function Resolve-Command {
    param($pkg, [string]$phase)
    # 用 $pkg.$phase 直接索引：兼容 hashtable 和 PSCustomObject 两种来源。
    # 之前用 $pkg.PSObject.Properties[$phase] 检测，对 hashtable 适配器
    # 不会返回 NoteProperty，导致 binary 包的 install/update 被漏掉。
    $custom = $pkg.$phase
    if (-not [string]::IsNullOrWhiteSpace($custom)) {
        return $custom
    }
    if ($typeDefaults.ContainsKey($pkg.type) -and $typeDefaults[$pkg.type].ContainsKey($phase)) {
        return (& $typeDefaults[$pkg.type][$phase] $pkg.name)
    }
    return $null
}

function Resolve-CheckStatus {
    param($pkg)
    # check 函数返回 status 字符串（up-to-date;X.Y.Z | outdated;local=A;remote=B | ''）
    # 区别于 install/update 的命令字符串。
    # 1) packages.psd1 中用户自定义 check —— 执行命令后把输出转为"近似 status"
    # 2) typeDefaults 内置 check —— 直接执行 scriptblock 并返回 status
    $userCheck = $pkg.check
    if (-not [string]::IsNullOrWhiteSpace($userCheck)) {
        try {
            $output = Invoke-Expression $userCheck 2>$null | Out-String
            $ver    = $output.Trim()
            if ($ver) { return "outdated;local=$ver;remote=$ver" }
            return 'not-installed;remote='
        } catch {
            return ''
        }
    }
    if ($typeDefaults.ContainsKey($pkg.type) -and $typeDefaults[$pkg.type].ContainsKey('check')) {
        try {
            return (& $typeDefaults[$pkg.type]['check'] $pkg.name) -join '' |
                ForEach-Object { $_.ToString().Trim() }
        } catch {
            return ''
        }
    }
    return ''
}

function Run-Command {
    param([string]$cmd, [string]$phase, [string]$pkgName)
    if ([string]::IsNullOrWhiteSpace($cmd)) {
        Write-Host "    [$phase] $pkgName : 无可用命令（跳过）" -ForegroundColor DarkGray
        return @{ skipped = $true }
    }
    Write-Host "    [$phase] $pkgName : $cmd" -ForegroundColor Cyan
    $exitCode = 0
    try {
        Invoke-Expression $cmd | Out-Null
        $exitCode = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }
    } catch {
        Write-Host "    [失败] $pkgName ($phase 异常: $($_.Exception.Message))" -ForegroundColor Yellow
        return @{ failed = $true; error = $_.Exception.Message }
    }
    if ($exitCode -ne 0) {
        Write-Host "    [失败] $pkgName ($phase 退出码 $exitCode)" -ForegroundColor Yellow
        return @{ failed = $true; exitCode = $exitCode }
    }
    return @{ ok = $true }
}

# ---------- 动作实现 ----------
function Invoke-UpdateOne {
    param($pkg)
    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    Write-Host "[检查中] $($pkg.name) [$($pkg.type)]" -ForegroundColor Yellow

    # check 走专门的状态解析函数：packages.psd1 配置的 check 当命令字符串执行；
    # typeDefaults 内置的 check 是 scriptblock 直接调用并捕获输出。
    # 之前把 checkCmd 直接 Invoke-Expression 会把已执行的 status 字符串
    # （如 "up-to-date;0.144.4"）当成 PS 代码再次执行，导致所有 npm 包误判为"未安装"。
    $status = Resolve-CheckStatus $pkg

    if ([string]::IsNullOrWhiteSpace($status)) {
        Write-Host "    [未安装/未检出] $($pkg.name)" -ForegroundColor Cyan
        $cmd = Resolve-Command $pkg 'install'
        if ([string]::IsNullOrWhiteSpace($cmd)) {
            Write-Host "    [失败] $($pkg.name) : 无 install 命令" -ForegroundColor Red
            return 'fail'
        }
        $r = Run-Command $cmd 'install' $pkg.name
        if ($r.ok) { return 'success' } else { return 'fail' }
    }

    if ($status.StartsWith('up-to-date')) {
        Write-Host "    [跳过] $($pkg.name) - $status" -ForegroundColor Green
        return 'skip'
    }

    Write-Host "    [需更新] $($pkg.name) - $status" -ForegroundColor Cyan
    $cmd = Resolve-Command $pkg 'update'
    if ([string]::IsNullOrWhiteSpace($cmd)) {
        Write-Host "    [失败] $($pkg.name) : 无 update 命令" -ForegroundColor Red
        return 'fail'
    }
    $r = Run-Command $cmd 'update' $pkg.name
    if ($r.ok) { return 'success' } else { return 'fail' }
}

function Invoke-UpdateAll {
    param($pkgs)
    $success = 0; $skip = 0; $fail = 0; $failed = @()
    foreach ($pkg in $pkgs) {
        $r = Invoke-UpdateOne $pkg
        switch ($r) {
            'success' { $success++ }
            'skip'    { $skip++ }
            'fail'    { $fail++; $failed += $pkg.name }
        }
    }
    Write-Host "============================================" -ForegroundColor DarkGray
    Write-Host "完成：成功 $success 个，跳过 $skip 个，失败 $fail 个" -ForegroundColor Yellow
    if ($fail -gt 0) {
        Write-Host "失败列表："
        $failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    }
}

function Show-List {
    param($pkgs)
    Write-Host "配置中的包（共 $($pkgs.Count) 个）：" -ForegroundColor Yellow
    foreach ($pkg in $pkgs) {
        Write-Host "  - $($pkg.name) [$($pkg.type)]"
    }
}

# ---------- 调度 ----------
switch ($Action) {
    'validate' {
        Write-Host "[OK] packages.psd1 schema 校验通过，共 $($packages.Count) 个条目" -ForegroundColor Green
    }
    'list' {
        Show-List $packages
    }
    'update' {
        if ($Name) {
            $target = $packages | Where-Object { $_.name -eq $Name }
            if (-not $target) { Write-Host "[错误] 未找到: $Name" -ForegroundColor Red; exit 1 }
            Invoke-UpdateAll $target
        } else {
            Invoke-UpdateAll $packages
        }
    }
}
