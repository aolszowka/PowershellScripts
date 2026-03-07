# Toy script to decode a Base64 String on the pipeline.
#
# Written with the assistance of Copilot.

[CmdletBinding()]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [string]$InputString
)

process {
    try {
        $bytes = [Convert]::FromBase64String($InputString)
        [System.Text.Encoding]::UTF8.GetString($bytes)
    }
    catch {
        Write-Error "Input is not valid Base64: $_"
    }
}
