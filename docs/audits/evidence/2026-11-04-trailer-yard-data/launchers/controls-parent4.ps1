# Reproducible BLACK-BOX LAUNCHER CONTROLS, not CityYardSupportMap correctness tests.
# Each scratch repository supplies a deliberately synthetic suite entry point.
# Only the copied permanent runner launches Godot, under its unchanged tiny guard.
param(
    [Parameter(Mandatory=$true)][string]$EvidenceDirectory,
    [string]$Engine=(Join-Path ([Environment]::GetFolderPath('Desktop')) 'Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64.exe')
)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$evidence=if ([IO.Path]::IsPathRooted($EvidenceDirectory)) {[IO.Path]::GetFullPath($EvidenceDirectory)} else {[IO.Path]::GetFullPath((Join-Path $root $EvidenceDirectory))}
if (Test-Path -LiteralPath $evidence) {throw 'Refusing existing control evidence directory'}
[IO.Directory]::CreateDirectory($evidence) | Out-Null
Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $evidence 'controls.ps1')
$results=@()
function Invoke-ControlRunner {
    param([string]$Runner,[string]$SelectedSuite,[string]$Destination,[string]$LogPrefix,[string]$Executor=$Engine)
    # PS5 promotes expected child stderr to NativeCommandError under Stop.
    $previousAction=$ErrorActionPreference
    try {
        $ErrorActionPreference='Continue'
        & powershell -NoProfile -ExecutionPolicy Bypass -File $Runner -Engine $Executor -Suite $SelectedSuite -RunDirectory $Destination > ($LogPrefix+'.log') 2> ($LogPrefix+'-stderr.log')
        return $LASTEXITCODE
    } finally {$ErrorActionPreference=$previousAction}
}
$controls=@{
    empty=@'
# CONTROL ONLY: entry point is not executed by the synthetic silent console EXE.
extends SceneTree
'@
    native=@'
extends SceneTree
func _initialize() -> void:
    print("CONTROL ONLY: native nonzero exit despite synthetic passing summary")
    print("CityYardSupportTest: 1 passed, 0 failed")
    quit(7)
'@
    diagnostic=@'
extends SceneTree
func _initialize() -> void:
    print("CONTROL ONLY: native zero exit with intentional diagnostic")
    push_warning("intentional launcher diagnostic probe")
    print("CityYardSupportMapTest: 1 passed, 0 failed")
    quit(0)
'@
    timeout=@'
extends SceneTree
func _initialize() -> void:
    Engine.max_fps = 20
    print("CONTROL ONLY: never quits; real resource guard must stop the engine")
    print("CityYardSupportMapTest: 1 passed, 0 failed")
'@
}
foreach ($mode in @('empty','native','diagnostic','timeout')) {
    $repo=Join-Path $evidence $mode
    foreach ($relative in @('tools/tests/run_yard_support_data_tests.ps1','tools/capture/city_resource_guard.ps1')) {
        $destination=Join-Path $repo $relative
        [IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
        Copy-Item -LiteralPath (Join-Path $root $relative) -Destination $destination
        if ((Get-FileHash -LiteralPath (Join-Path $root $relative)).Hash -ne (Get-FileHash -LiteralPath $destination).Hash) {throw 'Control runner/guard copy mismatch'}
    }
    $test=if ($mode -eq 'native') {'CityYardSupportTest.gd'} else {'CityYardSupportMapTest.gd'}
    $controls[$mode] | Set-Content -LiteralPath (Join-Path $repo ('tools/tests/'+$test)) -Encoding utf8
    $executor=$Engine
    if ($mode -eq 'empty') {
        # External executor control ONLY, not Godot or a map correctness test.
        # Empty redirected logs must yield a saved failure receipt, never a null
        # regex exception. Source is preserved; the runner pins the EXE's hash.
        $compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
        $source=Join-Path $repo 'SilentLauncherControl.cs'
        $executor=Join-Path $repo 'SilentLauncherControl.exe'
        @'
internal static class SilentLauncherControl {
    static int Main(string[] args) {
        System.Threading.Thread.Sleep(100);
        return 0;
    }
}
'@ | Set-Content -LiteralPath $source -Encoding utf8
        & $compiler /nologo /target:exe ('/out:'+$executor) $source > (Join-Path $repo 'compiler.log') 2> (Join-Path $repo 'compiler-stderr.log')
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $executor)) {throw 'Silent external control compilation failed'}
        [ordered]@{classification='synthetic external executor, not Godot';source_sha256=(Get-FileHash -LiteralPath $source).Hash;executor_sha256=(Get-FileHash -LiteralPath $executor).Hash} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $repo 'external-control-pins.json') -Encoding utf8
    }
    if ($mode -eq 'native') {
        # This file must NOT launch after the first suite's nonzero native exit.
        @'
extends SceneTree
func _initialize() -> void:
    print("CONTROL ONLY: this second suite must remain unlaunched")
    print("CityYardSupportMapTest: 1 passed, 0 failed")
    quit(0)
'@ | Set-Content -LiteralPath (Join-Path $repo 'tools/tests/CityYardSupportMapTest.gd') -Encoding utf8
    }
    $suite=if ($mode -eq 'native') {'both'} else {'map'}
    $runnerExit=Invoke-ControlRunner -Runner (Join-Path $repo 'tools/tests/run_yard_support_data_tests.ps1') -SelectedSuite $suite -Destination (Join-Path $repo 'run') -LogPrefix (Join-Path $repo 'invocation') -Executor $executor
    $result=Get-Content -LiteralPath (Join-Path $repo 'run/result.json') -Raw | ConvertFrom-Json
    $first=$result.suites[0]
    $valid=($runnerExit -ne 0 -and -not $result.success -and $first.launched -and -not $first.success -and (Test-Path -LiteralPath (Join-Path $repo ('run/'+$first.name+'/result.json'))))
    switch ($mode) {
        empty {$valid=$valid -and $first.exit_code -eq 0 -and $first.summary -eq '' -and $first.diagnostics.Count -eq 0 -and $result.failure -eq 'Data suite failed: map'}
        native {$valid=$valid -and $first.exit_code -eq 7 -and -not $result.suites[1].launched -and $result.suites[1].failure -eq 'not_launched'}
        diagnostic {$valid=$valid -and $first.exit_code -eq 0 -and $first.diagnostics.Count -gt 0}
        timeout {$valid=$valid -and $first.stop_reason -eq 'timeout'}
    }
    $results += [ordered]@{control=$mode;verified=$valid;runner_exit=$runnerExit;native_exit=$first.exit_code;stop_reason=$first.stop_reason;diagnostic_count=$first.diagnostics.Count}
    $results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $evidence 'control-results.json') -Encoding utf8
    if (-not $valid) {throw "Control not verified: $mode (including a startup gate or different resource stop)"}
}
$native=Join-Path $evidence 'native'
$before=(Get-FileHash -LiteralPath (Join-Path $native 'run/result.json')).Hash
$refusal=Invoke-ControlRunner -Runner (Join-Path $native 'tools/tests/run_yard_support_data_tests.ps1') -SelectedSuite both -Destination (Join-Path $native 'run') -LogPrefix (Join-Path $native 'no-overwrite')
$after=(Get-FileHash -LiteralPath (Join-Path $native 'run/result.json')).Hash
$noOverwrite=($refusal -ne 0 -and $before -eq $after)
$results += [ordered]@{control='no-overwrite';verified=$noOverwrite;runner_exit=$refusal;before_sha256=$before;after_sha256=$after}
$results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $evidence 'control-results.json') -Encoding utf8
if (-not $noOverwrite) {throw 'No-overwrite control failed'}
Write-Output 'All five launcher controls verified. These controls do not test game appearance or map correctness.'
