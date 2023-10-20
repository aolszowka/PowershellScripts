# See https://stackoverflow.com/a/77328383/433069
#
# While I have not been able to find a "pure" PowerShell way to do this, there
# is a similar post related to how to do this in C# Here:
# https://stackoverflow.com/a/24053204/433069 The gist of this persons answer
# was to use the (historically Microsoft Supported) [Windows® API Code Pack for
# Microsoft® .NET Framework][1].
#
# The problem is that this API Code pack is no longer found (at least in my
# searches) to be provided by Microsoft. However some developer copied the
# source as it existed and posted it up on GitHub [here][2].
#
# This provides interesting insight into how Microsoft would have done this.
#
# If you look at the [C# code][3] you'll see that eventually they'll call down
# into the following Shell classes [IShellItem2::GetPropertyStore][4] and then
# call [IPropertyStore::SetValue][5] however these are the C++ API's which do
# not appear to be exposed via COM, which means (as far as I know) is no
# straight forward way within PowerShell to accomplish this.
#
# There is an interesting discussion [here][6] wherein this developer was
# attempting to access this interface in various ways without much luck.The
# solution provided there I believe will only get you read access to the
# properties (I'd love to stand corrected).
#
# In theory you could rewrite the relevant portions of the Windows API Codepack
# and then `Add-Type` them in as required if you want to ship "Batteries
# Included". However for me, I just wanted to get something working.

# Therefore I pulled the two NuGet packages produced by that project
# (`windowsapicodepack-core.1.1.2` and `windowsapicodepack-shell.1.1.1`)
# extracted the DLL's (`Microsoft.WindowsAPICodePack.dll` and
# `Microsoft.WindowsAPICodePack.Shell.dll`) into the same path as my Script and
# then wrote up the following script included below.
#
# Its a rough transliteration of the C# code. The big kicker was I was unable to
# get the static property type
# (`Microsoft.WindowsAPICodePack.Shell.PropertySystem.SystemProperties.System.Title`)
# to load in, so I just ended up recreating the `PropertyKey` as the static
# class did.
#
# [1]:http://web.archive.org/web/20130717101016/http://archive.msdn.microsoft.com/WindowsAPICodePack/Project/License.aspx
# [2]:https://github.com/aybe/Windows-API-Code-Pack-1.1/
# [3]:https://github.com/aybe/Windows-API-Code-Pack-1.1/blob/ae73c1294fe9d47c5052d090b945f69a6364e3a8/source/WindowsAPICodePack/Shell/PropertySystem/ShellPropertyWriter.cs#L93
# [4]:https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-ishellitem2-getpropertystore
# [5]:https://learn.microsoft.com/en-us/windows/win32/api/propsys/nf-propsys-ipropertystore-setvalue
# [6]:https://stackoverflow.com/questions/55463067/is-it-possible-to-get-shell-properties-for-an-item-not-in-the-shell-namespace

$targetFile = "C:\Transcription\Sample.mp4"

# Requires both the `Microsoft.WindowsAPICodePack.Shell.dll` and its dependency
# `Microsoft.WindowsAPICodePack.dll` pulled from the NuGet Packages:
# https://www.nuget.org/packages/WindowsAPICodePack-Core/
# https://www.nuget.org/packages/WindowsAPICodePack-Shell/
Add-Type -Path $PSScriptRoot\Microsoft.WindowsAPICodePack.Shell.dll

$shellFile = [Microsoft.WindowsAPICodePack.Shell.ShellFile]::FromFilePath($targetFile)
$propertyWriter = $shellFile.Properties.GetPropertyWriter()
# Ideally we'd use
# `Microsoft.WindowsAPICodePack.Shell.PropertySystem.SystemProperties.System.Title`
# but for some reason I was unable to load this static type?
$titlePropertyKey = [Microsoft.WindowsAPICodePack.Shell.PropertySystem.PropertyKey]::new([Guid]::new("{F29F85E0-4FF9-1068-AB91-08002B27B3D9}"), 2)
$propertyWriter.WriteProperty($titlePropertyKey, "New Title")
$propertyWriter.Close()
