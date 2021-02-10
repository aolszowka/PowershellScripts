Describe "Get-FunctionDependencyTree.ps1" {
    Context "Functionality Tests" {
        it 'should work if there are no sub-functions' {
            # Arrange
            function NoSubfunctions {
            }

            # Act
            $result = Get-FunctionDependencyTree -Function NoSubfunctions

            # Assert
            ($result | Measure-Object).Count | Should -Be 1
            $result | Should -Be "NoSubfunctions"

        }

        it 'should work with a simple function' {
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

        it 'should follow down call tree all the way' {
            # Arrange
            function Primary {
                Secondary
            }

            function Secondary {
                Write-Host "Test"
            }

            # Act
            $result = Get-FunctionDependencyTree -Function Primary

            # Assert
            ($result | Measure-Object).Count | Should -Be 3
            $result | Should -Be @("Primary", "Secondary", "Write-Host")
        }

        it 'should return only distinct invocations' {
            # Arrange
            function Primary {
                Secondary
                Write-Host "Test"
            }
            
            function Secondary {
                Write-Host "Test"
            }
            
            # Act
            $result = Get-FunctionDependencyTree -Function Primary
            
            # Assert
            ($result | Measure-Object).Count | Should -Be 3
            $result | Should -Be @("Primary", "Write-Host", "Secondary")
        }
    }
}
