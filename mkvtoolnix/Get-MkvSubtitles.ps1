# Given a working directory, scan recursively for MKV files and determine if
# they have Subtitles associated with them.
#
# Written with the assistance of Copilot
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [string]$MkvMergePath = 'C:\DevApps\System\mkvtoolnix\mkvmerge.exe'
)

# Ensure mkvmerge is available
try {
    $null = & $MkvMergePath --version
}
catch {
    Write-Error "mkvmerge not found at [$MkvMergePath]."
    exit 1
}

# Gather MKV files
$files = Get-ChildItem -LiteralPath $Path -Filter *.mkv -Recurse

$results = foreach ($file in $files) {

    # Run mkvmerge identify
    $output = & $MkvMergePath --identify "$($file.FullName)" 2>$null

    # Extract subtitle track lines
    $subtitleTracks = $output |
    Where-Object { $_ -match "subtitles" -or $_ -match "S_TEXT" }

    # Build structured object
    [PSCustomObject]@{
        File           = $file.FullName
        HasSubtitles   = $subtitleTracks.Count -gt 0
        SubtitleTracks = $subtitleTracks
    }
}

# Output the structured report
$results

