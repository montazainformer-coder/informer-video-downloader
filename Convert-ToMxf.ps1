param(
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [Parameter(Mandatory = $true)][string]$FfmpegPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ManifestPath)) { throw 'Lista preuzetih fajlova nije pronadjena.' }
if (-not (Test-Path -LiteralPath $FfmpegPath)) { throw 'FFmpeg nije pronadjen.' }

$files = @(Get-Content -LiteralPath $ManifestPath -Encoding UTF8 | Where-Object { $_ -and (Test-Path -LiteralPath $_) })
if (-not $files.Count) { throw 'Nema MP4 fajlova za MXF konverziju.' }

foreach ($inputPath in $files) {
    $outputPath = [IO.Path]::ChangeExtension($inputPath, '.mxf')
    Write-Output "[MXF] Konvertujem: $([IO.Path]::GetFileName($inputPath))"
    & $FfmpegPath -hide_banner -y -i $inputPath `
        -map 0:v:0 -map '0:a:0?' -map_metadata 0 `
        -c:v dnxhd -profile:v dnxhr_hq -pix_fmt yuv422p `
        -c:a pcm_s24le -ar 48000 -f mxf $outputPath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outputPath)) {
        throw "MXF konverzija nije uspela: $inputPath"
    }
    $sourceSidecar = "$inputPath.source.txt"
    if (Test-Path -LiteralPath $sourceSidecar) {
        Move-Item -LiteralPath $sourceSidecar -Destination "$outputPath.source.txt" -Force
    }
    Remove-Item -LiteralPath $inputPath -Force
    Write-Output "[MXF] Zavrseno: $outputPath"
}

Remove-Item -LiteralPath $ManifestPath -Force -ErrorAction SilentlyContinue
