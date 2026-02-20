# Toy script to help extract video sections using FFMPEG.
#
# Written with the assistance of Copilot.

param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile,

    [Parameter(Mandatory = $true)]
    [string]$StartTime,   # Format: HH:MM:SS or seconds

    [Parameter(Mandatory = $true)]
    [string]$EndTime,     # Format: HH:MM:SS or seconds

    [string]$ffmpegPath = "C:\DevApps\System\ffmpeg\bin\ffmpeg.exe",
    [string]$OutputFile
)

# If no output file is provided, auto-generate one
if (-not $OutputFile) {
    $dir = Split-Path $InputFile
    $base = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $ext = [System.IO.Path]::GetExtension($InputFile)
    $OutputFile = Join-Path $dir "$base.trimmed$ext"
}

# Calculate duration (FFmpeg requires duration, not end timestamp)
function Convert-ToSeconds($ts) {
    if ($ts -match "^\d+(\.\d+)?$") {
        return [double]$ts
    }
    $t = [TimeSpan]::Parse($ts)
    return $t.TotalSeconds
}

$startSec = Convert-ToSeconds $StartTime
$endSec = Convert-ToSeconds $EndTime
$duration = $endSec - $startSec

if ($duration -le 0) {
    throw "EndTime must be greater than StartTime."
}

# Run FFmpeg in stream-copy mode (no re-encode)
& $ffmpegPath `
    -y `
    -ss $startSec `
    -i "$InputFile" `
    -t $duration `
    -c copy `
    "$OutputFile" `
    2>$null
