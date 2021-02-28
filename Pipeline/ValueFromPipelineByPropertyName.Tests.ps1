function Add-Numbers {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true)][int]$A,
        [Parameter(ValueFromPipelineByPropertyName = $true)][int]$B
    )
    process {
        $A + $B
    }
}

@([PSCustomObject]@{A = 1; B = 1 },[PSCustomObject]@{A = 1; B = 2 }) | Add-Numbers