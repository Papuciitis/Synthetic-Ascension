[CmdletBinding()]
param([string]$EvidenceName='first')
$ErrorActionPreference='Stop'
$candidateRoot=Join-Path $PSScriptRoot 'real-candidate-verify-fix1'
$candidateResult=Join-Path $candidateRoot ($EvidenceName+'-run-result.json')
if ($EvidenceName -notmatch '^[a-z0-9-]+$') {throw 'Invalid evidence name'}
if (Test-Path -LiteralPath $candidateResult) {throw 'Refusing to overwrite evidence'}
$candidateReservation=[IO.File]::Open(($candidateResult+'.reserve'),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
$candidateStatus=[ordered]@{success=$false;launched=$false;failure='';exit_code=$null;stop_reason='';started_utc=[DateTime]::UtcNow.ToString('o');profile=[ordered]@{startup_available_mb=512;startup_commit_mb=1536;maximum_private_mb=64;timeout_seconds=30;running_available_mb=384;running_commit_mb=768}}
$candidateProcess=$null
$candidateMutex=$null
$candidateLocked=$false
$candidateOldApp=$env:APPDATA
$candidateOldLocal=$env:LOCALAPPDATA
$candidateExit=1
try {
    $candidateRunnerHash=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $candidateRunnerPin=(Get-Content -Raw -LiteralPath (Join-Path $candidateRoot 'runner-pin.json') | ConvertFrom-Json).sha256
    if ($candidateRunnerHash -ne $candidateRunnerPin) {throw 'Runner pin mismatch'}
    $candidateStatus.runner_sha256=$candidateRunnerHash
    foreach ($candidatePin in (Get-Content -Raw -LiteralPath (Join-Path $candidateRoot 'source-pins.json') | ConvertFrom-Json)) {
        if ((Get-FileHash -LiteralPath (Join-Path $candidateRoot $candidatePin.packet) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $candidatePin.sha256) {throw ('Source pin mismatch: '+$candidatePin.packet)}
    }
    $candidateProject=Join-Path $candidateRoot 'fixture'
    if (Test-Path -LiteralPath (Join-Path $candidateProject 'derived-results.json')) {throw 'Previous engine results exist; no replays allowed'}
    if ((Get-Content -Raw -LiteralPath (Join-Path $candidateProject 'project.godot')) -match '\[autoload\]|run/main_scene') {throw 'No autoload/main-scene allowed'}
    if (Test-Path -LiteralPath (Join-Path $candidateProject '.godot')) {throw 'Fresh project unexpectedly has cache'}
    $candidateEngine='C:/Users/NaurisKrišjānis/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64.exe'
    $candidateEngineHash=(Get-FileHash -LiteralPath $candidateEngine -Algorithm SHA256).Hash.ToLowerInvariant()
    $candidateEnginePin=(Get-Content -Raw -LiteralPath (Join-Path $candidateRoot 'engine-pin.json') | ConvertFrom-Json).sha256
    if ($candidateEngineHash -ne $candidateEnginePin) {throw 'Engine pin mismatch'}
    $candidateStatus.engine_sha256=$candidateEngineHash
    # Load and compile the pinned guard BEFORE the final available-memory check.
    . (Join-Path $candidateRoot 'guard.ps1')
    $candidateStatus.guard_preloaded=$true
    $candidateStatus.guard_sha256=(Get-FileHash -LiteralPath (Join-Path $candidateRoot 'guard.ps1') -Algorithm SHA256).Hash.ToLowerInvariant()
    $env:APPDATA=Join-Path $candidateRoot ($EvidenceName+'-appdata')
    $env:LOCALAPPDATA=Join-Path $candidateRoot ($EvidenceName+'-localappdata')
    [IO.Directory]::CreateDirectory($env:APPDATA)|Out-Null
    [IO.Directory]::CreateDirectory($env:LOCALAPPDATA)|Out-Null
    $candidateArguments=@('--headless','--flush-output','--path',('"'+$candidateProject+'"'),'--script','res://verify.gd')
    $candidateStatus.arguments=$candidateArguments
    $candidateMutex=New-Object Threading.Mutex($false,'Local\SA_CityYardSupportDataEngine')
    $candidateLocked=$candidateMutex.WaitOne(0)
    if (-not $candidateLocked) {throw 'Another fixture owns engine'}
    $candidateOtherEngines=@(Get-Process | Where-Object {$_.ProcessName -match '(?i)godot'})
    if ($candidateOtherEngines.Count -gt 0) {throw 'Another Godot/editor exists'}
    $candidateMemory=[CityCaptureMemory]::Read()
    $candidateStatus.startup_available_mb=[math]::Round($candidateMemory.AvailablePhysical/1MB,2)
    $candidateStatus.startup_commit_mb=[math]::Round($candidateMemory.AvailablePageFile/1MB,2)
    Assert-CityCaptureMemory -MinimumAvailableMB 512 -MinimumCommitMB 1536
    $candidateProcess=Start-Process -FilePath $candidateEngine -ArgumentList $candidateArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $candidateRoot ($EvidenceName+'-stdout.log')) -RedirectStandardError (Join-Path $candidateRoot ($EvidenceName+'-stderr.log'))
    $candidateRetainedHandle=$candidateProcess.Handle
    $candidateStatus.launched=$true
    $candidateStatus.pid=$candidateProcess.Id
    $candidateMetrics=Wait-CityCaptureProcess -Process $candidateProcess -TimeoutSeconds 30 -MaximumPrivateMB 64
    foreach ($candidateKey in $candidateMetrics.Keys) {$candidateStatus[$candidateKey]=$candidateMetrics[$candidateKey]}
    $candidateStatus.exit_code=$candidateProcess.ExitCode
    $candidateStatus.cpu_seconds=[math]::Round($candidateProcess.TotalProcessorTime.TotalSeconds,3)
    $candidateStdout=[string](Get-Content -Raw -LiteralPath (Join-Path $candidateRoot ($EvidenceName+'-stdout.log')))
    $candidateStderr=[string](Get-Content -Raw -LiteralPath (Join-Path $candidateRoot ($EvidenceName+'-stderr.log')))
    $candidateStatus.diagnostics=@([regex]::Matches(($candidateStdout+"`n"+$candidateStderr),'(?im)^.*(?:SCRIPT ERROR|Parse Error|SHADER ERROR|ERROR:|WARNING:).*$')|ForEach-Object {$_.Value})
    $candidateSummary=[regex]::Match($candidateStdout,'RealCandidateVerify: (\d+) passed, (\d+) failed')
    if ($candidateSummary.Success) {$candidateStatus.passed=[int]$candidateSummary.Groups[1].Value;$candidateStatus.failed=[int]$candidateSummary.Groups[2].Value}
    $candidateDerivedPath=Join-Path $candidateProject 'derived-results.json'
    $candidateDerivedValid=$false
    if (Test-Path -LiteralPath $candidateDerivedPath) {
        $candidateDerived=Get-Content -Raw -LiteralPath $candidateDerivedPath|ConvertFrom-Json
        $candidateDerivedValid=($candidateDerived.passed -gt 0 -and $candidateDerived.failed -eq 0 -and @($candidateDerived.derived_verified).Count -eq 3)
        $candidateStatus.derived_results_sha256=(Get-FileHash -LiteralPath $candidateDerivedPath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $candidateStatus.success=($null -ne $candidateStatus.exit_code -and $candidateStatus.exit_code -eq 0 -and -not $candidateStatus.stop_reason -and $candidateStatus.diagnostics.Count -eq 0 -and $candidateSummary.Success -and $candidateStatus.passed -gt 0 -and $candidateStatus.failed -eq 0 -and $candidateDerivedValid)
    if ($candidateStatus.success) {$candidateExit=0} else {$candidateStatus.failure='Native exit, stop, diagnostics, positive-count or result gate failed'}
} catch {$candidateStatus.failure=$_.Exception.Message}
finally {
    if ($candidateProcess) {if (-not $candidateProcess.HasExited) {$candidateProcess.Kill();$candidateProcess.WaitForExit()};$candidateProcess.Dispose()}
    $env:APPDATA=$candidateOldApp
    $env:LOCALAPPDATA=$candidateOldLocal
    $candidateStatus.ended_utc=[DateTime]::UtcNow.ToString('o')
    try {$candidateStatus|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $candidateResult -Encoding utf8}
    finally {if ($candidateLocked) {$candidateMutex.ReleaseMutex()};if ($candidateMutex) {$candidateMutex.Dispose()};$candidateReservation.Dispose()}
}
$candidateStatus|ConvertTo-Json -Depth 8
exit $candidateExit
