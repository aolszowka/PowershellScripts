function Get-FunctionDependencyTree {
    <#
    .SYNOPSIS
    Return all N-Order dependent functions.
    .DESCRIPTION
    Given a function name return a listing that contains all of the distinct
    N-Order functions dependend upon by this function, including the target
    function.
    .PARAMETER Function
    The function for which to generate the dependency tree for.
    .OUTPUTS
    [hashtable[string]] or [string]
    The name of the given function and its N-Order dependent functions
    .EXAMPLE
    Get-FunctionDependencyTree -Function Get-FunctionDependencyTree
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Function
    )
    begin {
        function Get-DistinctFunctionsInFunction {
            <#
            .SYNOPSIS
            (Internal) Return distinct functions utilized by the given function
            .EXAMPLE
            Get-DistinctFunctionsInFunction -Function Get-DistinctFunctionsInFunction
            .OUTPUTS
            [string[]] or nothing
            The distinct functions called within the given function
            #>
            param (
                [string]$Function
            )
            process {
                # If a function is not defined in the environment (it may be
                # nested or defined inline for example) then do not attempt
                # to export the function
                $gcResult = Get-Command $Function -ErrorAction SilentlyContinue

                if ($null -eq $gcResult) {
                    Write-Verbose "Failed to find function $Function; Was it nested? Silently Continuing"
                }
                else {
                    # Attempt to extract the ScriptBlock using Get-Command some of
                    # the built in's such as Write-Host do not return anything
                    $scriptBlock = ($gcResult).ScriptBlock
                    if ($null -eq $scriptBlock) {
                        Write-Verbose "Failed to get a Script Block for function $Function; Is it a .NET cmdlet? Silently Continuing"
                    }
                    else {
                        # Utilize the PowerShell Abstract Syntax Tree to Parse
                        # See https://powershell.one/powershell-internals/parsing-and-tokenization/abstract-syntax-tree
                        $ast = $scriptBlock.Ast
                        $functions = $ast.FindAll( { $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)
                        $functions | ForEach-Object { $_.GetCommandName() } | Get-Unique
                    }
                }
            }
        }
    }

    process {
        [System.Collections.Generic.Stack[string]]$unresolved = [System.Collections.Generic.Stack[string]]::new()
        [System.Collections.Generic.HashSet[string]]$resolved = [System.Collections.Generic.HashSet[string]]::new()

        # Add ourselves to the list of resolved
        $resolved.Add($Function) | Out-Null

        # Do the initial load
        $currentFunctionCalls = Get-DistinctFunctionsInFunction -Function $Function
        foreach ($funCall in $currentFunctionCalls) {
            $unresolved.Push($funCall)
        }

        # While we still have unresolved functions, recurse
        while ($unresolved.Count -ne 0) {
            $currentFunction = $unresolved.Pop()
            # Don't attempt to resolve anything that was already resolved
            if ($resolved.Contains($currentFunction) -ne $true) {
                $resolved.Add($currentFunction) | Out-Null
                $currentFunctionCalls = Get-DistinctFunctionsInFunction -Function $currentFunction
                foreach ($funCall in $currentFunctionCalls) {
                    $unresolved.Push($funCall)
                }
            }
        }

        $resolved
    }
}
