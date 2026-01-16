# Script to search SRT Files looking for particular keywords/quotes
#
# Written with the assistance of Copilot.
param (
    # Root folder to search recursively
    [Parameter(Mandatory = $true)]
    [string]$RootPath
)

# Search patterns (regex, case-insensitive)
$SearchPatterns = @(
    "two minutes",
    "2 minutes"
)

$ContextLines = 2

Get-ChildItem -Path $RootPath -Filter *.srt -Recurse -File | ForEach-Object {

    $file = $_
    $content = Get-Content $file.FullName -Raw -Encoding UTF8

    # Split into SRT blocks
    $blocks = $content -split "(\r?\n){2,}"

    $entries = @()

    foreach ($block in $blocks) {
        $lines = $block -split "\r?\n" | Where-Object { $_.Trim() -ne "" }

        if ($lines.Count -lt 3) { continue }

        $timestamp = $lines[1]
        $text = ($lines[2..($lines.Count - 1)] -join " ").Trim()

        $entries += [PSCustomObject]@{
            Timestamp = $timestamp
            Text      = $text
        }
    }

    for ($i = 0; $i -lt $entries.Count; $i++) {
        foreach ($pattern in $SearchPatterns) {
            if ($entries[$i].Text -match $pattern) {

                Write-Host ""
                Write-Host ("=" * 70)
                Write-Host "File: $($file.FullName)"
                Write-Host "Time: $($entries[$i].Timestamp)"
                Write-Host "Match: $($entries[$i].Text)" -ForegroundColor Yellow

                # Context before
                for ($j = [Math]::Max(0, $i - $ContextLines); $j -lt $i; $j++) {
                    Write-Host "  PRE:  $($entries[$j].Text)"
                }

                # Context after
                for ($j = $i + 1; $j -le [Math]::Min($entries.Count - 1, $i + $ContextLines); $j++) {
                    Write-Host "  POST: $($entries[$j].Text)"
                }

                break
            }
        }
    }
}
