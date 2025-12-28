# Toy script that removes track names, tags, and titles from MKV Files.

function Clean-Mkv {
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string]
        $Path
    )
    process {
        $env:PATH = "C:\DevApps\System\mkvtoolnix;$env:PATH"
        Get-ChildItem -LiteralPath $Path -Recurse -Filter *.mkv | ForEach-Object {
            $file = $_.FullName
            Write-Host "Processing: $file"

            # Parse track info from mkvmerge JSON
            $json = mkvmerge -J --ui-language en $file | ConvertFrom-Json

            # For each track, clear the track name using mkvpropedit
            foreach ($track in $json.tracks) {
                $trackId = $track.id + 1
                Write-Host "  Removing name from track ID $trackId ($($track.type))"
                mkvpropedit $file --edit track:@"$trackId" --set name=
            }

            # Remove all the Tags
            mkvpropedit $file --tags all:

            # Remove Titles
            mkvpropedit $file --delete title
        }
    }
}

Clean-Mkv
