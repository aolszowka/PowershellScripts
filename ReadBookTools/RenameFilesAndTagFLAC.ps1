function Get-EnglishForNumber {
    param(
        [int]$Number
    )
    process {
        $EnglishNumbers = @{
            1  = 'One'
            2  = 'Two'
            3  = 'Three'
            4  = 'Four'
            5  = 'Five'
            6  = 'Six'
            7  = 'Seven'
            8  = 'Eight'
            9  = 'Nine'
            10 = 'Ten'
            11 = 'Eleven'
            12 = 'Twelve'
            13 = 'Thirteen'
            14 = 'Fourteen'
            15 = 'Fifteen'
            16 = 'Sixteen'
            17 = 'Seventeen'
            18 = 'Eighteen'
            19 = 'Nineteen'
            20 = 'Twenty'
            30 = 'Thirty'
            40 = 'Forty'
            50 = 'Fifty'
            60 = 'Sixty'
            70 = 'Seventy'
            80 = 'Eighty'
            90 = 'Ninety'
        }

        $readableNumber = [System.Text.StringBuilder]::new()

        if ($Number -gt 1000000) {
            throw "Numbers greater than 999,999 Not Supported"
        }

        $currentMod = $Number
        $Thousands = [Math]::Round($($currentMod / 1000), [System.MidpointRounding]::ToZero)
        if ($Thousands -ne 0) {
            $ReadableThousands = Get-EnglishForNumber $Thousands
            $readableNumber.Append("$ReadableThousands Thousand ") | Out-Null
        }

        $currentMod = $currentMod % 1000
        $Hundreds = [Math]::Round($($currentMod / 100), [System.MidpointRounding]::ToZero)
        if ($Hundreds -ne 0) {
            $ReadableHundreds = Get-EnglishForNumber $Hundreds
            $readableNumber.Append("$ReadableHundreds Hundred ") | Out-Null
        }

        $currentMod = $currentMod % 100
        $Tens = [Math]::Round($($currentMod / 10), [System.MidpointRounding]::ToZero)
        $currentMod = $currentMod % 10
        if ($Tens -ne 0) {
            if ($Tens -gt 1) {
                [int]$Offset = $Tens * 10
                $ReadableTens = "$($EnglishNumbers[$Offset]) $(Get-EnglishForNumber $currentMod)"
                $readableNumber.Append($ReadableTens) | Out-Null
            }
            else {
                [int]$Offset = ($Tens * 10) + $currentMod
                $readableNumber.Append($EnglishNumbers[$Offset]) | Out-Null
            }
        }
        else {
            if ($currentMod -ne 0) {
                $readableNumber.Append($EnglishNumbers[$currentMod]) | Out-Null
            }
        }

        if ($readableNumber.Length -ne 0) {
            $readableNumber.ToString().Trim()
        }
    }
}

function Invoke-RenameFilesAndTagFLAC {
    param(
        $Path,
        $Artist,
        $Album
    )
    process {
        $files = Get-ChildItem -Path $Path -Filter '*.flac'
        foreach ($file in $files) {
            $metaData = Get-MetadataForFile -Path $file -Artist $Artist -Album $Album
            Set-FLACMetadataForFile -Path $file -FLACMetadata $metaData
            Move-Item -Path $metaData.OriginalPath -Destination $metaData.NewPath
        }
    }
}

function Set-FLACMetadataForFile {
    param (
        [string]$Path,
        [PSCustomObject]$FLACMetadata
    )
    process {
        $metaflacPath = 'C:\DevApps\System\flac\win64\metaflac.exe'

        # We're going to write out the tags to a temporary file and then import
        # from it to avoid issues with any command line parser.
        $tempFile = New-TemporaryFile

        try {
            # Build up the tags file
            $commentsFileString = [System.Text.StringBuilder]::new()
            $commentsFileString.AppendLine("ARTIST=$($FLACMetadata.Artist)") | Out-Null
            $commentsFileString.AppendLine("TITLE=$($FLACMetadata.TrackTitle)") | Out-Null
            $commentsFileString.AppendLine("ALBUM=$($FLACMetadata.Album)") | Out-Null
            $commentsFileString.AppendLine("TRACKNUMBER=$($FLACMetadata.TrackNumber)") | Out-Null
            $commentsFileString.Append("COMMENT=$($FLACMetadata.Comment)") | Out-Null # Last Line No New Line
            $commentsFileString.ToString() | Set-Content -Path $tempFile

            # For now we're just going to overwrite any existing tags with our
            # specified ones
            &$metaflacPath --preserve-modtime --remove-all-tags --import-tags-from=$($tempFile.FullName) $Path
        }
        finally {
            Remove-Item $tempFile
        }
    }
}

function Get-MetadataForFile {
    param(
        $Path,
        $Artist,
        $Album
    )
    process {

        $result = [PSCustomObject]@{
            OriginalPath = $Path
            NewPath      = [string]::Empty
            TrackNumber  = [string]::Empty
            TrackTitle   = [string]::Empty
            Artist       = $Artist
            Album        = $Album
            Comment     = "As read by Ace Olszowka"
        }

        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
        $trackNumberRegex = [System.Text.RegularExpressions.Regex]::Match($fileName, '^(?<TrackNumber>\d+)')
        $trackNumberMatchValue = $trackNumberRegex.Groups['TrackNumber'].Value
        $parsedTrackNumber = [int]::Parse($trackNumberMatchValue)
        $result.TrackNumber = $parsedTrackNumber
        $paddedTrackNumber = $result.TrackNumber.ToString().PadLeft(2, '0')

        if ($parsedTrackNumber -eq 0) {
            # We special case track zero to indicate 'Title'
            $result.TrackTitle = "$paddedTrackNumber - Title"
        }
        else {
            # Now Get the English for this Number
            $englishNumber = Get-EnglishForNumber -Number $parsedTrackNumber
            $result.TrackTitle = "$paddedTrackNumber - Page $englishNumber"
        }

        # Now Generate the New File Path
        $newFileName = "$($result.TrackTitle)$([System.IO.Path]::GetExtension($Path))".Replace(' ', [string]::Empty)
        $result.NewPath = [System.IO.Path]::Combine($([System.IO.Path]::GetDirectoryName($Path)), $newFileName)

        $result
    }
}

$Path = 'C:\Users\ace.olszowka\OneDrive\Mars\Audacity\Read_Books\Llama.Llama.Red.Pajama.Anna.Dewdney'
$Artist = 'Anna Dewdney'
$Album = 'Llama Llama Red Pajama'

Invoke-RenameFilesAndTagFLAC -Path $Path -Artist $Artist -Album $Album
