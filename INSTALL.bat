@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Shortcut.ps1"

if errorlevel 1 (
  echo Instalacija precice nije uspela.
  pause
  exit /b 1
)

echo Video Downloader precica je napravljena na Desktopu.
echo Nemoj pomerati ovaj folder nakon instalacije precice.
pause
