param(
    [string]$InputFile = ".\music.txt",
    [string]$OutputFile = ".\music.wav"
)

# ------------------------------------------------
# File paths
# ------------------------------------------------

$inputPath = if ([System.IO.Path]::IsPathRooted($InputFile)) {
    [System.IO.Path]::GetFullPath($InputFile)
}
else {
    [System.IO.Path]::GetFullPath(
        (Join-Path $PSScriptRoot $InputFile)
    )
}

$outputPath = if ([System.IO.Path]::IsPathRooted($OutputFile)) {
    [System.IO.Path]::GetFullPath($OutputFile)
}
else {
    [System.IO.Path]::GetFullPath(
        (Join-Path $PSScriptRoot $OutputFile)
    )
}

# Check whether input and output files are the same.
if ([string]::Equals(
    $inputPath,
    $outputPath,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    Write-Warning "Input and output files must be different."
    return
}

# Check whether the input file exists.
if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) {
    Write-Warning "Input file not found: $inputPath"
    return
}

# Check whether the output directory exists.
$outputDirectory = [System.IO.Path]::GetDirectoryName($outputPath)

if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    Write-Warning "Output directory not found: $outputDirectory"
    return
}

# ------------------------------------------------
# Audio settings
# ------------------------------------------------

$sampleRate = 44100
$amplitude = 0.3
$channels = 1
$bitsPerSample = 16

# ------------------------------------------------
# TXT -> PCM samples
# ------------------------------------------------

$samples = [System.Collections.Generic.List[int16]]::new()

$lineNumber = 0

foreach ($line in Get-Content -LiteralPath $inputPath) {
    $lineNumber++
    $line = $line.Trim()

    # Skip empty lines and comments.
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
        continue
    }

    # Validate the input format.
    if ($line -notmatch "^\d+(\.\d+)?\s+\d+$") {
        Write-Warning "Invalid line ($lineNumber): $line"
        continue
    }

    $parts = $line -split "\s+"

    # Parse frequency and duration.
    $frequency = 0.0
    $durationMs = 0

    if (
        -not [double]::TryParse($parts[0], [ref]$frequency) -or
        -not [int]::TryParse($parts[1], [ref]$durationMs)
    ) {
        Write-Warning "Invalid numeric value ($lineNumber): $line"
        continue
    }

    # Validate frequency and duration.
    if ($frequency -gt ($sampleRate / 2)) {
        Write-Warning "Invalid frequency ($lineNumber): $frequency"
        continue
    }

    if ($durationMs -le 0) {
        Write-Warning "Invalid duration ($lineNumber): $durationMs"
        continue
    }

    $sampleCount = [int][Math]::Ceiling(
        $sampleRate * $durationMs / 1000.0
    )

    for ($i = 0; $i -lt $sampleCount; $i++) {
        # 0 Hz produces silence.
        if ($frequency -eq 0) {
            $value = 0.0
        }
        else {
            $time = $i / [double]$sampleRate

            # Generate a sine wave.
            $value = [Math]::Sin(
                2.0 * [Math]::PI * $frequency * $time
            )

            $value *= $amplitude
        }

        # Convert the sample to 16-bit PCM.
        $pcm = [int16]($value * 32767)
        $samples.Add($pcm)
    }
}

# Check whether any valid samples were generated.
if ($samples.Count -eq 0) {
    Write-Warning "No valid audio data found."
    return
}

# ------------------------------------------------
# WAV output
# ------------------------------------------------

$stream = [System.IO.File]::Create($outputPath)
$writer = [System.IO.BinaryWriter]::new($stream)

try {
    $blockAlign = $channels * ($bitsPerSample / 8)
    $byteRate = $sampleRate * $blockAlign
    $dataSize = $samples.Count * ($bitsPerSample / 8)

    # RIFF header
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
    $writer.Write([int](36 + $dataSize))
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("WAVE"))

    # fmt chunk
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("fmt "))
    $writer.Write([int]16)                 # Chunk size
    $writer.Write([int16]1)                # Audio format: PCM
    $writer.Write([int16]$channels)
    $writer.Write([int]$sampleRate)
    $writer.Write([int]$byteRate)
    $writer.Write([int16]$blockAlign)
    $writer.Write([int16]$bitsPerSample)

    # data chunk
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
    $writer.Write([int]$dataSize)

    foreach ($sample in $samples) {
        $writer.Write($sample)
    }
}
finally {
    $writer.Dispose()
}

Write-Host "Created: $outputPath"