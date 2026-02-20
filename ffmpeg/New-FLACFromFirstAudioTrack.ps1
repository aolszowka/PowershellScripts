# Toy script to extract the first audio track into FLAC.
#
# Written with the assistance of Copilot.

param(
    [Parameter(Mandatory)]
    [string]$InputFile,
    [string]$ffmpegPath = "C:\DevApps\System\ffmpeg\bin\ffmpeg.exe",
    [string]$OutputFile = ""
)

# If no output file specified, auto-generate one
if (-not $OutputFile) {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $dir = [System.IO.Path]::GetDirectoryName($InputFile)
    $OutputFile = Join-Path $dir "$base.flac"
}

# Build ffmpeg arguments
$ffArgs = @(
    "-y"                # overwrite output
    "-i", $InputFile    # input file
    "-map", "0:a:0"     # select first audio track
    "-c:a", "flac"      # encode as FLAC
    $OutputFile
)

# Run ffmpeg
& $ffmpegPath $ffArgs
