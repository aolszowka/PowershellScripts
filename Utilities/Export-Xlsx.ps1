# Function to export a PSObject to an Excel Spreadsheet
# Requires Excel to be installed
function Export-Xlsx {
    param(
        [string]$Path,
        [PSObject]$InputObject,
        [string]$SheetName = 'Sheet1',
        [bool]$NoClobber = $false
    )
    process {
        $CSVFullPath = New-TemporaryFile

        try {
            $InputObject | Export-Csv -Path $CSVFullPath -NoTypeInformation

            if (Test-Path -Path $Path) {
                if ($NoClobber) {
                    throw "Path [$Path] exists. Will not overwrite the file."
                }
                else {
                    Remove-Item -Path $Path
                }
            }

            # At a high level what we'll do is use the Excel COM Interface to
            # create a new Workbook and then use the Excel "Import From
            # Text/CSV" functionality (under the Data Tab) to import from a CSV
            # that we export using the PowerShell Native Export-Csv and the save
            # it as an xlsx file.
            $excelCom = New-Object -ComObject Excel.Application
            $excelCom.visible = $false
            $excelCom.sheetsInNewWorkbook = 1
            $workbooks = $excelCom.Workbooks.Add()

            $worksheets = $workbooks.worksheets
            $worksheet = $worksheets.Item(1)
            $worksheet.Name = $SheetName
            $textConnector = "TEXT;$CSVFullPath"
            $cellRef = $worksheet.Range('A1')
            $connector = $worksheet.QueryTables.add($textConnector, $cellRef)
            # https://learn.microsoft.com/en-us/office/vba/api/excel.querytable
            $worksheet.QueryTables.item($connector.name).TextFileCommaDelimiter = $true
            $worksheet.QueryTables.item($connector.name).TextFileParseType = 1
            $worksheet.QueryTables.item($connector.name).Refresh() | Out-Null
            $worksheet.QueryTables.item($connector.name).Delete()
            # https://learn.microsoft.com/en-us/office/vba/api/excel.range.autofit
            $worksheet.UsedRange.EntireColumn.AutoFit() | Out-Null

            # See https://learn.microsoft.com/en-us/office/vba/api/excel.workbook.saveas
            # Magic number 51 - xlOpenXMLWorkbook (xlsx) - https://learn.microsoft.com/en-us/office/vba/api/excel.xlfileformat
            $workbooks.SaveAs($Path, 51)
            $workbooks.Saved = $true
            $workbooks.Close()
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbooks) | Out-Null
            $excelCom.Quit()
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excelCom) | Out-Null
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
        }
        finally {
            Remove-Item -Path $CSVFullPath
        }
    }
}

## Example Usage
$ItemsToExport = @(
    [PSCustomObject]@{
        FirstName = 'Joe'
        LastName  = 'Smith'
        HomeTown  = 'Billings'
    },
    [PSCustomObject]@{
        FirstName = 'Jane'
        LastName  = 'Smith'
        HomeTown  = 'Laurel'
    }
)

Export-Xlsx -Path "$PSScriptRoot\Example.xlsx" -InputObject $ItemsToExport -SheetName 'Users'
