# Toy script to export a screenshot from a video file using ffmpeg.
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDirectory,
    [string]$ffmpegPath = 'C:\DevApps\System\ffmpeg\bin\ffmpeg.exe'
)

$mkvFiles = Get-ChildItem -LiteralPath $SourceDirectory -Filter *.mkv

foreach ($mkvFile in $mkvFiles) {
    $screenShotPath1 = [System.IO.Path]::Combine($mkvFile.DirectoryName, "$($mkvFile.BaseName)_Title1.png")
    &$ffmpegPath -ss "00:01:01" -i "$($mkvFile.FullName)" -frames:v 1 "$screenShotPath1"
}
