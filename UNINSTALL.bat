@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-Shortcut.ps1"

echo Desktop precica je uklonjena. Preuzeti video fajlovi nisu obrisani.
pause
