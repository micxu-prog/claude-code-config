@echo off
set "STATUSLINE_SCRIPT=%USERPROFILE%\claude-code-config\copilot\statusline-command.ps1"
if not exist "%STATUSLINE_SCRIPT%" set "STATUSLINE_SCRIPT=%USERPROFILE%\.copilot\statusline-command.ps1"

where pwsh.exe >nul 2>nul
if %ERRORLEVEL%==0 (
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%STATUSLINE_SCRIPT%"
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%STATUSLINE_SCRIPT%"
)
