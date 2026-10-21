param([Parameter(Mandatory=$true)][string]$ProjectPath,[Parameter(Mandatory=$true)][string]$RunDir,[ValidateSet('import','home')][string]$Mode='import')
$ErrorActionPreference='Stop'
. 'C:/Users/NaurisKrišjānis/Desktop/code_project/SA_proj/.worktrees/enemy-world/tools/capture/city_resource_guard.ps1'
$engine='C:/Users/NaurisKrišjānis/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64.exe'
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
$result=[ordered]@{mode=$Mode;project=$ProjectPath;engine=$engine;started=$false;stop_reason='';limits=@{max_private_mb=900;minimum_start_ram_mb=1536;minimum_start_commit_mb=3072;minimum_running_ram_mb=768;minimum_running_commit_mb=1536;timeout_seconds=150};peak_private_mb=0;minimum_available_mb=0;minimum_commit_mb=0}
$owned=$null
$previousAppData=$env:APPDATA
try {
 if (@(Get-Process -Name '*Godot*' -ErrorAction SilentlyContinue).Count -gt 0) {throw 'Existing Godot process: human-playtest exclusion'}
 $mem=[CityCaptureMemory]::Read();$result.available_start_mb=[math]::Round($mem.AvailablePhysical/1MB);$result.commit_start_mb=[math]::Round($mem.AvailablePageFile/1MB)
 Assert-CityCaptureMemory -MinimumAvailableMB 1536 -MinimumCommitMB 3072
 $result.head=((& git -C $ProjectPath rev-parse HEAD) -join '').Trim()
 $result.git_status_before=@(& git -C $ProjectPath status --porcelain --untracked-files=normal)
 $arguments=@('--path',('"'+$ProjectPath+'"'),'--rendering-method','gl_compatibility','--audio-driver','Dummy','--log-file',('"'+(Join-Path $RunDir 'engine.log')+'"'))
 if ($Mode -eq 'import') {$arguments+=@('--headless','--editor','--import','--quit')}
 else {$arguments+=@('--resolution','960x540','res://tools/dev/CityDomesticInteriorPreview.tscn','--','--review=small','--world-seed=16102026','--target-chunk=0,3','--target-building-id=944996572','--walkthrough',('--out='+($RunDir -replace '\\','/')))}
 $result.arguments=$arguments
 $env:APPDATA=Join-Path $RunDir 'isolated-appdata'
 New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
 $owned=Start-Process -FilePath $engine -ArgumentList $arguments -WorkingDirectory $ProjectPath -WindowStyle Hidden -RedirectStandardOutput (Join-Path $RunDir 'stdout.log') -RedirectStandardError (Join-Path $RunDir 'stderr.log') -PassThru
 $result.started=$true;$result.pid=$owned.Id
 try {$owned.PriorityClass=[Diagnostics.ProcessPriorityClass]::BelowNormal} catch {}
 $timer=[Diagnostics.Stopwatch]::StartNew();$low=$mem.AvailablePhysical;$lowCommit=$mem.AvailablePageFile;$peak=0L
 while (-not $owned.WaitForExit(250)) {
  $owned.Refresh();if ($owned.HasExited){break};$mem=[CityCaptureMemory]::Read()
  $peak=[math]::Max($peak,$owned.PrivateMemorySize64);$low=[math]::Min($low,$mem.AvailablePhysical);$lowCommit=[math]::Min($lowCommit,$mem.AvailablePageFile)
  if ($owned.PrivateMemorySize64 -gt 900MB){$result.stop_reason='engine_private_memory_limit'}
  elseif ($mem.AvailablePhysical -lt 768MB){$result.stop_reason='system_ram_headroom'}
  elseif ($mem.AvailablePageFile -lt 1536MB){$result.stop_reason='system_commit_headroom'}
  elseif ($timer.Elapsed.TotalSeconds -gt 150){$result.stop_reason='timeout'}
  if ($result.stop_reason){$owned.Kill();$owned.WaitForExit();break}
 }
 $owned.Refresh();$result.exit_code=$owned.ExitCode;$result.elapsed_seconds=[math]::Round($timer.Elapsed.TotalSeconds,2)
 $result.peak_private_mb=[math]::Round($peak/1MB);$result.minimum_available_mb=[math]::Round($low/1MB);$result.minimum_commit_mb=[math]::Round($lowCommit/1MB)
 $result.git_status_after=@(& git -C $ProjectPath status --porcelain --untracked-files=normal)
} catch {$result.stop_reason=$_.Exception.Message}
finally {
 $env:APPDATA=$previousAppData
 if ($owned -and -not $owned.HasExited){$owned.Kill();$owned.WaitForExit()}
 $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $RunDir 'run-result.json') -Encoding utf8
 $result | ConvertTo-Json -Depth 6
}
if ($result.stop_reason -or -not $result.started -or $result.exit_code -ne 0){exit 1}
