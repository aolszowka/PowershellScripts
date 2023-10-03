$wavFiles = Get-ChildItem -Path 'C:\Transcription' -Filter '*.wav'
foreach ($wavFile in $wavFiles.FullName) {
    $flacFileName = $wavFile.Replace('.wav', '.flac')
    if (Test-Path $flacFileName) {
        Write-Host "WAV File [$wavFile] has a FLAC File; Removing!"
        Remove-Item -Path $wavFile
    }
}
