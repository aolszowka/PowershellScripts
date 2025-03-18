[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $Path
)

$files = Get-ChildItem -LiteralPath $Path
foreach ($file in $files) {
    $newFileName = $file.Name
    $newFileName = $newFileName.Replace(' ', '.')

    $newPath = [System.IO.Path]::Combine($file.Directory, $newFileName)
    Move-Item -Path $file.FullName -Destination $newPath -WhatIf
}
