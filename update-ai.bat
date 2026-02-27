@echo off
chcp 65001 >nul
title AI CLI 一键升级工具

echo ============================================
echo        AI CLI 一键升级工具
echo ============================================
echo.
echo 即将安装/升级以下工具：
echo   - @google/gemini-cli
echo   - @iflow-ai/iflow-cli
echo   - @openai/codex
echo   - opencode-ai
echo.
echo 正在执行升级，请稍候...
echo.

npm install -g @google/gemini-cli @iflow-ai/iflow-cli@latest @openai/codex opencode-ai --registry=https://registry.npmmirror.com

echo.
if %ERRORLEVEL% == 0 (
    echo ============================================
    echo   所有工具升级成功！
    echo ============================================
) else (
    echo ============================================
    echo   升级过程中出现错误，请检查网络或 npm 配置。
    echo ============================================
)

echo.
pause
