param(
    [ValidateSet('normal','small','reduced','before')][string]$Review='normal',
    [string]$OutputDirectory='',
    [string]$Engine=(Join-Path $env:USERPROFILE 'Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64.exe'),
    [int]$WorldSeed=16102026,
    [int]$Segment=2,
    [switch]$DistrictCommonBase,
    [switch]$HideDistrictDetails,
    [switch]$StillOnly,
    [switch]$EntryOnly,
    [long]$TargetBuildingId=0,
    [string]$TargetChunk='',
    [ValidateRange(1,3600)][int]$OutputTimeoutSeconds=240,
    [switch]$Playable
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'city_process_guard.ps1')
$cityWorkspace = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$cityOtherRuns = @(Get-CimInstance Win32_Process | Where-Object { Test-CityCaptureGameProcess -Name $_.Name -CommandLine $_.CommandLine })
if ($cityOtherRuns.Count -gt 0) { throw 'Another Godot run is active; leaving it untouched.' }
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $cityWorkspace ('docs/art/reference/2026-10-18-city-block/' + $Review) }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if (-not $Playable -and (Test-Path -LiteralPath $OutputDirectory) -and @(Get-ChildItem -LiteralPath $OutputDirectory -Force).Count -gt 0) {
    throw 'Evidence folder already contains a run. Supply a new -OutputDirectory to preserve it.'
}
$cityRuntime = Join-Path $cityWorkspace ('.superpowers/sdd/2026-10-18-city-block/' + $Review + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $cityRuntime -Force | Out-Null
$cityArgs = @('--path', ('"' + $cityWorkspace + '"'), '--rendering-driver','opengl3','--audio-driver','Dummy','--log-file',('"' + (Join-Path $cityRuntime 'engine.log') + '"'),'--flush-output','res://tools/dev/CityBlockPlayablePreview.tscn','--',('--review=' + $Review),('"--out=' + $OutputDirectory.Replace('\','/') + '"'))
if ($Playable) { $cityArgs += @('--visible','--playable') }
$cityArgs += ('--world-seed=' + $WorldSeed)
$cityArgs += ('--segment=' + $Segment)
if ($DistrictCommonBase) { $cityArgs += '--district-common-base' }
if ($HideDistrictDetails) { $cityArgs += '--hide-district-details' }
if ($StillOnly) { $cityArgs += '--still-only' }
if ($EntryOnly) { $cityArgs += '--entry-only' }
if ($TargetBuildingId -gt 0) {
    if ($TargetChunk -notmatch '^-?\d+,-?\d+$') { throw 'Target building requires its recorded x,y chunk.' }
    $cityArgs += ('--target-building-id='+$TargetBuildingId)
    $cityArgs += ('--target-chunk='+$TargetChunk)
}
$cityFiles = @('scenes/world/buildings/CityBlockKit.gd','scenes/world/buildings/RoofOverlay.gd','scenes/world/buildings/city_stone.gdshader','scenes/world/buildings/city_paving.gdshader','core/systems/world/proc/SiteParcelsImpl.gd','core/systems/world/proc/chunkgen/ChunkGenDistrict.gd','core/systems/world/chunks/ChunkBlockRenderer.gd','core/systems/world/chunks/ChunkBlockVisualCatalog.gd','tools/dev/CityBlockPlayablePreview.gd')
$cityHashes = @($cityFiles | ForEach-Object { [ordered]@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $cityWorkspace $_) -Algorithm SHA256).Hash} })
$cityHashes += @('scenes/world/buildings/city_ground.gdshader','assets/world/ground/ground_cobble_01.png','assets/world/ground/ground_grass_01.png','assets/world/ground/ground_dirt_01.png' | ForEach-Object { [ordered]@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $cityWorkspace $_) -Algorithm SHA256).Hash} })
$cityHashes += @('core/systems/world/ChunkManager.gd','core/systems/world/ground/GroundSplatRenderer.gd','core/systems/world/ground/ground_splat.gdshader' | ForEach-Object { [ordered]@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $cityWorkspace $_) -Algorithm SHA256).Hash} })
$cityHashes += @('core/systems/world/WorldDepthStyle.gd','assets/world/dressing/generated/olive_shrub.tres','assets/world/dressing/generated/dressing_set_v2.png' | ForEach-Object { [ordered]@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $cityWorkspace $_) -Algorithm SHA256).Hash} })
$cityHashes += @('scenes/world/buildings/CityBlockRoofForms.gd','scenes/world/buildings/roof.gdshader' | ForEach-Object { [ordered]@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $cityWorkspace $_) -Algorithm SHA256).Hash} })
$cityHashes += @('scenes/world/buildings/CityBlockFrontages.gd' | ForEach-Object { [ordered]@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $cityWorkspace $_) -Algorithm SHA256).Hash} })
$cityHashes += @('scenes/world/buildings/RoofOverlay.tscn','core/actors/player/PlayerVisualController.gd','core/actors/player/PlayerRoofOcclusion.gd','core/actors/player/player_roof_occlusion.gdshader','ui/cursor/CursorManager.gd' | ForEach-Object { [ordered]@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $cityWorkspace $_) -Algorithm SHA256).Hash} })
$cityHashes += @(Get-ChildItem -LiteralPath (Join-Path $cityWorkspace 'assets/world/city_block') -Filter '*.png' | ForEach-Object { [ordered]@{path=('assets/world/city_block/' + $_.Name);sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash} })
$cityFamilyFiles=@('scenes/world/buildings/DistrictVisualProfiles.gd','scenes/world/buildings/CheckpointOfficeForms.gd','core/systems/world/proc/SegmentThemeData.gd','core/systems/world/proc/ChunkGenImpl.gd','assets/world/districts/checkpoint_lanes/guard_arch_open.png','assets/world/districts/checkpoint_lanes/guard_arch_closed.png','assets/world/districts/checkpoint_lanes/anchors.json','assets/world/districts/checkpoint_lanes/provenance.json','assets/world/districts/checkpoint_lanes/guard_quiet_infill_v2.png','assets/world/districts/checkpoint_lanes/infill-v2-provenance.json')
$cityHashes += @($cityFamilyFiles | ForEach-Object { [ordered]@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $cityWorkspace $_) -Algorithm SHA256).Hash} })
$cityOldApp = $env:APPDATA
$cityOldLocal = $env:LOCALAPPDATA
$cityStart = [DateTime]::UtcNow
try {
    $env:APPDATA = $cityRuntime
    $env:LOCALAPPDATA = $cityRuntime
    $cityProcess = Start-Process -FilePath $Engine -ArgumentList $cityArgs -WorkingDirectory $cityWorkspace -WindowStyle Hidden -RedirectStandardOutput (Join-Path $cityRuntime 'stdout.log') -RedirectStandardError (Join-Path $cityRuntime 'stderr.log') -PassThru
} finally { $env:APPDATA = $cityOldApp; $env:LOCALAPPDATA = $cityOldLocal }
Write-Output ('CITY_BLOCK pid=' + $cityProcess.Id + ' runtime=' + $cityRuntime)
if ($Playable) { Write-Output 'Interactive isolated Game is running. Close its window normally when finished.'; return }
$cityTimeout = -not $cityProcess.WaitForExit($OutputTimeoutSeconds*1000)
if ($cityTimeout) { Stop-Process -Id $cityProcess.Id -Force; $cityProcess.WaitForExit() }
$cityLines = @()
foreach ($cityLog in @('engine.log','stdout.log','stderr.log')) {
    if (Test-Path -LiteralPath (Join-Path $cityRuntime $cityLog)) { $cityLines += @(Get-Content -LiteralPath (Join-Path $cityRuntime $cityLog)) }
}
$cityResult = [ordered]@{review=$Review;scene='res://tools/dev/CityBlockPlayablePreview.tscn';engine=$Engine;pid=$cityProcess.Id;runtime=$cityRuntime;started_utc=$cityStart.ToString('o');ended_utc=[DateTime]::UtcNow.ToString('o');native_exit=$cityProcess.ExitCode;timeout=$cityTimeout;output_allowance_seconds=$OutputTimeoutSeconds;source_hashes=$cityHashes;diagnostics=@($cityLines | Where-Object { $_ -match 'SCRIPT ERROR|ERROR:|WARNING:|Parse Error|leaked|Orphan' } | Select-Object -Unique);summary=@($cityLines | Where-Object { $_ -match 'CityBlockPlayablePreview:|CityBlockStillPreview:|CityBlockEntryPreview:' } | Select-Object -Unique)}
if (Test-Path -LiteralPath $OutputDirectory) { $cityResult | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'run-results.json') -Encoding utf8 }
$cityResult | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $cityRuntime 'run-results.json') -Encoding utf8
$cityResult | ConvertTo-Json -Depth 6
if ($cityTimeout -or $cityProcess.ExitCode -ne 0 -or $cityResult.diagnostics.Count -gt 0) { exit 1 }
exit 0
