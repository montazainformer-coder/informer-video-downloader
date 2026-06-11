$ErrorActionPreference = 'Stop'

$git = 'C:\Program Files\Git\cmd\git.exe'
if (-not (Test-Path -LiteralPath $git)) {
    throw 'Git for Windows nije pronadjen.'
}

$version = (Read-Host 'Unesi novu verziju, na primer 1.1.0').Trim().TrimStart('v', 'V')
if ($version -notmatch '^\d+\.\d+\.\d+$') {
    throw 'Verzija mora biti u formatu 1.1.0.'
}

$tag = "v$version"
& $git rev-parse $tag 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    throw "Tag $tag vec postoji. Unesi vecu verziju."
}

$message = (Read-Host 'Kratak opis izmene').Trim()
if (-not $message) { $message = "Release $tag" }

Set-Content -LiteralPath (Join-Path $PSScriptRoot 'version.txt') -Value $version -Encoding ASCII
Push-Location $PSScriptRoot
try {
    & $git add --all
    if ($LASTEXITCODE -ne 0) { throw 'git add nije uspeo.' }

    & $git diff --cached --quiet
    if ($LASTEXITCODE -eq 0) {
        throw 'Nema novih izmena za objavljivanje.'
    }

    & $git commit -m $message
    if ($LASTEXITCODE -ne 0) { throw 'git commit nije uspeo.' }

    & $git tag -a $tag -m $message
    if ($LASTEXITCODE -ne 0) { throw "Kreiranje taga $tag nije uspelo." }

    & $git push origin main
    if ($LASTEXITCODE -ne 0) { throw 'Slanje main grane nije uspelo.' }

    & $git push origin $tag
    if ($LASTEXITCODE -ne 0) { throw "Slanje taga $tag nije uspelo." }

    Write-Host ''
    Write-Host "Objavljena je verzija $tag." -ForegroundColor Green
    Write-Host 'GitHub sada automatski pravi update paket.'
}
finally {
    Pop-Location
}

