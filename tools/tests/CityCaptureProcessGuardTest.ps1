$ErrorActionPreference='Stop'
$guardPath=Join-Path $PSScriptRoot '../capture/city_process_guard.ps1'
if (-not (Test-Path -LiteralPath $guardPath)) {Write-Output 'CityCaptureProcessGuardTest: missing exact editor/game process predicate';exit 1}
. $guardPath
$cases=@(
  @{name='Godot.exe';command='Godot.exe --path project --editor';want=$false},
  @{name='Godot.exe';command='Godot.exe -e --path project';want=$false},
  @{name='Godot.exe';command='Godot.exe --path project --editor-pid 29136';want=$true},
  @{name='Godot.exe';command='Godot.exe --headless --path project';want=$true},
  @{name='Godot.exe';command='Godot.exe --editor --import --path project';want=$true},
  @{name='Godot.exe';command='';want=$true},
  @{name='notepad.exe';command='notepad.exe --editor-pid 3';want=$false}
)
$failed=0
foreach($case in $cases) {
  $actual=Test-CityCaptureGameProcess -Name $case.name -CommandLine $case.command
  if($actual -ne $case.want) {$failed++;Write-Output ('FAIL: '+$case.command)}
}
Write-Output ('CityCaptureProcessGuardTest: '+($cases.Count-$failed)+' passed, '+$failed+' failed')
exit $(if($failed -gt 0){1}else{0})
