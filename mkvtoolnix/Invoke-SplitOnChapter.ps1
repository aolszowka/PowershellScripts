# Script to split a single MKV along a predetermined number of chapters. Useful
# when processing MKV files (such as Anime) which generally present as a single
# large MKV file with chapter markers.
#
# Take the total number of chapters from the source file, divide it by the
# `ChaptersPerSplit` argument and then use `mkvmerge --split chapters:` to
# perform the split. Once the split is completed, use `mkvpropedit` to properly
# renumber the chapters in the split file, strip any title that might exist on
# the file, and set the first English subtitle track as the default track.
#
# Written with the assistance of Copilot.
param(
    [Parameter(Mandatory)]
    [string]$InputFile,

    [int]$ChaptersPerSplit = 5,

    # Paths to mkvtoolnix tools
    [string]$MkvExtract = "C:\DevApps\System\mkvtoolnix\mkvextract.exe",
    [string]$MkvMerge = "C:\DevApps\System\mkvtoolnix\mkvmerge.exe",
    [string]$MkvPropEdit = "C:\DevApps\System\mkvtoolnix\mkvpropedit.exe"
)

# ------------------------------------------------------------
# Extract chapter XML from the original file
# ------------------------------------------------------------
function Get-MkvChapterXml {
    param(
        [string]$File,
        [string]$MkvExtract
    )

    $xmlTemp = [System.IO.Path]::GetTempFileName()

    # XML is the default format
    & $MkvExtract $File chapters $xmlTemp

    return $xmlTemp
}

# ------------------------------------------------------------
# Parse chapter XML and return top-level chapter start times
# ------------------------------------------------------------
function Get-ChapterStarts {
    param([string]$XmlPath)

    [xml]$xml = Get-Content $XmlPath -Raw

    $atoms = $xml.Chapters.EditionEntry.ChapterAtom

    $i = 0
    foreach ($c in $atoms) {
        [PSCustomObject]@{
            Index = $i
            Start = $c.ChapterTimeStart
            End   = $c.ChapterTimeEnd
            Node  = $c
        }
        $i++
    }
}

# ------------------------------------------------------------
# Compute split points: 1,5,9,13,... make sure to use 1 base
# ------------------------------------------------------------
function Get-SplitChapterIndices {
    param(
        [int]$TotalChapters,
        [int]$GroupSize
    )

    $indices = @()
    for ($i = 0; $i -lt $TotalChapters; $i += $GroupSize) {
        # mkvmerge requires 1-based chapter numbers
        $indices += ($i + 1)
    }
    return $indices
}

# ------------------------------------------------------------
# Split using mkvmerge --split chapters:X,Y,Z
# ------------------------------------------------------------
function Invoke-MkvSplit {
    param(
        [string]$InputFile,
        [int[]]$SplitIndices,
        [string]$MkvMerge,
        [switch]$Debug
    )

    $dir = Split-Path $InputFile
    $base = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)

    # mkvmerge will generate: base-split-001.mkv, base-split-002.mkv, ...
    $outputFileNameBase = Join-Path $dir "${base}-split.mkv"

    $indexList = ($SplitIndices -join ",")

    Write-Host "Splitting using chapter indices: $indexList"

    # Build the argument array EXACTLY as mkvmerge expects it
    $args = @(
        "--split", "chapters:$indexList",
        "-o", $outputFileNameBase,
        $InputFile
    )

    if ($Debug -eq $true) {
        $pretty = $args | ForEach-Object {
            if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ }
        }

        Write-Host "=== DEBUG: mkvmerge command ==="
        Write-Host "$MkvMerge $($pretty -join ' ')"
        Write-Host "================================"
    }

    # Execute mkvmerge
    & $MkvMerge @args
}

function Set-MkvChaptersAndMetadata {
    param(
        [Parameter(Mandatory)]
        [string]$Directory,

        [Parameter(Mandatory)]
        [string]$MkvExtract,

        [Parameter(Mandatory)]
        [string]$MkvPropEdit
    )

    # Only touch split outputs; avoids accidental edits to other MKVs in the same folder
    $files = Get-ChildItem $Directory -Filter "*split-*.mkv"

    foreach ($file in $files) {
        Write-Host "Processing chapters and metadata in $($file.Name)"

        # Create temp files
        $xmlTemp = [System.IO.Path]::GetTempFileName()
        $newXml = [System.IO.Path]::GetTempFileName()

        try {
            #
            # 1. Extract chapters
            #
            & $MkvExtract $file.FullName chapters $xmlTemp

            #
            # 2. Load and renumber chapter titles
            #
            [xml]$xml = Get-Content $xmlTemp -Raw

            $i = 1
            foreach ($atom in $xml.Chapters.EditionEntry.ChapterAtom) {
                $display = $atom.ChapterDisplay
                if ($display) {
                    $display.ChapterString = "Chapter $i"
                }
                $i++
            }

            #
            # 3. Save modified XML
            #
            $xml.Save($newXml)

            #
            # 4. Inject updated chapters, set subtitle default, strip title
            #
            & $MkvPropEdit $file.FullName `
                --chapters $newXml `
                --edit track:s1 --set flag-default=1 `
                --edit info --delete title
        }
        finally {
            #
            # 5. Cleanup temp files
            #
            if (Test-Path $xmlTemp) { Remove-Item $xmlTemp -Force }
            if (Test-Path $newXml) { Remove-Item $newXml  -Force }
        }
    }
}

# ------------------------------------------------------------
# MAIN PIPELINE
# ------------------------------------------------------------

$dir = Split-Path $InputFile
$completed = Join-Path $dir "_Completed"

if (-not (Test-Path $completed)) {
    New-Item -ItemType Directory -Path $completed | Out-Null
}


Write-Host "Extracting chapter XML..."
$xmlPath = Get-MkvChapterXml -File $InputFile -MkvExtract $MkvExtract

Write-Host "Parsing chapter XML..."
$chapters = Get-ChapterStarts -XmlPath $xmlPath

$total = $chapters.Count
Write-Host "Found $total chapters."

Write-Host "Computing split indices..."
$splitIndices = Get-SplitChapterIndices -TotalChapters $total -GroupSize $ChaptersPerSplit
Write-Host "Split indices: $($splitIndices -join ', ')"

Write-Host "Splitting file..."
Invoke-MkvSplit -InputFile $InputFile -SplitIndices $splitIndices -MkvMerge $MkvMerge

Write-Host "Moving source file to _Completed..."
Move-Item -LiteralPath $InputFile -Destination $completed

Write-Host "Fixing chapters, title, and setting English subtitles to default in output files..."
Set-MkvChaptersAndMetadata -Directory $dir -MkvExtract $MkvExtract -MkvPropEdit $MkvPropEdit

Write-Host "Done."
