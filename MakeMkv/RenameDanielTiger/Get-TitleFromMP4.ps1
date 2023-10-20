$targetPath = 'E:\Shows\Daniel.Tiger'

$mp4Files = Get-ChildItem -Path $targetPath -Filter '*.mp4'

# See https://learn.microsoft.com/en-us/windows/win32/shell/shell-application
$shellApplication = New-Object -ComObject "Shell.Application"

$fileInfo = foreach ($mp4File in $mp4Files) {

    $parentFolder = [System.IO.Path]::GetDirectoryName($mp4File)
    $fileName = [System.IO.Path]::GetFileName($mp4File)

    # See https://learn.microsoft.com/en-us/windows/win32/shell/shell-namespace
    $folderObject = $shellApplication.NameSpace($parentFolder)

    # See https://learn.microsoft.com/en-us/windows/win32/shell/folder-parsename
    $folderItem = $folderObject.ParseName($fileName)

    # Magic Number 21 - Title From https://stackoverflow.com/a/37061433/433069
    $title = $folderObject.GetDetailsOf($folderItem, 21)

    if ([string]::IsNullOrWhiteSpace($title)) {
        Write-Warning "Failed to Find Title for [$mp4File]"
        # When this happens we simply pass the file name in as the title.
        [PSCustomObject]@{
            FileName = $mp4File
            # The magic number 34 came from the fact that all of the source
            # files looked like `Daniel Tiger_s Neighborhood_S07E05_Daniel Makes
            # a Noise Maker_Daniel Makes the Neighborhood` cutting off at 35
            # allowed us just to get the title. We also replace _ with / as that
            # is assumed to be the invalid character there.
            Title    = $([System.IO.Path]::GetFileNameWithoutExtension($mp4File)).Substring(35).Trim().Replace('_', '/')
        }
    }
    else {
        [PSCustomObject]@{
            FileName = $mp4File
            Title    = $title
        }
    }
}

$fileInfo | Export-Csv $PSScriptRoot\BadNames.csv
