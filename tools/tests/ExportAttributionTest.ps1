$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script:passes = 0
$script:failures = 0

function Assert-Contract([bool]$Condition, [string]$Message) {
    if ($Condition) {
        $script:passes += 1
        Write-Output "PASS: $Message"
    } else {
        $script:failures += 1
        Write-Output "FAIL: $Message"
    }
}

function Test-Filter([string]$File, [string]$Patterns) {
    foreach ($pattern in $Patterns.Split(',')) {
        if ([string]::IsNullOrWhiteSpace($pattern)) { continue }
        $matcher = [System.Management.Automation.WildcardPattern]::new($pattern.Trim(), [System.Management.Automation.WildcardOptions]::IgnoreCase)
        if ($matcher.IsMatch($File) -or $matcher.IsMatch('res://' + $File)) { return $true }
    }
    return $false
}

# Godot applies include/exclude wildcard filters to project-relative paths
# (and their res:// form). Non-resource notice files need explicit inclusion.
$presetText = Get-Content -LiteralPath (Join-Path $projectRoot 'export_presets.cfg') -Raw
$presets = [System.Text.RegularExpressions.Regex]::Matches($presetText, '(?ms)^\[preset\.(\d+)\]\s*(.*?)(?=^\[|\z)')
Assert-Contract ($presets.Count -gt 0) 'export presets are discovered'
$required = @(
    'THIRD_PARTY_NOTICES.txt',
    'assets/audio/sfx/CREDITS.md',
    'assets/audio/sfx/bosses/CREDITS.md',
    'assets/audio/sfx/bosses/candidates_v2/CREDITS.md',
    'assets/audio/sfx/bosses/candidates_v3/CREDITS.md',
    'assets/audio/sfx/bosses/candidates_v2/LICENSE-qubodup-ice-electricity.txt',
    'assets/audio/sfx/bosses/candidates_v2/LICENSE-Kenney-impact-sounds.txt',
    'assets/audio/sfx/bosses/candidates_v3/LICENSE-Kenney-impact-sounds.txt'
)
Assert-Contract (Test-Path -LiteralPath (Join-Path $projectRoot 'THIRD_PARTY_NOTICES.txt') -PathType Leaf) 'discoverable root notice exists'
$fontNotices = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'assets/fonts') -Recurse -File -Filter '*.txt' | ForEach-Object {
    [System.IO.Path]::GetRelativePath($projectRoot, $_.FullName).Replace('\', '/')
}) + @('assets/fonts/README.md')
foreach ($preset in $presets) {
    $section = $preset.Groups[2].Value
    $include = [System.Text.RegularExpressions.Regex]::Match($section, '(?m)^include_filter="([^"]*)"').Groups[1].Value
    $exclude = [System.Text.RegularExpressions.Regex]::Match($section, '(?m)^exclude_filter="([^"]*)"').Groups[1].Value
    foreach ($file in ($required + $fontNotices)) {
        Assert-Contract ((Test-Filter $file $include) -and -not (Test-Filter $file $exclude)) ("preset {0} ships {1}" -f $preset.Groups[1].Value, $file)
    }
}

# Exercise the actual release script with a controlled export boundary. This
# dummy script writes inert bytes; it neither starts Godot nor builds a game.
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('sa-attribution-test-' + [guid]::NewGuid().ToString('N'))
$fixtureExpected = [System.IO.Path]::GetFullPath($fixtureRoot)
$buildInfoPath = Join-Path $projectRoot 'build_info.json'
if (Test-Path -LiteralPath $buildInfoPath) { throw 'Existing build_info.json prevents an isolated packaging fixture.' }
New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
try {
    $fakeGodot = Join-Path $fixtureRoot 'FakeGodot.ps1'
    $fakeSource = @'
$artifact = [string]$args[-1]
[System.IO.File]::WriteAllBytes($artifact, [byte[]](0x46, 0x49, 0x58, 0x54, 0x55, 0x52, 0x45))
[System.IO.File]::WriteAllBytes([System.IO.Path]::ChangeExtension($artifact, '.pck'), [byte[]](0x50, 0x43, 0x4b))
exit 0
'@
    [System.IO.File]::WriteAllText($fakeGodot, $fakeSource, [System.Text.UTF8Encoding]::new($false))
    $outputRoot = Join-Path $fixtureRoot 'releases'
    New-Item -ItemType Directory -Path $outputRoot | Out-Null
    & (Join-Path $projectRoot 'tools/package_release.ps1') -GodotConsole $fakeGodot -OutputRoot $outputRoot
    $releaseFolders = @(Get-ChildItem -LiteralPath $outputRoot -Directory)
    Assert-Contract ($releaseFolders.Count -eq 1) 'actual packager creates one versioned release around the inert export'
    if ($releaseFolders.Count -eq 1) {
        $releaseRoot = $releaseFolders[0].FullName
        $sidecar = Join-Path $releaseRoot 'THIRD_PARTY_NOTICES.txt'
        $sidecarExists = Test-Path -LiteralPath $sidecar -PathType Leaf
        Assert-Contract $sidecarExists 'release contains a directly readable notice beside EXE and PCK'
        if ($sidecarExists) {
            $sourceHash = (Get-FileHash -LiteralPath (Join-Path $projectRoot 'THIRD_PARTY_NOTICES.txt') -Algorithm SHA256).Hash.ToLowerInvariant()
            $copyHash = (Get-FileHash -LiteralPath $sidecar -Algorithm SHA256).Hash.ToLowerInvariant()
            Assert-Contract ($copyHash -eq $sourceHash) 'shipped notice exactly matches the reviewed source notice'
            $sums = Get-Content -LiteralPath (Join-Path $releaseRoot 'SHA256SUMS.txt')
            Assert-Contract ($sums -contains ($sourceHash + '  THIRD_PARTY_NOTICES.txt')) 'release integrity manifest covers the readable notice'
        }
    }
} finally {
    # Delete only this freshly created fixture after checking the literal
    # resolved path. No project files or externally supplied roots are removed.
    $resolvedFixture = (Resolve-Path -LiteralPath $fixtureRoot).Path
    if ($resolvedFixture -ne $fixtureExpected -or -not $resolvedFixture.StartsWith([System.IO.Path]::GetTempPath(), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw ('Refusing fixture cleanup outside its verified temporary directory: ' + $resolvedFixture)
    }
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
}
Write-Output ("ExportAttributionTest: {0} passed, {1} failed" -f $script:passes, $script:failures)
if ($script:failures -gt 0) { exit 1 }
exit 0
