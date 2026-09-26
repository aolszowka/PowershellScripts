# Written with the assistance of Copilot.

function Clip-Audio {
    param(
        [Parameter(Mandatory)]
        [string]$InputFolder,
        [Parameter(Mandatory)]
        [string]$OutputFolder,
        [Parameter(Mandatory)]
        [int]$Seconds,
        [string]$ffmpegPath = "C:\DevApps\System\ffmpeg\bin\ffmpeg.exe"
    )

    # Create output folder if it doesn't exist
    if (!(Test-Path $OutputFolder)) {
        New-Item -ItemType Directory -Path $OutputFolder | Out-Null
    }

    # Process each WAV file
    Get-ChildItem -Path $InputFolder -Filter *.wav | ForEach-Object {
        $inputFile = $_.FullName
        $outputFile = Join-Path $OutputFolder $_.Name

        &$ffmpegPath -hide_banner -loglevel error -i "$inputFile" -t $Seconds -c copy "$outputFile"
        Write-Host "Exported first $Seconds seconds of $($_.Name)"
    }
}

Clip-Audio
