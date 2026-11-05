# Tiny pure-data fixtures ONLY. Never starts the repository project or imports assets.
[CmdletBinding()]
param(
    [ValidateSet('support','map','both')][string]$Suite='both',
    [string]$Engine=(Join-Path ([Environment]::GetFolderPath('Desktop')) 'Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64.exe'),
    [string]$RunDirectory=''
)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $RunDirectory) {
    $RunDirectory=Join-Path $root ('output/yard-support-data/'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff')+'-'+[Guid]::NewGuid().ToString('N'))
}
$run=if ([IO.Path]::IsPathRooted($RunDirectory)) {[IO.Path]::GetFullPath($RunDirectory)} else {[IO.Path]::GetFullPath((Join-Path $root $RunDirectory))}
if (Test-Path -LiteralPath $run) {throw "Refusing to overwrite existing evidence: $run"}
# CreateNew supplies an atomic reservation even when two invocations race.
$parent=Split-Path -Parent $run
[IO.Directory]::CreateDirectory($parent) | Out-Null
$reservation=$run+'.reserve'
$reservationHandle=[IO.File]::Open($reservation,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
$mutex=$null
$locked=$false
$ownsRun=$false
$oldAppData=$env:APPDATA
$oldLocalAppData=$env:LOCALAPPDATA
$status=[ordered]@{suite=$Suite;success=$false;failure='';engine=$Engine;engine_sha256='';profile=[ordered]@{startup_available_mb=512;startup_commit_mb=1536;maximum_private_mb=64;timeout_seconds=30;running_available_mb=384;running_commit_mb=768};suites=@()}
$selected=if ($Suite -eq 'both') {@('support','map')} else {@($Suite)}
foreach ($name in $selected) {$status.suites += [ordered]@{name=$name;launched=$false;success=$false;exit_code=$null;stop_reason='';diagnostics=@();failure='not_launched'}}
$exitCode=1
try {
    if (Test-Path -LiteralPath $run) {throw "Refusing to overwrite existing evidence: $run"}
    [IO.Directory]::CreateDirectory($run) | Out-Null
    $ownsRun=$true
    $receipt=Join-Path $run 'launcher-sources'
    [IO.Directory]::CreateDirectory($receipt) | Out-Null
    $launcherPins=@()
    foreach ($source in @($PSCommandPath,(Join-Path $root 'tools/capture/city_resource_guard.ps1'))) {
        $destination=Join-Path $receipt ([IO.Path]::GetFileName($source))
        Copy-Item -LiteralPath $source -Destination $destination
        $sourceHash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        $copyHash=(Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
        if ($sourceHash -ne $copyHash) {throw "Launcher receipt hash mismatch: $source"}
        $launcherPins += [ordered]@{source=$source;source_sha256=$sourceHash;copy_sha256=$copyHash}
    }
    $launcherPins | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $receipt 'pins.json') -Encoding utf8
    $Engine=(Resolve-Path -LiteralPath $Engine).Path
    $status.engine=$Engine
    $status.engine_sha256=(Get-FileHash -LiteralPath $Engine -Algorithm SHA256).Hash
    $mutex=New-Object Threading.Mutex($false,'Local\SA_CityYardSupportDataEngine')
    $locked=$mutex.WaitOne(0)
    if (-not $locked) {throw 'Another yard data runner owns the engine.'}
    . (Join-Path $receipt 'city_resource_guard.ps1')
    $allowlist=@{
        support=@('core/systems/world/ground/CityYardSupport.gd','tools/tests/CityYardSupportTest.gd')
        map=@('core/systems/world/ground/CityYardSupportMap.gd','tools/tests/CityYardSupportMapTest.gd')
    }
    foreach ($entry in $status.suites) {
        $name=$entry.name
        $suiteRun=Join-Path $run $name
        $fixture=Join-Path $suiteRun 'fixture'
        [IO.Directory]::CreateDirectory($fixture) | Out-Null
        # This literal minimal project has no autoload, assets, scenes or imports.
        @'
[application]
config/name="City yard pure data fixture"
[rendering]
renderer/rendering_method="gl_compatibility"
'@ | Set-Content -LiteralPath (Join-Path $fixture 'project.godot') -Encoding utf8
        $pins=@()
        foreach ($relative in $allowlist[$name]) {
            $source=Join-Path $root $relative
            $destination=Join-Path $fixture $relative
            if (Test-Path -LiteralPath $source) {
                [IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
                Copy-Item -LiteralPath $source -Destination $destination
                $sourceHash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
                $copyHash=(Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
                if ($sourceHash -ne $copyHash) {throw "Copy hash mismatch: $relative"}
                $pins += [ordered]@{path=$relative;source_sha256=$sourceHash;copy_sha256=$copyHash}
            } else {$pins += [ordered]@{path=$relative;absent=$true}}
        }
        $pins | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $suiteRun 'pins.json') -Encoding utf8
        $test=$allowlist[$name][1]
        if (-not (Test-Path -LiteralPath (Join-Path $fixture $test))) {throw "Test entry point missing: $test"}
        $existing=@(Get-Process | Where-Object {$_.ProcessName -match '(?i)godot'})
        if ($existing.Count) {throw ('Refusing another Godot process: '+($existing.Id -join ','))}
        Assert-CityCaptureMemory -MinimumAvailableMB 512 -MinimumCommitMB 1536
        $env:APPDATA=Join-Path $suiteRun 'appdata'
        $env:LOCALAPPDATA=Join-Path $suiteRun 'localappdata'
        [IO.Directory]::CreateDirectory($env:APPDATA) | Out-Null
        [IO.Directory]::CreateDirectory($env:LOCALAPPDATA) | Out-Null
        $arguments=@('--headless','--flush-output','--path',('"'+$fixture+'"'),'--script',('res://'+$test))
        $entry.arguments=$arguments
        $process=Start-Process -FilePath $Engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $suiteRun 'stdout.log') -RedirectStandardError (Join-Path $suiteRun 'stderr.log')
        $entry.launched=$true
        $entry.pid=$process.Id
        try {
            # PS5 can lose a redirected short-lived process's exit code unless
            # its native handle is retained before waiting. Keep cleanup in scope.
            $null=$process.Handle
            $metrics=Wait-CityCaptureProcess -Process $process -TimeoutSeconds 30 -MaximumPrivateMB 64
            $process.WaitForExit()
            $process.Refresh()
            $entry.exit_code=$process.ExitCode
            foreach ($key in $metrics.Keys) {$entry[$key]=$metrics[$key]}
        } finally {
            # Only this launcher's owned process, including an exceptional monitor exit.
            if (-not $process.HasExited) {$process.Kill(); $process.WaitForExit()}
            $process.Dispose()
        }
        $stdout=Get-Content -LiteralPath (Join-Path $suiteRun 'stdout.log') -Raw
        $stderr=Get-Content -LiteralPath (Join-Path $suiteRun 'stderr.log') -Raw
        $diagnostics=@()
        if ($stderr -and $stderr.Trim()) {$diagnostics += $stderr.Trim()}
        $diagnostics += @($stdout -split '\r?\n' | Where-Object {$_ -match '(?i)(SCRIPT ERROR|(^|\s)(ERROR|WARNING):)'})
        $entry.diagnostics=$diagnostics
        $suiteClass=if ($name -eq 'support') {'CityYardSupportTest'} else {'CityYardSupportMapTest'}
        $summary=[regex]::Match($stdout,([regex]::Escape($suiteClass)+': (\d+) passed, (\d+) failed'))
        $entry.summary=if ($summary.Success) {$summary.Value} else {''}
        $entry.success=($null -ne $entry.exit_code -and $entry.exit_code -eq 0 -and -not $entry.stop_reason -and $diagnostics.Count -eq 0 -and $summary.Success -and [int]$summary.Groups[1].Value -gt 0 -and [int]$summary.Groups[2].Value -eq 0)
        $entry.failure=if ($entry.success) {''} else {'native_exit_guard_diagnostic_or_summary_failure'}
        $entry | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $suiteRun 'result.json') -Encoding utf8
        Write-Output $stdout
        if ($stderr) {Write-Output $stderr}
        if (-not $entry.success) {throw "Data suite failed: $name"}
    }
    $status.success=(@($status.suites | Where-Object {-not $_.launched -or -not $_.success}).Count -eq 0)
    if ($status.success) {$exitCode=0}
} catch {
    $status.failure=$_.ToString()
    Write-Output $status.failure
} finally {
    $env:APPDATA=$oldAppData
    $env:LOCALAPPDATA=$oldLocalAppData
    if ($ownsRun) {$status | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $run 'result.json') -Encoding utf8}
    if ($locked) {$mutex.ReleaseMutex()}
    if ($null -ne $mutex) {$mutex.Dispose()}
    $reservationHandle.Dispose()
    Remove-Item -LiteralPath $reservation
}
Write-Output "Evidence: $run"
exit $exitCode
