# Toy Script to mass edit MKV Metadata using a CSV File
# CSV File is expected to be in the following format:
# FileName,Title
$mkvPropEdit = 'C:\DevApps\System\mkvtoolnix\mkvpropedit.exe'

function Get-ItemListing {
    param(
        $TargetPath
    )
    process {
        $fileNames = Get-ChildItem -LiteralPath $TargetPath -Recurse -Filter '*.mkv' | Select-Object -ExpandProperty FullName
        # Start to build up the title based on the file naming convention
        foreach ($fileName in $fileNames) {
            $title = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
            $title = $title.Replace('.', ' ')
            $seasonEpisodeString = [System.Text.RegularExpressions.Regex]::Match($title, 'S[0-9]+E[0-9]+')
            $title = $title.Insert($seasonEpisodeString.Index, '- ')
            # Calculate Again to Add it After
            $seasonEpisodeString = [System.Text.RegularExpressions.Regex]::Match($title, 'S[0-9]+E[0-9]+')
            $title = $title.Insert($seasonEpisodeString.Index + $seasonEpisodeString.Length, ' -')
            $title = "$title"

            [PSCustomObject]@{FileName = $fileName; Title = $title }
        }
    }
}

function Invoke-MkvMetadataRewrite {
    param(
        $InputCsv
    )
    process {
        $renameOperations = Import-Csv $InputCsv

        foreach ($renameOperation in $renameOperations) {
            &$mkvPropEdit $renameOperation.FileName --edit info --set "title=$($renameOperation.Title)"
        }
    }
}

# You can quickly list out the files that would need to be renamed using this tool
#Get-ItemListing -TargetPath 'D:\Input' | Export-Csv -Path $PSScriptRoot\Rename.csv -NoTypeInformation
# Assumes you've edited the above CSV
#Invoke-MkvMetadataRewrite -InputCsv $PSScriptRoot\Rename.csv
