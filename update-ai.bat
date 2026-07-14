@echo off
rem update-ai.bat - Windows 薄 wrapper，转发给 update-ai.ps1

where.exe powershell >nul 2>&1
if errorlevel 1 (
    echo [错误] 未检测到 PowerShell，请安装 Windows PowerShell 5.1 或更高版本
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update-ai.ps1" %*
exit /b %ERRORLEVEL%
