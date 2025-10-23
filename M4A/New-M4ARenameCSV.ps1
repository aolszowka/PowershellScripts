# Generates the CSV file consumed by `Invoke-M4ARenameBasedOnCSV.ps1`
#
# The CSV File is assumed to have the following columns:
#    File
#    Date
#    Title
#    Author
#    Narrator

function Invoke-M4ARenameBasedOnCSV {
    [CmdletBinding()]
    param (
        [Parameter( Position = 0, Mandatory = $true)]
        [string]
        $FolderPath
    )
    process {
        $files = Get-ChildItem -LiteralPath $FolderPath -Filter "*.m4a"

        foreach ($file in $files) {
            [PSCustomObject]@{
                File     = $file.FullName
                Date     = $file.LastWriteTime.ToString("MM/dd/yyyy")
                Title    = ""
                Author   = ""
                Narrator = "Alex, Caitlin, Ace Olszowka"
            }
        }
    }
}

Invoke-M4ARenameBasedOnCSV | Export-Csv -Path "$PSScriptRoot\LookupTable.csv"
