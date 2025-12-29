# Toy program to recreate an MKV with only English Audio and Subtitles
param(
    [Parameter(Mandatory = $true)]
    [string]$InputFolder,
    [string]$MkvMergePath = 'C:\DevApps\System\mkvtoolnix\mkvmerge.exe',
    [switch]$Recurse
)

# Build search parameters for Get-ChildItem
$searchParams = @{
    LiteralPath = $InputFolder
    Filter      = '*.mkv'
    File        = $true
}
if ($Recurse) { $searchParams.Recurse = $true }

$files = Get-ChildItem @searchParams

foreach ($file in $files) {

    Write-Host "Processing: $($file.FullName)"

    # Get JSON metadata from mkvmerge
    $json = & $MkvMergePath -J "$($file.FullName)" 2>$null
    if (-not $json) {
        Write-Warning "Failed to read track info. Skipping."
        continue
    }

    $data = $json | ConvertFrom-Json

    $audioTracks = @()
    $subtitleTracks = @()

    foreach ($t in $data.tracks) {
        $lang = $t.properties.language
        $id = $t.id

        if ($t.type -eq 'audio') {
            $audioTracks += [PSCustomObject]@{ ID = $id; Lang = $lang }
        }
        elseif ($t.type -eq 'subtitles') {
            $subtitleTracks += [PSCustomObject]@{ ID = $id; Lang = $lang }
        }
    }

    # Filter English tracks (eng or en)
    $englishAudio = $audioTracks    | Where-Object { $_.Lang -match '^en[g]?$' }
    $englishSubs = $subtitleTracks | Where-Object { $_.Lang -match '^en[g]?$' }

    if ($englishAudio.Count -eq 0) {
        Write-Warning "No English audio tracks found. Skipping."
        continue
    }

    if ($englishSubs.Count -eq 0) {
        Write-Warning "No English subtitle tracks found. Skipping."
        continue
    }

    $audioIDs = ($englishAudio.ID) -join ","
    $subIDs = ($englishSubs.ID) -join ","

    # First English subtitle becomes default
    $defaultSubID = $englishSubs[0].ID

    # Output file path
    $outputFile = Join-Path $file.DirectoryName "$($file.BaseName).clean.mkv"

    # Build mkvmerge arguments
    $arguments = @(
        "--audio-tracks", $audioIDs,
        "--subtitle-tracks", $subIDs,
        "--default-track", "$($defaultSubID):yes",
        "-o", $outputFile,
        $file.FullName
    )

    Write-Host "Running mkvmerge..."
    & $MkvMergePath $arguments

    Write-Host "Created: $outputFile"
    Write-Host ""
}

Write-Host "All done."
