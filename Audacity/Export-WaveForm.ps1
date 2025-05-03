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

function Get-WindowPositionFromHandle {
    param(
        [System.IntPtr]
        $MainWindowHandle
    )
    begin {
        Add-Type @"
          using System;
          using System.Runtime.InteropServices;
          public class Window {
            [DllImport("user32.dll")]
            [return: MarshalAs(UnmanagedType.Bool)]
            public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
          }
          public struct RECT
          {
            public int Left;        // x position of upper-left corner
            public int Top;         // y position of upper-left corner
            public int Right;       // x position of lower-right corner
            public int Bottom;      // y position of lower-right corner
          }
"@
    }
    process {
        $Rectangle = [RECT]::new()
        [Window]::GetWindowRect($MainWindowHandle, [ref]$Rectangle)
        if ($Rectangle.Top -lt 0 -AND $Rectangle.Left -lt 0) {
            Write-Warning "Window is minimized! Coordinates will not be accurate."
        }
        $Rectangle
    }
}

function Get-ScreenshotOfEntireWindow {
    param(
        [System.Diagnostics.Process]
        $Process,
        [string]
        $FileName
    )
    process {
        Add-Type -AssemblyName System.Drawing

        $rectangle = Get-WindowPositionFromHandle -MainWindowHandle $process.MainWindowHandle
        $bounds = [Drawing.Rectangle]::FromLTRB($rectangle.left, $rectangle.top, $rectangle.right, $rectangle.bottom)
        $bmp = [System.Drawing.Bitmap]::new([int]$bounds.width, [int]$bounds.height)
        $graphics = [Drawing.Graphics]::FromImage($bmp)

        $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.size)

        $bmp.Save($FileName)

        $graphics.Dispose()
        $bmp.Dispose()
    }
}

function Get-WAVFormsForAllFLACFiles {
    param(
        [Parameter(Mandatory = $true)]
        $Path
    )

    process {
        $allFLACFiles = Get-ChildItem -LiteralPath $Path -Filter '*.flac' -Recurse

        # Start the process up and give it a few moments to load
        $process = Start-Process -FilePath "C:\DevApps\System\audacity-win-3.4.2-64bit\Audacity.exe" -PassThru
        Start-Sleep 10

        foreach ($flacFile in $allFLACFiles) {
            $flacFile = $flacFile.FullName
            Invoke-AudacityCommand -Command "Import2: Filename=""$flacFile""" | Out-Null
            Invoke-AudacityCommand -Command "FitInWindow:" | Out-Null
            Start-Sleep 5
            Get-ScreenshotOfEntireWindow -Process $process -FileName "$flacFile.png"
            Invoke-AudacityCommand -Command "SelectTracks: Track=0 TrackCount=100 Mode=Set" | Out-Null
            Invoke-AudacityCommand -Command "RemoveTracks:" | Out-Null
        }
    }
}


Get-WAVFormsForAllFLACFiles
