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

    # Capture the Date Modified of the first file
    $firstFileTimestamp = (Get-Item $FilePaths[0]).LastWriteTime

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

        # Apply the timestamp to the output file
        if (Test-Path $OutputFile) {
            (Get-Item $OutputFile).LastWriteTime = $firstFileTimestamp
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

<#
.SYNOPSIS
Analyzes a directory of audio files and identifies groups of files that should
be combined based on duration and sequential numbering.

.DESCRIPTION
Get-AudioCombinePlan scans a directory for WAV or FLAC files whose filenames are
numeric (typically representing timestamps or sequence numbers). It identifies
"chains" of files that should be combined into a single output file.

A chain begins when:
  - The first file in the sequence is approximately the specified MinuteMark
    (default: 60 minutes).

A chain continues when:
  - Subsequent files are sequentially numbered (e.g., 20260225002 →
    20260225003).
  - Each sequential file is also approximately the MinuteMark in duration.

A chain ends when:
  - A sequential file is found whose duration is NOT approximately the
    MinuteMark. This file is treated as the final "remainder" segment and
    included in the chain.
  - OR the next file is not sequentially numbered.

The function does NOT perform any combining. Instead, it returns PowerShell
objects describing the planned combine operations. These objects can later be
passed to a function such as Invoke-AudioCombinePlan or used for dry-run
inspection.

.PARAMETER InputDirectory
The directory containing WAV or FLAC files to analyze. Filenames must be numeric
(e.g., 20260225002.wav) for sequencing to work correctly.

.PARAMETER MinuteMark
The expected duration (in minutes) that indicates a file is a "full segment".
Defaults to 60. Files within ±0.1 minutes of this value are considered matches.

.EXAMPLE
Get-AudioCombinePlan -InputDirectory "C:\Audio"

Scans the directory and returns planned combine operations using the default
60-minute heuristic.

.EXAMPLE
Get-AudioCombinePlan -InputDirectory "C:\Audio" -MinuteMark 30

Uses a 30-minute split heuristic instead of 60 minutes.

.OUTPUTS
A collection of PSCustomObjects with the following properties:

  FirstFile       - The first file in the chain. FilesToCombine  - Array of full
  paths to files in the chain. FileCount       - Number of files in the chain.
  SuggestedOutput - Recommended output filename for the combined file.
  MinuteMark      - The minute mark used for this analysis.

.NOTES
This function does not modify any files. It is intended for planning and dry-run
analysis. Another function should perform the actual combination using
Combine-AudioFilesCore.

Written with the assistance of Copilot.
#>
function Get-AudioCombinePlan {
    param(
        [Parameter(Mandatory)]
        [string]$InputDirectory,
        [int]$MinuteMark = 60
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

    # Define tolerance window
    $lowerBound = $MinuteMark - 0.1
    $upperBound = $MinuteMark + 0.1

    for ($i = 0; $i -lt $audioFiles.Count; $i++) {
        $currentFile = $audioFiles[$i]
        $baseNumber = [int64]$currentFile.BaseName

        $duration = Get-AudioDuration -Path $currentFile.FullName

        # Only start a chain if the FIRST file is ~MinuteMark minutes
        if ($duration.TotalMinutes -ge $lowerBound -and $duration.TotalMinutes -le $upperBound) {

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

                # If this next file is NOT ~MinuteMark minutes, treat it as the final remainder
                if (-not ($nextDuration.TotalMinutes -ge $lowerBound -and $nextDuration.TotalMinutes -le $upperBound)) {
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
                    MinuteMark      = $MinuteMark
                }

                # Skip past the files we just consumed in this chain
                $i = $lastIndex
            }
        }
    }

    return $plans
}

function Combine-AllAudioFilesInDirectory {
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

function Combine-AudioFilesMeetingCriteria {
    param(
        [Parameter(Mandatory)]
        [string]$InputDirectory,
        [int]$MinuteMark = 60
    )

    if (-not (Test-Path $InputDirectory)) {
        throw "Directory not found: $InputDirectory"
    }

    # 1. Generate the plan
    $plans = Get-AudioCombinePlan -InputDirectory $InputDirectory -MinuteMark $MinuteMark

    if ($plans.Count -eq 0) {
        Write-Host "No combine operations detected." -ForegroundColor Yellow
        return
    }

    # 2. Display the plan for approval
    Write-Host "Review the planned operations. Select the ones you want to run." -ForegroundColor Cyan
    $selected = $plans | Out-GridView -Title "Audio Combine Plan" -PassThru

    if (-not $selected) {
        Write-Host "No operations selected. Exiting." -ForegroundColor Yellow
        return
    }

    # 3. Prepare the completed folder
    $completedDir = Join-Path $InputDirectory "_CompletedCombined"
    if (-not (Test-Path $completedDir)) {
        New-Item -ItemType Directory -Path $completedDir | Out-Null
    }

    # 4. Execute each selected plan
    foreach ($plan in $selected) {
        Write-Host "Combining $($plan.FileCount) files into $($plan.SuggestedOutput)..." -ForegroundColor Green

        Combine-AudioFilesCore `
            -FilePaths $plan.FilesToCombine `
            -OutputFile $plan.SuggestedOutput

        # 5. Move source files into the completed folder
        foreach ($file in $plan.FilesToCombine) {
            $dest = Join-Path $completedDir (Split-Path $file -Leaf)
            Move-Item -Path $file -Destination $dest -Force
        }

        Write-Host "Completed: $($plan.SuggestedOutput)" -ForegroundColor Green
    }

    Write-Host "All selected operations completed." -ForegroundColor Cyan
}

Combine-AudioFilesMeetingCriteria
