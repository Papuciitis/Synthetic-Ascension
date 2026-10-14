# Technical export only: use recorded ImageGen masters, never modify them.
# Run after all 52 final illustrations and prompt manifests are present.
[CmdletBinding()]
param(
    [string]$ProjectRoot = (Join-Path $PSScriptRoot '..\..'),
    [switch]$IncludeThumbnails,
    [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectPath = (Resolve-Path -LiteralPath $ProjectRoot).Path.TrimEnd('\', '/')
$cardPath = Join-Path $projectPath 'assets\ui\augments\cards'
$manifestPath = Join-Path $projectPath 'docs\art\augment-card-prompts'
$qaPath = Join-Path $projectPath 'docs\art\reference\augment-cards-2026-10-14'

function Assert-WorkspacePath([string]$Path) {
    $absolute = [IO.Path]::GetFullPath($Path)
    if (-not $absolute.StartsWith($projectPath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Destination is outside the project: $absolute"
    }
    # Refuse junctions/symlinks that could redirect a project destination.
    $ancestor = $absolute
    while ($ancestor -and $ancestor.Length -ge $projectPath.Length) {
        if (Test-Path -LiteralPath $ancestor) {
            $item = Get-Item -LiteralPath $ancestor
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Destination crosses a junction or symlink: $ancestor"
            }
        }
        if ($ancestor -eq $projectPath) { break }
        $ancestor = [IO.Path]::GetDirectoryName($ancestor)
    }
    return $absolute
}

function New-Entry([string]$Group, [string]$Slug, [string]$Label) {
    $folder = if ($Group -eq 'base') { '' } else { $Group + '/' }
    $prefix = switch ($Group) { 'base' { '' } 'transcend' { 'transcend_' } 'facets' { 'facet_' } 'duos' { 'duo_' } }
    [pscustomobject]@{
        Group = $Group; Slug = $Slug; Label = $Label
        RelativePath = "assets/ui/augments/cards/$folder$Slug.png"
        Manifest = Join-Path $manifestPath "$prefix$Slug.json"
        Target = Assert-WorkspacePath (Join-Path $cardPath "$folder$Slug.png")
        Source = ''; SourceHash = ''; SourceWidth = 0
    }
}

$bases = [ordered]@{
    magic_missile = 'Magic Missile'; tesla_aura = 'Tesla Aura'
    spirit_slash = 'Spirit Slash'; blink_hex = 'Blink Hex'
    summon_spiderlings = 'Summon Spiderlings'; reflect_shield = 'Reflect Shield'
    stamina_core = 'Stamina Core'; sprint_servos = 'Sprint Servos'
    lucky_charm = 'Lucky Charm'; corruption_engine = 'Corruption Engine'
    doctrine_of_burden = 'Doctrine of Burden'; inversion_lens = 'Inversion Lens'
    equilibrium_sigil = 'Equilibrium Sigil'; litany_of_wounds = 'Litany of Wounds'
    cult_of_personality = 'Cult of Personality'; gamblers_rite = "Gambler's Rite"
}
$facets = [ordered]@{
    magic_missile_salvo = 'Magic Missile / Salvo'; magic_missile_lance = 'Magic Missile / Lance'
    tesla_aura_overcharge = 'Tesla Aura / Overcharge'; tesla_aura_static_field = 'Tesla Aura / Static Field'
    spirit_slash_hemorrhage = 'Spirit Slash / Hemorrhage'; spirit_slash_executioner = 'Spirit Slash / Executioner'
    blink_hex_long_step = 'Blink Hex / Long Step'; blink_hex_deep_mark = 'Blink Hex / Deep Mark'
    summon_spiderlings_swarm = 'Spiderlings / Swarm'; summon_spiderlings_venom_sacs = 'Spiderlings / Venom Sacs'
    reflect_shield_riposte = 'Reflect Shield / Riposte'; reflect_shield_long_guard = 'Reflect Shield / Long Guard'
    stamina_core_second_wind = 'Stamina Core / Second Wind'; stamina_core_iron_lung = 'Stamina Core / Iron Lung'
}
$duos = [ordered]@{
    lightning_rods = 'Lightning Rods'; phantom_step = 'Phantom Step'; static_brood = 'Static Brood'
    bulwark_engine = 'Bulwark Engine'; slipstream_coil = 'Slipstream Coil'; loaded_dice = 'Loaded Dice'
}
$entries = @(
    foreach ($slug in $bases.Keys) { New-Entry 'base' $slug $bases[$slug] }
    foreach ($slug in $bases.Keys) { New-Entry 'transcend' $slug ($bases[$slug] + ' / Transcend') }
    foreach ($slug in $facets.Keys) { New-Entry 'facets' $slug $facets[$slug] }
    foreach ($slug in $duos.Keys) { New-Entry 'duos' $slug $duos[$slug] }
)
if ($entries.Count -ne 52) { throw 'Expected exactly 52 export entries.' }
Assert-WorkspacePath $qaPath | Out-Null

function Get-SquareWidth([string]$Path) {
    $image = [Drawing.Image]::FromFile($Path)
    try {
        if ($image.Width -ne $image.Height) {
            throw "Refusing to stretch a non-square illustration: $Path ($($image.Width)x$($image.Height))"
        }
        return $image.Width
    } finally { $image.Dispose() }
}

# Validate the complete set before writing even one project image.
$projectPngs = @(Get-ChildItem -LiteralPath $cardPath -Recurse -File -Filter '*.png')
if ($projectPngs.Count -ne 52) { throw "Expected 52 project PNGs, found $($projectPngs.Count)." }
$expectedPaths = @($entries | ForEach-Object { $_.Target })
foreach ($file in $projectPngs) {
    if ($expectedPaths -notcontains $file.FullName) { throw "Unexpected card PNG: $($file.FullName)" }
}
foreach ($entry in $entries) {
    if (-not (Test-Path -LiteralPath $entry.Target -PathType Leaf)) { throw "Missing project card: $($entry.Target)" }
    if (-not (Test-Path -LiteralPath $entry.Manifest -PathType Leaf)) { throw "Missing prompt manifest: $($entry.Manifest)" }
    $manifest = Get-Content -LiteralPath $entry.Manifest -Raw -Encoding UTF8 | ConvertFrom-Json
    $sourceProperty = $manifest.PSObject.Properties['output_source']
    if ($null -eq $sourceProperty) { $sourceProperty = $manifest.PSObject.Properties['source'] }
    if ($null -eq $sourceProperty -or [string]::IsNullOrWhiteSpace([string]$sourceProperty.Value)) {
        throw "Prompt manifest has no generated master source: $($entry.Manifest)"
    }
    # Some early manifests encoded doubled Windows separators.
    $entry.Source = [IO.Path]::GetFullPath(([string]$sourceProperty.Value -replace '\\{2,}', '\'))
    if ($entry.Source -eq $entry.Target) { throw "Master source points at the project export: $($entry.Source)" }
    if (-not (Test-Path -LiteralPath $entry.Source -PathType Leaf)) { throw "Missing generated master: $($entry.Source)" }
    $declaredProperty = $manifest.PSObject.Properties['output_path']
    if ($null -eq $declaredProperty) { $declaredProperty = $manifest.PSObject.Properties['path'] }
    if ($null -eq $declaredProperty) { throw "Prompt manifest has no project destination: $($entry.Manifest)" }
    $declaredPath = [string]$declaredProperty.Value
    if (-not [IO.Path]::IsPathRooted($declaredPath)) { $declaredPath = Join-Path $projectPath $declaredPath }
    if ((Assert-WorkspacePath $declaredPath) -ne $entry.Target) { throw "Manifest destination does not match $($entry.RelativePath)" }
    $entry.SourceWidth = Get-SquareWidth $entry.Source
    if ($entry.SourceWidth -lt 512) { throw "Refusing to upscale a master below 512px: $($entry.Source)" }
    Get-SquareWidth $entry.Target | Out-Null
    $entry.SourceHash = (Get-FileHash -LiteralPath $entry.Source -Algorithm SHA256).Hash
}
if ($ValidateOnly) {
    Write-Output 'Validated all 52 square cards and recorded masters; no files written.'
    return
}

function Save-Png([Drawing.Bitmap]$Bitmap, [string]$Path) {
    $destination = Assert-WorkspacePath $Path
    $temporary = Assert-WorkspacePath ($destination + '.export.tmp')
    $stream = [IO.MemoryStream]::new()
    try {
        $Bitmap.Save($stream, [Drawing.Imaging.ImageFormat]::Png)
        [IO.File]::WriteAllBytes($temporary, $stream.ToArray())
        Move-Item -LiteralPath $temporary -Destination $destination -Force
    } finally {
        $stream.Dispose()
        if (Test-Path -LiteralPath $temporary -PathType Leaf) { Remove-Item -LiteralPath $temporary }
    }
}

function Set-Quality([Drawing.Graphics]$Graphics) {
    $Graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
    $Graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $Graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
    $Graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
}

function Draw-Art([Drawing.Graphics]$Graphics, [Drawing.Image]$Image, [Drawing.Rectangle]$Rectangle) {
    $attributes = [Drawing.Imaging.ImageAttributes]::new()
    try {
        $attributes.SetWrapMode([Drawing.Drawing2D.WrapMode]::TileFlipXY)
        $Graphics.DrawImage($Image, $Rectangle, 0, 0, $Image.Width, $Image.Height, [Drawing.GraphicsUnit]::Pixel, $attributes)
    } finally { $attributes.Dispose() }
}

foreach ($entry in $entries) {
    $image = [Drawing.Image]::FromFile($entry.Source)
    $bitmap = [Drawing.Bitmap]::new(512, 512, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        Set-Quality $graphics
        $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.Clear([Drawing.Color]::Transparent)
        Draw-Art $graphics $image ([Drawing.Rectangle]::new(0, 0, 512, 512))
        Save-Png $bitmap $entry.Target
    } finally { $graphics.Dispose(); $bitmap.Dispose(); $image.Dispose() }
}
[IO.Directory]::CreateDirectory($qaPath) | Out-Null

function New-ContactSheet([string]$Group, [int]$ArtSize) {
    $groupEntries = @($entries | Where-Object { $_.Group -eq $Group })
    $columns = 4
    $rows = [int][Math]::Ceiling($groupEntries.Count / [double]$columns)
    $padding = 16
    $cellWidth = [Math]::Max(252, $ArtSize + 32)
    $cellHeight = $ArtSize + 58
    $bitmap = [Drawing.Bitmap]::new(($padding * 2 + $columns * $cellWidth), (70 + $rows * $cellHeight), [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $titleFont = [Drawing.Font]::new('Segoe UI', 20, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
    $labelFont = [Drawing.Font]::new('Segoe UI', 14, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
    $brush = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(235, 224, 197))
    $format = [Drawing.StringFormat]::new()
    try {
        Set-Quality $graphics
        $graphics.Clear([Drawing.Color]::FromArgb(28, 25, 23))
        $graphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $graphics.DrawString("AUGMENT ART / $($Group.ToUpperInvariant()) / ${ArtSize}px / $($groupEntries.Count) cards", $titleFont, $brush, 16, 16)
        $format.Alignment = [Drawing.StringAlignment]::Center
        $format.LineAlignment = [Drawing.StringAlignment]::Near
        for ($index = 0; $index -lt $groupEntries.Count; $index++) {
            $entry = $groupEntries[$index]
            $x = $padding + ($index % $columns) * $cellWidth
            $y = 64 + [int][Math]::Floor($index / [double]$columns) * $cellHeight
            $image = [Drawing.Image]::FromFile($entry.Target)
            try { Draw-Art $graphics $image ([Drawing.Rectangle]::new(($x + [int](($cellWidth - $ArtSize) / 2)), $y, $ArtSize, $ArtSize)) }
            finally { $image.Dispose() }
            $graphics.DrawString($entry.Label, $labelFont, $brush, [Drawing.RectangleF]::new($x + 4, $y + $ArtSize + 8, $cellWidth - 8, 46), $format)
        }
        Save-Png $bitmap (Join-Path $qaPath "contact_${Group}_${ArtSize}.png")
    } finally {
        $format.Dispose(); $brush.Dispose(); $labelFont.Dispose(); $titleFont.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
    }
}
foreach ($group in @('base', 'transcend', 'facets', 'duos')) {
    New-ContactSheet $group 220
    if ($IncludeThumbnails) { New-ContactSheet $group 40 }
}

$report = @(
    foreach ($entry in $entries) {
        $afterHash = (Get-FileHash -LiteralPath $entry.Source -Algorithm SHA256).Hash
        if ($afterHash -ne $entry.SourceHash) { throw "Generated master changed during export: $($entry.Source)" }
        if ((Get-SquareWidth $entry.Target) -ne 512) { throw "Export dimensions failed: $($entry.Target)" }
        [ordered]@{
            group = $entry.Group; slug = $entry.Slug; path = $entry.RelativePath
            master = $entry.Source; master_width = $entry.SourceWidth; master_sha256 = $afterHash
            export_width = 512; export_sha256 = (Get-FileHash -LiteralPath $entry.Target -Algorithm SHA256).Hash
        }
    }
)
$reportPath = Assert-WorkspacePath (Join-Path $qaPath 'export-manifest.json')
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reportPath -Encoding UTF8
Write-Output "Exported 52 cards at 512x512; masters unchanged. Contact sheets: $qaPath"
