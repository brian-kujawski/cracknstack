# Exports the game, packages the playtest build, and uploads it to itch.io.
#
#   .\tools\release.ps1                      # Chapters 1-2, export + package + upload
#   .\tools\release.ps1 -Version 0.6         # also label the build "0.6" on itch
#   .\tools\release.ps1 -Chapters 3          # ship Chapters 1-3
#   .\tools\release.ps1 -NoUpload            # export + package only, to try it first
#
# Stops at the first step that fails, so a stale build is never uploaded.

param(
    [int]$Chapters = 2,
    [string]$Version = "",
    [switch]$NoUpload,
    [string]$Godot = "$env:USERPROFILE\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe",
    [string]$Butler = "C:\butler\butler.exe",
    [string]$Target = "umamimilkers/crackandstack:windows"
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

function Stop-Release($message) {
    Write-Host "`nSTOPPED: $message" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $Godot)) { Stop-Release "Godot not found at $Godot (pass -Godot <path>)." }

# 1. Export. Remove the old .pck first so a failed export can't leave it behind.
Write-Host "`n[1/3] Exporting from Godot..." -ForegroundColor Cyan
$pck = Join-Path $root "builds\windows\CrackAndStack.pck"
if (Test-Path $pck) { Remove-Item $pck }
& $Godot --headless --path $root --export-release "Crack & Stack" "builds/windows/CrackAndStack.exe"
if (-not (Test-Path $pck)) { Stop-Release "Godot export failed (no .pck written). See the errors above." }
$pckMB = [math]::Round((Get-Item $pck).Length / 1MB)
Write-Host "Exported. CrackAndStack.pck is $pckMB MB."
if ($pckMB -gt 300) { Stop-Release "The .pck is $pckMB MB, far bigger than expected (~40 MB). Something big got packed in; not uploading." }

# 2. Package Chapters 1..N into builds/alpha.
Write-Host "`n[2/3] Packaging Chapters 1-$Chapters into builds/alpha..." -ForegroundColor Cyan
python tools/package_alpha.py --chapters $Chapters
if ($LASTEXITCODE -ne 0) { Stop-Release "Packaging failed. See the errors above." }

# 3. Upload.
if ($NoUpload) {
    Write-Host "`nDone (no upload). builds/alpha is ready." -ForegroundColor Green
    exit 0
}
Write-Host "`n[3/3] Uploading builds/alpha to $Target..." -ForegroundColor Cyan
$pushArgs = @("push", "builds\alpha", $Target)
if ($Version) { $pushArgs += @("--userversion", $Version) }
& $Butler @pushArgs
if ($LASTEXITCODE -ne 0) { Stop-Release "Butler upload failed. See the errors above." }
& $Butler status $Target

Write-Host "`nReleased." -ForegroundColor Green
