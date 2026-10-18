param([string]$Name, [string[]]$EngineArgs, [string]$ProfileName = '')
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..\..')).Path
$profileKey = if ($ProfileName) { $ProfileName } else { $Name }
$profilePath = Join-Path $PSScriptRoot ('userdata\' + $profileKey)
$roamingPath = Join-Path $profilePath 'Roaming'
$localPath = Join-Path $profilePath 'Local'
New-Item -ItemType Directory -Path $roamingPath,$localPath -Force | Out-Null
$env:APPDATA = $roamingPath
$env:LOCALAPPDATA = $localPath
$logPath = Join-Path $PSScriptRoot ($Name + '.log')
$binaryPath = 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe'
$arguments = @('--path', ('"' + $projectPath + '"'), '--log-file', ('"' + $logPath + '"')) + $EngineArgs
$engineProcess = Start-Process -FilePath $binaryPath -ArgumentList $arguments -WindowStyle Hidden -PassThru
$engineProcess.WaitForExit()
$engineExit = $engineProcess.ExitCode
Get-Content -LiteralPath $logPath
Write-Output ('NativeExitCode=' + $engineExit)
exit $engineExit
