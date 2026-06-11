param(
    [Parameter(Mandatory = $true)][string]$InstallDirectory,
    [Parameter(Mandatory = $true)][string]$ZipPath,
    [Parameter(Mandatory = $true)][int]$ParentProcessId
)

$ErrorActionPreference = 'Stop'
$logPath = Join-Path $InstallDirectory 'update.log'

try {
    try { Wait-Process -Id $ParentProcessId -Timeout 30 -ErrorAction Stop } catch {}

    $extractDirectory = Join-Path ([IO.Path]::GetDirectoryName($ZipPath)) 'extracted'
    if (Test-Path -LiteralPath $extractDirectory) {
        Remove-Item -LiteralPath $extractDirectory -Recurse -Force
    }
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $extractDirectory -Force

    Get-ChildItem -LiteralPath $extractDirectory -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $InstallDirectory -Recurse -Force
    }

    Add-Content -LiteralPath $logPath -Value "[$(Get-Date -Format s)] Ažuriranje je uspešno instalirano."
    $launcher = Join-Path $InstallDirectory 'Launch-Downloader.ps1'
    $arguments = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + $launcher + '"'
    Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WindowStyle Hidden
}
catch {
    Add-Content -LiteralPath $logPath -Value "[$(Get-Date -Format s)] GREŠKA: $($_.Exception)"
}
finally {
    try { Remove-Item -LiteralPath ([IO.Path]::GetDirectoryName($ZipPath)) -Recurse -Force } catch {}
}
