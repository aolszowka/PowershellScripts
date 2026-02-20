# Toy script to extract screenshots based on the Chapter Markers.
#
# Written with the assistance of Copilot.

param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDirectory,

    [string]$ffmpegPath = 'C:\DevApps\System\ffmpeg\bin\ffmpeg.exe',
    [string]$ffprobePath = 'C:\DevApps\System\ffmpeg\bin\ffprobe.exe'
)

$mkvFiles = Get-ChildItem -LiteralPath $SourceDirectory -Filter *.mkv

foreach ($mkvFile in $mkvFiles) {

    Write-Host "Processing: $($mkvFile.FullName)"

    # Extract chapter metadata as JSON
    $chapterJson = & $ffprobePath -v quiet -print_format json -show_chapters "$($mkvFile.FullName)"
    $chapters = ($chapterJson | ConvertFrom-Json).chapters

    if (-not $chapters) {
        Write-Host "  No chapters found."
        continue
    }

    $chapterIndex = 1

    foreach ($chapter in $chapters) {
        # Chapter start time (in seconds)
        $startSeconds = [double]$chapter.start_time

        # Add 1 second to allow the titles to load
        $startSeconds = $startSeconds + 1

        # Format timestamp for ffmpeg (HH:MM:SS.mmm)
        $ts = [TimeSpan]::FromSeconds($startSeconds).ToString("hh\:mm\:ss\.fff")

        # Output filename
        $chapterName = "Chapter{0:D2}" -f $chapterIndex
        $outputPath = Join-Path $mkvFile.DirectoryName "$($mkvFile.BaseName)_$chapterName.png"

        Write-Host "  Exporting screenshot at $ts → $outputPath"

        # Run ffmpeg
        & $ffmpegPath -v error -y -ss $ts -i "$($mkvFile.FullName)" -frames:v 1 -q:v 2 "$outputPath"

        $chapterIndex++
    }
}
