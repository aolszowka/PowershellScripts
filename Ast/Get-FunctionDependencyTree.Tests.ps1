Describe "Get-FunctionDependencyTree.ps1" {
    Context "Functionality Tests" {
        it 'should have a single result with a simple function' {
            # Arrange
            function SimpleFunction {
                Write-Host
            }

            # Act
            $result = Get-FunctionDependencyTree -Function SimpleFunction

            # Assert
            ($result | Measure-Object).Count | Should -Be 2
            $result | Should -Be @("SimpleFunction", "Write-Host")
        }

        it 'should follow down call tree' {
            # Arrange
            function Primary {
                Secondary
            }

            function Secondary {
            }

            # Act
            $result = Get-FunctionDependencyTree -Function Primary

            # Assert
            ($result | Measure-Object).Count | Should -Be 2
            $result | Should -Be @("Primary", "Secondary")
        }
    }
}
