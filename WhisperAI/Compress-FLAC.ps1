function Compress-FLAC {
    [CmdletBinding()]
    param (
        [Parameter( Position = 0, Mandatory = $true)]
        [string]
        $Path
    )

    process {
        $flacPath = 'C:\DevApps\System\flac\win64\flac.exe'
        $metaflacPath = 'C:\DevApps\System\flac\win64\metaflac.exe'

        $wavFiles = Get-ChildItem -LiteralPath $Path -Filter '*.wav' -Recurse
        foreach ($wavFile in $wavFiles.FullName) {
            $flacFilePath = [System.IO.Path]::Combine($([System.IO.Path]::GetDirectoryName($wavFile)), $("$([System.IO.Path]::GetFileNameWithoutExtension($wavFile)).flac"))
            # If No FLAC File Found; Compress!
            if (-Not(Test-path $flacFilePath)) {
                &$flacPath "$wavFile"
            }

            # Now see if the FLAC File Exists
            if (Test-Path $flacFilePath) {
                # Delete if FlAC File Exists
                Write-Host "WAV File [$wavFile] has a FLAC File; Removing!"
                Remove-Item -Path $wavFile
            }
        }

        # Update FLAC Metadata As well
        $flacFiles = Get-ChildItem -Path $Path -Filter '*.flac' -Recurse
        foreach ($flacFile in $flacFiles.FullName) {
            $metaDataPath = [System.IO.Path]::Combine($([System.IO.Path]::GetDirectoryName($flacFile)), 'metadata.txt')
            if (Test-Path $metaDataPath) {
                # Assumption that metadata.txt is a plain text file in the following
                # format:
                #   ARTIST
                #   TITLE
                #   ALBUM
                $metaData = Get-Content -Path $metaDataPath
                if ($metaData.Length -eq 3) {
                    $metaDataObject = [PSCustomObject]@{
                        Artist = "$($metaData[0])"
                        Title  = "$($metaData[1])"
                        Album  = "$($metaData[2])"
                    }

                    # If #DATE# is specified inside of the metadata file, we need to
                    # extract the date from the filename.
                    $fileNameDate = [System.IO.Path]::GetFileNameWithoutExtension($flacFile).Substring(0, 8)
                    $metaDataObject.Title = $metaDataObject.Title.Replace('#DATE#', $fileNameDate)

                    # Extract the Existing FLAC Metadata
                    $existingMetaDataObject = [PSCustomObject]@{
                        Artist = "$($(&$metaflacPath --show-tag=ARTIST "$flacFile")?.Replace('ARTIST=', ''))"
                        Title  = "$($(&$metaflacPath --show-tag=TITLE "$flacFile")?.Replace('TITLE=', ''))"
                        Album  = "$($(&$metaflacPath --show-tag=ALBUM "$flacFile")?.Replace('ALBUM=', ''))"
                    }

                    # Compare the Objects
                    if ((Compare-Object -ReferenceObject $metaDataObject -DifferenceObject $existingMetaDataObject -Property Artist, Title, Album).Length -ne 0) {
                        Write-Host "Meta Data Did Not Match for [$flacFile]."
                        &$metaflacPath --remove-tag="ARTIST" "$flacFile"
                        &$metaflacPath --set-tag="ARTIST=$($metaDataObject.Artist)" "$flacFile"
                        &$metaflacPath --remove-tag="TITLE" "$flacFile"
                        &$metaflacPath --set-tag="TITLE=$($metaDataObject.Title)" "$flacFile"
                        &$metaflacPath --remove-tag="ALBUM" "$flacFile"
                        &$metaflacPath --set-tag="ALBUM=$($metaDataObject.Album)" "$flacFile"
                    }
                }
                else {
                    Write-Error -Message "Malformed Metadata File Found at [$metaDataPath]; Unexpected number of elements found [$($metaData.Length)]"
                }
            }
        }
    }
}

Compress-FLAC
