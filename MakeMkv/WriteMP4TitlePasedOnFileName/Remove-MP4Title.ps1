function Remove-MP4Title {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true, Position = 0, Mandatory = $true)]
        [string]
        $Path
    )

    begin {
        # This is only required if attempting to edit MP4 metadata
        $windowsAPICodePackShellDll = "$PSScriptRoot\Microsoft.WindowsAPICodePack.Shell.dll"

        if (Test-Path $windowsAPICodePackShellDll) {
            Add-Type -Path $windowsAPICodePackShellDll
        }
    }

    process {
        # There really doesn't seem to be a way to do this within PowerShell;
        # See this guy [0]. I think the key is to use something like they do in
        # C# using the Windows API Code pack [1] If you look at the underlying
        # code[2] he'll eventually call down into IShellItem2::GetPropertyStore
        # [3] and then call IPropertyStore::SetValue [4], however these are the
        # C++ API's which do not appear to be exposed via COM, which means there
        # is no straight forward way within PowerShell to accomplish this.
        #
        # [0]-https://stackoverflow.com/questions/65228096/powershell-changing-mp4-metadata-right-click-properties
        # [1]-https://stackoverflow.com/questions/24040248/is-it-possible-to-set-edit-a-file-extended-properties-with-windows-api-code-pack
        # [2]-https://github.com/aybe/Windows-API-Code-Pack-1.1/blob/master/source/WindowsAPICodePack/Shell/PropertySystem/ShellPropertyWriter.cs
        # [3]-https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-ishellitem2-getpropertystore
        # [4]-https://learn.microsoft.com/en-us/windows/win32/api/propsys/nf-propsys-ipropertystore-setvalue
        $shellFile = [Microsoft.WindowsAPICodePack.Shell.ShellFile]::FromFilePath($Path)
        $propertyWriter = $shellFile.Properties.GetPropertyWriter()
        # Ideally we'd use
        # `Microsoft.WindowsAPICodePack.Shell.PropertySystem.SystemProperties.System.Title`
        # but for some reason I was unable to load this static type?
        $titlePropertyKey = [Microsoft.WindowsAPICodePack.Shell.PropertySystem.PropertyKey]::new([Guid]::new("{F29F85E0-4FF9-1068-AB91-08002B27B3D9}"), 2)
        $propertyWriter.WriteProperty($titlePropertyKey, [string]::Empty)
        $propertyWriter.Close()
    }
}

function Main {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )
    Get-ChildItem -LiteralPath $Path -Recurse -Filter '*.mp4' | Remove-MP4Title
}

Main
