# Add an item to a Jellyfin collection.
#
# Written with the assistance of Copilot.
param(
    [Parameter(Mandatory)]
    [string]$JellyfinServer,      # Example: http://localhost:8096
    [Parameter(Mandatory)]
    [string]$ApiKey,              # Your Jellyfin API key
    [Parameter(Mandatory)]
    [string]$CollectionId,        # The ID of the collection you want to modify
    [Parameter(Mandatory)]
    [string[]]$ItemIds            # One or more Item IDs to add
)

# Build headers
$Headers = @{
    "X-Emby-Token" = $ApiKey
}

# Build URL
$Url = "$JellyfinServer/Collections/$CollectionId/Items?Ids=$($ItemIds -join ',')"

try {
    $Response = Invoke-RestMethod -Uri $Url -Headers $Headers -Method POST
    Write-Host "Successfully added items to collection '$CollectionId'."
}
catch {
    Write-Error "Failed to add items: $_"
}
