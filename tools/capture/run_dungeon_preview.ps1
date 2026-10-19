param(
    [ValidateSet('facilities','runtime','district')][string]$Review='facilities',
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [string]$Engine=(Join-Path $env:USERPROFILE 'Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64.exe')
)
$ErrorActionPreference = 'Stop'
$dungeonWorkspace = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$dungeonOtherRuns = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^Godot' -and $_.CommandLine -notmatch '(--editor| -e( |$))' })
if ($dungeonOtherRuns.Count) { throw 'Another Godot run is active; leaving it untouched.' }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if ((Test-Path -LiteralPath $OutputDirectory) -and @(Get-ChildItem -LiteralPath $OutputDirectory -Force).Count) { throw 'Choose an empty output directory to preserve existing evidence.' }
$dungeonRuntime = Join-Path $dungeonWorkspace ('.superpowers/sdd/2026-10-19-dungeon-preview/'+$Review+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $dungeonRuntime -Force | Out-Null
$dungeonSources = @('core/systems/world/proc/DungeonLayout.gd','core/systems/world/proc/SiteOverlayImpl.gd','core/systems/world/proc/chunkgen/ChunkGenDistrict.gd','scenes/world/buildings/DungeonBuilding.gd','scenes/world/buildings/DungeonRoof.gd','core/actors/player/PlayerRoofOcclusion.gd','tools/dev/DungeonArchitecturePreview.gd','tools/capture/run_dungeon_preview.ps1')
$dungeonBefore = @($dungeonSources | ForEach-Object { [ordered]@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $dungeonWorkspace $_) -Algorithm SHA256).Hash} })
$dungeonArgs = @('--path',('"'+$dungeonWorkspace+'"'),'--rendering-driver','opengl3','--audio-driver','Dummy','--log-file',('"'+(Join-Path $dungeonRuntime 'engine.log')+'"'),'--flush-output','--quit-after','24000','res://tools/dev/DungeonArchitecturePreview.tscn','--',('--review='+$Review),('"--out='+$OutputDirectory.Replace('\','/')+'"'))
if ($Review -eq 'district') { $dungeonArgs += '--donjon-only' }
$dungeonOldApp = $env:APPDATA
$dungeonOldLocal = $env:LOCALAPPDATA
try {
    $env:APPDATA = $dungeonRuntime
    $env:LOCALAPPDATA = $dungeonRuntime
    $dungeonProcess = Start-Process -FilePath $Engine -ArgumentList $dungeonArgs -WorkingDirectory $dungeonWorkspace -WindowStyle Hidden -RedirectStandardOutput (Join-Path $dungeonRuntime 'stdout.log') -RedirectStandardError (Join-Path $dungeonRuntime 'stderr.log') -PassThru
} finally { $env:APPDATA = $dungeonOldApp; $env:LOCALAPPDATA = $dungeonOldLocal }
Write-Output ('DUNGEON_RUN pid='+$dungeonProcess.Id+' runtime='+$dungeonRuntime)
$dungeonTimeout = -not $dungeonProcess.WaitForExit(300000)
if ($dungeonTimeout) { Stop-Process -Id $dungeonProcess.Id -Force; $dungeonProcess.WaitForExit() }
$dungeonLines = @()
foreach ($dungeonLog in @('engine.log','stdout.log','stderr.log')) { if (Test-Path -LiteralPath (Join-Path $dungeonRuntime $dungeonLog)) { $dungeonLines += @(Get-Content -LiteralPath (Join-Path $dungeonRuntime $dungeonLog)) } }
$dungeonAfter = @($dungeonSources | ForEach-Object { [ordered]@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $dungeonWorkspace $_) -Algorithm SHA256).Hash} })
$dungeonChanged = @($dungeonAfter | Where-Object { $dungeonCurrent=$_; -not ($dungeonBefore | Where-Object { $_.path -eq $dungeonCurrent.path -and $_.sha256 -eq $dungeonCurrent.sha256 }) })
$dungeonDiagnostics = @($dungeonLines | Where-Object { $_ -match 'SCRIPT ERROR|ERROR:|WARNING:|Parse Error|leaked|Orphan' } | Select-Object -Unique)
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$dungeonResult = [ordered]@{mode=$Review;scene='res://tools/dev/DungeonArchitecturePreview.tscn';pid=$dungeonProcess.Id;native_exit=$dungeonProcess.ExitCode;timeout=$dungeonTimeout;diagnostics=$dungeonDiagnostics;source_hashes_before=$dungeonBefore;source_hashes_after=$dungeonAfter;source_drift=$dungeonChanged;summary=@($dungeonLines | Where-Object { $_ -match 'DungeonFinalCapture:' } | Select-Object -Unique);runtime=$dungeonRuntime}
$dungeonResult | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'run-results.json') -Encoding utf8
[pscustomobject]$dungeonResult | Select-Object mode,native_exit,timeout,diagnostics,source_drift,summary | ConvertTo-Json -Depth 5
if ($dungeonTimeout -or $dungeonProcess.ExitCode -ne 0 -or $dungeonDiagnostics.Count -or $dungeonChanged.Count) { exit 1 }
