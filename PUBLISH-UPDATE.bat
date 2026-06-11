@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Publish-Update.ps1"
if errorlevel 1 pause

