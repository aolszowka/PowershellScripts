# Toy script to grab items that have missing metadata from Jellyfin
param(
    [Parameter(Mandatory = $true)]
    [string]$ServerUrl, # Change to your Jellyfin server URL
    [Parameter(Mandatory = $true)]
    [string]$ApiKey, # Replace with your API key
    [string]$OutputCsv = 'MissingMetadata.csv'
)

$uri = "$ServerUrl/Items?IncludeItemTypes=Movie&Recursive=true&Fields=ProviderIds"

$response = Invoke-RestMethod -Uri $uri -Headers @{ "X-Emby-Token" = $ApiKey }

$missing = @()

foreach ($item in $response.Items) {
    $missingReasons = @()

    if (-not $item.ProviderIds -or $null -eq $item.ProviderIds.PSObject.Properties.Count) { $missingReasons += "Missing provider IDs" }

    if ($missingReasons.Count -gt 0) {
        $missing += [PSCustomObject]@{
            Name           = $item.Name
            Year           = $item.ProductionYear
            Id             = $item.Id
            Path           = $item.Path
            ReasonsMissing = ($missingReasons -join ", ")
        }
    }
}

if ($missing.Count -gt 0) {
    $missing | Export-Csv $OutputCsv -NoTypeInformation -Encoding UTF8
    Write-Host "✅ Report generated: $OutputCsv ($($missing.Count) items missing metadata)"
}
else {
    Write-Host "🎉 All items have metadata!"
}
