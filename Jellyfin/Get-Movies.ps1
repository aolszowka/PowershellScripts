# --- CONFIGURATION ---
$Server = ""      # Change to your Jellyfin server URL
$ApiKey = ""          # Replace with your API key
$OutputCsv = "Jellyfin_MovieList.csv"

# --- BUILD API URL ---
# 'IsMovie=true' filters only movies
$Url = "$Server/Items?IncludeItemTypes=Movie&Recursive=true&Fields=OfficialRating,Overview,ProductionYear"

# --- MAKE REQUEST ---
$Headers = @{
    "X-Emby-Token" = $ApiKey
}

Write-Host "Querying Jellyfin server..."
$response = Invoke-RestMethod -Uri $Url -Headers $Headers -Method Get

# --- EXTRACT MOVIE DATA ---
$movies = $response.Items | ForEach-Object {
    [PSCustomObject]@{
        "Title"       = if ($_.ProductionYear) { "$($_.Name) ($($_.ProductionYear))" } else { $_.Name }
        "MPAA Rating" = $_.OfficialRating
        "Synopsis"    = $_.Overview
    }
}

$movies = $movies | Sort-Object -Property 'Title'

# --- EXPORT TO CSV ---
Write-Host "Writing to $OutputCsv..."
$Utf8Bom = New-Object System.Text.UTF8Encoding($true)  # 'true' adds BOM
[System.IO.File]::WriteAllText($OutputCsv, ($movies | ConvertTo-Csv -NoTypeInformation | Out-String), $Utf8Bom)

Write-Host "Done! $($movies.Count) movies exported to $OutputCsv."
