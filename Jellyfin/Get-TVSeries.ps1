# --- CONFIGURATION ---
$Server = ""      # Change to your Jellyfin server URL
$ApiKey = ""      # Replace with your API key
$OutputCsv = "Jellyfin_TVSeriesList.csv"

# --- BUILD API URL ---
# IncludeItemTypes=Series returns only TV series (no episodes)
$Url = "$Server/Items?IncludeItemTypes=Series&Recursive=true&Fields=Overview,ProductionYear"

# --- AUTH HEADER (Jellyfin 12.x) ---
$Headers = @{
    "Authorization" = "MediaBrowser Token=`"$ApiKey`""
}

Write-Host "Querying Jellyfin server for TV series..."
$response = Invoke-RestMethod -Uri $Url -Headers $Headers -Method Get

# --- EXTRACT SERIES DATA ---
$series = $response.Items | ForEach-Object {
    [PSCustomObject]@{
        "Title"    = if ($_.ProductionYear) { "$($_.Name) ($($_.ProductionYear))" } else { $_.Name }
        "Synopsis" = $_.Overview
    }
}

$series = $series | Sort-Object -Property 'Title'

# --- EXPORT TO CSV ---
Write-Host "Writing to $OutputCsv..."
$Utf8Bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($OutputCsv, ($series | ConvertTo-Csv -NoTypeInformation | Out-String), $Utf8Bom)

Write-Host "Done! $($series.Count) TV series exported to $OutputCsv."
