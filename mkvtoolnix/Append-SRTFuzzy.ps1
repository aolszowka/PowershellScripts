# Appends an existing SRT file by searching a `subs` folder expected to exist as
# a subdirectory looking for a file that matches the criteria `S\d{2}E\d{2}` and
# ending in `.en.srt` to an existing MKV file.
#
# The match criteria is displayed prior to execution, with the merge only
# occurring when there is only a single SRT found for the file.
#
# Successful operations move the original MKV and SRT file in to a `_Completed`
# folder.
#
# Written with the assistance of Copilot.
param(
    [Parameter(Mandatory = $true)]
    [string]$Directory,
    [string]$MkvMergePath = 'C:\DevApps\System\mkvtoolnix\mkvmerge.exe'
)

# Normalize directory path
$completedDir = Join-Path $Directory "_Completed"
$subsRoot = Join-Path $Directory "subs"

# Ensure _Completed exists
if (-not (Test-Path $completedDir)) {
    New-Item -ItemType Directory -Path $completedDir | Out-Null
}

# Gather MKV files
$mkvFiles = Get-ChildItem -LiteralPath $Directory -Filter *.mkv -File

# Gather all SRT files under subs (any depth)
$allSrtFiles = Get-ChildItem -LiteralPath $subsRoot -Filter *.en.srt -Recurse -File

# Regex for S00E00 pattern
$episodeRegex = 'S\d{2}E\d{2}'

# Build match report
$matchReport = foreach ($mkv in $mkvFiles) {

    $mkvMatch = [regex]::Match($mkv.Name, $episodeRegex)

    if (-not $mkvMatch.Success) {
        [PSCustomObject]@{
            MKV          = $mkv.FullName
            EpisodeToken = $null
            SRT          = $null
            Status       = "❌ No S00E00 token found in MKV name"
        }
        continue
    }

    $token = $mkvMatch.Value

    # Find matching SRT by token
    $matchedSrt = $allSrtFiles | Where-Object { $_.Name -match $token }

    if ($matchedSrt.Count -eq 0) {
        [PSCustomObject]@{
            MKV          = $mkv.FullName
            EpisodeToken = $token
            SRT          = $null
            Status       = "❌ No matching SRT found"
        }
        continue
    }

    if ($matchedSrt.Count -gt 1) {
        [PSCustomObject]@{
            MKV          = $mkv.FullName
            EpisodeToken = $token
            SRT          = ($matchedSrt | Select-Object -ExpandProperty FullName)
            Status       = "⚠ Multiple SRT matches found"
        }
        continue
    }

    # Single match
    [PSCustomObject]@{
        MKV          = $mkv.FullName
        EpisodeToken = $token
        SRT          = $matchedSrt.FullName
        Status       = "OK"
    }
}

# Output report BEFORE processing
Write-Host ""
Write-Host "=== MATCH REPORT ===" -ForegroundColor Cyan
$matchReport | Out-GridView
Write-Host ""
Read-Host -Prompt "Press Any Key To Continue"

# Process only valid matches
foreach ($entry in $matchReport | Where-Object { $_.Status -eq "OK" }) {

    $mkvPath = $entry.MKV
    $srtPath = $entry.SRT
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($mkvPath)

    Write-Host "Merging subtitles for: $baseName" -ForegroundColor Green

    $tempOutput = Join-Path $Directory "${baseName}.new.mkv"
    $finalOutput = Join-Path $Directory "${baseName}.mkv"

    # Build mkvmerge arguments
    $args = @(
        "--output", $tempOutput,
        $mkvPath,
        "--language", "0:en",
        "--default-track", "0:yes",
        $srtPath
    )

    & $MkvMergePath $args

    if ($LASTEXITCODE -ne 0) {
        Write-Error "mkvmerge failed for: $baseName"
        continue
    }

    # Move original MKV + SRT to _Completed
    Move-Item -LiteralPath $mkvPath -Destination $completedDir
    Move-Item -LiteralPath $srtPath -Destination $completedDir

    # Rename new MKV to original name
    Move-Item -LiteralPath $tempOutput -Destination $finalOutput

    Write-Host "✔ Completed: $baseName"
}
