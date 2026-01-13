# Appends an existing SRT file (in the form `basefile.en.srt`) to an existing
# MKV file and then moves the file into a `_Completed` folder.
#
# Written with the assistance of Copilot.
param(
    [Parameter(Mandatory = $true)]
    [string]$Directory,
    [string]$MkvMergePath = 'C:\DevApps\System\mkvtoolnix\mkvmerge.exe'
)

# Normalize directory path
$Directory = (Resolve-Path $Directory).Path
$completedDir = Join-Path $Directory "_Completed"

# Ensure _Completed exists
if (-not (Test-Path $completedDir)) {
    New-Item -ItemType Directory -Path $completedDir | Out-Null
}

# Get MKV files only
$mkvFiles = Get-ChildItem -LiteralPath $Directory -Filter *.mkv -File

foreach ($mkv in $mkvFiles) {

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($mkv.Name)
    $srtPath = Join-Path $Directory "$baseName.en.srt"

    if (-not (Test-Path $srtPath)) {
        Write-Warning "No matching .en.srt found for: $($mkv.Name)"
        continue
    }

    # Temporary output file (avoid overwriting during merge)
    $tempOutput = Join-Path $Directory "${baseName}.new.mkv"

    Write-Host "Merging subtitles into: $($mkv.Name)"

    # Build mkvmerge arguments
    $args = @(
        "--output", $tempOutput,
        $mkv.FullName,
        "--language", "0:en",
        "--default-track", "0:yes",
        $srtPath
    )

    # Run mkvmerge
    & $MkvMergePath $args

    if ($LASTEXITCODE -ne 0) {
        Write-Error "mkvmerge failed for: $($mkv.Name)"
        continue
    }

    # Replace original MKV with new one
    $finalOutput = Join-Path $Directory "$baseName.mkv"

    # Move original MKV + SRT to _Completed
    Move-Item -LiteralPath $mkv.FullName -Destination $completedDir
    Move-Item -LiteralPath $srtPath -Destination $completedDir

    # Rename new MKV to original name
    Move-Item -LiteralPath $tempOutput -Destination $finalOutput

    Write-Host "✔ Completed: $baseName"
}
