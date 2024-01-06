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
        $StartEpisode
    )
    process {
        if (Test-Path $Path) {
            $filesInFolder = Get-ChildItem -LiteralPath $Path | Sort-Object -Property Name | Select-Object -ExpandProperty FullName

            # We need to sort this by the Title
            [System.Collections.Generic.SortedDictionary[string, string]]$titleSort = [System.Collections.Generic.SortedDictionary[string, string]]::new()
            foreach ($file in $filesInFolder) {
                $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($file)
                $title = [System.Text.RegularExpressions.Regex]::Match($fileNameWithoutExtension, '[A-Z][0-9]_t(?<TitleNumber>[0-9]+)').Groups['TitleNumber'].Value
                if ($titleSort.ContainsKey($title)) {
                    Write-Error "Duplicate Titles Found; This Tool Cannot Be Used"
                    exit
                }
                else {
                    $titleSort.Add($title, $file)
                }
            }

            $currentEpisode = [int]::Parse($StartEpisode)

            # Rename all the files in S00E00 Format
            foreach ($fileKvp in $titleSort.GetEnumerator()) {
                $file = $fileKvp.Value
                $parentFolder = [System.IO.Path]::GetDirectoryName($file)
                $fileExtension = [System.IO.Path]::GetExtension($file)
                $newName = "S$($Season.PadLeft(2,'0'))E$($currentEpisode.ToString().PadLeft(2,'0'))$fileExtension"
                $newPath = [System.IO.Path]::Combine($parentFolder, $newName)
                Move-Item -LiteralPath $file -Destination $newPath
                $currentEpisode++
            }

            # Now Move the Folder
            $parentFolder = [System.IO.Path]::GetDirectoryName($Path)
            $newFolderName = "Season.$Season"
            $newPath = [System.IO.Path]::Combine($parentFolder, $newFolderName)
            Move-Item -LiteralPath $Path -Destination $newPath
        }
    }
}

Invoke-SeasonEpisodeNaming
