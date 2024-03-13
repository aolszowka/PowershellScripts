# This toy script was created to help perform mass renaming of files based on an
# excel spreadsheet.
function Invoke-MetaFlacRenameBasedOnCSV {
    [CmdletBinding()]
    param (
        [Parameter( Position = 0, Mandatory = $true)]
        [string]
        $Path,
        [Parameter( Position = 1, Mandatory = $true)]
        [string]
        $CSVFile
    )
    process {
        $csvEntries = Import-Csv -LiteralPath $CSVFile
        $fileLookupTable = Get-FileLookupTable -Path $Path

        foreach ($csvEntry in $csvEntries) {
            $fileName = $fileLookupTable[$csvEntry.TrackNumber]
            if (Test-Path -LiteralPath $fileName) {
                $metaFlacObject = [PSCustomObject]@{
                    TrackNumber = $csvEntry.TrackNumber
                    Artist      = $csvEntry.Artist
                    Title       = $csvEntry.Title
                    Album       = $csvEntry.Album
                    Year        = $csvEntry.Year
                }
                Set-FlacMetaData -FlacFile $fileName -MetaFLACObject $metaFlacObject
                Set-FileNameFromFlacMetaData -FlacFile $fileName
            }
            else {
                Write-Error "Unable to find file [$fileName]; this indicates that the CSV had the same track number listed twice"
                exit
            }
        }
    }
}

function Set-FileNameFromFlacMetaData {
    [CmdletBinding()]
    param (
        [Parameter( Position = 0, Mandatory = $true)]
        [string]
        $FlacFile
    )
    begin {
        $metaflacPath = 'C:\DevApps\System\flac\win64\metaflac.exe'
    }

    process {
        # Extract the Existing FLAC Metadata
        $existingMetaDataObject = [PSCustomObject]@{
            Artist      = "$($(&$metaflacPath --show-tag=ARTIST "$FlacFile")?.Replace('ARTIST=', ''))"
            Title       = "$($(&$metaflacPath --show-tag=TITLE "$FlacFile")?.Replace('TITLE=', ''))"
            TrackNumber = "$($(&$metaflacPath --show-tag=TRACKNUMBER "$FlacFile")?.Replace('TRACKNUMBER=', ''))"
        }

        if ($null -eq $existingMetaDataObject.Artist) {
            Write-Error -Message "No Artist Tag Found on [$FlacFile]; This tool cannot be used."
            exit
        }

        if ($null -eq $existingMetaDataObject.Title) {
            Write-Error -Message "No Title Tag Found on [$FlacFile]; This tool cannot be used."
            exit
        }

        if ($null -eq $existingMetaDataObject.TrackNumber) {
            Write-Error -Message "No TrackNumber Tag Found on [$FlacFile]; This tool cannot be used."
            exit
        }

        $newFileName = "$($existingMetaDataObject.TrackNumber) - $($existingMetaDataObject.Artist) - $($existingMetaDataObject.Title)"

        $existingFileName = [System.IO.Path]::GetFileNameWithoutExtension($FlacFile)

        if ($newFileName -ne $existingFileName) {
            $fullNewFileName = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($FlacFile), "$newFileName.flac")

            if (Test-Path -LiteralPath $fullNewFileName) {
                Write-Error "The new destination path [$newFullFilePath] already exists. This tool cannot be used."
                exit
            }
            else {
                Move-Item -LiteralPath $FlacFile -Destination $fullNewFileName
            }
        }
    }
}

function Set-FlacMetaData {
    [CmdletBinding()]
    param (
        [Parameter( Position = 0, Mandatory = $true)]
        [string]
        $FlacFile,
        [Parameter( Position = 1, Mandatory = $true)]
        [PSCustomObject]
        $MetaFLACObject
    )

    begin {
        $metaflacPath = 'C:\DevApps\System\flac\win64\metaflac.exe'
    }

    process {
        if ($null -ne $($MetaFLACObject.Artist)) {
            $existingArtistTag = "$($(&$metaflacPath --show-tag=ARTIST "$FlacFile")?.Replace('ARTIST=', ''))"
            if ($($MetaFLACObject.Artist) -ne $existingArtistTag) {
                &$metaflacPath --remove-tag="ARTIST" "$FlacFile"
                &$metaflacPath --set-tag="ARTIST=$($MetaFLACObject.Artist)" "$FlacFile"
            }
        }

        if ($null -ne $($MetaFLACObject.Title)) {
            $existingTitleTag = "$($(&$metaflacPath --show-tag=TITLE "$FlacFile")?.Replace('TITLE=', ''))"
            if ($($MetaFLACObject.Title) -ne $existingTitleTag) {
                &$metaflacPath --remove-tag="TITLE" "$FlacFile"
                &$metaflacPath --set-tag="TITLE=$($MetaFLACObject.Title)" "$FlacFile"
            }
        }

        if ($null -ne $($MetaFLACObject.Album)) {
            $existingAlbumTag = "$($(&$metaflacPath --show-tag=ALBUM "$FlacFile")?.Replace('ALBUM=', ''))"
            if ($($MetaFLACObject.Album) -ne $existingAlbumTag) {
                &$metaflacPath --remove-tag="ALBUM" "$FlacFile"
                &$metaflacPath --set-tag="ALBUM=$($MetaFLACObject.Album)" "$flacFile"
            }
        }

        if ($null -ne $($MetaFLACObject.Year)) {
            $existingYearTag = "$($(&$metaflacPath --show-tag=YEAR "$FlacFile")?.Replace('YEAR=', ''))"
            if ($($MetaFLACObject.Year) -ne $existingYearTag) {
                &$metaflacPath --remove-tag="YEAR" "$FlacFile"
                &$metaflacPath --set-tag="YEAR=$($MetaFLACObject.Year)" "$flacFile"
            }
        }

        if ($null -ne $($MetaFLACObject.TrackNumber)) {
            $existingTrackNumberTag = "$($(&$metaflacPath --show-tag=TRACKNUMBER "$FlacFile")?.Replace('TRACKNUMBER=', ''))"
            if ($($MetaFLACObject.TrackNumber) -ne $existingTrackNumberTag) {
                &$metaflacPath --remove-tag="TRACKNUMBER" "$FlacFile"
                &$metaflacPath --set-tag="TRACKNUMBER=$($MetaFLACObject.TrackNumber)" "$flacFile"
            }
        }
    }
}

function Get-FileLookupTable {
    [CmdletBinding()]
    param (
        [Parameter( Position = 0, Mandatory = $true)]
        [string]
        $Path
    )

    process {
        $files = Get-ChildItem -LiteralPath $Path -Filter '*.flac'

        [System.Collections.Generic.SortedDictionary[int, string]]$fileLookupTable = [System.Collections.Generic.SortedDictionary[int, string]]::new()

        foreach ($file in $files.FullName) {
            # Assume that the numbers at the start of the file name are the
            # track number
            $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($file)
            $trackNumberString = [System.Text.RegularExpressions.Regex]::Match($fileNameWithoutExtension, '^(?<TrackNumber>[0-9]+)').Groups['TrackNumber'].Value
            if ($null -eq $trackNumberString) {
                Write-Error "Error Parsing Track Number From [$fileNameWithoutExtension]; This tool cannot be used."
                exit
            }

            $trackNumber = [int]::Parse($trackNumberString)
            if ($null -eq $trackNumber) {
                Write-Error "Error Parsing Track Number From [$trackNumberString]; This tool cannot be used."
                exit
            }

            if ($fileLookupTable.ContainsKey($trackNumber)) {
                Write-Error "Duplicate Tracks Found ([$trackNumber]); This tool cannot be used."
                exit
            }
            else {
                $fileLookupTable.Add($trackNumber, $file)
            }
        }

        $fileLookupTable
    }
}

Invoke-MetaFlacRenameBasedOnCSV
