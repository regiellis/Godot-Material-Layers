<#
.SYNOPSIS
    Syncs the addon into the test and example projects, runs the headless test
    suite, then verifies the example project end to end.

.DESCRIPTION
    test/addons/materialLayers and examples/vcol-heightblend/addons/materialLayers
    are generated copies of addon/materialLayers, so the addon has exactly one
    source of truth. This script refreshes those copies, imports each project if
    needed, runs the GDScript test runner, and (on full runs) verifies the
    example project: scene loads, stacks compile, uniforms propagate.

.PARAMETER Case
    Substring filter on test case filenames, e.g. -Case codegen. A filtered run
    skips the example verification.

.PARAMETER Godot
    Path to the Godot executable. Defaults to "godot" on PATH.

.PARAMETER Reimport
    Force a full reimport of both projects before running.

.PARAMETER SkipExample
    Run only the test suite, without the example project verification.

.EXAMPLE
    .\run-tests.ps1
    .\run-tests.ps1 -Case codegen
#>
[CmdletBinding()]
param(
    [string]$Case = "",
    [string]$Godot = "godot",
    [switch]$Reimport,
    [switch]$SkipExample
)

$ErrorActionPreference = "Stop"

$testRoot = $PSScriptRoot
$repoRoot = Split-Path -Parent $testRoot
$addonSrc = Join-Path $repoRoot "addon\materialLayers"
$exampleRoot = Join-Path $repoRoot "examples\vcol-heightblend"

if (-not (Test-Path $addonSrc)) {
    Write-Error "addon source not found: $addonSrc"
}

# Full replace, so deletions upstream propagate. Shader sources are forced to
# LF: Godot's preprocessor does not continue a #define across "\" + CRLF, so a
# CRLF copy would silently destroy the SETUP_LAYER_* macros. .gitattributes
# pins LF already; this keeps the suite honest on stale clones.
function Sync-Addon([string]$Destination) {
    Write-Host "sync   $addonSrc -> $Destination" -ForegroundColor DarkGray
    if (Test-Path $Destination) {
        Remove-Item -Recurse -Force $Destination
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
    Copy-Item -Recurse -Force $addonSrc $Destination

    $normalised = 0
    Get-ChildItem $Destination -Recurse -File -Include *.gdshader, *.gdshaderinc | ForEach-Object {
        $text = [System.IO.File]::ReadAllText($_.FullName)
        if ($text.Contains("`r`n")) {
            [System.IO.File]::WriteAllText($_.FullName, $text.Replace("`r`n", "`n"))
            $normalised++
        }
    }
    if ($normalised -gt 0) {
        Write-Host "       normalised $normalised shader file(s) to LF" -ForegroundColor DarkYellow
    }
}

# Godot needs the script class cache before --script can resolve class_name
# globals such as LayerStack.
function Ensure-Import([string]$ProjectRoot) {
    $godotDir = Join-Path $ProjectRoot ".godot"
    if ($Reimport -and (Test-Path $godotDir)) {
        Remove-Item -Recurse -Force $godotDir
    }
    if (-not (Test-Path (Join-Path $godotDir "global_script_class_cache.cfg"))) {
        Write-Host "import $ProjectRoot" -ForegroundColor DarkGray
        & $Godot --headless --path $ProjectRoot --import 2>&1 | Where-Object { $_ -match "ERROR|SCRIPT ERROR|Parse Error" }
    }
}

# --- test suite -------------------------------------------------------------

Sync-Addon (Join-Path $testRoot "addons\materialLayers")
Ensure-Import $testRoot

Write-Host "run    tests" -ForegroundColor DarkGray
$runArgs = @("--headless", "--path", $testRoot, "--script", "res://tests/run_tests.gd")
if ($Case -ne "") {
    $runArgs += @("--", "--case=$Case")
}

& $Godot @runArgs
$testFailures = $LASTEXITCODE

# --- example project --------------------------------------------------------

$exampleFailures = 0
if ($SkipExample -or $Case -ne "") {
    Write-Host "skip   example verification" -ForegroundColor DarkGray
} else {
    Sync-Addon (Join-Path $exampleRoot "addons\materialLayers")
    Ensure-Import $exampleRoot

    Write-Host "run    example verification" -ForegroundColor DarkGray
    & $Godot --headless --path $exampleRoot --script "res://tools/verify_example.gd"
    $exampleFailures = $LASTEXITCODE
}

# --- verdict ----------------------------------------------------------------

$total = $testFailures + $exampleFailures
Write-Host ""
if ($total -eq 0) {
    Write-Host "PASS" -ForegroundColor Green
} else {
    Write-Host "FAIL (tests: $testFailures, example: $exampleFailures)" -ForegroundColor Red
}
exit $total
