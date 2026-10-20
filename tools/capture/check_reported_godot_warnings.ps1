param(
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [string]$SnapshotDirectory='',
    [switch]$DirectCheckOnly,
    [string]$Engine=(Join-Path $env:USERPROFILE 'Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64.exe')
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'city_process_guard.ps1')
. (Join-Path $PSScriptRoot 'city_resource_guard.ps1')
$warningRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$otherRuns=@(Get-CimInstance Win32_Process | Where-Object {Test-CityCaptureGameProcess -Name $_.Name -CommandLine $_.CommandLine})
if ($otherRuns.Count -gt 0) {throw 'Another Godot run is active; leaving it untouched.'}
$warningOutput=[IO.Path]::GetFullPath($OutputDirectory)
if ((Test-Path -LiteralPath $warningOutput) -and @(Get-ChildItem -LiteralPath $warningOutput -Force).Count -gt 0) {throw 'Use a fresh output directory to preserve prior diagnostics.'}
New-Item -ItemType Directory -Path $warningOutput -Force | Out-Null
$reuse=-not [string]::IsNullOrEmpty($SnapshotDirectory)
$snapshot=if ($reuse) {(Resolve-Path -LiteralPath $SnapshotDirectory).Path} else {Join-Path $warningRoot ('.superpowers/sdd/warning-snapshot-'+[Guid]::NewGuid().ToString('N').Substring(0,8))}
$snapshotPrefix=Join-Path $warningRoot '.superpowers/sdd/warning-snapshot-'
if (-not $snapshot.StartsWith($snapshotPrefix,[StringComparison]::OrdinalIgnoreCase)) {throw 'Snapshot must be an isolated warning-snapshot directory inside .superpowers/sdd.'}
if (-not $reuse) {New-Item -ItemType Directory -Path $snapshot | Out-Null}
# Physical copies keep source and import sidecars isolated. Check-only reads
# the existing imported textures through a junction; it never runs the editor
# importer or opens a Game scene. No working-project setting is edited.
foreach ($folder in @('assets','autoload','core','scenes','data','ui','tools','effects','spells','addons')) {
    if ($reuse) {continue}
    $source=Join-Path $warningRoot $folder
    if (-not (Test-Path -LiteralPath $source)) {continue}
    & robocopy $source (Join-Path $snapshot $folder) /E /NFL /NDL /NJH /NJS /NP /R:0 /W:0 /XD __pycache__ | Out-Null
    if ($LASTEXITCODE -gt 7) {throw ('Snapshot copy failed: '+$folder)}
}
if (-not $reuse) {
New-Item -ItemType Directory -Path (Join-Path $snapshot '.godot') | Out-Null
foreach ($cache in @('global_script_class_cache.cfg','uid_cache.bin')) {
    Copy-Item -LiteralPath (Join-Path $warningRoot ('.godot/'+$cache)) -Destination (Join-Path $snapshot ('.godot/'+$cache))
}
New-Item -ItemType Junction -Path (Join-Path $snapshot '.godot/imported') -Target (Join-Path $warningRoot '.godot/imported') | Out-Null
}
$categories=@('shadowed_variable_base_class','unused_private_class_variable','unused_parameter','shadowed_global_identifier','confusable_local_declaration','integer_division','redundant_await')
$projectPath=Join-Path $warningRoot 'project.godot'
$projectHash=(Get-FileHash -LiteralPath $projectPath -Algorithm SHA256).Hash
$projectText=Get-Content -Raw -LiteralPath $projectPath
if (-not $reuse) {
if ($projectText -match '(?m)^\[debug\]\s*$') {throw 'Snapshot runner expects no existing debug section; review local severity insertion before use.'}
$projectText += "`n[debug]`n"
foreach ($category in $categories) {$projectText += ('gdscript/warnings/'+$category+'=2' + "`n")}
$projectText | Set-Content -LiteralPath (Join-Path $snapshot 'project.godot') -Encoding utf8
}
$targets=@(
    'scenes/world/buildings/RoofOverlay.gd','scenes/world/buildings/DungeonRoof.gd',
    'scenes/world/buildings/CityBlockKit.gd','scenes/world/buildings/DungeonBuilding.gd',
    'core/systems/world/ChunkManager.gd','ui/screens/CityDevelopmentScreen.gd',
    'ui/widgets/library/LibraryBook.gd','ui/widgets/library/LibraryOpenBook.gd',
    'ui/widgets/library/LibraryRibbon.gd','ui/widgets/library/LibraryPagination.gd',
    'ui/screens/opening/OpeningPresentation.gd','core/systems/world/Level1Builder.gd',
    'scenes/world/bosses/BossBulldozerBrain.gd','core/systems/world/objectives/BreachSealObjective.gd'
)
$rows=@()
$oldApp=$env:APPDATA
$oldLocal=$env:LOCALAPPDATA
if (-not $DirectCheckOnly) {
    # Reuse refreshes the affected files only. Use it only while the rest of
    # this snapshot's dependency/resource tree still matches the working tree.
    foreach ($target in $targets) {Copy-Item -LiteralPath (Join-Path $warningRoot $target) -Destination (Join-Path $snapshot $target)}
    Copy-Item -LiteralPath (Join-Path $warningRoot 'tools/dev/ReportedWarningAudit.gd') -Destination (Join-Path $snapshot 'tools/dev/ReportedWarningAudit.gd')
    $oldAudit=$env:REPORTED_WARNING_AUDIT_OUT
    Assert-CityCaptureMemory
    try {
        $env:APPDATA=$snapshot
        $env:LOCALAPPDATA=$snapshot
        $env:REPORTED_WARNING_AUDIT_OUT=Join-Path $warningOutput 'audit.json'
        $quotedSnapshot='"'+$snapshot+'"'
        $process=Start-Process -FilePath $Engine -ArgumentList @('--headless','--path',$quotedSnapshot,'--script','res://tools/dev/ReportedWarningAudit.gd') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $warningOutput 'stdout.log') -RedirectStandardError (Join-Path $warningOutput 'stderr.log')
    } finally {$env:APPDATA=$oldApp; $env:LOCALAPPDATA=$oldLocal; $env:REPORTED_WARNING_AUDIT_OUT=$oldAudit}
    $resources=Wait-CityCaptureProcess -Process $process -TimeoutSeconds 180
    $timeout=$resources.stop_reason -eq 'timeout'
    $diagnostics=@(Get-Content -LiteralPath (Join-Path $warningOutput 'stderr.log') | Where-Object {$_ -match 'SCRIPT ERROR|ERROR:|WARNING:'})
    $auditPath=Join-Path $warningOutput 'audit.json'
    $audit=if (Test-Path -LiteralPath $auditPath) {Get-Content -Raw -LiteralPath $auditPath | ConvertFrom-Json} else {$null}
    $unchanged=$projectHash -eq (Get-FileHash -LiteralPath $projectPath -Algorithm SHA256).Hash
    $result=[ordered]@{snapshot=$snapshot;autoload_context=$true;exit=$process.ExitCode;timeout=$timeout;resources=$resources;diagnostics=$diagnostics;failed_scripts=if ($null -ne $audit) {$audit.failed_scripts} else {-1};project_settings_file_unchanged=$unchanged}
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $warningOutput 'results.json') -Encoding utf8
    $result | ConvertTo-Json -Depth 6
    if ($process.ExitCode -ne 0 -or $resources.stop_reason -or $diagnostics.Count -gt 0 -or -not $unchanged -or $null -eq $audit -or -not $audit.startup_severities_strict) {exit 1}
    exit 0
}
foreach ($target in $targets) {
    $stem=[IO.Path]::GetFileNameWithoutExtension($target)
    $stdout=Join-Path $warningOutput ($stem+'-stdout.log')
    $stderr=Join-Path $warningOutput ($stem+'-stderr.log')
    Assert-CityCaptureMemory
    try {
        $env:APPDATA=$snapshot
        $env:LOCALAPPDATA=$snapshot
        $process=Start-Process -FilePath $Engine -ArgumentList @('--headless','--path',('"'+$snapshot+'"'),'--check-only','--script',('res://'+$target)) -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    } finally {$env:APPDATA=$oldApp; $env:LOCALAPPDATA=$oldLocal}
    $resources=Wait-CityCaptureProcess -Process $process -TimeoutSeconds 120
    $timeout=$resources.stop_reason -eq 'timeout'
    $lines=@(Get-Content -LiteralPath $stderr)
    $diagnostics=@($lines | Where-Object {$_ -match 'SCRIPT ERROR|ERROR:|WARNING:|Warning treated as error'})
    $rows += [ordered]@{path=$target;source_sha256=(Get-FileHash -LiteralPath (Join-Path $snapshot $target) -Algorithm SHA256).Hash;exit=$process.ExitCode;timeout=$timeout;resources=$resources;diagnostics=$diagnostics}
    Write-Output ($stem+': exit='+$process.ExitCode+' diagnostics='+$diagnostics.Count)
}
$unchanged=$projectHash -eq (Get-FileHash -LiteralPath $projectPath -Algorithm SHA256).Hash
$result=[ordered]@{snapshot=$snapshot;warning_categories=$categories;targets=$rows;failed_scripts=@($rows | Where-Object {$_.exit -ne 0 -or $_.resources.stop_reason -or $_.diagnostics.Count -gt 0}).Count;project_settings_file_unchanged=$unchanged;limit='Check-only compiler diagnostics may report only the first warning per file; dependencies can also appear. This audits the reported categories in the 14 target scripts, not the complete human editor warning panel.'}
$result | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $warningOutput 'results.json') -Encoding utf8
Write-Output ('ReportedWarningAudit: targets='+$rows.Count+' failed_scripts='+$result.failed_scripts+' project_unchanged='+$unchanged)
if ($result.failed_scripts -gt 0 -or -not $unchanged) {exit 1}
