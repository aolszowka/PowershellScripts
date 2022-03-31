# Script to create a CSV of all recent RDP login attempts

# This script assumes that EventID 4625 has been enabled. You can validate this
# by running `auditpol /get /category:Logon/Logoff` it can be enabled by running
# `auditpol /set /subcategory:"Logon" /failure:enable`

[System.Xml.XmlNamespaceManager]$nsmgr = [System.Xml.XmlNamespaceManager]::new([System.Xml.NameTable]::new())
$nsmgr.AddNamespace('event', 'http://schemas.microsoft.com/win/2004/08/events/event')

$failedLogins = Get-WinEvent -FilterHashtable @{Logname='Security';ID=4625} | ForEach-Object {
    $xdoc = [System.Xml.Linq.XDocument]::Parse($_.ToXml())

    [PSCustomObject]@{
        SourceIpAddress = [System.Xml.XPath.Extensions]::XPathSelectElement($xdoc, '//event:Data[@Name=''IpAddress'']', $nsmgr).Value
        TargetUserName = [System.Xml.XPath.Extensions]::XPathSelectElement($xdoc, '//event:Data[@Name=''TargetUserName'']', $nsmgr).Value
        Status = [System.Xml.XPath.Extensions]::XPathSelectElement($xdoc, '//event:Data[@Name=''Status'']', $nsmgr).Value
        Substatus = [System.Xml.XPath.Extensions]::XPathSelectElement($xdoc, '//event:Data[@Name=''SubStatus'']', $nsmgr).Value
        TimeCreated = [System.Xml.XPath.Extensions]::XPathSelectElement($xdoc, '//event:TimeCreated', $nsmgr).Attribute('SystemTime').Value
    }
}

$failedLogins | Export-Csv -NoTypeInformation FailedLogins.csv
