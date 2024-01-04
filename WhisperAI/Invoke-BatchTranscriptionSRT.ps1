function ConvertTo-SRT {
    param (
        [Parameter( Position = 0, Mandatory = $true)]
        [string]
        $SourceFile,
        [Parameter( Position = 1, Mandatory = $false)]
        [string]
        $DestinationFile = "$SourceFile.srt"
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

function ConvertTo-JsonDiarize {
    param (
        [Parameter( Position = 0, Mandatory = $true)]
        [string]
        $SourceFile,
        [Parameter( Position = 1, Mandatory = $false)]
        [string]
        $DestinationFile = "$SourceFile.json",
        [Parameter( Position = 2, Mandatory = $false)]
        [int]
        $MinSpeakers = 2,
        [Parameter( Position = 3, Mandatory = $false)]
        [int]
        $MaxSpeakers = 2
    )

    # Do not use an initial prompt as this does not work for WhisperX
    $uri = "http://mp80.localdomain:9001/asr?task=transcribe&language=en&encode=true&output=json&diarize=true&min_speakers=$MinSpeakers&max_speakers=$MaxSpeakers"
    $headers = @{
        'accept'       = 'application/json'
        'Content-Type' = 'multipart/form-data'
    }
    $form = @{
        'audio_file' = Get-Item -Path $SourceFile
        'type'       = 'audio/x-flac'
    }

    $duration = Get-Duration -SourceFile $SourceFile
    Write-Host "Creating Diarized JSON for [$SourceFile] at [$DestinationFile] with Duration of [$duration] at [$([System.DateTime]::Now)]"

    $executionTime = Measure-Command -Expression {
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Form $form -Method 'POST'
        $response | ConvertTo-Json -Depth 100 | Out-File -FilePath $DestinationFile
    }

    Write-Host "Converted [$SourceFile]; Took [$executionTime]"
}

function Get-Duration {
    param (
        [Parameter( Position = 0, Mandatory = $true)]
        [string]
        $SourceFile
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

function Invoke-SRTConversion {
    param (
        [Parameter( Position = 0, Mandatory = $true)]
        [string]
        $Path
    )

    $sourceFiles = Get-ChildItem -LiteralPath $Path -Filter *.flac -Recurse | Select-Object -ExpandProperty FullName

    foreach ($sourceFile in $sourceFiles) {
        if (Test-Path -Path "$sourceFile.srt") {
            Write-Warning "SRT Exists for [$sourceFile]. Skipping..."
        }
        else {
            ConvertTo-SRT -SourceFile $sourceFile
        }
    }
}

function Invoke-DiarizedJSONConversion {
    param (
        [Parameter( Position = 0, Mandatory = $true)]
        [string]
        $Path
    )

    $sourceFiles = Get-ChildItem -LiteralPath $Path -Filter *.flac -Recurse | Select-Object -ExpandProperty FullName

    foreach ($sourceFile in $sourceFiles) {
        if (Test-Path -Path "$sourceFile.json") {
            Write-Warning "JSON Exists for [$sourceFile]. Skipping..."
        }
        else {
            ConvertTo-JsonDiarize -SourceFile $sourceFile
        }
    }
}


Invoke-SRTConversion
#Invoke-DiarizedJSONConversion
