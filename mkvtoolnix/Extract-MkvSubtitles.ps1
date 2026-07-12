# Utility script to use mkvtoolnix tooling (mkvmerge/mkvextract) to extract the
# English subtitles from an mkv file. Useful when attempting to parse for
# episode quotes.
#
# Written with the assistance of Copilot

param(
    [Parameter(Mandatory = $true)]
    [string]$InputFolder,

    [string]$MkvMergePath = "C:\DevApps\System\mkvtoolnix\mkvmerge.exe",
    [string]$MkvExtractPath = "C:\DevApps\System\mkvtoolnix\mkvextract.exe",

    [switch]$Recurse
)

# Build search parameters
$searchParams = @{
    LiteralPath = $InputFolder
    Filter      = '*.mkv'
    File        = $true
}
if ($Recurse) { $searchParams.Recurse = $true }

$files = Get-ChildItem @searchParams

foreach ($file in $files) {

    Write-Host "Processing: $($file.FullName)"

    # Read metadata
    $json = & $MkvMergePath -J "$($file.FullName)" 2>$null
    if (-not $json) {
        Write-Warning "Failed to read track info. Skipping."
        continue
    }

    $data = $json | ConvertFrom-Json

    # Collect English subtitle tracks
    $englishSubs = @()
    foreach ($t in $data.tracks) {
        if ($t.type -eq "subtitles") {
            $lang = $t.properties.language
            if ($lang -match '^en[g]?$') {
                $englishSubs += $t
            }
        }
    }

    if ($englishSubs.Count -eq 0) {
        Write-Host "  No English subtitles found."
        continue
    }

    # Extract each English subtitle track
    $index = 1
    foreach ($sub in $englishSubs) {
        $trackId = $sub.id
        $base = [System.IO.Path]::Combine($file.DirectoryName, $file.BaseName)
        $outFile = "$base.en.$index.srt"

        Write-Host "  Extracting track $trackId → $outFile"

        & $MkvExtractPath 'tracks' "$($file.FullName)" "$($trackId):$outFile"

        $index++
    }

    Write-Host ""
}

Write-Host "All done."
