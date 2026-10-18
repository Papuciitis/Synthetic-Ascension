$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../../..')).Path
$sourcePaths = @(
 'autoload/global.gd','autoload/BalanceRecorder.gd',
 'scenes/game.gd','ui/screens/MainMenu.gd','ui/screens/SaveSelect.gd','ui/screens/hud.gd',
 'ui/widgets/LoadingScrim.gd','ui/widgets/PerformanceOverlay.gd',
 'core/systems/world/ChunkManager.gd','core/systems/world/WorldArt.gd',
 'core/systems/world/Level1Builder.gd','core/systems/world/SegmentProcBuilder.gd',
 'tools/tests/FrontEndFlowTest.gd','tools/tests/LoadingScrimTest.gd','tools/tests/CityDevelopmentUiTest.gd',
 'tools/tests/CityContinuationTest.gd','tools/tests/PauseMenuFlowTest.gd',
 'tools/tests/LoadingTransitionResponsivenessTest.gd','tools/tests/SceneTransitionInterruptionTest.gd',
 'tools/tests/TransitionResourceWarmupTest.gd',
 'assets/world/ground/baked/ground_materials.res','assets/world/ground/baked/ground_materials.json'
)
$sourceHashes = @()
$methodHashes = @()
foreach ($relativePath in $sourcePaths) {
 $path = Join-Path $projectPath $relativePath
 $file = Get-Item -LiteralPath $path
 $sourceHashes += [ordered]@{ path=$relativePath; bytes=$file.Length; sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }
 if ($relativePath.EndsWith('.gd')) {
  $source = [IO.File]::ReadAllText($path).Replace("`r`n","`n")
  foreach ($method in [regex]::Matches($source, '(?ms)^(?:static )?func (\w+)\([^\n]*\n.*?(?=^(?:static )?func |\z)')) {
   $bytes = [Text.Encoding]::UTF8.GetBytes($method.Value)
   $hash = [Security.Cryptography.SHA256]::HashData($bytes)
   $methodHashes += [ordered]@{ path=$relativePath; method=$method.Groups[1].Value; sha256=([Convert]::ToHexString($hash)).ToLowerInvariant() }
  }
 }
}
$evidenceHashes = @()
$evidenceFiles = @(Get-ChildItem -LiteralPath $PSScriptRoot -File -Filter '*.log')
foreach ($captureFolder in @('native-s1-captures','native-s2-captures')) {
 $capturePath = Join-Path $PSScriptRoot $captureFolder
 if (Test-Path -LiteralPath $capturePath) { $evidenceFiles += @(Get-ChildItem -LiteralPath $capturePath -File -Filter '*.png') }
}
foreach ($file in $evidenceFiles) {
 $evidenceHashes += [ordered]@{ path=[IO.Path]::GetRelativePath($PSScriptRoot,$file.FullName).Replace('\','/'); bytes=$file.Length; sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
}
$audit = [ordered]@{
 schema_revision=1
 generated_utc=[DateTime]::UtcNow.ToString('o')
 git_head=(& git -C $projectPath rev-parse HEAD)
 engine='Godot 4.7.1 stable official a13da4feb, native Windows executable'
 method_hash_format='Top-level function stanza through the next top-level function; normalized LF UTF-8.'
 source_files=$sourceHashes
 method_source_hashes=$methodHashes
 evidence=$evidenceHashes
 findings='FINDINGS.md distinguishes clean passes, deliberate negative controls, native strict timing failures, invalid probes, and harness limitations.'
}
$auditPath = Join-Path $PSScriptRoot 'audit.json'
[IO.File]::WriteAllText($auditPath, ($audit | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
Write-Output ('Audit source_files=' + $sourceHashes.Count + ' methods=' + $methodHashes.Count + ' evidence=' + $evidenceHashes.Count)
