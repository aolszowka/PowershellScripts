<#
    Script: Censor-AudioWords.ps1
    Purpose: Identify and mute censored words in an audio file using Whisper + ffmpeg.
    Workflow:
        1. Normalize audio → WAV (only if needed)
        2. Generate Whisper transcript (JSON with per-word timestamps)
        3. Load censor list
        4. Identify timestamps for censored words
        5. Produce human-readable debug map
        6. Produce ffmpeg mute filter file
        7. Apply censoring (lossless when possible)
#>

# -------------------------------
# Convert input audio to WAV
# -------------------------------
function Convert-ToWav {
    param(
        [string]$InputPath,
        [string]$ffmpegPath = "D:\My Downloads\Software\Faster-Whisper-XXL\ffmpeg.exe"
    )

    $ext = [IO.Path]::GetExtension($InputPath).ToLower()
    if ($ext -eq ".wav") {
        return $InputPath
    }

    $out = [IO.Path]::ChangeExtension($InputPath, ".wav")

    & $ffmpegPath -y -i $InputPath -ac 1 -ar 16000 -c:a pcm_s16le $out

    if (-not (Test-Path $out)) {
        throw "Failed to convert $InputPath to WAV."
    }

    return $out
}

# -------------------------------
# Run Whisper to generate transcript JSON
# -------------------------------
function Get-WhisperTranscript {
    param(
        [string]$WavPath,
        [string]$WhisperPath = "D:\My Downloads\Software\whisper-cpp\whisper-cli.exe",
        [string]$ModelPath = "D:\My Downloads\Software\whisper-cpp\models\ggml-medium.en-q5_0.bin",
        [string]$Language = "en"
    )

    if (-not (Test-Path $WavPath)) {
        throw "WAV file not found: $WavPath"
    }

    # Base output path (no extension)
    $dir = Split-Path $WavPath
    $base = [IO.Path]::GetFileNameWithoutExtension($WavPath)
    $outBase = Join-Path $dir "$base.whisper"

    # Expected JSON output
    $jsonPath = "$outBase.json"

    # Build explicit whisper.cpp CLI args
    $args = @(
        "--model", $ModelPath
        "--language", $Language
        "--split-on-word"          # per-word segmentation
        "--output-json"            # JSON output (default true, but explicit)
        "--output-file", $outBase  # base path without extension
        "--file", $WavPath         # input audio
    )

    & $WhisperPath @args

    if (-not (Test-Path $jsonPath)) {
        throw "Whisper CLI did not produce expected JSON file: $jsonPath"
    }

    return $jsonPath
}

# -------------------------------
# Load censor list
# -------------------------------
function Get-CensorList {
    param([string]$Path)

    Get-Content $Path |
    Where-Object { $_.Trim() -ne "" } |
    ForEach-Object { $_.Trim().ToLower() }
}

# -------------------------------
# Extract timestamps for censored words
# -------------------------------
function Get-CensorTimestamps {
    param(
        [string]$TranscriptJson,
        [string[]]$CensorWords
    )

    $json = Get-Content $TranscriptJson -Raw | ConvertFrom-Json
    $matches = @()

    foreach ($seg in $json.segments) {
        foreach ($w in $seg.words) {
            $clean = $w.word.Trim().ToLower()

            if ($CensorWords -contains $clean) {
                $matches += [PSCustomObject]@{
                    Word  = $clean
                    Start = [double]$w.start
                    End   = [double]$w.end
                }
            }
        }
    }

    return $matches
}

# -------------------------------
# Write human-readable debug map
# -------------------------------
function Write-CensorMap {
    param(
        [object[]]$Matches,
        [string]$OutputPath
    )

    $lines = $Matches | ForEach-Object {
        "{0:F3} → {1:F3}  ({2})" -f $_.Start, $_.End, $_.Word
    }

    Set-Content -Path $OutputPath -Value $lines
    return $OutputPath
}

# -------------------------------
# Write ffmpeg mute filter file
# -------------------------------
function Write-FfmpegMuteFilter {
    param(
        [object[]]$Matches,
        [string]$OutputPath
    )

    $filters = $Matches | ForEach-Object {
        "volume=0:enable='between(t,{0},{1})'" -f $_.Start, $_.End
    }

    $filterString = $filters -join ","

    Set-Content $OutputPath $filterString
    return $OutputPath
}

# -------------------------------
# Apply censoring with ffmpeg
# -------------------------------
function Apply-Censoring {
    param(
        [string]$InputPath,
        [string]$FilterPath,
        [string]$OutputPath,
        [string]$ffmpegPath = "D:\My Downloads\Software\Faster-Whisper-XXL\ffmpeg.exe"
    )

    $ext = [IO.Path]::GetExtension($InputPath).ToLower()

    switch ($ext) {
        ".wav" { $codec = "pcm_s16le" }
        ".flac" { $codec = "flac" }
        default { $codec = "aac" } # unavoidable re-encode
    }

    $filter = Get-Content $FilterPath -Raw

    & $ffmpegPath -y -i $InputPath -af $filter -c:a $codec $OutputPath

    if (-not (Test-Path $OutputPath)) {
        throw "Failed to generate censored output."
    }

    return $OutputPath
}

# -------------------------------
# MAIN PIPELINE
# -------------------------------
function Invoke-CensorAudioFile {
    param(
        [Parameter(Mandatory)]
        [string]$AudioFile,
        [Parameter(Mandatory)]
        [string]$CensorListPath
    )

    Write-Host "Normalizing audio..."
    $wav = Convert-ToWav $AudioFile

    Write-Host "Running Whisper..."
    $transcript = Get-WhisperTranscript -WavPath $wav

    Write-Host "Loading censor list..."
    $censorWords = Get-CensorList $CensorListPath

    Write-Host "Extracting timestamps..."
    $matches = Get-CensorTimestamps -TranscriptJson $transcript -CensorWords $censorWords

    Write-Host "Writing debug map..."
    $debugMap = Write-CensorMap -Matches $matches -OutputPath "censor_map.txt"

    Write-Host "Writing ffmpeg filter..."
    $filterFile = Write-FfmpegMuteFilter -Matches $matches -OutputPath "mute_filter.txt"

    Write-Host "Applying censoring..."
    $output = Apply-Censoring -InputPath $AudioFile -FilterPath $filterFile -OutputPath "output_censored.wav"

    Write-Host "Done!"
    Write-Host "Debug map: $debugMap"
    Write-Host "Filter file: $filterFile"
    Write-Host "Output audio: $output"
}

Invoke-CensorAudioFile -AudioFile "C:\My Downloads\CensorTest\Input.mp4" -CensorListPath "C:\My Downloads\CensorTest\English-Censor.csv"
