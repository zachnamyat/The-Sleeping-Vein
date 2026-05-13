# tools/export.ps1
# Ticket 0.16 — Build pipeline. Exports release builds to dist/ for Windows / Linux /
# Mac / Web. Requires Godot 4.6 with export templates installed.
#
# Usage:
#   .\tools\export.ps1                # all 4 platforms
#   .\tools\export.ps1 win             # one platform
#
# Export presets must exist in export_presets.cfg with names that match $Presets keys.
# Run 'godot --headless --import' once on a fresh checkout to materialize .import files.

param(
	[string]$Only = ""
)

$ErrorActionPreference = 'Stop'
$Godot = "$env:USERPROFILE\bin\godot.exe"
if (-not (Test-Path $Godot)) { $Godot = "godot" }

$ProjectPath = (Resolve-Path "$PSScriptRoot\..").Path
$DistDir = Join-Path $ProjectPath "dist"
New-Item -Path $DistDir -ItemType Directory -Force | Out-Null

$Presets = @{
	"win"   = @{ preset = "Windows Desktop"; output = "TheSleepingVein.exe" }
	"linux" = @{ preset = "Linux/X11";       output = "TheSleepingVein.x86_64" }
	"mac"   = @{ preset = "macOS";           output = "TheSleepingVein.zip" }
	"web"   = @{ preset = "Web";             output = "index.html" }
}

$Targets = if ($Only) { @($Only) } else { $Presets.Keys }

foreach ($key in $Targets) {
	if (-not $Presets.ContainsKey($key)) {
		Write-Host "Unknown preset: $key" -ForegroundColor Red
		continue
	}
	$preset = $Presets[$key]
	$outDir = Join-Path $DistDir $key
	New-Item -Path $outDir -ItemType Directory -Force | Out-Null
	$outFile = Join-Path $outDir $preset.output

	Write-Host "Exporting $key → $outFile" -ForegroundColor Yellow
	& $Godot --headless --path $ProjectPath --export-release $preset.preset $outFile
	if ($LASTEXITCODE -ne 0) {
		Write-Host "Export failed for $key (exit $LASTEXITCODE)" -ForegroundColor Red
	} else {
		Write-Host "✓ Exported $key" -ForegroundColor Green
	}
}
