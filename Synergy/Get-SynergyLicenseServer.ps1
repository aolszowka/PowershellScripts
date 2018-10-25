function Get-SynergyLicenseServer
{
    <#
.SYNOPSIS
Gets the Synergy License Server for the target computers.

.DESCRIPTION
Gets the Synergy License Server for the target computers by querying the registry remotely.

.PARAMETER ComputerNames
An array of Servers to Get the Synergy License Server From.

.EXAMPLE
Get-SynergyLicenseServer
Will get the current license server for this machine.

.EXAMPLE
Get-SynergyLicenseServer -ComputerNames "server1", "server2"
Will get the current license server for server1 and server2

.EXAMPLE
"server1","server2" | Get-SynergyLicenseServer
Will get the current license server for server1 and server2

.LINK
https://github.com/aolszowka/PowerShellScripts

.NOTES
This script is provided under the MIT License.
The most current version can be found at https://github.com/aolszowka/PowerShellScripts as well as bug reports
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [string[]]$ComputerNames = $env:COMPUTERNAME
    )
    process
    {
        ForEach ($computerName in $ComputerNames)
        {
            if ($PSCmdlet.ShouldProcess("$computerName"))
            {
                $result = @{ComputerName = $computerName}

                $Reg = $null

                # Assume that we are NOT a 32bit OS
                $is32bitOS = $false

                # The first attempt to query the registry should tell us if we're
                # properly setup for remote registry, if not bail out.
                try
                {
                    $Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $computerName)

                    # See if we're a 32-bit OS
                    # https://docs.microsoft.com/en-us/windows/desktop/WinProg64/wow64-implementation-details
                    $RegKey = $Reg.OpenSubKey("SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment")
                    $PROCESSOR_ARCHITECTURE = $RegKey.GetValue("PROCESSOR_ARCHITECTURE")

                    if ($PROCESSOR_ARCHITECTURE -eq "x86")
                    {
                        $is32bitOS = $true
                    }
                }
                catch
                {
                    # Don't Attempt to recover; just move on
                    $Reg = $null
                    $result.SynergyLicenseServer32 = "AccessRemoteRegistryFailure"
                    $result.SynergyLicenseServer64 = "AccessRemoteRegistryFailure"
                }

                if ($Reg)
                {
                    $RegKey = $Reg.OpenSubKey("SOFTWARE\\Synergex\\Synergy License Manager")
                    if ($RegKey)
                    {
                        if ($is32bitOS)
                        {
                            $result.SynergyLicenseServer32 = $RegKey.GetValue("Server Machine Name")
                            $result.SynergyLicenseServer64 = "Detected32bitOS"
                        }
                        else
                        {
                            $result.SynergyLicenseServer64 = $RegKey.GetValue("Server Machine Name")
                        }
                    }
                    else
                    {
                        $result.SynergyLicenseServer64 = "NoValueOrNotInstalled"
                    }

                    # This key should only be looked at if it is not a 32bit OS
                    if ($is32bitOS -ne $true)
                    {
                        $RegKey = $Reg.OpenSubKey("SOFTWARE\\Wow6432Node\\Synergex\\Synergy License Manager")
                        if ($RegKey)
                        {
                            $result.SynergyLicenseServer32 = $RegKey.GetValue("Server Machine Name")
                        }
                        else
                        {
                            $result.SynergyLicenseServer32 = "NoValueOrNotInstalled"
                        }
                    }

                }

                [PSCustomObject]@{
                    ComputerName           = $result.ComputerName
                    SynergyLicenseServer32 = $result.SynergyLicenseServer32
                    SynergyLicenseServer64 = $result.SynergyLicenseServer64
                }
            }
        }
    }
}