# Utility to perform a naive file name replacement based on a particular string
# replacing it with a given string.
#
# Written with the assistance of Copilot.
param (
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Find,

    [Parameter(Mandatory = $true)]
    [string]$Replace
)

Get-ChildItem -Path $Path -File | ForEach-Object {
    if ($_.Name -like "*$Find*") {
        $NewName = $_.Name -replace [regex]::Escape($Find), $Replace
        Rename-Item -Path $_.FullName -NewName $NewName
    }
}
