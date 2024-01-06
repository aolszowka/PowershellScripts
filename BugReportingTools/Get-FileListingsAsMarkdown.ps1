################################################################################
# This toy script allows you to pass in a directory along with a list of file
# extensions to convert them all to markdown for ease in reporting bug reports
# on GitHub.
#
# See https://github.com/MicrosoftPremier/VstsExtensions/issues/223 for an
# example of this script in use.
################################################################################
$targetDirectory = $PSScriptRoot

# Use a case insensitive HashSet to avoid any casing issues
$supportedExtensions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::InvariantCultureIgnoreCase)
$supportedExtensions.Add('.cs') | Out-Null
$supportedExtensions.Add('.csproj') | Out-Null
$supportedExtensions.Add('.sln') | Out-Null
$supportedExtensions.Add('.yml') | Out-Null

$filesToPrint = Get-ChildItem -Path $targetDirectory -Recurse | Where-Object { $supportedExtensions.Contains($_.Extension) }

foreach ($file in $filesToPrint) {
    Write-Host "**$($file.Name)**"
    $fileType = [string]::Empty
    switch ($file.Extension) {
        '.cs' {
            $fileType = 'csharp'
        }
        '.csproj' {
            $fileType = 'xml'
        }
        '.yml' {
            $fileType = 'yml'
        }
        default {
            $fileType = [string]::Empty
        }
    }

    Write-Host "``````$fileType"
    Write-Host "$(Get-Content -Path $file -Raw)"
    Write-Host "``````"
    Write-Host ""
}
