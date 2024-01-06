BeforeAll {
    . $PSScriptRoot\Invoke-SeasonEpisodeNaming.ps1
}

Describe 'Sort-ByTitle' {
    It 'Should Sort Correctly' {
        # Arrange
        $files = @(
            'T:\S1D1\A1_t10',
            'T:\S1D1\C1_t9',
            'T:\S1D1\D1_t8'
        )

        # Act
        $actual = Sort-ByTitle -Files $files

        # Assert
        $actual.Keys | Should -Be @(8, 9, 10)
        $actual.Values | Should -Be @('T:\S1D1\D1_t8', 'T:\S1D1\C1_t9', 'T:\S1D1\A1_t10')
    }
}
