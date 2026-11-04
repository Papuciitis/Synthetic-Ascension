$ErrorActionPreference='Stop'
$parseWorkspace=(Get-Location).Path
$parseRun=Join-Path $parseWorkspace '.superpowers/sdd/2026-11-04-trailer-yard-preview/task2b-project-parse'
if (Test-Path -LiteralPath $parseRun) {throw 'Fresh parse evidence directory required'}
[void][IO.Directory]::CreateDirectory($parseRun)
[IO.File]::WriteAllBytes((Join-Path $parseRun '.gdignore'),[byte[]]@())
$parseEngine='C:/Users/NaurisKrišjānis/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64.exe'
$parseGuard='tools/capture/city_resource_guard.ps1'
$parseArgs=@('--headless','--flush-output','--path',('"'+$parseWorkspace+'"'),'--audio-driver','Dummy','res://tools/tests/ScriptParseAuditTest.tscn')
$parseState=[ordered]@{scope='whole-project ScriptParseAuditTest';launched=$false;success=$false;failure='';exit_code=$null;arguments=$parseArgs;profile=@{startup_available_mb=1536;startup_commit_mb=3072;maximum_private_mb=1200;timeout_seconds=120;running_available_mb=384;running_commit_mb=768};wrapper_sha256=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash;guard_sha256=(Get-FileHash -LiteralPath $parseGuard -Algorithm SHA256).Hash;engine_sha256=(Get-FileHash -LiteralPath $parseEngine -Algorithm SHA256).Hash}
Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $parseRun 'executed-wrapper.ps1')
Copy-Item -LiteralPath $parseGuard -Destination (Join-Path $parseRun 'city_resource_guard.ps1')
$parsePins=@()
foreach($parseSource in @('project.godot','core/systems/world/ChunkManager.gd','core/systems/world/ground/GroundSplatRenderer.gd','core/systems/world/ground/ground_splat.gdshader','core/systems/world/ground/CityYardSupport.gd','core/systems/world/ground/CityYardSupportMap.gd','core/systems/world/ground/YardSupportPreviewShader.gd','tools/tests/ScriptParseAuditTest.gd','tools/tests/ScriptParseAuditTest.tscn')) {$parsePins+=@{path=$parseSource;sha256=(Get-FileHash -LiteralPath $parseSource -Algorithm SHA256).Hash}}
$parsePins | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $parseRun 'selected-source-pins.json') -Encoding utf8
$parseProc=$null
$parseOldApp=$env:APPDATA
$parseOldLocal=$env:LOCALAPPDATA
try {
    if (@(Get-Process | Where-Object {$_.ProcessName -match '(?i)godot'}).Count) {throw 'Another Godot exists; leaving it untouched'}
    . (Join-Path $parseRun 'city_resource_guard.ps1')
    $parseMemory=[CityCaptureMemory]::Read()
    $parseState.startup_available_mb=[math]::Round($parseMemory.AvailablePhysical/1MB)
    $parseState.startup_commit_headroom_mb=[math]::Round($parseMemory.AvailablePageFile/1MB)
    Assert-CityCaptureMemory -MinimumAvailableMB 1536 -MinimumCommitMB 3072
    $env:APPDATA=Join-Path $parseRun 'appdata'
    $env:LOCALAPPDATA=Join-Path $parseRun 'localappdata'
    [void][IO.Directory]::CreateDirectory($env:APPDATA)
    [void][IO.Directory]::CreateDirectory($env:LOCALAPPDATA)
    $parseProc=Start-Process -FilePath $parseEngine -ArgumentList $parseArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $parseRun 'stdout.log') -RedirectStandardError (Join-Path $parseRun 'stderr.log')
    $parseRetainedHandle=$parseProc.Handle
    $parseState.launched=$true
    $parseState.pid=$parseProc.Id
    $parseMetrics=Wait-CityCaptureProcess -Process $parseProc -TimeoutSeconds 120 -MaximumPrivateMB 1200
    foreach($parseKey in $parseMetrics.Keys) {$parseState[$parseKey]=$parseMetrics[$parseKey]}
    $parseState.exit_code=$parseProc.ExitCode
    $parseOutput=[string](Get-Content -Raw -LiteralPath (Join-Path $parseRun 'stdout.log'))
    $parseErrors=[string](Get-Content -Raw -LiteralPath (Join-Path $parseRun 'stderr.log'))
    $parseState.diagnostics=@([regex]::Matches(($parseOutput+"`n"+$parseErrors),'(?im)^.*(?:SCRIPT ERROR|Parse Error|SHADER ERROR|ERROR:|WARNING:).*$') | ForEach-Object {$_.Value})
    $parseSummary=[regex]::Match($parseOutput,'ScriptParseAuditTest: (\d+) passed, (\d+) failed')
    $parseState.success=($parseState.exit_code -eq 0 -and -not $parseState.stop_reason -and $parseState.diagnostics.Count -eq 0 -and $parseSummary.Success -and [int]$parseSummary.Groups[2].Value -eq 0 -and [int]$parseSummary.Groups[1].Value -ge 340)
    if (-not $parseState.success) {$parseState.failure='native exit, guard, diagnostics or coverage/summary gate failed'}
} catch {$parseState.failure=$_.Exception.Message}
finally {
    if ($parseProc) {if (-not $parseProc.HasExited) {$parseProc.Kill();$parseProc.WaitForExit()};$parseProc.Dispose()}
    $env:APPDATA=$parseOldApp
    $env:LOCALAPPDATA=$parseOldLocal
    $parseState | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $parseRun 'result.json') -Encoding utf8
}
$parseState | ConvertTo-Json -Depth 6
if (-not $parseState.success) {exit 1}
