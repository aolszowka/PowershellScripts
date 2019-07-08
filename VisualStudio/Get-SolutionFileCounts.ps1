param
(
    [Parameter(Mandatory = $true)]
    [string]$DirectoryToScan
)

# Basically perform all the logic in C#; we only use powershell because it
# allows us to have C# Code under version control that is not a committed binary
$msBuildAssembly = [Reflection.Assembly]::Load("Microsoft.Build, Version=14.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a, processorArchitecture=MSIL")

Add-Type @'
using Microsoft.Build.Construction;

public static class SolutionUtilities
{
    public static int ProjectCount(string solutionFile)
    {
        SolutionFile sln = SolutionFile.Parse(solutionFile);
        return sln.ProjectsByGuid.Count;
    }
}
'@ -ReferencedAssemblies $msBuildAssembly

# Find all SLN Files
Get-ChildItem -Path $DirectoryToScan -Filter *.sln -Recurse | ForEach-Object {
    New-Object psobject -Property @{FileName = $_.FullName; ProjectCount = [SolutionUtilities]::ProjectCount($_.FullName) }
}