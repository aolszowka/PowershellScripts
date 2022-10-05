function Get-EnglishForNumber {
    param(
        [int]$Number
    )
    process {
        $EnglishNumbers = @{
            1   = 'One'
            2   = 'Two'
            3   = 'Three'
            4   = 'Four'
            5   = 'Five'
            6   = 'Six'
            7   = 'Seven'
            8   = 'Eight'
            9   = 'Nine'
            10  = 'Ten'
            11  = 'Eleven'
            12  = 'Twelve'
            13  = 'Thirteen'
            14  = 'Fourteen'
            15  = 'Fifteen'
            16  = 'Sixteen'
            17  = 'Seventeen'
            18  = 'Eighteen'
            19  = 'Nineteen'
            20  = 'Twenty'
            30  = 'Thirty'
            40  = 'Forty'
            50  = 'Fifty'
            60  = 'Sixty'
            70  = 'Seventy'
            80  = 'Eighty'
            90  = 'Ninety'
        }

        $readableNumber = [System.Text.StringBuilder]::new()

        if ($Number -gt 1000000) {
            throw "Numbers greater than 999,999 Not Supported"
        }

        $currentMod = $Number
        $Thousands = [Math]::Round($($currentMod / 1000), [System.MidpointRounding]::ToZero)
        if ($Thousands -ne 0) {
            $ReadableThousands = Get-EnglishForNumber $Thousands
            $readableNumber.Append("$ReadableThousands Thousand ") | Out-Null
        }

        $currentMod = $currentMod % 1000
        $Hundreds = [Math]::Round($($currentMod / 100), [System.MidpointRounding]::ToZero)
        if ($Hundreds -ne 0) {
            $ReadableHundreds = Get-EnglishForNumber $Hundreds
            $readableNumber.Append("$ReadableHundreds Hundred ") | Out-Null
        }

        $currentMod = $currentMod % 100
        $Tens = [Math]::Round($($currentMod / 10), [System.MidpointRounding]::ToZero)
        $currentMod = $currentMod % 10
        if ($Tens -ne 0) {
            if ($Tens -gt 1) {
                [int]$Offset = $Tens * 10
                $ReadableTens = "$($EnglishNumbers[$Offset]) $(Get-EnglishForNumber $currentMod)"
                $readableNumber.Append($ReadableTens) | Out-Null
            }
            else {
                [int]$Offset = ($Tens * 10) + $currentMod
                $readableNumber.Append($EnglishNumbers[$Offset]) | Out-Null
            }
        }
        else {
            if ($currentMod -ne 0) {
                $readableNumber.Append($EnglishNumbers[$currentMod]) | Out-Null
            }
        }

        if ($readableNumber.Length -ne 0) {
            $readableNumber.ToString().Trim()
        }
    }
}

Get-EnglishForNumber -Number 2200
Get-EnglishForNumber -Number 22000
Get-EnglishForNumber -Number 2201
Get-EnglishForNumber -Number 2221
Get-EnglishForNumber -Number 2211
Get-EnglishForNumber -Number 2213
Get-EnglishForNumber -Number 11

for ($i = 1; $i -lt 1025; $i++) {
    Write-Host "$i - $(Get-EnglishForNumber -Number $i)"
}
