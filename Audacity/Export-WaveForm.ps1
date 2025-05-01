# Make sure the following is configured:
#
# 1. (Windows) WCF Services Named Pipe Activation
#    appwiz.cpl -> Turn Windows Features on or off ->
#    .NET Framework x.x Advanced Services > WCF Services ->
#    Named Pipe Activation
# 2. (Audacity) mod-script-pipe Enabled
#    Audacity -> Edit -> Preferences -> Modules -> mod-script-pipe -> enabled

function Invoke-AudacityCommand {
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string]
        $Command
    )

    process {
        try {
            $connectionTimeout = 2000

            $toAudacityPipe = [System.IO.Pipes.NamedPipeClientStream]::new(".", "ToSrvPipe", [System.IO.Pipes.PipeDirection]::Out, [System.IO.Pipes.PipeOptions]::None, [System.Security.Principal.TokenImpersonationLevel]::Impersonation)
            $toAudacityPipe.Connect($connectionTimeout) | Out-Null

            $fromAudacityPipe = [System.IO.Pipes.NamedPipeClientStream]::new(".", "FromSrvPipe", [System.IO.Pipes.PipeDirection]::In, [System.IO.Pipes.PipeOptions]::None, [System.Security.Principal.TokenImpersonationLevel]::Impersonation)
            $fromAudacityPipe.Connect($connectionTimeout) | Out-Null

            if (!$toAudacityPipe.IsConnected) {
                Write-Error -Message "Connection to Audacity Failed"
                exit
            }

            if (!$fromAudacityPipe.IsConnected) {
                Write-Error -Message "Connection from Audacity Failed"
                exit
            }

            $toAudacity = [System.IO.StreamWriter]::new($toAudacityPipe)
            $toAudacity.AutoFlush = $true

            $fromAudacity = [System.IO.StreamReader]::new($fromAudacityPipe)

            $toAudacity.WriteLine($Command)

            $responseSb = [System.Text.StringBuilder]::new()
            while ($null -ne ($currentResponse = $fromAudacity.ReadLine())) {
                if ($currentResponse -like "BatchCommand finished:*") {
                    [PSCustomObject] @{
                        Response = $responseSb.ToString()
                        Status   = $currentResponse.Substring(23)
                    }
                    break
                }
                $responseSb.Append($currentResponse) | Out-Null
            }
        }
        finally {
            if ($null -ne $fromAudacity) {
                $fromAudacity.Dispose()
            }
            if ($null -ne $toAudacity) {
                $fromAudacity.Dispose()
            }
            if ($null -ne $toAudacityPipe) {
                $toAudacityPipe.Dispose()
            }
            if ($null -ne $fromAudacityPipe) {
                $fromAudacityPipe.Dispose()
            }
        }
    }
}

Invoke-AudacityCommand -Command "Message: Text=""Hello World!"""
#$result = Invoke-AudacityCommand -Command "Message: Text=""Good Bye World!"""
#$result2 = Invoke-AudacityCommand -Command "Help:"
