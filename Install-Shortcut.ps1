$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$launcher = Join-Path $root 'Launch-Downloader.ps1'
if (-not (Test-Path -LiteralPath $launcher)) {
    throw 'Launch-Downloader.ps1 nije pronadjen u folderu aplikacije.'
}

$desktop = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktop 'Video Downloader.lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$shortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + $launcher + '"'
$shortcut.WorkingDirectory = $root
$shortcut.Description = 'Za Informer od srca <3 Endrju Bejbi'
$shortcut.IconLocation = (Join-Path $env:WINDIR 'System32\shell32.dll') + ',14'
$shortcut.Save()

Write-Output "Desktop precica je napravljena: $shortcutPath"
