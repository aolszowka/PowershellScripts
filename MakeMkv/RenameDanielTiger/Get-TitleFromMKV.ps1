$targetPath = 'D:\MakeMKV\Encoded'
$mkvInfoPath = 'C:\DevApps\System\mkvtoolnix\mkvinfo.exe'

$mkvFiles = Get-ChildItem -Path $targetPath -Filter '*.mkv'

$fileInfo = foreach ($mkvFile in $mkvFiles) {
    $mkvResult = &$mkvInfoPath "$mkvFile"

    $title = $mkvResult | ForEach-Object { if ($_.StartsWith('| + Title:')) { $_.Substring(10).Trim() } }

    if ($null -eq $title) {
        Write-Warning "Failed to Find Title for [$mkvFile]"
        # When this happens we simply pass the file name in as the title.
        [PSCustomObject]@{
            FileName = $mkvFile
            # The magic number 34 came from the fact that all of the source
            # files looked like `Daniel Tiger_s Neighborhood_S07E05_Daniel Makes
            # a Noise Maker_Daniel Makes the Neighborhood` cutting off at 34
            # allowed us just to get the title.
            Title    = $([System.IO.Path]::GetFileNameWithoutExtension($mkvFile)).Substring(34).Trim()
        }
    }
    else {
        [PSCustomObject]@{
            FileName = $mkvFile
            Title    = $title
        }
    }
}

$fileInfo | Export-Csv $PSScriptRoot\BadNames.csv
