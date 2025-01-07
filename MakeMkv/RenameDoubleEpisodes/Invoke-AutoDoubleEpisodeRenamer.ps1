# This was written to help rename double episodes in a format that FileBot would
# support. These are coming from the DVD Rips but each title represents two
# episodes.
#
# I was not smart enough to figure out how to get FileBot to work as expected
# but renaming the files like the above helped FileBot figure it out.

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $Path,
    [string]
    $SeriesName = 'Rugrats (1991)',
    [int]
    $Season = 3,
    [Parameter(Mandatory = $true)]
    [int]
    $NextEpisode
)


$files = Get-ChildItem -LiteralPath $Path | Sort-Object -Property FullName

foreach ($file in $files) {
    # Format with a padded 0, FileBot seems to get confused otherwise.
    $episodeString = "S$('{0:d2}' -f $Season)E$('{0:d2}' -f $NextEpisode)-$('{0:d2}' -f $($NextEpisode+1))"
    $NextEpisode = $NextEpisode + 2

    # Build up the new proposed file name
    $currentFolderPath = [System.IO.Path]::GetDirectoryName($file.FullName)
    $currentFileExtension = [System.IO.Path]::GetExtension($file.FullName)
    $proposedFileName = "$SeriesName $episodeString$currentFileExtension"
    $proposedNewFilePath = [System.IO.Path]::Combine($currentFolderPath, $proposedFileName)

    # Now Perform the Rename/Move
    Move-Item -LiteralPath $file.FullName -Destination $proposedNewFilePath
}
