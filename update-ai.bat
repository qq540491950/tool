@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title AI CLI 一键升级工具

echo ============================================
echo        AI CLI 一键升级工具
echo ============================================
echo.

:: 前置检查
where npm >nul 2>&1
if errorlevel 1 (
    echo [错误] 未检测到 npm，请先安装 Node.js！
    echo 下载地址：https://nodejs.org/
    pause
    exit /b 1
)

:: 读取要安装的包列表
set "packages_file=%~dp0packages.txt"
if not exist "%packages_file%" (
    echo [错误] 未找到 packages.txt！
    pause
    exit /b 1
)

echo 即将检查/升级以下工具：
for /f "usebackq delims=" %%p in ("%packages_file%") do echo   - %%p
echo.

:: 逐个检查并安装
set "fail_count=0"
set "success_count=0"
set "skip_count=0"
set "failed_list="

for /f "usebackq delims=" %%p in ("%packages_file%") do (
    set "local_ver="
    set "remote_ver="

    echo ----------------------------------------
    echo [检查中] %%p ...

    :: 获取本地已安装版本（匹配 package@version，兼容 scoped 和 unscoped 包）
    for /f "delims=" %%l in ('npm list -g --depth=0 2^>nul ^| findstr /C:"%%p@"') do (
        set "pkg_line=%%l"
        set "local_ver=!pkg_line:*%%p@=!"
    )

    :: 获取远程最新版本
    for /f %%v in ('npm view %%p version 2^>nul') do set "remote_ver=%%v"

    :: 版本比较
    if "!remote_ver!" == "" (
        echo   [安装中] %%p ^(无法获取远程版本，直接安装^)
        call npm install -g %%p
        if !ERRORLEVEL! == 0 (
            echo   [成功] %%p
            set /a success_count+=1
        ) else (
            echo   [失败] %%p
            set /a fail_count+=1
            set "failed_list=!failed_list! %%p"
        )
    ) else if "!local_ver!" == "!remote_ver!" (
        echo   [跳过] %%p 已是最新版 ^(!local_ver!^)
        set /a skip_count+=1
    ) else (
        if "!local_ver!" == "" (
            echo   [安装中] %%p ^(未安装，最新版: !remote_ver!^)
        ) else (
            echo   [安装中] %%p ^(本地: !local_ver! -^> 最新: !remote_ver!^)
        )
        call npm install -g %%p
        if !ERRORLEVEL! == 0 (
            echo   [成功] %%p
            set /a success_count+=1
        ) else (
            echo   [失败] %%p
            set /a fail_count+=1
            set "failed_list=!failed_list! %%p"
        )
    )
    echo.
)

:: 汇总结果
echo ============================================
echo   完成！成功: !success_count! 个, 跳过: !skip_count! 个, 失败: !fail_count! 个
echo ============================================
if !fail_count! gtr 0 (
    echo.
    echo 以下包安装失败，请检查网络或 npm 配置：
    for %%f in (!failed_list!) do echo   - %%f
)

echo.
pause
endlocal
