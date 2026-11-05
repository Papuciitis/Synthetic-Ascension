param([Parameter(Mandatory=$true)][string]$Label)
$ErrorActionPreference='Stop'
$root=(Get-Location).Path
$scratch=Join-Path $root '.superpowers/sdd/2026-11-04-trailer-yard-preview'
$run=Join-Path $scratch $Label
New-Item -ItemType Directory -Path $run -Force | Out-Null
$fixture=Join-Path $run 'fixture'
New-Item -ItemType Directory -Path (Join-Path $fixture 'core/systems/world/ground'),(Join-Path $fixture 'tools/tests'),(Join-Path $run 'appdata'),(Join-Path $run 'localappdata') -Force | Out-Null
Set-Content -LiteralPath (Join-Path $fixture 'project.godot') -Encoding utf8 -Value '[application]
config/name="CityYardSupport data-only fixture"
[rendering]
renderer/rendering_method="gl_compatibility"'
$pins=@()
foreach($relative in @('core/systems/world/ground/CityYardSupport.gd','tools/tests/CityYardSupportTest.gd')) {
    $source=Join-Path $root $relative
    if(Test-Path -LiteralPath $source) {
        $destination=Join-Path $fixture $relative
        Copy-Item -LiteralPath $source -Destination $destination
        $pins+= [ordered]@{path=$relative;source_sha256=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash;copy_sha256=(Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash}
    } else {$pins+= [ordered]@{path=$relative;absent=$true}}
}
$pins | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $run 'pins.json') -Encoding utf8
. (Join-Path $root 'tools/capture/city_resource_guard.ps1')
$engine='C:/Users/NaurisKrišjānis/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64.exe'
$existing=@(Get-Process | Where-Object {$_.ProcessName -match '(?i)godot'})
if($existing.Count) {throw ('Refusing: another Godot process exists: '+($existing.Id -join ','))}
try {Assert-CityCaptureMemory -MinimumAvailableMB 512 -MinimumCommitMB 1536} catch {
    $_.ToString() | Set-Content -LiteralPath (Join-Path $run 'gate-failure.txt')
    throw
}
$oldAppData=$env:APPDATA
$oldLocalAppData=$env:LOCALAPPDATA
try {
    $env:APPDATA=Join-Path $run 'appdata'
    $env:LOCALAPPDATA=Join-Path $run 'localappdata'
    $arguments=@('--headless','--flush-output','--path',('"'+$fixture+'"'),'--script','res://tools/tests/CityYardSupportTest.gd')
    $process=Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'stdout.log') -RedirectStandardError (Join-Path $run 'stderr.log')
    $pidValue=$process.Id
    $metrics=Wait-CityCaptureProcess -Process $process -TimeoutSeconds 30 -MaximumPrivateMB 64
    $process.WaitForExit()
    $process.Refresh()
    $metrics['pid']=$pidValue
    $metrics['exit_code']=$process.ExitCode
    $metrics['arguments']=$arguments
    $metrics | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $run 'result.json') -Encoding utf8
    Get-Content -LiteralPath (Join-Path $run 'stdout.log')
    Get-Content -LiteralPath (Join-Path $run 'stderr.log')
    Get-Content -LiteralPath (Join-Path $run 'result.json')
} finally {
    $env:APPDATA=$oldAppData
    $env:LOCALAPPDATA=$oldLocalAppData
}


