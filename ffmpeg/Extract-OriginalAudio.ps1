param(
    [Parameter(Mandatory)]
    [string]$InputDirectory,

    # Optional: path to ffmpeg.exe
    [string]$ffmpegPath = 'C:\DevApps\System\ffmpeg\bin\ffmpeg.exe',

    # Optional: path to ffprobe.exe
    [string]$ffprobePath = 'C:\DevApps\System\ffmpeg\bin\ffprobe.exe'
)

# Normalize directory
$dir = (Resolve-Path -LiteralPath $InputDirectory).Path

# Video extensions to process
$videoExts = @("*.avi", "*.mkv", "*.mp4", "*.mov", "*.wmv", "*.flv", "*.mpeg", "*.mpg")

# Map codec → file extension
$extMap = @{
    "aac"       = "aac"
    "mp3"       = "mp3"
    "flac"      = "flac"
    "pcm_s16le" = "wav"
    "pcm_s24le" = "wav"
    "vorbis"    = "ogg"
    "opus"      = "opus"
    "ac3"       = "ac3"
    "eac3"      = "eac3"
}

Write-Host "Scanning directory: $dir"
Write-Host ""

foreach ($pattern in $videoExts) {
    foreach ($file in Get-ChildItem -Recurse -LiteralPath $dir -Filter $pattern) {

        $full = $file.FullName
        $base = [System.IO.Path]::GetFileNameWithoutExtension($full)

        Write-Host "→ Processing: $file"

        # Use ffprobe to get primary audio stream codec
        $probeJson = & $ffprobePath -v quiet -print_format json -show_streams -select_streams a:0 -i $full
        $probe = $probeJson | ConvertFrom-Json

        if (-not $probe.streams) {
            Write-Warning "   No audio stream found — skipping."
            continue
        }

        $codec = $probe.streams[0].codec_name
        $audioExt = $extMap[$codec]

        if (-not $audioExt) {
            Write-Warning "   Unknown codec '$codec' — using generic '.audio'."
            $audioExt = "audio"
        }

        $outFile = Join-Path $file.DirectoryName "$base.audio.$audioExt"

        if (Test-Path $outFile) {
            Write-Host "   Output already exists — skipping."
            continue
        }

        Write-Host "   Extracting → $outFile"

        $ffArgs = @(
            "-y"
            "-i", $full
            "-map", "0:a:0"
            "-c:a", "copy"
            $outFile
        )

        & $ffmpegPath $ffArgs

        Write-Host "   ✔ Done."
        Write-Host ""
    }
}

Write-Host "Batch extraction complete."
