BeforeAll {
    . $PSScriptRoot\MKVToolNix.ps1
}

Describe 'Get-TitleFromFileName' {
    It 'Should Support Multi-Episodes' {
        # Arrange / Act
        $actual = Get-TitleFromFileName -FileName 'Series.S01E01-E02.It.Begins' -IncludeSeasonAndEpisode $true -IncludeSeriesName $true

        # Assert
        $actual | Should -Be 'Series - S01E01-E02 - It Begins'
    }

    It 'Should Exclude Series Name Even If It Exists When Asked' {
        # Arrange / Act
        $actual = Get-TitleFromFileName -FileName 'Series.S02E01.Starts.Again' -IncludeSeasonAndEpisode $true -IncludeSeriesName $false

        # Assert
        $actual | Should -Be 'S02E01 - Starts Again'
    }

    It 'Should Handle Missing Series Names' {
        # Arrange / Act
        $actual = Get-TitleFromFileName -FileName 'S03E01.Missing.Series' -IncludeSeasonAndEpisode $true -IncludeSeriesName $true

        # Assert
        $actual | Should -Be 'S03E01 - Missing Series'
    }

    It 'Should Support Absolute Ordering Naming' {
        # Arrange / Act
        $actual = Get-TitleFromFileName -FileName 'E02.Absolute.Order' -IncludeSeasonAndEpisode $true -IncludeSeriesName $true

        # Assert
        $actual | Should -Be 'E02 - Absolute Order'
    }

    It 'Should Support Absolute Ordering Naming No Season and Episode' {
        # Arrange / Act
        $actual = Get-TitleFromFileName -FileName 'E02.Absolute.Order' -IncludeSeasonAndEpisode $false -IncludeSeriesName $true

        # Assert
        $actual | Should -Be 'Absolute Order'
    }

    It 'Should Support No Season and Episode' {
        # Arrange / Act
        $actual = Get-TitleFromFileName -FileName 'S02E02.No.Season.And.Episode' -IncludeSeasonAndEpisode $false -IncludeSeriesName $true

        # Assert
        $actual | Should -Be 'No Season And Episode'
    }

    It 'Should Preserve Periods In Spaced Names' {
        # Arrange / Act
        $actual = Get-TitleFromFileName -FileName 'S02E02 All Good Things...' -IncludeSeasonAndEpisode $false -IncludeSeriesName $true

        # Assert
        $actual | Should -Be 'All Good Things...'
    }

    It 'Should Support Plex Named Seasons' {
        # Arrange / Act
        $actual = Get-TitleFromFileName -FileName 'S02E02-E03 - All Good Things...' -IncludeSeasonAndEpisode $true -IncludeSeriesName $true

        # Assert
        $actual | Should -Be 'S02E02-E03 - All Good Things...'
    }

    It 'Should Not Print The Season and Episode When Not Asked' {
        # Arrange / Act
        $actual = Get-TitleFromFileName -FileName 'Cool.Tunes.S02E02.No.Season.And.Episode' -IncludeSeasonAndEpisode $false -IncludeSeriesName $true

        # Assert
        $actual | Should -Be 'Cool Tunes - No Season And Episode'
    }
}
