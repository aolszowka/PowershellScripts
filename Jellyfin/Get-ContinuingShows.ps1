# Toy script to grab series that are continuing.
#
# Written with the assistance of Copilot
param(
    [Parameter(Mandatory)]
    [string]$JellyfinServer,   # Example: http://localhost:8096

    [Parameter(Mandatory)]
    [string]$ApiKey            # Your Jellyfin API key
)

# Build base headers
$Headers = @{
    "X-Emby-Token" = $ApiKey
}

# Query all series
$Url = "$JellyfinServer/Items?IncludeItemTypes=Series&Recursive=true"

try {
    $Response = Invoke-RestMethod -Uri $Url -Headers $Headers -Method GET
}
catch {
    Write-Error "Failed to query Jellyfin API: $_"
    return
}

# Filter for ongoing shows
$Ongoing = $Response.Items | Where-Object {
    $_.Status -eq "Continuing"
}

# Output structured objects
$Ongoing | Select-Object Name, ProductionYear, Status, PremiereDate, EndDate
