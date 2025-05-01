# Script to move files into a datebased folder. Assumes that the first 8
# characters of the file name represent the date or folder name to push these
# files into. Works for both *.flac and *.srt files.
function Move-IntoDateBasedFolder {
    param (
        [Parameter( Position = 0, Mandatory = $true)]
        [string]
        $Path
    )

    $filters = @('*.flac', '*.flac.srt')
    foreach ($filter in $filters) {
        $sourceFiles = Get-ChildItem -LiteralPath $Path -Filter $filter | Select-Object -ExpandProperty FullName

        foreach ($sourceFile in $sourceFiles) {
            $date = [System.IO.Path]::GetFileNameWithoutExtension($sourceFile).Substring(0, 8)
            $destinationFolder = [System.IO.Path]::Combine($Path, $date)
            if (-Not(Test-Path $destinationFolder)) {
                New-Item -Path $destinationFolder -ItemType Directory
            }

            Move-Item -LiteralPath $sourceFile -Destination $destinationFolder
        }
    }
}

Move-IntoDateBasedFolder
