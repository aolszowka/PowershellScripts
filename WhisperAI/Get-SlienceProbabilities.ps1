# Script to detect mostly‑silent WAV files using fast C#‑based RMS analysis.
#
# Written with the assistance of Copilot.
$WavAnalyzerCSharp = @"
/*
   High‑performance WAV silence analyzer.

   This routine parses a 16‑bit PCM WAV file, locates the "fmt " and "data"
   chunks, and processes audio in fixed‑duration frames (e.g., 20 ms). Each
   frame is read as a raw byte block and decoded sample‑by‑sample with no
   allocations or PowerShell overhead.

   For every frame, the algorithm computes RMS amplitude by accumulating the
   sum of squared sample magnitudes (promoted to int to avoid overflow on
   short.MinValue), then normalizing by 32768. Frames whose RMS falls below
   the caller‑supplied silence threshold are counted as "silent".

   The function returns the percentage of silent frames across the entire
   file. This design keeps all DSP‑heavy work in C# for speed, while allowing
   PowerShell to handle orchestration and reporting.
*/
using System;
using System.IO;

public static class WavSilenceAnalyzer
{
    /// <summary>
    /// Analyzes a 16‑bit PCM WAV file and computes the percentage of frames
    /// whose RMS amplitude falls below a specified silence threshold.
    /// </summary>
    /// <param name="path">
    /// Full file system path to the WAV file. The file must contain a valid
    /// RIFF/WAVE header with a PCM "fmt " chunk and a 16‑bit "data" chunk.
    /// </param>
    /// <param name="silenceThreshold">
    /// Normalized RMS threshold (0–1). Frames whose RMS amplitude is below
    /// this value are classified as silent.
    /// </param>
    /// <param name="frameMs">
    /// Duration of each analysis frame in milliseconds. The method reads and
    /// processes audio in fixed‑size blocks derived from this value.
    /// </param>
    /// <returns>
    /// The percentage of analyzed frames that are considered silent.
    /// </returns>
    /// <remarks>
    /// The method parses the WAV header, locates the "fmt " and "data" chunks,
    /// and then reads the audio stream in fixed‑duration frames. Each frame is
    /// decoded sample‑by‑sample directly from a byte buffer to avoid allocations.
    ///
    /// Stereo audio is downmixed by averaging left and right channels. Sample
    /// magnitudes are promoted to <see cref="int"/> before applying absolute value
    /// to avoid overflow on <see cref="short.MinValue"/>. RMS amplitude is computed
    /// by accumulating squared magnitudes and normalizing by 32768.
    ///
    /// Frames with RMS below <paramref name="silenceThreshold"/> are counted as
    /// silent, and the final result is expressed as a percentage of total frames.
    /// </remarks>
    public static double Analyze(string path, double silenceThreshold, int frameMs)
    {
        using (var fs = File.OpenRead(path))
        using (var br = new BinaryReader(fs))
        {
            // --- Parse RIFF/WAVE header ---
            var riff = new string(br.ReadChars(4));
            if (riff != "RIFF") throw new Exception("Not RIFF");

            br.ReadInt32(); // file size

            var wave = new string(br.ReadChars(4));
            if (wave != "WAVE") throw new Exception("Not WAVE");

            // Find fmt chunk
            string chunkId;
            while ((chunkId = new string(br.ReadChars(4))) != "fmt ")
            {
                int skip = br.ReadInt32();
                br.ReadBytes(skip);
            }

            int fmtSize = br.ReadInt32();
            short audioFormat = br.ReadInt16();
            short channels = br.ReadInt16();
            int sampleRate = br.ReadInt32();
            br.ReadInt32(); // byteRate
            br.ReadInt16(); // blockAlign
            short bitsPerSample = br.ReadInt16();

            if (audioFormat != 1 || bitsPerSample != 16)
                throw new Exception("Only 16-bit PCM supported");

            if (fmtSize > 16)
                br.ReadBytes(fmtSize - 16);

            // Find data chunk
            while ((chunkId = new string(br.ReadChars(4))) != "data")
            {
                int skip = br.ReadInt32();
                br.ReadBytes(skip);
            }

            int dataSize = br.ReadInt32();
            int bytesPerSample = bitsPerSample / 8;
            int frameSamples = (int)(sampleRate * (frameMs / 1000.0));

            int bytesPerFrame = frameSamples * channels * bytesPerSample;
            byte[] buffer = new byte[bytesPerFrame];

            int silentFrames = 0;
            int totalFrames = 0;

            // --- Frame loop ---
            int read;
            while ((read = fs.Read(buffer, 0, buffer.Length)) > 0)
            {
                int sampleCount = read / (bytesPerSample * channels);
                if (sampleCount == 0)
                    continue;

                double sumSquares = 0;

                int offset = 0;
                for (int i = 0; i < sampleCount; i++)
                {
                    short left = BitConverter.ToInt16(buffer, offset);
                    offset += 2;

                    short sample = left;

                    if (channels == 2)
                    {
                        short right = BitConverter.ToInt16(buffer, offset);
                        offset += 2;
                        sample = (short)((left + right) / 2);
                    }

                    // Promote to int before abs to avoid overflow on short.MinValue
                    int si = sample;
                    if (si < 0) si = -si;

                    double s = (double)si;
                    sumSquares += s * s;
                }

                double rms = Math.Sqrt(sumSquares / sampleCount) / 32768.0;

                if (rms < silenceThreshold)
                    silentFrames++;

                totalFrames++;
            }

            if (totalFrames == 0) return 0;
            return (silentFrames / (double)totalFrames) * 100.0;
        }
    }
}
"@

Add-Type -Language CSharp -TypeDefinition $WavAnalyzerCSharp

function Get-WavSilenceStats {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        # RMS threshold for silence (normalized 0–1)
        [double]$SilenceThreshold = 0.01,
        # Percentage threshold for classifying a file as "silent"
        [double]$PercentThreshold = 90
    )

    $percentSilent = [WavSilenceAnalyzer]::Analyze($FilePath, $SilenceThreshold, 20)

    return [PSCustomObject]@{
        File              = $FilePath
        PercentSilent     = [math]::Round($percentSilent, 2)
        IsSilentThreshold = $percentSilent -ge $PercentThreshold
    }
}

function Get-FlacSilenceStats {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        # RMS threshold for silence (normalized 0–1)
        [double]$SilenceThreshold = 0.01,
        # Percentage threshold for classifying a file as "silent"
        [double]$PercentThreshold = 90,
        [string]$flacPath = 'C:\DevApps\System\flac\win64\flac.exe',
        [switch]$DebugFlac
    )

    if (-not (Test-Path $FilePath)) {
        throw "FLAC file not found: $FilePath"
    }

    # Build a safe temporary WAV path
    $base = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    $dir = [System.IO.Path]::GetDirectoryName($FilePath)

    # Use a GUID suffix to guarantee no collisions
    $tempWav = Join-Path $dir "$base.temp.$([guid]::NewGuid().ToString()).wav"

    try {
        # Decode FLAC → WAV
        # --force: decode even if metadata is odd
        # --decode: output WAV
        # --output-name: specify destination
        $arguments = @(
            "--decode"
            "--force"
            "--output-name=$tempWav"
            $FilePath
        )

        # Capture output silently
        $flacOutput = & $flacPath @arguments 2>&1

        if ($DebugFlac) {
            Write-Host "FLAC output for ${FilePath}:"
            Write-Host $flacOutput
        }


        if (-not (Test-Path $tempWav)) {
            throw "FLAC decode failed: WAV not created."
        }

        # Analyze the temporary WAV
        $stats = Get-WavSilenceStats -FilePath $tempWav `
            -SilenceThreshold $SilenceThreshold `
            -PercentThreshold $PercentThreshold

        # Rewrite the File property so the report refers to the FLAC, not the temp WAV
        $stats.File = $FilePath
        return $stats
    }
    finally {
        # Cleanup
        if (Test-Path $tempWav) {
            Remove-Item $tempWav -Force
        }
    }
}

function Get-AudioSilenceReport {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        # RMS threshold for silence (normalized 0–1)
        [double]$SilenceThreshold = 0.01,
        # Percentage threshold for classifying a file as "silent"
        [double]$PercentThreshold = 90
    )

    $audioFiles = Get-ChildItem -Path $Path -Recurse -File |
    Where-Object { $_.Extension -in ".wav", ".flac" }

    foreach ($file in $audioFiles) {
        try {
            if ($file.Extension -eq ".wav") {
                Get-WavSilenceStats -FilePath $file.FullName `
                    -SilenceThreshold $SilenceThreshold `
                    -PercentThreshold $PercentThreshold
            }
            elseif ($file.Extension -eq ".flac") {
                Get-FlacSilenceStats -FilePath $file.FullName `
                    -SilenceThreshold $SilenceThreshold `
                    -PercentThreshold $PercentThreshold
            }
        }
        catch {
            [PSCustomObject]@{
                File              = $file.FullName
                PercentSilent     = 0
                IsSilentThreshold = $false
                Error             = $_.Exception.Message
            }
        }
    }
}

function Get-AudioSilenceReportParallel {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        # RMS threshold for silence (normalized 0–1)
        [double]$SilenceThreshold = 0.01,
        # Percentage threshold for classifying a file as "silent"
        [double]$PercentThreshold = 90,
        [int]$ThrottleLimit = [System.Environment]::ProcessorCount
    )

    $audioFiles = Get-ChildItem -Path $Path -Recurse -File |
    Where-Object { $_.Extension -in ".wav", ".flac" }

    # Capture function source text (preserves signatures)
    $wavFuncText = ${function:Get-WavSilenceStats}.Ast.Extent.Text
    $flacFuncText = ${function:Get-FlacSilenceStats}.Ast.Extent.Text

    $audioFiles | ForEach-Object -Parallel {

        # Load C# type only if not already present in this runspace
        if (-not ('WavSilenceAnalyzer' -as [type])) {
            Add-Type -Language CSharp -TypeDefinition $using:WavAnalyzerCSharp
        }

        # Rehydrate functions
        Invoke-Expression $using:wavFuncText
        Invoke-Expression $using:flacFuncText

        try {
            if ($_.Extension -eq ".wav") {
                Get-WavSilenceStats -FilePath $_.FullName `
                    -SilenceThreshold $using:SilenceThreshold `
                    -PercentThreshold $using:PercentThreshold
            }
            else {
                Get-FlacSilenceStats -FilePath $_.FullName `
                    -SilenceThreshold $using:SilenceThreshold `
                    -PercentThreshold $using:PercentThreshold
            }
        }
        catch {
            [PSCustomObject]@{
                File              = $_.FullName
                PercentSilent     = 0
                IsSilentThreshold = $false
                Error             = $_.Exception.Message
            }
        }

    } -ThrottleLimit $ThrottleLimit
}
