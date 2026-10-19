function Test-CityCaptureGameProcess {
    param([string]$Name,[string]$CommandLine)
    if ($Name -notmatch '^Godot') { return $false }
    # --editor-pid belongs to a game launched by the editor. Only an exact
    # --editor/-e argument exempts the editor itself; missing info blocks.
    return ($CommandLine -match '(^|\s)--import(?=\s|$)' -or $CommandLine -notmatch '(^|\s)(--editor|-e)(?=\s|$)')
}
