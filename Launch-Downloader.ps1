$ErrorActionPreference = 'Stop'

$env:DOWNLOADER_ROOT = $PSScriptRoot
$scriptPath = Join-Path $PSScriptRoot 'Downloader.ps1'
$logPath = Join-Path $PSScriptRoot 'launcher-error.log'

try {
    $code = Get-Content -LiteralPath $scriptPath -Raw -Encoding UTF8
    & ([scriptblock]::Create($code))
}
catch {
    $_ | Out-String | Set-Content -LiteralPath $logPath -Encoding UTF8
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        'Aplikacija nije mogla da se pokrene. Detalji su sačuvani u launcher-error.log.',
        'Video Downloader', 'OK', 'Error'
    ) | Out-Null
}
