# This script is used to perform a poor-man's monitoring of changes in the IP
# address pointed at by a particular hostname exporting into a CSV, updating
# only when the address changes.

$ipAddressLogFile = "$PSScriptRoot\IPAddresses.csv"
$previousAddresses = $null

# Load up the address list
if (Test-Path -Path $ipAddressLogFile) {
    [System.Collections.Generic.List[PSCustomObject]]$previousAddresses = Import-Csv -Path $ipAddressLogFile
}

$externalIP = Resolve-DnsName -Name 'example.com' | Where-Object { $_.Type -eq 'A' }

if ($null -eq $previousAddresses) {
    # This is the first time we're initializing this file go ahead and create it
    $previousAddresses = [PSCustomObject]@{
        IPAddress = $externalIP.IPAddress
        FirstSeen = Get-Date
    }
}
else {
    $mostCurrentAddress = $previousAddresses[0]
    if ($mostCurrentAddress.IPAddress -eq $externalIP.IPAddress) {
        # IP Address has not changed do nothing
    }
    else {
        $currentIPAddress = [PSCustomObject]@{
            IPAddress = $externalIP.IPAddress
            FirstSeen = Get-Date
        }
        $previousAddresses.Insert(0, $currentIPAddress)
    }
}

$previousAddresses | Export-Csv -Path $ipAddressLogFile -Force -NoTypeInformation
