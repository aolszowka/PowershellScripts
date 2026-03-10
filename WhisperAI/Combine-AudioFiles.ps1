# A set of scripts to help join audio files that might be split along particular
# minute markers.
#
# Written with the assistance of Copilot.

function Combine-AudioFilesCore {
    param(
        [Parameter(Mandatory)]
        [string[]]$FilePaths,
        [Parameter(Mandatory)]
        [string]$OutputFile,
        [string]$ffmpegPath = "C:\DevApps\System\ffmpeg\bin\ffmpeg.exe"
    )

    if ($FilePaths.Count -lt 2) {
        throw "Combine-AudioFilesCore requires at least two input files."
    }

    # Create a temporary concat list file
    $listFile = New-TemporaryFile

    try {
        # Write FFmpeg concat entries
        $FilePaths | ForEach-Object {
            "file '$($_.Replace("'", "''"))'"
        } | Set-Content -Encoding UTF8 $listFile.FullName

        # Build FFmpeg command
        $ffmpegArgs = @(
            "-f", "concat",
            "-safe", "0",
            "-i", "`"$($listFile.FullName)`"",
            "-c", "copy",
            "`"$OutputFile`""
        )

        Write-Host "Combining $($FilePaths.Count) files into $OutputFile ..."
        $process = Start-Process -FilePath $ffmpegPath -ArgumentList $ffmpegArgs -NoNewWindow -Wait -PassThru

        if ($process.ExitCode -ne 0) {
            throw "FFmpeg failed with exit code $($process.ExitCode)"
        }
    }
    finally {
        # Cleanup temp file
        if (Test-Path $listFile.FullName) {
            Remove-Item $listFile.FullName -Force
        }
    }
}

function Get-AudioDuration {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$ffprobePath = "C:\DevApps\System\ffmpeg\bin\ffprobe.exe",
        [switch]$DebugOutput
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    $arguments = @(
        "-v", "error",
        "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1",
        $Path
    )

    if ($DebugOutput) {
        $cmdLine = "$ffprobePath " + ($arguments | ForEach-Object { "`"$_`"" }) -join " "
        Write-Host "[Get-AudioDuration] ffprobe command:" -ForegroundColor Cyan
        Write-Host "  $cmdLine" -ForegroundColor DarkCyan
    }

    $raw = & $ffprobePath $arguments 2>&1

    if ($DebugOutput) {
        Write-Host "[Get-AudioDuration] ffprobe raw output:" -ForegroundColor Cyan
        $raw | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkCyan }
    }

    if (-not $raw) {
        throw "Unable to read duration for file: $Path"
    }

    $firstLine = ($raw | Where-Object { $_ -and $_.Trim().Length -gt 0 } | Select-Object -First 1).Trim()

    [double]$seconds = 0
    $culture = [System.Globalization.CultureInfo]::InvariantCulture

    if (-not [double]::TryParse($firstLine, [System.Globalization.NumberStyles]::Float, $culture, [ref]$seconds)) {
        throw "Invalid duration returned by ffprobe for file: $Path (value: '$firstLine')"
    }

    return [TimeSpan]::FromSeconds($seconds)
}

function Get-AudioCombinePlan {
    param(
        [Parameter(Mandatory)]
        [string]$InputDirectory
    )

    if (-not (Test-Path $InputDirectory)) {
        throw "Directory not found: $InputDirectory"
    }

    $audioFiles = Get-ChildItem -Path "$InputDirectory\*" -File -Include *.wav, *.flac |
    Sort-Object { [int64]($_.BaseName) }

    if ($audioFiles.Count -eq 0) {
        Write-Verbose "No audio files found in $InputDirectory."
        return @()
    }

    $plans = @()

    for ($i = 0; $i -lt $audioFiles.Count; $i++) {
        $currentFile = $audioFiles[$i]
        $baseNumber = [int64]$currentFile.BaseName

        $duration = Get-AudioDuration -Path $currentFile.FullName -DebugOutput

        # Only start a chain if the FIRST file is ~60 minutes
        if ($duration.TotalMinutes -ge 59.9 -and $duration.TotalMinutes -le 60.1) {
            $chain = @($currentFile)
            $nextNumber = $baseNumber + 1
            $lastIndex = $i

            # Look ahead for sequentially numbered files
            for ($j = $i + 1; $j -lt $audioFiles.Count; $j++) {
                $nextFile = $audioFiles[$j]
                $nextBase = [int64]$nextFile.BaseName

                # If the next file is not sequentially numbered this is not a
                # candidate
                if ($nextBase -ne $nextNumber) {
                    break
                }

                # Get the next sequential file duration
                $nextDuration = Get-AudioDuration -Path $nextFile.FullName
                $chain += $nextFile
                $lastIndex = $j
                $nextNumber++

                # If this next file is NOT ~60 minutes, treat it as the final remainder and stop extending
                if (-not ($nextDuration.TotalMinutes -ge 59.9 -and $nextDuration.TotalMinutes -le 60.1)) {
                    break
                }
            }

            if ($chain.Count -gt 1) {
                $first = $chain[0]
                $extension = $first.Extension.TrimStart('.').ToLower()
                $outputFile = Join-Path $InputDirectory ("{0}_Combined.{1}" -f $first.BaseName, $extension)

                $plans += [pscustomobject]@{
                    FirstFile       = $first.FullName
                    FilesToCombine  = $chain.FullName
                    FileCount       = $chain.Count
                    SuggestedOutput = $outputFile
                }

                # Skip past the files we just consumed in this chain
                $i = $lastIndex
            }
        }
    }

    return $plans
}

function Combine-AudioFilesInDirectory {
    param(
        [Parameter(Mandatory)]
        [string]$InputDirectory
    )

    if (-not (Test-Path $InputDirectory)) {
        throw "Directory not found: $InputDirectory"
    }

    # Discover and sort audio files numerically by filename
    $audioFiles = Get-ChildItem -Path "$InputDirectory\*" -File -Include *.wav, *.flac |
    Sort-Object { [int64]($_.BaseName) }

    if ($audioFiles.Count -lt 2) {
        throw "Need at least two WAV or FLAC files to combine."
    }

    # Determine output name
    $lowestName = $audioFiles[0].BaseName
    $extension = $audioFiles[0].Extension.TrimStart('.').ToLower()
    $outputFile = Join-Path $InputDirectory "${lowestName}_Combined.$extension"

    # Call the core function
    Combine-AudioFilesCore -FilePaths $audioFiles.FullName -OutputFile $outputFile

    Write-Host "Success! Combined file created at: $outputFile"
}

Get-AudioCombinePlan
