# Utility script to use FFMPEG to convert FLAC to OGG Vorbis for playback on
# space constrained devices.
#
# Written with the assistance of Copilot

param(
    [Parameter(Mandatory = $true)]
    [string]$InputDir,
    [string]$OutputDir = "E:\Encoded\Ogg",
    [string]$FfmpegPath = "C:\DevApps\System\ffmpeg\bin\ffmpeg.exe"
)

# Ensure output directory exists
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$files = Get-ChildItem -LiteralPath $InputDir -Filter *.flac

if ($files.Count -eq 0) {
    Write-Host "No FLAC files found in $InputDir"
    exit
}

foreach ($file in $files) {
    $outFile = Join-Path $OutputDir (
        [IO.Path]::GetFileNameWithoutExtension($file.Name) + ".ogg"
    )

    Write-Host "Converting $($file.Name) → $(Split-Path $outFile -Leaf)"

    $args = @(
        "-y",
        "-i", "`"$($file.FullName)`"",
        "-map_metadata", "0",          # Copy all metadata from input
        "-c:a", "libvorbis",           # Encode to OGG Vorbis
        "`"$outFile`""
    )

    $proc = Start-Process -FilePath $FfmpegPath -ArgumentList $args -NoNewWindow -Wait -PassThru

    if ($proc.ExitCode -ne 0) {
        Write-Warning "ffmpeg failed on $($file.Name) with exit code $($proc.ExitCode)"
    }
}
