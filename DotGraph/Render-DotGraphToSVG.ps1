<#
.SYNOPSIS
Renders a given DotGraph File into an SVG

.DESCRIPTION
Given a DotGraph File use GraphViz to Render the corresponding SVG.

.PARAMETER DotGraph
This is the DotGraph file to render the SVG for.

.PARAMETER OutputPath
(Optional) This is the fully qualified location to save the SVG to. This defaults to the same location as the DotGraph but changing its extension to .svg

.PARAMETER ToolPath
(Optional) Allows you to specify the fully qualified path to the Dot.exe generator. Defaults to the default install location of GraphViz 2.38 on the C Drive.

.LINK
https://github.com/aolszowka/PowerShellScripts

.NOTES
This script is provided under the MIT License.
The most current version can be found at https://github.com/aolszowka/PowerShellScripts as well as bug reports
#>
param
(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
    [ValidateScript(
        {
            if (-Not(Test-Path($_)))
            {
                throw [System.ArgumentException] "The specified Dotgraph '$_' does not exist; are you sure you typed the path correctly?"
            }
            $true
        }
    )]
    [string]$DotGraph,
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = [string]::Empty,
    [Parameter(Mandatory = $false)]
    [ValidateScript(
        {
            if (-Not(Test-Path($_)) -Or -Not($_.EndsWith("dot.exe", "InvariantCultureIgnoreCase") ))
            {
                throw [System.ArgumentException] "Dot.exe was not found at '$_'; are you sure you gave the right tool path?"
            }
            $true
        }
    )]
    [string]
    $ToolPath = "C:\Program Files (x86)\Graphviz2.38\bin\dot.exe"
)

# We need to check again because it is possible that the user was attempting to
# use the default instead of specifying the path.
if (-Not(Test-Path($ToolPath)))
{
    Write-Error -Message "Dot.exe was not found at '$_' are you sure GraphViz is installed? You can override the default location by specifying -ToolPath"
    Exit 9009
}

# If the user did not specify an output path then we'll generate one
# by creating the output file right next to the dotgraph but with the
# .svg extension
if([string]::IsNullOrEmpty($OutputPath))
{
    $OutputPath = [System.IO.Path]::ChangeExtension($DotGraph, ".svg")
}

# If the save location does not exist create the subfolders
$folderPath = [System.IO.Path]::GetDirectoryName($OutputPath)
New-Item -ItemType Directory -Path $folderPath -Force | Out-Null
if (-Not(Test-Path -Path $folderPath))
{
    Write-Error -Message "The output folder path '$folderPath' did not exist and could not be created; do you have write permissions?"
    Exit 9009
}

# Now actually attempt to run the utilty and output as SVG
$command = "& ""$ToolPath"" -Tsvg ""$DotGraph"" -o ""$OutputPath"""
Invoke-Expression $command

# See if we got a non-zero exit code; if so we need to alert the end user
if ($LASTEXITCODE -ne 0)
{
    Write-Error -Message "Dot.exe exited with a non-zero exit code; this was the command '$command'"
    exit $LASTEXITCODE
}