<#
.SYNOPSIS
Batch‑removes all audio tracks from MP4 and MKV files in a directory using
FFmpeg.

Written with the assistance of Copilot.

.DESCRIPTION
This script scans a specified directory (non‑recursive) for all .mp4 and .mkv
files and creates new versions of each file with all audio streams removed.
Video streams are copied without re‑encoding for maximum speed and quality
preservation.

Each processed file is written alongside the original using the naming pattern:
    <filename>.noaudio.<ext>

The script accepts an optional path to the FFmpeg executable; if not provided,
it defaults to: C:\DevApps\System\ffmpeg\bin\ffmpeg.exe

.PARAMETER Directory
The directory containing the video files to process.

.PARAMETER ffmpegPath
Optional. Full path to the FFmpeg executable.

.NOTES
- Original files are never modified or overwritten.
- Processing is non‑recursive; only files directly in the target directory are
  used.
#>

param(
    [Parameter(Mandatory)]
    [string]$Directory,
    [string]$ffmpegPath = "C:\DevApps\System\ffmpeg\bin\ffmpeg.exe"
)

# Get all MKV and MP4 files in the directory (non‑recursive by default)
$files = Get-ChildItem -Path "$Directory\*" -Include *.mp4, *.mkv


foreach ($file in $files) {

    $base = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $ext = [System.IO.Path]::GetExtension($file.Name)
    $out = Join-Path $file.DirectoryName "$base.noaudio$ext"

    Write-Host "Processing $($file.Name)..."

    $ffArgs = @(
        "-y"
        "-i", $file.FullName
        "-c:v", "copy"   # keep video as-is
        "-an"            # remove all audio streams
        $out
    )

    & $ffmpegPath $ffArgs
}
