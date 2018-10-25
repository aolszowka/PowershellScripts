function Test-RemoteRegistry()
{
    <#
.SYNOPSIS
Tests if Remote Registry works for the given servers.

.DESCRIPTION
Tests if Remote Registry works for the given servers.

.PARAMETER ComputerNames
An array of servers to test for Remote Registry ability.

.EXAMPLE
Test-RemoteRegistry
Will test if remote registry works for the current machine.

.EXAMPLE
Test-RemoteRegistry -ComputerNames "server1", "server2"
Will test Remote Registry for server1 and server2

.EXAMPLE
"server1","server2" | Test-RemoteRegistry
Will test Remote Registry for server1 and server2

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
        ForEach ($ComputerName in $ComputerNames)
        {
            if ($PSCmdlet.ShouldProcess("$ComputerName"))
            {
                $result = $false;

                try
                {
                    $Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $ComputerName)
                    $RegKey = $Reg.OpenSubKey("SYSTEM")

                    #Assume that if we're able to open a sub-key we're golden
                    $result = $true;
                }
                catch
                {
                    # Otherwise assume we're toast
                    $result = $false;
                }

                $result;
            }
        }
    }
}