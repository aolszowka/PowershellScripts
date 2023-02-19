$targetFolder = 'L:\MakeMKV\DS9'
$files = Get-ChildItem -Path $targetFolder -Filter *.mkv -Recurse | Select-Object -ExpandProperty FullName | Sort-Object

$episodePrefix = "Star.Trek.DS9"

[System.Collections.Generic.Dictionary[int, int]]$currentSeasonEpisode = [System.Collections.Generic.Dictionary[int, int]]::new()

[System.Collections.Generic.HashSet[string]]$doubleEpisodes = @(
    "S01E01";
    "S04E01";
    "S07E25"
)

[System.Collections.Generic.Dictionary[string, string]]$fileRenames = [System.Collections.Generic.Dictionary[string, string]]::new()

foreach ($file in $files) {
    # Get the Season
    $sourceFolderPath = [System.IO.Path]::GetDirectoryName($file)
    $sourceFolder = [System.IO.Path]::GetFileNameWithoutExtension($sourceFolderPath)
    $seasonText = ([System.Text.RegularExpressions.Regex]::Match($sourceFolder, 'S(?<Season>[\d+])')).Groups['Season'].Value
    $seasonInt = [System.Int32]::Parse($seasonText)

    if (-Not($currentSeasonEpisode.ContainsKey($seasonInt))) {
        $currentSeasonEpisode[$seasonInt] = 0
    }
    $currentSeasonEpisode[$seasonInt]++

    $episodeNumber = "S$($seasonInt.ToString('D2'))E$($currentSeasonEpisode[$seasonInt].ToString('D2'))"

    if ($doubleEpisodes.Contains($episodeNumber)) {
        $currentSeasonEpisode[$seasonInt]++
        $episodeNumber = "$($episodeNumber)E$($currentSeasonEpisode[$seasonInt].ToString('D2'))"
    }

    $episodeName = "$episodePrefix.$episodeNumber$([System.IO.Path]::GetExtension($file))"
    $fileRenames.Add($file, $episodeName)
}

$uniqueFileNameCount = ($fileRenames.Values | Get-Unique | Measure-Object).Count

if($fileRenames.Count -eq $uniqueFileNameCount) {
    foreach($kvp in $fileRenames.GetEnumerator()) {
        # Get the Season
        $sourceFolderPath = [System.IO.Path]::GetDirectoryName($kvp.Key)
        $sourceFolder = [System.IO.Path]::GetFileNameWithoutExtension($sourceFolderPath)
        $seasonText = ([System.Text.RegularExpressions.Regex]::Match($sourceFolder, 'S(?<Season>[\d+])')).Groups['Season'].Value
        $seasonInt = [System.Int32]::Parse($seasonText)

        $destinationFolder = [System.IO.Path]::Combine($targetFolder, "Season.$seasonInt")
        if(-Not(Test-Path $destinationFolder)) {
            New-Item -Path $destinationFolder -ItemType Directory
        }
        $destinationFileName = [System.IO.Path]::Combine($destinationFolder, $kvp.Value)
        Write-Host "$($kvp.Key) -> $destinationFileName"
        Move-Item -Path $kvp.Key -Destination $destinationFileName

    }
    Write-Host 'All Names Unique'
}
else {
    foreach($kvp in $fileRenames.GetEnumerator()) {
        Write-Host "$($kvp.Key) -> $($kvp.Value)"
    }
    Write-Error 'A logic error has occurred that resulted in the generation of non-unique file names; See the above listing.'
}
