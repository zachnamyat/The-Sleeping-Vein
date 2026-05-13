# tools/clean_alpha.ps1
#
# ImageMagick-based chroma-key pipeline. For each PNG path passed in (or every
# PNG under assets/sprites/ if no path is given), it:
#   1. Samples the top-left and three other corner pixels.
#   2. If any corner is near-magenta (Gemini's generated background — any of the
#      shades from pure #FF00FF down through #E84080 due to model variation),
#      runs `magick -fuzz N% -transparent` with each detected bg color to remove
#      it cleanly with proper anti-alias handling.
#   3. Otherwise leaves the file alone (it's already cleaned).
#
# This replaces the sharp/Pillow chroma-key step that was tolerance-tuning
# sensitive. ImageMagick's `-fuzz` uses proper color-distance + handles
# semi-transparent edge pixels correctly.
#
# Usage:
#   .\tools\clean_alpha.ps1                       # clean every sprite
#   .\tools\clean_alpha.ps1 -Path src.png        # clean one file in place
#   .\tools\clean_alpha.ps1 -Path src.png -Dst d.png   # one file, dst path
#   .\tools\clean_alpha.ps1 -Dry                  # report only, don't modify

[CmdletBinding()]
param(
    [string]$Path = "",
    [string]$Dst = "",
    [switch]$Dry,
    [int]$FuzzPercent = 22,
    [int]$NearMagentaThreshold = 150
)

$ErrorActionPreference = "Stop"

$magick = Get-Command magick -ErrorAction SilentlyContinue
if (-not $magick) {
    $candidate = "C:\Program Files\ImageMagick-7.1.2-Q16-HDRI\magick.exe"
    if (Test-Path $candidate) { $magick = $candidate }
    else {
        Write-Host "ERROR: ImageMagick (magick.exe) not found on PATH and not at $candidate" -ForegroundColor Red
        exit 1
    }
} else {
    $magick = $magick.Source
}

# Magenta variants Gemini produces. The fuzz percentage will smear each of
# these to catch nearby shades.
$BgVariants = @("#FF00FF", "#E84080", "#FB2D83", "#FF1493", "#C70066")

# Pixel art demands BINARY alpha (0 or 255, never partial). Anti-aliased edges
# from chroma-keying create see-through body pixels; the threshold pass forces
# every pixel with alpha > 30% to fully opaque, the rest to fully transparent.
$AlphaThreshold = "30%"

function Get-CornerColor {
    param([string]$ImgPath, [int]$X, [int]$Y)
    # ImageMagick prints color as e.g. "srgba(255,0,255,1)" or "#FF00FFFF".
    $raw = & $magick $ImgPath -format "%[pixel:p{$X,$Y}]" info: 2>$null
    return $raw
}

function Is-NearMagenta {
    param([string]$Color)
    # Color string from magick is like "srgba(255,0,255,1)" — extract r,g,b.
    if ($Color -match "srgba?\((\d+),(\d+),(\d+)") {
        $r = [int]$Matches[1]; $g = [int]$Matches[2]; $b = [int]$Matches[3]
        # Near magenta means: high R, low G, high B.
        return ($r -gt 200 -and $g -lt 100 -and $b -gt 100)
    }
    return $false
}

function Has-AlphaChannel {
    param([string]$ImgPath)
    $raw = & $magick identify -format "%[channels]" $ImgPath 2>$null
    return ($raw -match "a")
}

function Get-MidAlpha {
    # Sample alpha at image center — if it's clearly opaque (≥ 0.95) AND no corner
    # is near-magenta, the sprite is fully clean. Otherwise we need a threshold pass.
    param([string]$ImgPath, [int]$W, [int]$H)
    $cx = [int]($W / 2); $cy = [int]($H / 2)
    $raw = & $magick $ImgPath -format "%[fx:p{$cx,$cy}.a]" info: 2>$null
    return [double]$raw
}

function Clean-OneFile {
    param([string]$InPath, [string]$OutPath, [switch]$DryRun)
    if (-not (Test-Path $InPath)) {
        Write-Host "skip (missing): $InPath" -ForegroundColor DarkYellow
        return
    }
    $size = & $magick identify -format "%w %h" $InPath 2>$null
    $parts = $size -split " "
    if ($parts.Length -lt 2) {
        Write-Host "skip (not an image?): $InPath" -ForegroundColor DarkYellow
        return
    }
    $w = [int]$parts[0]; $h = [int]$parts[1]
    $tl = Get-CornerColor $InPath 0 0
    $br = Get-CornerColor $InPath ($w - 1) ($h - 1)
    $hasMagenta = (Is-NearMagenta $tl) -or (Is-NearMagenta $br)

    # Tiles (16x16 / 16x24) tile across the floor — alpha thresholding would
    # destroy biome floor blending. Skip threshold on anything that doesn't
    # have alpha=0 corners (i.e. solid-fill tiles).
    $cornerIsTransparent = $tl -match "srgba\(.+,0(\.0+)?\)"
    $needsThreshold = $false
    if ($cornerIsTransparent) {
        $midA = Get-MidAlpha $InPath $w $h
        if ($midA -lt 1.0 -and $midA -gt 0.0) {
            $needsThreshold = $true
        }
    }

    if (-not $hasMagenta -and -not $needsThreshold) {
        Write-Host "skip (clean): $InPath  tl=$tl" -ForegroundColor DarkGray
        return
    }

    if ($DryRun) {
        $reasons = @()
        if ($hasMagenta) { $reasons += "magenta-bg" }
        if ($needsThreshold) { $reasons += "partial-alpha" }
        Write-Host "would clean: $InPath  reason=$($reasons -join ',')  tl=$tl" -ForegroundColor Yellow
        return
    }

    $args = @($InPath)
    if ($hasMagenta) {
        foreach ($bg in $BgVariants) {
            $args += @("-fuzz", "$FuzzPercent%", "-transparent", $bg)
        }
    }
    if ($needsThreshold) {
        # Threshold alpha to binary: any pixel above $AlphaThreshold becomes
        # fully opaque, the rest fully transparent. This is the canonical
        # pixel-art correction; partial alpha is wrong for hard-edged sprites.
        $args += @("-channel", "A", "-threshold", $AlphaThreshold, "+channel")
    }
    $args += @("-alpha", "on", $OutPath)
    & $magick @args
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED ($LASTEXITCODE): $InPath" -ForegroundColor Red
        return
    }
    $changes = @()
    if ($hasMagenta) { $changes += "chroma-key" }
    if ($needsThreshold) { $changes += "alpha-threshold" }
    Write-Host "cleaned ($($changes -join '+')): $InPath" -ForegroundColor Green
}

if ($Path -ne "") {
    if ($Dst -eq "") { $Dst = $Path }
    Clean-OneFile $Path $Dst -DryRun:$Dry
} else {
    $root = Join-Path (Split-Path $PSScriptRoot -Parent) "assets\sprites"
    if (-not (Test-Path $root)) {
        Write-Host "ERROR: assets/sprites/ not found at $root" -ForegroundColor Red
        exit 1
    }
    Write-Host "Scanning $root ..." -ForegroundColor Cyan
    $count = 0
    Get-ChildItem -Path $root -Filter "*.png" -Recurse -File | ForEach-Object {
        Clean-OneFile $_.FullName $_.FullName -DryRun:$Dry
        $count++
    }
    Write-Host "Processed $count files." -ForegroundColor Cyan
}
