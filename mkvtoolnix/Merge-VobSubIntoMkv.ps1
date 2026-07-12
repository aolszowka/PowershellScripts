# Utility script to use mkvmerge to merge in VobSub Subtitles into a single MKV
#
# Written with the assistance of Copilot
param(
    [Parameter(Mandatory)]
    [string]$Directory,

    [Parameter()]
    [string]$MkvMerge = 'C:\DevApps\System\mkvtoolnix\mkvmerge.exe'
)

# Ensure directory exists
if (-not (Test-Path $Directory)) {
    throw "Directory not found: $Directory"
}

$completed = Join-Path $Directory "_Completed"
if (-not (Test-Path $completed)) {
    New-Item -ItemType Directory -Path $completed | Out-Null
}

# Find all MKVs that have matching IDX/SUB
$mkvs = Get-ChildItem $Directory -Filter *.mkv

foreach ($mkv in $mkvs) {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($mkv.Name)

    $idx = Join-Path $Directory "$base.idx"
    $sub = Join-Path $Directory "$base.sub"

    if (-not ($(Test-Path $idx) -and $(Test-Path $sub))) {
        Write-Host "Skipping $($base): IDX/SUB pair not found."
        continue
    }

    $output = Join-Path $Directory "${base}-merged.mkv"

    Write-Host "Merging: $base.mkv + $base.idx/$base.sub"

    # mkvmerge only needs the IDX; it automatically pulls in the SUB
    $args = @(
        "-o", $output,
        $mkv.FullName,
        $idx
    )

    & $MkvMerge @args

    Write-Host "Moving original files to _Completed..."
    Move-Item $mkv.FullName -Destination $completed
    Move-Item $idx -Destination $completed
    Move-Item $sub -Destination $completed

    Write-Host "Completed: $output"
}
