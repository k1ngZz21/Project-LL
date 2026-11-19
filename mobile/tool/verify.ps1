<#
.SYNOPSIS
  Runs LearnLite verification (pub get, analyze, test, optional debug APK)
  in a temporary copy of the Flutter project.

.DESCRIPTION
  OneDrive locks files under mobile/build, which makes `flutter test` and
  `flutter clean` fail inside the workspace. This script mirrors only the
  sources Flutter needs into %TEMP%\learnlite_verify and runs the checks
  there. It never writes into the project folder.

.EXAMPLE
  powershell -File mobile\tool\verify.ps1
  powershell -File mobile\tool\verify.ps1 -Build
#>
param(
    [switch]$Build
)

$ErrorActionPreference = 'Stop'

$source = Split-Path -Parent $PSScriptRoot
$target = Join-Path $env:TEMP 'learnlite_verify'
if ([string]::IsNullOrWhiteSpace($env:TEMP) -or -not (Test-Path (Join-Path $source 'pubspec.yaml'))) {
    throw "Could not resolve the LearnLite project or the TEMP directory."
}

Write-Host "Source: $source"
Write-Host "Copy:   $target"
New-Item -ItemType Directory -Force $target | Out-Null

foreach ($dir in 'lib', 'test', 'assets', 'android') {
    $from = Join-Path $source $dir
    if (-not (Test-Path $from)) { continue }
    # /MIR mirrors into the temp copy only. Build outputs are excluded.
    robocopy $from (Join-Path $target $dir) /MIR /NFL /NDL /NJH /NJS /NP /XD build .gradle .dart_tool .cxx | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Copying '$dir' failed (robocopy exit $LASTEXITCODE)." }
}
foreach ($file in 'pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml') {
    Copy-Item (Join-Path $source $file) $target -Force
}

$results = [ordered]@{}
function Invoke-Step([string]$name, [scriptblock]$command) {
    Write-Host "`n=== $name ==="
    & $command
    $results[$name] = if ($LASTEXITCODE -eq 0) { 'PASSED' } else { "FAILED (exit $LASTEXITCODE)" }
}

Push-Location $target
try {
    Invoke-Step 'flutter pub get' { flutter pub get }
    if ($results['flutter pub get'] -eq 'PASSED') {
        Invoke-Step 'flutter analyze' { flutter analyze }
        Invoke-Step 'flutter test' { flutter test }
        if ($Build) {
            Invoke-Step 'flutter build apk --debug' { flutter build apk --debug }
            $apk = Join-Path $target 'build\app\outputs\flutter-apk\app-debug.apk'
            if (Test-Path $apk) { Write-Host "Debug APK: $apk" }
        }
    }
}
finally {
    Pop-Location
}

Write-Host "`n=== Summary ==="
$results.GetEnumerator() | ForEach-Object { Write-Host ("{0,-28} {1}" -f $_.Key, $_.Value) }
if ($results.Values | Where-Object { $_ -ne 'PASSED' }) { exit 1 }
exit 0
