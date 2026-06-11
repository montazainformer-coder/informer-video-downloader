Option Explicit

Dim shell, fso, root, scriptPath, logPath, command
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

root = fso.GetParentFolderName(WScript.ScriptFullName)
scriptPath = root & "\Downloader.ps1"
logPath = root & "\launcher-error.log"
shell.Environment("Process")("DOWNLOADER_ROOT") = root

command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -Command " _
    & Chr(34) _
    & "try { $code = Get-Content -LiteralPath '" & Replace(scriptPath, "'", "''") _
    & "' -Raw -Encoding UTF8; & ([scriptblock]::Create($code)) } " _
    & "catch { $_ | Out-String | Set-Content -LiteralPath '" & Replace(logPath, "'", "''") _
    & "' -Encoding UTF8 }" _
    & Chr(34)

shell.Run command, 0, False
