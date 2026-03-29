# Find Zero byte SRT Files.
#
# Written with the assistance of Copilot.
param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

if (-not (Test-Path $Path)) {
    Write-Error "The path '$Path' does not exist."
    exit 1
}

Write-Host "Scanning for 0-byte .srt files under: $Path" -ForegroundColor Cyan

$zeroByteSrts = Get-ChildItem -Path $Path -Filter *.srt -Recurse -File |
Where-Object { $_.Length -eq 0 }

if ($zeroByteSrts.Count -eq 0) {
    Write-Host "No zero-byte .srt files found." -ForegroundColor Green
}
else {
    Write-Host "Found $($zeroByteSrts.Count) zero-byte .srt file(s):" -ForegroundColor Yellow
    $zeroByteSrts | Select-Object FullName, Length | Format-Table -AutoSize
}
