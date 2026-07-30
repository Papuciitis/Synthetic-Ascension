param(
    [Parameter(Mandatory = $true)]
    [string]$GodotConsole,

    [Parameter(Mandatory = $true)]
    [string]$OutputRoot,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$version = '0.0.0.25.5'
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
& $godotPath --headless --path $projectRoot --export-release $presetName $executablePath
if ($LASTEXITCODE -ne 0) {
    throw "Godot export failed with exit code $LASTEXITCODE"
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
