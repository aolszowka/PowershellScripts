# This was written to help rename double episodes in a format that FileBot would
# support. In this particular scenario we started with Arthur Episodes that
# looked like: `8x01 - Dear Adil; Bitzi's Break-Up` but should have been
# `8x01-02 - Dear Adil; Bitzi's Break-Up`.
#
# I was not smart enough to figure out how to get FileBot to work as expected
# but renaming the files like the above helped FileBot figure it out.

$files = Get-ChildItem -Path 'E:\Arthur\Season.7' | Sort-Object -Property FullName

[int]$nextEpisode = 10

foreach ($file in $files) {
    # Format with a padded 0, FileBot seems to get confused otherwise.
    $episodeString = "$('{0:d2}' -f $nextEpisode)-$('{0:d2}' -f $($nextEpisode+1))"
    $nextEpisode = $nextEpisode + 2

    # This Regex needs to account for formats like 1x1-2 to help when I mess up
    # the rename.
    $currentSeasonEpisodeString = ([Regex]::Match($file.Name, '^\d+x\d+(-\d+)?')).Value

    # Fail Safely
    if ($null -eq $currentSeasonEpisodeString) {
        throw 'This tool cannot continue'
    }
    # We want to save the Season Information
    $currentSeasonEpisodeSplit = $currentSeasonEpisodeString.Split('x')
    $currentSeason = $currentSeasonEpisodeSplit[0]

    # Build up the new proposed file name
    $proposedEpisodeString = "$($currentSeason)x$episodeString"
    $proposedNewFilePath = $file.FullName.Replace($currentSeasonEpisodeString, $proposedEpisodeString)

    # Now Perform the Rename/Move
    Move-Item -LiteralPath $file.FullName -Destination $proposedNewFilePath
}
