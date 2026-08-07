@echo off
set ORZ_COPILOT_FLAGS=
if defined ZELLIJ set ORZ_COPILOT_FLAGS=--no-color --mouse

where agency >nul 2>nul
if %errorlevel%==0 (
    agency copilot %ORZ_COPILOT_FLAGS% %*
    exit /b %errorlevel%
)

copilot %ORZ_COPILOT_FLAGS% %*
