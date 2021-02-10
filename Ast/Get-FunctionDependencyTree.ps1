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
    Write-Host "Again"
}

function Get-FunctionDependencyTree {
    param (
        [string]$Function
    )
    process {
        $Ast = (Get-Command $Function).ScriptBlock.Ast
        $Functions = $Ast.FindAll( { $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)
        $Functions | ForEach-Object { $_.GetCommandName() } | Get-Unique | Where-Object { (Get-Command $_).Source -eq "" }
    }
}

Get-FunctionDependencyTree -Function 'Primary'

# $Ast = (Get-Command Primary).ScriptBlock.Ast
# $Functions = $Ast.FindAll( { $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)
# $Functions | ForEach-Object { $_.GetCommandName() } | Get-Unique | Where-Object { (Get-Command $_).Source -eq "" }


Function Get-DependentFunction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [String[]]
        $Name
    )

    begin {
        [ScriptBlock]$predicate = {
            Param ([System.Management.Automation.Language.Ast]$Ast)
        
            $Ast -is [System.Management.Automation.Language.CommandAst]
        }
    }

    process {
        foreach ($funcName in $Name) {
            $func = Get-Item -Path Function:$funcName -ErrorAction SilentlyContinue
            if (-not $func) {
                Write-Error -Message "Failed to find function $funName" -Category ObjectNotFound
                return
            }

            $ast = $func.ScriptBlock.Ast
            [System.Management.Automation.Language.Ast[]]$violations = $ast.FindAll($predicate, $true)

            [PSCustomObject]@{
                Name     = $funcName
                Commands = [string[]]@($violations.Extent.Text)
            }
        }

    }
}

#Get-DependentFunction -Name Secondary