# Get-SilenceProbabilities.ps1

I have a large number of WAV files, many of which can sometimes consist
completely of "silence". Historically I was using tools like Audacity to pull
WAV Forms or passing the files into Whisper AI to understand if these were files
I wanted to ignore. In a discussion with Copilot it made the recommendation to
use RMS for this task which is orders of magnitude faster.

## Reading the Entire File/Span<T>

Out of curiosity I had Copilot write a version of this that loaded the entire
file into memory and then used `Span<T>` to perform the same calculation
thinking that this might speed up the process. However in testing with my
workloads this really did not seem to speed it up. The limiting factor still
seems to be disk I/O. I have saved this version off just in case this ever
becomes more interesting.

```csharp
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Buffers.Binary;
using System.Numerics;

public static class WavSilenceAnalyzer
{
    public static double Analyze(string path, double silenceThreshold, int frameMs)
    {
        using var fs = File.OpenRead(path);
        using var br = new BinaryReader(fs);

        // --- Parse RIFF/WAVE header ---
        if (new string(br.ReadChars(4)) != "RIFF")
            throw new Exception("Not RIFF");

        br.ReadInt32(); // file size

        if (new string(br.ReadChars(4)) != "WAVE")
            throw new Exception("Not WAVE");

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

        // --- Single large read ---
        byte[] pcm = br.ReadBytes(dataSize);

        // Interpret as 16-bit samples
        Span<short> samples = MemoryMarshal.Cast<byte, short>(pcm);

        int samplesPerFrame = (int)(sampleRate * (frameMs / 1000.0)) * channels;
        int totalFrames = samples.Length / samplesPerFrame;

        if (totalFrames == 0)
            return 0;

        int silentFrames = 0;

        // Precompute threshold² to avoid sqrt
        double thresholdSquared = silenceThreshold * silenceThreshold;

        // --- Frame loop ---
        for (int f = 0; f < totalFrames; f++)
        {
            var frame = samples.Slice(f * samplesPerFrame, samplesPerFrame);

            double sumSquares = 0;

            if (channels == 1)
            {
                // Mono
                for (int i = 0; i < frame.Length; i++)
                {
                    int si = frame[i];
                    if (si < 0) si = -si;

                    double d = si / 32768.0;
                    sumSquares += d * d;
                }
            }
            else
            {
                // Stereo → average pairs
                for (int i = 0; i < frame.Length; i += 2)
                {
                    int avg = (frame[i] + frame[i + 1]) / 2;
                    int si = avg < 0 ? -avg : avg;

                    double d = si / 32768.0;
                    sumSquares += d * d;
                }
            }

            double rmsSquared = sumSquares / (samplesPerFrame / channels);

            if (rmsSquared < thresholdSquared)
                silentFrames++;
        }

        return (silentFrames / (double)totalFrames) * 100.0;
    }
}
```
