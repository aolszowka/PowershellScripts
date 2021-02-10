function Primary {
    param (
        
    )
    Write-Host "Primary"
    Secondary
}

function Secondary {
    param (
        
    )
    Write-Host "Secondary"
    Tertiary -SayWhat "Tertiary"
}

function Tertiary {
    param (
        [string]$SayWhat
    )
    Write-Host $SayWhat
}

function Get-FunctionDependencyTree {
    param (
        [string]$Function
    )
    begin {
        [System.Collections.Generic.Stack[string]]$unresolved = [System.Collections.Generic.Stack[string]]::new()
        [System.Collections.Generic.HashSet[string]]$resolved = [System.Collections.Generic.HashSet[string]]::new()

        function Get-DistinctFunctionsInFunction {
            param (
                [string]$Function
            )
            process {
                # Attempt to extract the ScriptBlock using Get-Command some of
                # the built in's such as Write-Host do not return anything
                $scriptBlock = (Get-Command $Function).ScriptBlock
                if ($null -eq $scriptBlock) {
                    # For now do nothing; but perhaps log verbose?
                }
                else {
                    $Ast = $scriptBlock.Ast
                    $Functions = $Ast.FindAll( { $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)
                    $Functions | ForEach-Object { $_.GetCommandName() } | Get-Unique
                }
            }
        }
    }

    process {
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

Get-FunctionDependencyTree -Function 'Primary'