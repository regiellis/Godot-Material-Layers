<#
.SYNOPSIS
    Syncs the addon into the test project and runs the headless test suite.

.DESCRIPTION
    test/addons/materialLayers is a generated copy of addon/materialLayers, so
    the addon has exactly one source of truth. This script refreshes that copy,
    imports the project if needed, then runs the GDScript test runner.

.PARAMETER Case
    Substring filter on test case filenames, e.g. -Case codegen.

.PARAMETER Godot
    Path to the Godot executable. Defaults to "godot" on PATH.

.PARAMETER Reimport
    Force a full reimport before running.

.EXAMPLE
    .\run-tests.ps1
    .\run-tests.ps1 -Case codegen
#>
[CmdletBinding()]
param(
    [string]$Case = "",
    [string]$Godot = "godot",
    [switch]$Reimport
)

$ErrorActionPreference = "Stop"

$testRoot = $PSScriptRoot
$repoRoot = Split-Path -Parent $testRoot
$addonSrc = Join-Path $repoRoot "addon\materialLayers"
$addonDst = Join-Path $testRoot "addons\materialLayers"

if (-not (Test-Path $addonSrc)) {
    Write-Error "addon source not found: $addonSrc"
}

# 1. Sync the addon. Full replace, so deletions upstream propagate.
Write-Host "sync   $addonSrc -> $addonDst" -ForegroundColor DarkGray
if (Test-Path $addonDst) {
    Remove-Item -Recurse -Force $addonDst
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $addonDst) | Out-Null
Copy-Item -Recurse -Force $addonSrc $addonDst

# 1b. Force LF on shader sources. Godot's preprocessor does not continue a
#     #define across "\" + CRLF, so a CRLF checkout silently destroys the
#     SETUP_LAYER_* macros in layer_lib.gdshaderinc. Normalising here keeps the
#     suite honest on machines with core.autocrlf=true.
$normalised = 0
Get-ChildItem $addonDst -Recurse -File -Include *.gdshader, *.gdshaderinc | ForEach-Object {
    $text = [System.IO.File]::ReadAllText($_.FullName)
    if ($text.Contains("`r`n")) {
        [System.IO.File]::WriteAllText($_.FullName, $text.Replace("`r`n", "`n"))
        $normalised++
    }
}
if ($normalised -gt 0) {
    Write-Host "       normalised $normalised shader file(s) to LF" -ForegroundColor DarkYellow
}

# 2. Import. Godot needs the script class cache before --script can resolve
#    class_name globals such as LayerStack.
$godotDir = Join-Path $testRoot ".godot"
if ($Reimport -and (Test-Path $godotDir)) {
    Remove-Item -Recurse -Force $godotDir
}
if (-not (Test-Path (Join-Path $godotDir "global_script_class_cache.cfg"))) {
    Write-Host "import $testRoot" -ForegroundColor DarkGray
    & $Godot --headless --path $testRoot --import 2>&1 | Where-Object { $_ -match "ERROR|SCRIPT ERROR|Parse Error" }
}

# 3. Run.
Write-Host "run    tests" -ForegroundColor DarkGray
$runArgs = @("--headless", "--path", $testRoot, "--script", "res://tests/run_tests.gd")
if ($Case -ne "") {
    $runArgs += @("--", "--case=$Case")
}

& $Godot @runArgs
$code = $LASTEXITCODE

Write-Host ""
if ($code -eq 0) {
    Write-Host "PASS" -ForegroundColor Green
} else {
    Write-Host "FAIL (exit $code)" -ForegroundColor Red
}
exit $code
