# Get all Jellyfin Collections.
#
# Written with the assistance of Copilot.
param(
    [Parameter(Mandatory)]
    [string]$JellyfinServer,      # Example: http://localhost:8096
    [Parameter(Mandatory)]
    [string]$ApiKey              # Your Jellyfin API key
)

$Headers = @{
    "X-Emby-Token" = $ApiKey
}

$Url = "$JellyfinServer/Items?IncludeItemTypes=BoxSet&Recursive=true"

Write-Host "Querying all collections..." -ForegroundColor Cyan

try {
    $Response = Invoke-RestMethod -Uri $Url -Headers $Headers -Method GET
}
catch {
    Write-Error "Failed to query collections: $_"
    return
}

if (-not $Response.Items) {
    Write-Warning "No collections found."
    return
}

Write-Host "`nCollections (raw properties):" -ForegroundColor Green
$Response.Items | Format-List *

