# Toy program that merges mp4 and srt files into a single MKV File using
# mkvmerge. Assumes the SRT file found is English and that you wish to set it as
# the default track.
param(
    [Parameter(Mandatory = $true)]
    [string]$InputDirectory,
    [string]$MkvMergePath = 'C:\DevApps\System\mkvtoolnix\mkvmerge.exe',
    [switch]$Recurse
)

# Normalize directory path
$InputDirectory = (Resolve-Path $InputDirectory).Path

Write-Host "Scanning directory: $InputDirectory"

# Find all MP4 files (with optional recursion)
$mp4Files = Get-ChildItem -LiteralPath $InputDirectory -Filter *.mp4 -File -Recurse:$Recurse

foreach ($mp4 in $mp4Files) {

    $dir = $mp4.DirectoryName
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($mp4.Name)
    $srtPath = Join-Path $dir "$baseName.srt"

    if (-Not (Test-Path $srtPath)) {
        Write-Warning "No SRT found for: $($mp4.FullName)"
        continue
    }

    $outputMkv = Join-Path $dir "$baseName.mkv"

    Write-Host "Creating MKV for: $baseName"

    # Build mkvmerge command
    $args = @(
        "--output", $outputMkv,
        $mp4.FullName,
        "--language", "0:en",
        "--default-track", "0:yes",
        $srtPath
    )

    # Run mkvmerge
    & $MkvMergePath $args

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully created: $outputMkv"
    }
    else {
        Write-Error "mkvmerge failed for: $baseName"
    }
}
