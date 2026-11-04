# Runs ONLY a previously pinned tiny fixture. No import, Game, or autoloads.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$FixtureDirectory,
    [ValidateSet('renderer','subset','support','map','native','native-parse')][string]$Suite='renderer',
    [string]$Engine=(Join-Path ([Environment]::GetFolderPath('Desktop')) 'Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64.exe')
)
$ErrorActionPreference='Stop'
$yardRun=(Resolve-Path -LiteralPath $FixtureDirectory).Path
$yardProject=Join-Path $yardRun 'fixture'
$yardResult=Join-Path $yardRun ($Suite+'-result.json')
if (Test-Path -LiteralPath $yardResult) {throw 'Refusing to overwrite run evidence'}
$yardReservation=[IO.File]::Open(($yardResult+'.reserve'),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
$yardMutex=$null
$yardLocked=$false
$yardProc=$null
$yardOldApp=$env:APPDATA
$yardOldLocal=$env:LOCALAPPDATA
$yardStatus=[ordered]@{suite=$Suite;success=$false;launched=$false;failure='';exit_code=$null;stop_reason='';engine_sha256='';arguments=@()}
$yardExit=1
try {
    $yardConfig=Get-Content -Raw -LiteralPath (Join-Path $yardRun 'fixture.json') | ConvertFrom-Json
    if (($Suite -in @('native','native-parse')) -ne [bool]$yardConfig.native) {throw 'Suite/profile mismatch'}
    $yardPins=Get-Content -Raw -LiteralPath (Join-Path $yardRun 'source-pins.json') | ConvertFrom-Json
    $yardExecutingHash=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $yardPinnedLauncher=@($yardPins | Where-Object {$_.path -eq 'launcher-sources/run_yard_support_renderer_fixture.ps1'})
    if ($yardPinnedLauncher.Count -ne 1 -or $yardExecutingHash -ne $yardPinnedLauncher[0].sha256) {throw 'Executing launcher differs from pinned fixture snapshot'}
    $yardStatus.launcher_sha256=$yardExecutingHash
    foreach ($yardPin in $yardPins) {
        $yardPath=if ($yardPin.path.StartsWith('launcher-sources/')) {Join-Path $yardRun $yardPin.path} else {Join-Path $yardProject $yardPin.path}
        if ((Get-FileHash -LiteralPath $yardPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $yardPin.sha256) {throw ('Fixture source pin mismatch: '+$yardPin.path)}
    }
    if ((Get-Content -Raw -LiteralPath (Join-Path $yardProject 'project.godot')) -match '\[autoload\]') {throw 'No autoloads allowed'}
    $yardMutex=New-Object Threading.Mutex($false,'Local\SA_CityYardSupportDataEngine')
    $yardLocked=$yardMutex.WaitOne(0)
    if (-not $yardLocked) {throw 'Another fixture owns the engine'}
    if (@(Get-Process | Where-Object {$_.ProcessName -match '(?i)godot'}).Count) {throw 'Another engine exists'}
    $Engine=(Resolve-Path -LiteralPath $Engine).Path
    $yardStatus.engine_sha256=(Get-FileHash -LiteralPath $Engine -Algorithm SHA256).Hash
    . (Join-Path $yardRun 'launcher-sources/city_resource_guard.ps1')
    $yardMinimum=if ($Suite -eq 'native') {704} else {512}
    $yardCap=if ($Suite -eq 'native') {256} else {64}
    $yardTimeout=if ($Suite -eq 'native') {120} else {30}
    $yardStatus.profile=[ordered]@{startup_available_mb=$yardMinimum;startup_commit_mb=1536;maximum_private_mb=$yardCap;timeout_seconds=$yardTimeout;running_available_mb=384;running_commit_mb=768}
    Assert-CityCaptureMemory -MinimumAvailableMB $yardMinimum -MinimumCommitMB 1536
    $env:APPDATA=Join-Path $yardRun ($Suite+'-appdata')
    $env:LOCALAPPDATA=Join-Path $yardRun ($Suite+'-localappdata')
    [IO.Directory]::CreateDirectory($env:APPDATA) | Out-Null
    [IO.Directory]::CreateDirectory($env:LOCALAPPDATA) | Out-Null
    $yardArgs=@('--flush-output','--path',('"'+$yardProject+'"'))
    if ($Suite -ne 'native') {$yardArgs=@('--headless')+$yardArgs}
    switch ($Suite) {
        renderer {$yardArgs+='res://tools/tests/YardSupportRendererTest.tscn';$yardSummary='YardSupportRendererTest'}
        subset {$yardArgs+='res://tools/tests/YardSupportGroundDataSubsetTest.tscn';$yardSummary='WorldGroundSplatDataSubset'}
        support {$yardArgs+=@('--script','res://tools/tests/CityYardSupportTest.gd');$yardSummary='CityYardSupportTest'}
        map {$yardArgs+=@('--script','res://tools/tests/CityYardSupportMapTest.gd');$yardSummary='CityYardSupportMapTest'}
        native {$yardArgs+=@('--resolution','512x512','res://tools/tests/YardSupportNativeTest.tscn');$yardSummary='YardSupportNativeTest'}
        native-parse {$yardArgs+=@('--script','res://tools/tests/YardSupportNativeParseTest.gd');$yardSummary='YardSupportNativeParseTest'}
    }
    $yardStatus.arguments=$yardArgs
    $yardProc=Start-Process -FilePath $Engine -ArgumentList $yardArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $yardRun ($Suite+'-stdout.log')) -RedirectStandardError (Join-Path $yardRun ($Suite+'-stderr.log'))
    $yardRetainedHandle=$yardProc.Handle
    $yardStatus.launched=$true
    $yardStatus.pid=$yardProc.Id
    $yardMetrics=Wait-CityCaptureProcess -Process $yardProc -TimeoutSeconds $yardTimeout -MaximumPrivateMB $yardCap
    foreach ($yardKey in $yardMetrics.Keys) {$yardStatus[$yardKey]=$yardMetrics[$yardKey]}
    $yardStatus.exit_code=$yardProc.ExitCode
    $yardStatus.cpu_seconds=[math]::Round($yardProc.TotalProcessorTime.TotalSeconds,3)
    $yardGenerated=Join-Path $yardRun 'generated-yard-support.gdshader'
    if (Test-Path -LiteralPath $yardGenerated) {$yardStatus.generated_shader_sha256=(Get-FileHash -LiteralPath $yardGenerated -Algorithm SHA256).Hash}
    $yardStdout=[string](Get-Content -Raw -LiteralPath (Join-Path $yardRun ($Suite+'-stdout.log')))
    $yardStderr=[string](Get-Content -Raw -LiteralPath (Join-Path $yardRun ($Suite+'-stderr.log')))
    $yardStatus.diagnostics=@([regex]::Matches(($yardStdout+"`n"+$yardStderr),'(?im)^.*(?:SCRIPT ERROR|Parse Error|SHADER ERROR|ERROR:|WARNING:).*$') | ForEach-Object {$_.Value})
    $yardMatch=[regex]::Match($yardStdout,([regex]::Escape($yardSummary)+': (\d+) passed, (\d+) failed'))
    if ($yardMatch.Success) {$yardStatus.passed=[int]$yardMatch.Groups[1].Value;$yardStatus.failed=[int]$yardMatch.Groups[2].Value}
    $yardStatus.success=($yardStatus.exit_code -eq 0 -and -not $yardStatus.stop_reason -and $yardStatus.diagnostics.Count -eq 0 -and $yardMatch.Success -and $yardStatus.failed -eq 0 -and $yardStatus.passed -gt 0)
    if ($yardStatus.success) {$yardExit=0} else {$yardStatus.failure='native exit, guard, diagnostic or positive summary gate failed';if ($yardStatus.exit_code -ne 0 -and $null -ne $yardStatus.exit_code) {$yardExit=$yardStatus.exit_code}}
} catch {$yardStatus.failure=$_.Exception.Message}
finally {
    if ($yardProc) {if (-not $yardProc.HasExited) {$yardProc.Kill();$yardProc.WaitForExit()};$yardProc.Dispose()}
    $env:APPDATA=$yardOldApp
    $env:LOCALAPPDATA=$yardOldLocal
    try {$yardStatus | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $yardResult -Encoding utf8}
    finally {if ($yardLocked) {$yardMutex.ReleaseMutex()};if ($yardMutex) {$yardMutex.Dispose()};$yardReservation.Dispose()}
}
$yardStatus | ConvertTo-Json -Depth 8
exit $yardExit
