BeforeAll {
    . $PSScriptRoot\Invoke-SeasonEpisodeNaming.ps1
}

Describe 'Sort-ByTitle' {
    It 'Should Sort Correctly' {
        # Arrange
        $files = @(
            'T:\S1D1\A1_t10.mkv',
            'T:\S1D1\C1_t9.mkv',
            'T:\S1D1\D1_t8.mkv'
        )

        # Act
        $actual = Sort-ByTitle -Files $files

        # Assert
        $actual.Keys | Should -Be @(8, 9, 10)
        $actual.Values | Should -Be @('T:\S1D1\D1_t8.mkv', 'T:\S1D1\C1_t9.mkv', 'T:\S1D1\A1_t10.mkv')
    }

    It 'Should Support Full File Names' {
        # Arrange
        $files = @(
            'T:\S1D1\Some Title_t01',
            'T:\S1D1\SomeTitle_t02',
            'T:\S1D1\Some Title 1_t03',
            'T:\S1D1\Some Title 2_t04',
            'T:\S1D1\Some Title3_t05',
            'T:\S1D1\Some Title (2005)_t06'
        )

        # Act
        $actual = Sort-ByTitle -Files $files

        # Assert
        $actual.Keys | Should -Be @(
            1,
            2,
            3,
            4,
            5,
            6
        )
        $actual.Values | Should -Be @(
            'T:\S1D1\Some Title_t01',
            'T:\S1D1\SomeTitle_t02',
            'T:\S1D1\Some Title 1_t03',
            'T:\S1D1\Some Title 2_t04',
            'T:\S1D1\Some Title3_t05',
            'T:\S1D1\Some Title (2005)_t06'
        )
    }
}

Describe 'Get-RenameOperations' {
    It 'Should Rename Correctly' {
        # Arrange
        [System.Collections.Generic.SortedDictionary[int, string]]$sortedDictionary = [System.Collections.Generic.SortedDictionary[int, string]]::new()
        $sortedDictionary.Add(8, 'T:\S1D1\D1_t8.mkv')
        $sortedDictionary.Add(9, 'T:\S1D1\C1_t9.mkv')
        $sortedDictionary.Add(10, 'T:\S1D1\A1_t10.mkv')

        # Act
        $actual = Get-RenameOperations -TitleOrder $sortedDictionary -Season 1 -StartEpisode 1

        # Assert
        $actual['T:\S1D1\D1_t8.mkv'] | Should -Be 'T:\S1D1\S01E01.mkv'
        $actual['T:\S1D1\C1_t9.mkv'] | Should -Be 'T:\S1D1\S01E02.mkv'
        $actual['T:\S1D1\A1_t10.mkv'] | Should -Be 'T:\S1D1\S01E03.mkv'
    }

    It 'Should Support Double Episodes' {
        # Arrange
        [System.Collections.Generic.SortedDictionary[int, string]]$sortedDictionary = [System.Collections.Generic.SortedDictionary[int, string]]::new()
        $sortedDictionary.Add(8, 'T:\S1D1\D1_t8.mkv')
        $sortedDictionary.Add(9, 'T:\S1D1\C1_t9.mkv')
        $sortedDictionary.Add(10, 'T:\S1D1\A1_t10.mkv')

        # Act
        $actual = Get-RenameOperations -TitleOrder $sortedDictionary -Season 1 -StartEpisode 1 -TreatAsDoubleEpisode $true

        # Assert
        $actual['T:\S1D1\D1_t8.mkv'] | Should -Be 'T:\S1D1\S01E01E02.mkv'
        $actual['T:\S1D1\C1_t9.mkv'] | Should -Be 'T:\S1D1\S01E03E04.mkv'
        $actual['T:\S1D1\A1_t10.mkv'] | Should -Be 'T:\S1D1\S01E05E06.mkv'
    }
}
