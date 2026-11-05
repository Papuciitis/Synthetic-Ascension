# Filesystem-only marker regression. No Godot, compiler, memory gate or executor.
param([Parameter(Mandatory=$true)][string]$EvidenceDirectory)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$evidence=[IO.Path]::GetFullPath((Join-Path $root $EvidenceDirectory))
if (Test-Path -LiteralPath $evidence) {throw 'Refusing existing marker-check evidence'}
[IO.Directory]::CreateDirectory($evidence) | Out-Null
$missingEngine=Join-Path $evidence 'missing-Godot.exe'
$repo=Join-Path $evidence 'harness-repo'
[IO.Directory]::CreateDirectory((Join-Path $repo 'tools/tests')) | Out-Null
Copy-Item -LiteralPath (Join-Path $root 'tools/tests/test_yard_support_launcher.ps1') -Destination (Join-Path $repo 'tools/tests/test_yard_support_launcher.ps1')
$checks=@()
foreach ($name in @('runner','harness')) {
    $output=Join-Path $evidence ($name+'-output')
    $previousAction=$ErrorActionPreference
    try {
        $ErrorActionPreference='Continue'
        if ($name -eq 'runner') {
            & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools/tests/run_yard_support_data_tests.ps1') -Suite map -Engine $missingEngine -RunDirectory $output > (Join-Path $evidence 'runner.log') 2> (Join-Path $evidence 'runner-stderr.log')
        } else {
            # Missing runner source stops the harness before compiler/executor work.
            & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'tools/tests/test_yard_support_launcher.ps1') -Engine $missingEngine -EvidenceDirectory $output > (Join-Path $evidence 'harness.log') 2> (Join-Path $evidence 'harness-stderr.log')
        }
        $code=$LASTEXITCODE
    } finally {$ErrorActionPreference=$previousAction}
    $marker=Join-Path $output '.gdignore'
    $payload=if ($name -eq 'runner') {Join-Path $output 'launcher-sources/run_yard_support_data_tests.ps1'} else {Join-Path $output 'controls.ps1'}
    $exists=Test-Path -LiteralPath $marker
    $empty=$exists -and (Get-Item -LiteralPath $marker).Length -eq 0
    $ordered=$exists -and (Test-Path -LiteralPath $payload) -and (Get-Item -LiteralPath $marker).CreationTimeUtc -le (Get-Item -LiteralPath $payload).CreationTimeUtc
    $noLaunch=if ($name -eq 'runner') {-not (Get-Content -LiteralPath (Join-Path $output 'result.json') -Raw | ConvertFrom-Json).suites[0].launched} else {-not (Test-Path -LiteralPath (Join-Path $output 'empty/run'))}
    $checks += [ordered]@{name=$name;child_exit=$code;marker_exists=$exists;marker_empty=$empty;marker_precedes_payload=$ordered;no_executor_launch=$noLaunch;verified=($code -ne 0 -and $empty -and $ordered -and $noLaunch)}
}
$checks | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $evidence 'marker-check.json') -Encoding utf8
$checks | ConvertTo-Json -Depth 5
if (@($checks | Where-Object {-not $_.verified}).Count) {exit 1}
