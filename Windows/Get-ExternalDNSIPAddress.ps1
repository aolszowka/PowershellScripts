# This script is used to perform a poor-man's monitoring of changes in the IP
# address pointed at by a particular hostname exporting into a CSV, updating
# only when the address changes.

$targetHostName = 'example.com'
$ipAddressLogFile = "$PSScriptRoot\IPAddresses.csv"
$previousAddresses = $null

# Load up the address list
if (Test-Path -Path $ipAddressLogFile) {
    [System.Collections.Generic.List[PSCustomObject]]$previousAddresses = Import-Csv -Path $ipAddressLogFile
}

$externalIP = 'Failed to get external IP from https://checkip.amazonaws.com'
$externalIPWebRequest = Invoke-WebRequest -Uri 'https://checkip.amazonaws.com'
if($null -ne $externalIPWebRequest -and $externalIPWebRequest.StatusCode -eq 200) {
    $externalIP = [string]::new($externalIPWebRequest.Content)
    $externalIP = $externalIP.Replace("`n", [string]::Empty)
}

$dnsIP = Resolve-DnsName -Name $targetHostName | Where-Object { $_.Type -eq 'A' }

if ($null -eq $previousAddresses) {
    # This is the first time we're initializing this file go ahead and create it
    $previousAddresses = [PSCustomObject]@{
        HostName = $targetHostName
        DNSIP = $dnsIP.IPAddress
        IPAddress = $externalIP
        FirstSeen = Get-Date
    }
}
else {
    $mostCurrentAddress = $previousAddresses[0]
    if ($mostCurrentAddress.IPAddress -eq $externalIP -and $mostCurrentAddress.DNSIP -eq $dnsIP.IPAddress) {
        # IP Address has not changed do nothing
    }
    else {
        $currentIPAddress = [PSCustomObject]@{
            HostName = $targetHostName
            DNSIP = $dnsIP.IPAddress
            IPAddress = $externalIP
            FirstSeen = Get-Date
        }
        $previousAddresses.Insert(0, $currentIPAddress)
    }
}

$previousAddresses | Export-Csv -Path $ipAddressLogFile -Force -NoTypeInformation
