# This toy script was created to help perform mass renaming of files based on a
# CSV.
#
# The CSV File is assumed to have the following columns:
#    File
#    Date
#    Title
#    Author
#    Narrator
#
# * `Author` column will be mapped to the `Contributing artists` metadata
# * `Narrator` column will be mapped to the `Artist` metadata
# * `Date` column will be mapped to the `Comments` metadata
function Invoke-M4ARenameBasedOnCSV {
    [CmdletBinding()]
    param (
        [Parameter( Position = 0, Mandatory = $true)]
        [string]
        $CSVFile
    )
    begin {
        # This is only required if attempting to edit M4A metadata
        $windowsAPICodePackShellDll = "$PSScriptRoot\Microsoft.WindowsAPICodePack.Shell.dll"

        if (Test-Path $windowsAPICodePackShellDll) {
            Add-Type -Path $windowsAPICodePackShellDll
        }
    }
    process {
        $csvEntries = Import-Csv -LiteralPath $CSVFile

        # First make sure all files are really M4A
        $uniqueFileExtensions = $csvEntries | ForEach-Object { [System.IO.Path]::GetExtension($_.File) } | Select-Object -Unique
        if (($uniqueFileExtensions | Measure-Object).Count -ne 1 -or $uniqueFileExtensions -ne '.m4a') {
            Write-Error -Message "All files were not m4a; This tool cannot be used."
            exit
        }

        # Process the files in Parallel
        # We have to pass any custom functions used to the inner jobs
        $getSafeFileNameFromCSVEntryDef = ${function:Get-SafeFileNameFromCSVEntry}.ToString()
        $csvEntries | ForEach-Object -ThrottleLimit 10 -Parallel {
            $currentCsvEntry = $_

            # Import the custom functions
            ${function:Get-SafeFileNameFromCSVEntry} = $using:getSafeFileNameFromCSVEntryDef

            # There really doesn't seem to be a way to do this within PowerShell;
            # See this guy [0]. I think the key is to use something like they do in
            # C# using the Windows API Code pack [1] If you look at the underlying
            # code[2] he'll eventually call down into IShellItem2::GetPropertyStore
            # [3] and then call IPropertyStore::SetValue [4], however these are the
            # C++ API's which do not appear to be exposed via COM, which means there
            # is no straight forward way within PowerShell to accomplish this.
            #
            # [0]-https://stackoverflow.com/questions/65228096/powershell-changing-mp4-metadata-right-click-properties
            # [1]-https://stackoverflow.com/questions/24040248/is-it-possible-to-set-edit-a-file-extended-properties-with-windows-api-code-pack
            # [2]-https://github.com/aybe/Windows-API-Code-Pack-1.1/blob/master/source/WindowsAPICodePack/Shell/PropertySystem/ShellPropertyWriter.cs
            # [3]-https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-ishellitem2-getpropertystore
            # [4]-https://learn.microsoft.com/en-us/windows/win32/api/propsys/nf-propsys-ipropertystore-setvalue
            $shellFile = [Microsoft.WindowsAPICodePack.Shell.ShellFile]::FromFilePath($currentCsvEntry.File)
            $propertyWriter = $shellFile.Properties.GetPropertyWriter()
            # Ideally we'd use
            # `Microsoft.WindowsAPICodePack.Shell.PropertySystem.SystemProperties.System.Title`
            # but for some reason I was unable to load this static type?
            $titlePropertyKey = [Microsoft.WindowsAPICodePack.Shell.PropertySystem.PropertyKey]::new([Guid]::new("{F29F85E0-4FF9-1068-AB91-08002B27B3D9}"), 2)
            $propertyWriter.WriteProperty($titlePropertyKey, $currentCsvEntry.Title)
            $commentPropertyKey = [Microsoft.WindowsAPICodePack.Shell.PropertySystem.PropertyKey]::new([Guid]::new("{F29F85E0-4FF9-1068-AB91-08002B27B3D9}"), 6)
            $propertyWriter.WriteProperty($commentPropertyKey, $currentCsvEntry.Date)
            # See https://github.com/MicrosoftDocs/win32/blob/docs/desktop-src/medfound/metadata-properties-for-media-files.md
            # See https://github.com/MicrosoftDocs/win32/blob/docs/desktop-src/properties/props-system-music-artist.md
            $artistPropertyKey = [Microsoft.WindowsAPICodePack.Shell.PropertySystem.PropertyKey]::new([Guid]::new("{56A3372E-CE9C-11D2-9F0E-006097C686F6}"), 2)
            $propertyWriter.WriteProperty($artistPropertyKey, $currentCsvEntry.Author)
            # See https://github.com/MicrosoftDocs/win32/blob/docs/desktop-src/properties/props-system-music-albumartist.md
            $albumArtistPropertyKey = [Microsoft.WindowsAPICodePack.Shell.PropertySystem.PropertyKey]::new([Guid]::new("{56A3372E-CE9C-11D2-9F0E-006097C686F6}"), 13)
            $propertyWriter.WriteProperty($albumArtistPropertyKey, $currentCsvEntry.Narrator)
            $propertyWriter.Close()

            $newFileName = Get-SafeFileNameFromCSVEntry -CSVEntry $currentCsvEntry
            Move-Item -Path $currentCsvEntry.File -Destination $newFileName

            # Lets save the Text File Too
            $sourceTextFile = [System.Text.RegularExpressions.Regex]::Replace($currentCsvEntry.File, '\.m4a$', '.txt')
            $destinationTextFile = [System.Text.RegularExpressions.Regex]::Replace($newFileName, '\.m4a$', '.txt')
            Move-Item -Path $sourceTextFile -Destination $destinationTextFile
        }
    }
}

function Get-SafeFileNameFromCSVEntry {
    [CmdletBinding()]
    param (
        [Parameter( Position = 0, Mandatory = $true)]
        $CSVEntry
    )
    process {
        # First Author Only
        $firstAuthorOnly = $CSVEntry.Author
        $indexOfSemiColon = $firstAuthorOnly.IndexOf(';')
        if ($indexOfSemiColon -gt 0) {
            $firstAuthorOnly = $($CSVEntry.Author).Substring(0, $indexOfSemiColon)
        }

        # Convert Date to yyyyMMdd Format
        $dateTime = [DateTime]::Parse($CSVEntry.Date)
        $formattedDate = $dateTime.ToString('yyyyMMdd')

        $proposedFileName = "$($CSVEntry.Title) - $firstAuthorOnly - $($CSVEntry.Narrator) - $formattedDate"
        $proposedFileNameFileSystemSafe = [string]::Concat($proposedFileName.Split([System.IO.Path]::GetInvalidFileNameChars()))

        if ($proposedFileName -ne $proposedFileNameFileSystemSafe) {
            Write-Warning "Had to remove unsafe characters from proposed file name [$proposedFileName] resulted in [$proposedFileNameFileSystemSafe]"
        }

        $currentDirectory = [System.IO.Path]::GetDirectoryName($CSVEntry.File)
        $fileSystemSafePath = [System.IO.Path]::Combine($currentDirectory, "$proposedFileNameFileSystemSafe.m4a")

        $fileSystemSafePath
    }
}
