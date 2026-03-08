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

:: 定义要安装的包列表
set "packages=@google/gemini-cli @iflow-ai/iflow-cli @openai/codex opencode-ai @tencent-ai/codebuddy-code @qwen-code/qwen-code"

echo 即将安装/升级以下工具：
for %%p in (%packages%) do echo   - %%p
echo.

:: 逐个安装并记录结果
set "fail_count=0"
set "success_count=0"
set "failed_list="

for %%p in (%packages%) do (
    echo ----------------------------------------
    echo [安装中] %%p ...
    echo.
    call npm install -g %%p
    if !ERRORLEVEL! == 0 (
        echo   [成功] %%p
        set /a success_count+=1
    ) else (
        echo   [失败] %%p
        set /a fail_count+=1
        set "failed_list=!failed_list! %%p"
    )
    echo.
)

:: 汇总结果
echo ============================================
echo   安装完成！成功: !success_count! 个, 失败: !fail_count! 个
echo ============================================
if !fail_count! gtr 0 (
    echo.
    echo 以下包安装失败，请检查网络或 npm 配置：
    for %%f in (!failed_list!) do echo   - %%f
)

echo.
pause
endlocal
