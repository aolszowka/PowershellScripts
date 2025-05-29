# Script to set the LastModified Property based on the
# `System.Media.DateEncoded` (aka "Media created" property).
#
# This was created because Google Recorder's downloads did not have the modified
# date of the files based on when they were recorded.

function Set-LastModifiedTimeBasedOnMediaCreatedProperty {
    [CmdletBinding()]
    param (
        [Parameter( Position = 0, ValueFromPipeline = $true, Mandatory = $true)]
        [string]
        $Path
    )

    process {
        if (Test-Path -Path $Path) {
            $folderPath = [System.IO.Path]::GetDirectoryName($Path)
            $fileName = [System.IO.Path]::GetFileName($Path)
            $shellApplication = New-Object -COMObject Shell.Application
            $shellFolder = $shellApplication.NameSpace($folderPath)
            $shellFile = $shellFolder.ParseName($fileName)
            $dateEncodedUtc = $shellFile.ExtendedProperty("System.Media.DateEncoded")
            $dateEncoded = $dateEncodedUtc.ToLocalTime()
            if ($null -ne $dateEncoded) {
                $file = Get-ChildItem -LiteralPath $Path
                $file.LastWriteTime = $dateEncoded
            }
        }
    }
}

function Set-LastModifiedTimeBasedOnMediaCreatedPropertyForFolder {
    [CmdletBinding()]
    param (
        [Parameter( Position = 0, ValueFromPipeline = $true, Mandatory = $true)]
        [string]
        $FolderPath
    )

    process {
        Get-ChildItem -LiteralPath $FolderPath -Filter "*.m4a" | Set-LastModifiedTimeBasedOnMediaCreatedProperty
    }
}

Set-LastModifiedTimeBasedOnMediaCreatedPropertyForFolder
