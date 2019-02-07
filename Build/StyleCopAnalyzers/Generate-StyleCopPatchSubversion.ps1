function Generate-StyleCopPatchSubversion
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $true, Position = 0)]
        [string]$WorkingCopy,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $true, Position = 1)]
        [string]$StyleCopRule,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $true, Position = 2)]
        [string]$PatchOutputLocation
    )

    process
    {
        $shouldProcessVerboseWarning = "This process will revert all changes in your working copy; are you sure you want to do this?"
        if ($PSCmdlet.ShouldProcess($shouldProcessVerboseWarning))
        {
            # Always Create The Output Location
            New-Item -ItemType Directory -Path $PatchOutputLocation -Force | Out-Null

            Write-Host "Reverting Working Copy At $WorkingCopy"
            SVN-RevertAndCleanWorkingCopy -WorkingCopy $WorkingCopy

            $solutionsToApplyRulesTo = @(
                [System.IO.Path]::Combine($WorkingCopy, "Dotnet", "CUBO.sln"),
                [System.IO.Path]::Combine($WorkingCopy, "Fusion", "CU.Fusion.Client.sln"),
                [System.IO.Path]::Combine($WorkingCopy, "Fusion", "CU.Fusion.Server.sln")
            )

            ForEach ($solution in $solutionsToApplyRulesTo) 
            {
                Write-Host "Applying StyleCop Rule $StyleCopRule to $solution"
                StyleCop-ApplyRule -SolutionFile $solution -StyleCopRule $StyleCopRule
            }

            Write-Host "Reformatting According to FormatCSharpFiles on $WorkingCopy"
            FormatCSharpFiles-Execute -WorkingCopy $WorkingCopy

            $patchFileName = [System.IO.Path]::Combine($PatchOutputLocation, "$StyleCopRule.patch")
            Write-Host "Creating Patch of Changes saving to $patchFileName"
            SVN-CreatePatchFile -WorkingCopy $WorkingCopy -PatchOutputLocation $patchFileName
        }
    }
}

function SVN-RevertAndCleanWorkingCopy
{
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $true, Position = 0)]
        [string]$WorkingCopy
    )

    svn cleanup "$WorkingCopy" --remove-unversioned
    if ($LastExitCode -ne 0)
    {
        Write-Host "Failed to cleanup $WorkingCopy"
        exit $LastExitCode
    }

    svn revert --depth=infinity "$WorkingCopy"
    if ($LastExitCode -ne 0)
    {
        Write-Host "Failed to revert $WorkingCopy"
        exit $LastExitCode
    }
}

function StyleCop-ApplyRule
{
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $true, Position = 0)]
        [string]$SolutionFile,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $true, Position = 1)]
        [string]$StyleCopRule
    )

    S:\GitHub\StyleCopAnalyzers\StyleCop.Analyzers\StyleCopTester\bin\Debug\net46\StyleCopTester.exe /id:$StyleCopRule /fixall /apply "$SolutionFile"
}

function FormatCSharpFiles-Execute
{
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $true, Position = 0)]
        [string]$WorkingCopy
    )

    $foldersToFormat = @(
        [System.IO.Path]::Combine($WorkingCopy, "Dotnet"),
        [System.IO.Path]::Combine($WorkingCopy, "Fusion")
    )

    foreach ($folderToFormat in $foldersToFormat)
    {
        S:\TimsInternalSVN\X\Trunk\Build\RoslynDocumentFormatting\FormatCSharpFiles\bin\Release\FormatCSharpFiles.exe $folderToFormat S:\TimsInternalSVN\X\Trunk\Build\RoslynDocumentFormatting\FormatCSharpFiles\bin\Release\Filters.txt
    }
}

function SVN-CreatePatchFile
{
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $true, Position = 0)]
        [string]$WorkingCopy,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $true, Position = 1)]
        [string]$PatchOutputLocation
    )

    $patchOutput = &svn diff "$WorkingCopy"

    if ($LastExitCode -ne 0)
    {
        Write-Host "Failed to Create Patch"
        exit $LastExitCode
    }

    $patchOutput | Out-File $PatchOutputLocation
}

$versions = @("6", "7", "8")
$styleCopRules = @("SA1111")

foreach ($styleCopRule in $styleCopRules)
{
    foreach ($version in $versions)
    {
        $folderToModify = "S:\TimsSVN\" + $version + "x\Trunk"
        $saveLocation = "R:\StyleCopPatches\" + $version + "T\"
        Generate-StyleCopPatchSubversion -WorkingCopy $folderToModify -StyleCopRule "$styleCopRule" -PatchOutputLocation $saveLocation
    }
}