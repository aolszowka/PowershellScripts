# Script to extract all Zip Files to the specified directory; currently we are
# set to "Skip" any files that might be overwritten.

$7zLocation = 'C:\DevApps\System\7za\7za.exe'

function Invoke-ExtractAllZipFiles {
    param (
        [Parameter( Position = 0, Mandatory = $true)]
        [string]
        $Path,
        [Parameter( Position = 1, Mandatory = $true)]
        [string]
        $Destination
    )

    $filters = @('*.zip')
    foreach ($filter in $filters) {
        $sourceFiles = Get-ChildItem -LiteralPath $Path -Filter $filter | Select-Object -ExpandProperty FullName

        foreach ($sourceFile in $sourceFiles) {
            # Extract but also skip any existing files so as not to override
            &$7zLocation x "$sourceFile" -o"$Destination" -aos
        }
    }
}

Invoke-ExtractAllZipFiles
