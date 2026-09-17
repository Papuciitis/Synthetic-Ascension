param(
    [Parameter(Mandatory = $true)]
    [string]$GodotConsole,

    [Parameter(Mandatory = $true)]
    [string]$OutputRoot,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
# Single source of truth: application/config/version in project.godot.
$version = (Select-String -Path (Join-Path $PSScriptRoot '..\project.godot') -Pattern '^config/version="(.+)"').Matches[0].Groups[1].Value
if ([string]::IsNullOrWhiteSpace($version)) { throw 'config/version missing from project.godot' }
$presetName = 'Windows Desktop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$godotPath = [System.IO.Path]::GetFullPath($GodotConsole)
$outputRootPath = [System.IO.Path]::GetFullPath($OutputRoot)
$versionDirectory = Join-Path $outputRootPath "synthetic-ascension-$version-windows"
$executablePath = Join-Path $versionDirectory "SyntheticAscension-$version.exe"
$presetPath = Join-Path $projectRoot 'export_presets.cfg'

if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Godot console executable not found: $godotPath"
}
if (-not (Test-Path -LiteralPath $presetPath -PathType Leaf)) {
    throw "Export preset not found: $presetPath"
}
if ((Get-Content -Raw -LiteralPath $presetPath) -notmatch 'name="Windows Desktop"') {
    throw "Export preset '$presetName' is missing from $presetPath"
}
if (Test-Path -LiteralPath $versionDirectory) {
    throw "Refusing to overwrite existing release directory: $versionDirectory"
}

if ($DryRun) {
    Write-Output "Dry run valid: $presetName -> $executablePath"
    exit 0
}

New-Item -ItemType Directory -Path $versionDirectory | Out-Null
# Bake the git identity for BuildInfo: exported builds have no .git to read.
# The file is git-ignored and removed again after the export.
$buildInfoPath = Join-Path $projectRoot 'build_info.json'
$gitCommit = (& git -C $projectRoot rev-parse --short=12 HEAD 2>$null)
$gitBranch = (& git -C $projectRoot rev-parse --abbrev-ref HEAD 2>$null)
@{ git_commit = "$gitCommit"; git_branch = "$gitBranch"; game_version = $version } |
    ConvertTo-Json -Compress | Set-Content -LiteralPath $buildInfoPath -Encoding utf8
try {
    & $godotPath --headless --path $projectRoot --export-release $presetName $executablePath
    if ($LASTEXITCODE -ne 0) {
        throw "Godot export failed with exit code $LASTEXITCODE"
    }
} finally {
    Remove-Item -LiteralPath $buildInfoPath -Force -ErrorAction SilentlyContinue
}
if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
    throw "Godot reported success but did not create $executablePath"
}

$manifestPath = Join-Path $versionDirectory 'SHA256SUMS.txt'
$manifestLines = Get-ChildItem -LiteralPath $versionDirectory -File -Recurse |
    Where-Object { $_.FullName -ne $manifestPath } |
    Sort-Object FullName |
    ForEach-Object {
        $relativePath = [System.IO.Path]::GetRelativePath($versionDirectory, $_.FullName).Replace('\', '/')
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash  $relativePath"
    }
Set-Content -LiteralPath $manifestPath -Value $manifestLines -Encoding utf8
Write-Output "Release created: $versionDirectory"
