# The intent of this script is to help with mass renaming files ripped via
# MakeMKV to the format S00E00 by giving the Season and Start Episode and then
# assuming that the order of the files based on the Title (IE C_T01.mkv,
# C_T02.mkv) will be the order of the Episodes. It will also rename the parent
# folder to the format `Season.SeasonNumber` to assist Filebot.
function Invoke-SeasonEpisodeNaming {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]
        $Path,
        [Parameter(Position = 1, Mandatory = $true)]
        [string]
        $Season,
        [Parameter(Position = 2, Mandatory = $true)]
        [string]
        $StartEpisode,
        [Parameter(Position = 3, Mandatory = $false)]
        [bool]
        $TreatAsDoubleEpisode = $false
    )
    process {
        if (Test-Path $Path) {
            $filesInFolder = Get-ChildItem -LiteralPath $Path | Sort-Object -Property Name | Select-Object -ExpandProperty FullName

            $titleSort = Sort-ByTitle -Files $filesInFolder

            $renameOperations = Get-RenameOperations -TitleOrder $titleSort -Season $Season -StartEpisode $StartEpisode -TreatAsDoubleEpisode $TreatAsDoubleEpisode

            foreach ($renameOperation in $renameOperations.GetEnumerator()) {
                Move-Item -LiteralPath $renameOperation.Key -Destination $renameOperation.Value
            }

            # Now Move the Folder
            $parentFolder = [System.IO.Path]::GetDirectoryName($Path)
            $newFolderName = "Season.$Season"
            $newPath = [System.IO.Path]::Combine($parentFolder, $newFolderName)
            Move-Item -LiteralPath $Path -Destination $newPath
        }
    }
}

# A List of files that contains an MakeMKV Rip with files the format A1_T09.mkv
# / C1_T09.mkv return a sorted dictionary that contains the files in title
# order.
function Sort-ByTitle {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string[]]
        $Files
    )

    process {
        # We need to sort this by the Title
        [System.Collections.Generic.SortedDictionary[int, string]]$titleSort = [System.Collections.Generic.SortedDictionary[int, string]]::new()
        foreach ($file in $Files) {
            $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($file)
            $titleString = [System.Text.RegularExpressions.Regex]::Match($fileNameWithoutExtension, '(^[A-Z][0-9]|[A-Za-z\)])_t(?<TitleNumber>[0-9]+)').Groups['TitleNumber'].Value
            $title = [int]::Parse($titleString)
            if ($titleSort.ContainsKey($title)) {
                Write-Error "Duplicate Titles Found ([$title]); This Tool Cannot Be Used"
                exit
            }
            else {
                $titleSort.Add($title, $file)
            }
        }

        $titleSort
    }
}

# Given a sorted dictionary that indicates the order in which the files should
# be renamed, return a dictionary that contains the old file name along with the
# newly generated name in S00E00 format.
function Get-RenameOperations {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [System.Collections.Generic.SortedDictionary[int, string]]
        $TitleOrder,
        [Parameter(Position = 1, Mandatory = $true)]
        [string]
        $Season,
        [Parameter(Position = 2, Mandatory = $true)]
        [string]
        $StartEpisode,
        [Parameter(Position = 3, Mandatory = $false)]
        [bool]
        $TreatAsDoubleEpisode = $false
    )
    process {
        [System.Collections.Generic.Dictionary[string, string]]$renameOperations = [System.Collections.Generic.Dictionary[string, string]]::new()

        $currentEpisode = [int]::Parse($StartEpisode)

        # Rename all the files in S00E00 Format
        foreach ($fileKvp in $TitleOrder.GetEnumerator()) {
            $file = $fileKvp.Value
            $parentFolder = [System.IO.Path]::GetDirectoryName($file)
            $fileExtension = [System.IO.Path]::GetExtension($file)
            if ($TreatAsDoubleEpisode) {
                $firstEpisode = $currentEpisode
                $currentEpisode++
                $newName = "S$($Season.PadLeft(2,'0'))E$($firstEpisode.ToString().PadLeft(2,'0'))E$($currentEpisode.ToString().PadLeft(2,'0'))$fileExtension"
            }
            else {
                $newName = "S$($Season.PadLeft(2,'0'))E$($currentEpisode.ToString().PadLeft(2,'0'))$fileExtension"
            }
            $newPath = [System.IO.Path]::Combine($parentFolder, $newName)
            $renameOperations.Add($file, $newPath)
            $currentEpisode++
        }

        $renameOperations
    }
}

Invoke-SeasonEpisodeNaming
