# Toy Script to mass edit MKV Metadata using a CSV File
# CSV File is expected to be in the following format:
# FileName,Title
$mkvPropEdit = 'C:\DevApps\System\mkvtoolnix\mkvpropedit.exe'
$mkvMerge = 'C:\DevApps\System\mkvtoolnix\mkvmerge.exe'

# Creates PowerShell Objects that contain a FileName and Title property
# generated based on the file name.
function Get-ItemListing {
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string]
        $Path,
        [Parameter(Position = 1, Mandatory = $false)]
        [bool]
        $IncludeSeasonAndEpisode = $false,
        [Parameter(Position = 2, Mandatory = $false)]
        [bool]
        $IncludeSeriesName = $true
    )
    process {
        # Use LiteralPath to work around bug with Get-ChildItem with paths that
        # contain square brackets. See:
        # https://stackoverflow.com/q/33721892/433069
        $fileNames = Get-ChildItem -LiteralPath $Path -Recurse -Filter '*.mkv' | Select-Object -ExpandProperty FullName

        # Start to build up the title based on the file naming convention
        foreach ($fileName in $fileNames) {
            $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
            $title = Get-TitleFromFileName -FileName $fileNameWithoutExtension -IncludeSeriesName $IncludeSeriesName -IncludeSeasonAndEpisode $IncludeSeasonAndEpisode

            [PSCustomObject]@{FileName = $fileName; Title = $title }
        }
    }
}

# Extract the Title from the File Name
function Get-TitleFromFileName {
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string]
        $FileName,
        [Parameter(Position = 1, Mandatory = $false)]
        [bool]
        $IncludeSeasonAndEpisode = $false,
        [Parameter(Position = 2, Mandatory = $false)]
        [bool]
        $IncludeSeriesName = $true
    )
    process {
        $sanitizedFileName = $FileName
        if (-Not $sanitizedFileName.Contains(" ")) {
            # If there are no spaces in the file name; assume that `.` is
            # used as a space delimiter.
            $sanitizedFileName = $sanitizedFileName.Replace('.', ' ')
        }

        # Support for Absolute Ordering (No Seasons)
        # Watch out for Double Episodes!
        $seasonEpisodeMatch = [System.Text.RegularExpressions.Regex]::Match($sanitizedFileName, '(S[0-9]+)?E[0-9]+(-E[0-9]+)?')
        $episodeTitle = $sanitizedFileName.Substring($seasonEpisodeMatch.Index + $seasonEpisodeMatch.Length).Trim()

        # Handle additional Dashes
        while ($episodeTitle.StartsWith('-') -or $episodeTitle.EndsWith('-')) {
            $episodeTitle = $episodeTitle.Trim('-')
            $episodeTitle = $episodeTitle.Trim()
        }

        $constructedTitle = [string]::Empty
        if ($IncludeSeriesName) {
            $seriesName = $sanitizedFileName.Substring(0, $seasonEpisodeMatch.Index).Trim()

            # Handle when the series name was not in the filename
            if (-Not [string]::IsNullOrEmpty($seriesName)) {
                $constructedTitle = $seriesName
            }
        }

        if ($IncludeSeasonAndEpisode) {
            if ([string]::IsNullOrEmpty($constructedTitle)) {
                $constructedTitle = $seasonEpisodeMatch.Value
            }
            else {
                $constructedTitle = "$constructedTitle - $($seasonEpisodeMatch.Value)"
            }
        }

        if ([string]::IsNullOrEmpty($constructedTitle)) {
            $constructedTitle = $episodeTitle
        }
        else {
            $constructedTitle = "$constructedTitle - $episodeTitle"
        }

        $constructedTitle
    }
}

function Get-MkvTitles {
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string]
        $Path
    )
    process {
        # Use LiteralPath to work around bug with Get-ChildItem with paths that
        # contain square brackets. See:
        # https://stackoverflow.com/q/33721892/433069
        $fileNames = Get-ChildItem -LiteralPath $Path -Recurse -Filter '*.mkv' | Select-Object -ExpandProperty FullName

        # Get the MKV Title (if it exists; otherwise this will be blank)
        foreach ($fileName in $fileNames) {
            $mkvProperties = &$mkvMerge --identification-format json --identify "$fileName" | ConvertFrom-Json
            [PSCustomObject]@{
                FileName = $fileName
                Title    = $mkvProperties.container.properties.title
            }
        }
    }
}

function Remove-MkvTitles {
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string]
        $Path
    )
    process {
        # Use LiteralPath to work around bug with Get-ChildItem with paths that
        # contain square brackets. See:
        # https://stackoverflow.com/q/33721892/433069
        $fileNames = Get-ChildItem -LiteralPath $Path -Recurse -Filter '*.mkv' | Select-Object -ExpandProperty FullName

        foreach ($fileName in $fileNames) {
            &$mkvPropEdit $fileName --delete title
        }
    }
}

# Given an Input CSV wherein the first column is `FileName` and the second
# column is `Title` use `mkvpropedit.exe` to set the Title.
function Invoke-MkvMetadataRewrite {
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string]
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
#Get-ItemListing | Export-Csv -Path $PSScriptRoot\Rename.csv -NoTypeInformation
#Get-MkvTitles | Export-Csv -Path $PSScriptRoot\ExistingTitles.csv
#Remove-MkvTitles
# Assumes you've edited the above CSV
#Invoke-MkvMetadataRewrite -InputCsv $PSScriptRoot\Rename.csv
