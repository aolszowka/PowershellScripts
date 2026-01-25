<#
.SYNOPSIS
    Measure durations of WAV and FLAC audio files.

.DESCRIPTION
    Provides functions to measure the duration of WAV and FLAC files using
    lightweight header parsing (WAV) and metaflac metadata extraction (FLAC).
    Includes a unified Measure-AudioDuration and an aggregator
    Measure-AverageAudioLength for directory-wide statistics.

    Written with the assistance of Copilot.
#>

# -------------------------------
# WAV Duration (header parsing)
# -------------------------------
function Measure-WavDuration {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $fs = [System.IO.File]::OpenRead($Path)
    $br = New-Object System.IO.BinaryReader($fs)

    try {
        # Channels (offset 22)
        $fs.Seek(22, 'Begin') | Out-Null
        $channels = $br.ReadInt16()

        # Sample rate (offset 24)
        $sampleRate = $br.ReadInt32()

        # Bits per sample (offset 34)
        $fs.Seek(34, 'Begin') | Out-Null
        $bitsPerSample = $br.ReadInt16()

        # Find the "data" chunk
        $fs.Seek(12, 'Begin') | Out-Null
        while ($true) {
            $chunkId = -join ([char[]]$br.ReadBytes(4))
            $chunkSize = $br.ReadInt32()

            if ($chunkId -eq "data") {
                break
            }

            $fs.Seek($chunkSize, 'Current') | Out-Null
        }

        $dataSize = $chunkSize
        $bytesPerSample = $bitsPerSample / 8
        $blockAlign = $channels * $bytesPerSample
        $numSamples = $dataSize / $blockAlign

        $durationSeconds = $numSamples / $sampleRate
        return [TimeSpan]::FromSeconds($durationSeconds)
    }
    finally {
        $br.Close()
        $fs.Close()
    }
}

# -------------------------------
# FLAC Duration (via metaflac)
# -------------------------------
function Measure-FlacDuration {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        # Path to metaflac.exe if not in PATH
        [string]$MetaFlac = "C:\DevApps\System\flac\win64\metaflac.exe"
    )

    if (-not (Test-Path $Path)) {
        throw "FLAC file not found: $Path"
    }

    # Query STREAMINFO
    $output = & $MetaFlac --show-total-samples --show-sample-rate $Path 2>$null
    if (-not $output -or $output.Count -lt 2) {
        throw "metaflac failed to read metadata for $Path"
    }

    $totalSamples = [double]$output[0]
    $sampleRate = [double]$output[1]

    if ($sampleRate -le 0) {
        throw "Invalid sample rate returned by metaflac for $Path"
    }

    $seconds = $totalSamples / $sampleRate
    return [TimeSpan]::FromSeconds($seconds)
}

# -------------------------------
# Unified Audio Duration
# -------------------------------
function Measure-AudioDuration {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    switch ([System.IO.Path]::GetExtension($Path).ToLower()) {
        ".wav" { return Measure-WavDuration -Path $Path }
        ".flac" { return Measure-FlacDuration -Path $Path }
        default { throw "Unsupported audio format: $Path" }
    }
}

# -------------------------------
# Average Duration Across Directory
# -------------------------------
function Measure-AverageAudioLength {
    param(
        [Parameter(Mandatory)]
        [string]$Directory
    )

    $files = Get-ChildItem -Path $Directory -Recurse -File |
    Where-Object { $_.Extension -in ".wav", ".flac" }

    if (-not $files) {
        Write-Warning "No WAV or FLAC files found."
        return
    }

    # Emit structured objects
    $results = foreach ($f in $files) {
        $duration = Measure-AudioDuration -Path $f.FullName

        [PSCustomObject]@{
            FullName = $f.FullName
            Duration = $duration
        }
    }

    # Compute average
    $avgSeconds = ($results.Duration | ForEach-Object { $_.TotalSeconds }) |
    Measure-Object -Average |
    Select-Object -ExpandProperty Average

    # Emit structured objects to pipeline
    # $results

    # Return average as the function's return value
    return [TimeSpan]::FromSeconds($avgSeconds)
}

Measure-AverageAudioLength
