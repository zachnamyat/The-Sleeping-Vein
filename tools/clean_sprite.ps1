# tools/clean_sprite.ps1
#
# Drives clean_alpha.lua through LibreSprite to chroma-key a single PNG.
# Usage:
#   .\tools\clean_sprite.ps1 -InputPath path\to\sprite.png
#   .\tools\clean_sprite.ps1 -InputPath src.png -OutputPath dst.png
#
# If -OutputPath is omitted, the input is overwritten in place.

param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"

$libresprite = "C:\Users\zach\Desktop\Programming\libresprite\libresprite.exe"
$lua = Join-Path $PSScriptRoot "clean_alpha.js"

if (-not (Test-Path $libresprite)) {
    Write-Host "ERROR: LibreSprite not found at $libresprite" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $InputPath)) {
    Write-Host "ERROR: input not found: $InputPath" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $lua)) {
    Write-Host "ERROR: clean_alpha.lua not found at $lua" -ForegroundColor Red
    exit 1
}

if ($OutputPath -eq "") { $OutputPath = $InputPath }

$absInput  = (Resolve-Path $InputPath).Path
$absLua    = (Resolve-Path $lua).Path
# Output may not exist yet; resolve its parent + concatenate.
$absOutput = if (Test-Path $OutputPath) {
    (Resolve-Path $OutputPath).Path
} else {
    Join-Path ((Resolve-Path (Split-Path $OutputPath -Parent)).Path) (Split-Path $OutputPath -Leaf)
}

Write-Host "clean_sprite: $absInput  ->  $absOutput" -ForegroundColor Cyan

# LibreSprite chains operations: open INPUT, run script, save-as OUTPUT.
# --batch suppresses the GUI.
& $libresprite --batch $absInput --script $absLua --save-as $absOutput

if ($LASTEXITCODE -ne 0) {
    Write-Host "LibreSprite exit code $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "clean_sprite: done." -ForegroundColor Green
