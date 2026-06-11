$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$launcher = Join-Path $root 'Video-Downloader.vbs'
if (-not (Test-Path -LiteralPath $launcher)) {
    throw 'Video-Downloader.vbs nije pronadjen u folderu aplikacije.'
}

$desktop = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktop 'Video Downloader.lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = Join-Path $env:WINDIR 'System32\wscript.exe'
$shortcut.Arguments = '"' + $launcher + '"'
$shortcut.WorkingDirectory = $root
$shortcut.Description = 'Za Informer od srca <3 Endrju Bejbi'
$shortcut.IconLocation = (Join-Path $env:WINDIR 'System32\shell32.dll') + ',14'
$shortcut.Save()

Write-Output "Desktop precica je napravljena: $shortcutPath"
