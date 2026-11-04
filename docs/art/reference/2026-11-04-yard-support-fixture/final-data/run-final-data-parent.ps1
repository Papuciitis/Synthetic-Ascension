$ErrorActionPreference='Stop'
$parentRun='.superpowers/sdd/2026-11-04-trailer-yard-preview/task2b-final-data'
& 'C:/Users/NaurisKrišjānis/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -X utf8 tools/tests/build_yard_support_renderer_fixture.py --out $parentRun | Out-Null
if ($LASTEXITCODE -ne 0) {exit $LASTEXITCODE}
$parentPins=[ordered]@{wrapper=$PSCommandPath;wrapper_sha256=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash;started_utc=[DateTime]::UtcNow.ToString('o');suites=@('renderer','support','map','subset');recovery='One temporary current ChatGPT/codex resident-page recovery after compiling pinned guard and recovery helper; no apps closed or working-set limits changed'}
$parentPins | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $parentRun 'parent-sequence-pins.json') -Encoding utf8
. (Join-Path $parentRun 'launcher-sources/city_resource_guard.ps1')
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public static class YardFinalDataRecovery {
 [DllImport("kernel32.dll",SetLastError=true)]
 public static extern bool K32EmptyWorkingSet(IntPtr process);
}
'@
foreach($parentChat in @(Get-Process -Name ChatGPT,codex -ErrorAction SilentlyContinue)) {[void][YardFinalDataRecovery]::K32EmptyWorkingSet($parentChat.Handle)}
$parentRecords=@()
$parentExit=0
foreach($parentSuite in $parentPins.suites) {
    & tools/tests/run_yard_support_renderer_fixture.ps1 -FixtureDirectory $parentRun -Suite $parentSuite > (Join-Path $parentRun ($parentSuite+'-outer-stdout.log')) 2> (Join-Path $parentRun ($parentSuite+'-outer-stderr.log'))
    $parentCode=$LASTEXITCODE
    $parentRecord=Get-Content -Raw -LiteralPath (Join-Path $parentRun ($parentSuite+'-result.json')) | ConvertFrom-Json
    $parentRecords+=@([ordered]@{suite=$parentSuite;wrapper_exit=$parentCode;success=$parentRecord.success;launched=$parentRecord.launched;passed=$parentRecord.passed;failed=$parentRecord.failed;failure=$parentRecord.failure;stop_reason=$parentRecord.stop_reason})
    if ($parentCode -ne 0 -or -not $parentRecord.success) {$parentExit=1;break}
}
$parentRecords | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $parentRun 'parent-sequence-result.json') -Encoding utf8
$parentRecords | ConvertTo-Json -Depth 5
exit $parentExit
