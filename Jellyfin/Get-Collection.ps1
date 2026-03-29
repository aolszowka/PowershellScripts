# Get a single Jellyfin Collection.
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
    [string[]]$CheckItemIds       # Optional: item IDs you expect to be in the collection
)

$Headers = @{
    "X-Emby-Token" = $ApiKey
}

$Url = "$JellyfinServer/Items?ParentId=$CollectionId"

Write-Host "Querying collection contents..." -ForegroundColor Cyan

try {
    $Response = Invoke-RestMethod -Uri $Url -Headers $Headers -Method GET
}
catch {
    Write-Error "Failed to query collection: $_"
    return
}

if (-not $Response.Items) {
    Write-Warning "Collection contains no items (or Jellyfin returned an empty list)."
    return
}

Write-Host "`nItems currently in the collection:" -ForegroundColor Green
$Response.Items | Select-Object Name, Id, Type | Format-Table

if ($CheckItemIds) {
    Write-Host "`nChecking for expected item IDs..." -ForegroundColor Yellow

    foreach ($id in $CheckItemIds) {
        if ($Response.Items.Id -contains $id) {
            Write-Host "✔ Item $id is present" -ForegroundColor Green
        }
        else {
            Write-Host "✘ Item $id is NOT present" -ForegroundColor Red
        }
    }
}
