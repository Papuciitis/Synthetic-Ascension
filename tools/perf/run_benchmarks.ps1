# Runs the performance benchmark scenes with their acceptance gates and
# propagates a non-zero exit code if any gate fails.
#
#   powershell -ExecutionPolicy Bypass -File tools/perf/run_benchmarks.ps1 [-Godot <path>] [-SkipWindowed]
#
# 1. EnemyHordeBenchmark  - WINDOWED (a real renderer; the 33 ms frame-p95 gate
#                           is skipped headless because headless frames carry
#                           no draw cost).
# 2. MinigunStressBenchmark - headless, measurement only.
# 3. EnemyPressureBenchmark - both arms run under a controlled pressure override
#                           so the emergency tier policy is exercised; the legacy
#                           arm (BENCHMARK_LEGACY_PRESSURE=1) writes the baseline,
#                           then the candidate must keep >= 20% fewer ordinary
#                           physics bodies (per-step time is reported alongside).
param(
    [string]$Godot = "$env:USERPROFILE\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe",
    [switch]$SkipWindowed
)

$project = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$reports = Join-Path $project "performance_results\benchmarks"
New-Item -ItemType Directory -Force $reports | Out-Null
$baseline = Join-Path $reports "enemy-pressure-baseline.json"
$candidate = Join-Path $reports "enemy-pressure.json"
$failed = @()

function Invoke-Bench([string]$label, [string[]]$extraArgs, [hashtable]$envVars) {
    Write-Host "===== $label ====="
    foreach ($k in $envVars.Keys) { Set-Item -Path "Env:$k" -Value $envVars[$k] }
    & $Godot --path $project --quit-after 200000 @extraArgs
    $code = $LASTEXITCODE
    foreach ($k in $envVars.Keys) { Remove-Item -Path "Env:$k" -ErrorAction SilentlyContinue }
    if ($code -ne 0) {
        Write-Host "$label -> exit $code" -ForegroundColor Red
        $script:failed += $label
    } else {
        Write-Host "$label -> ok"
    }
}

if (-not $SkipWindowed) {
    Invoke-Bench "horde (windowed, gated)" @("res://tools/tests/EnemyHordeBenchmark.tscn") @{}
}
Invoke-Bench "minigun (headless)" @("--headless", "res://tools/tests/MinigunStressBenchmark.tscn") @{}
Invoke-Bench "pressure baseline (legacy arm)" @("--headless", "res://tools/tests/EnemyPressureBenchmark.tscn") @{
    BENCHMARK_LEGACY_PRESSURE = "1"
    BENCHMARK_REPORT_PATH = $baseline
}
Invoke-Bench "pressure candidate (gated vs baseline)" @("--headless", "res://tools/tests/EnemyPressureBenchmark.tscn") @{
    BENCHMARK_BASELINE_PATH = $baseline
    BENCHMARK_REPORT_PATH = $candidate
}

if ($failed.Count -gt 0) {
    Write-Host "GATES FAILED: $($failed -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host "all benchmark gates passed"
exit 0
