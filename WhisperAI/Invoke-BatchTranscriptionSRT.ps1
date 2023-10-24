$targetDirectory = 'C:\Transcription'

function ConvertTo-SRT {
    param (
        [string]$SourceFile,
        [string]$DestinationFile = "$SourceFile.srt"
    )

    # Use an initial prompt of `Hello.` to work around around this issue:
    # https://github.com/openai/whisper/discussions/194 testing shows that this
    # does not even need to exist in the transcription.
    $uri = 'http://mp80.localdomain:9000/asr?task=transcribe&language=en&initial_prompt=Hello.&encode=true&output=srt&word_timestamps=false'
    $headers = @{
        'accept'       = 'application/json'
        'Content-Type' = 'multipart/form-data'
    }
    $form = @{
        'audio_file' = Get-Item -Path $SourceFile
        'type'       = 'audio/x-flac'
    }

    $duration = Get-Duration -SourceFile $SourceFile
    Write-Host "Creating SRT for [$SourceFile] at [$DestinationFile] with Duration of [$duration] at [$([System.DateTime]::Now)]"

    $executionTime = Measure-Command -Expression {
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Form $form -Method 'POST'
        $response | Out-File -FilePath $DestinationFile
    }

    Write-Host "Converted [$SourceFile]; Took [$executionTime]"
}

function Get-Duration {
    param (
        [string]$SourceFile
    )

    $ffprobePath = 'C:\DevApps\System\ffmpeg\bin\ffprobe.exe'
    $duration = "unknown"

    if (Test-Path $SourceFile) {
        if (Test-Path $ffprobePath) {
            $duration = &$ffprobePath -show_entries format=duration -v quiet -of csv="p=0" -sexagesimal "$SourceFile" 2>$null
        }
        else {
            Write-Warning "ffprobe was not located at [$ffprobePath]; this function will not work"
        }
    }
    else {
        Write-Warning "SourceFile [$SourceFile] was not found."
    }

    return $duration
}

$sourceFiles = Get-ChildItem -Path $targetDirectory -Filter *.flac -Recurse | Select-Object -ExpandProperty FullName

foreach ($sourceFile in $sourceFiles) {
    if (Test-Path -Path "$sourceFile.srt") {
        Write-Warning "SRT Exists for [$sourceFile]. Skipping..."
    }
    else {
        ConvertTo-SRT -SourceFile $sourceFile
    }
}

