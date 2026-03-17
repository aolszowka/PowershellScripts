# A set of scripts to help join SRT Files properly.
#
# Written with the assistance of Copilot.

function Combine-SrtFiles {
    param(
        [Parameter(Mandatory)]
        [string[]] $InputFiles,

        [Parameter(Mandatory)]
        [string] $OutputFile
    )

    function Parse-SrtTime([string]$ts) {
        $parts = $ts -split '[:,]'
        New-TimeSpan -Hours $parts[0] -Minutes $parts[1] -Seconds $parts[2] -Milliseconds $parts[3]
    }

    function Format-SrtTime([TimeSpan]$ts) {
        "{0:00}:{1:00}:{2:00},{3:000}" -f $ts.Hours, $ts.Minutes, $ts.Seconds, $ts.Milliseconds
    }

    $globalIndex = 1
    $offset = [TimeSpan]::Zero
    $output = New-Object System.Collections.Generic.List[string]

    foreach ($file in $InputFiles) {
        $lines = Get-Content $file -Raw
        $blocks = $lines -split "(\r?\n){2,}"

        foreach ($block in $blocks) {
            $trim = $block.Trim()
            if (-not $trim) { continue }

            $blockLines = $trim -split "\r?\n"

            $tsLine = $blockLines[1]
            if ($tsLine -notmatch ' --> ') {
                throw "Invalid SRT timestamp line in file $($file): $tsLine"
            }

            $start, $end = $tsLine -split ' --> '
            $startTs = Parse-SrtTime $start
            $endTs = Parse-SrtTime $end

            # Index
            $output.Add($globalIndex.ToString())
            $globalIndex++

            # Timestamps with offset
            $output.Add("$(Format-SrtTime ($startTs + $offset)) --> $(Format-SrtTime ($endTs + $offset))")

            # Text lines
            for ($i = 2; $i -lt $blockLines.Count; $i++) {
                $output.Add($blockLines[$i])
            }

            $output.Add("")
        }

        # Update offset using last end timestamp in the file
        $lastTimestampMatch = $lines | Select-String -Pattern '(?m)(\d\d:\d\d:\d\d,\d\d\d)(?=\s*$)' -AllMatches
        if ($lastTimestampMatch) {
            $last = $lastTimestampMatch.Matches | Select-Object -Last 1
            $offset += Parse-SrtTime $last.Value
        }
    }

    $output -join "`r`n" | Set-Content -Path $OutputFile -Encoding UTF8
}

Combine-SrtFiles
