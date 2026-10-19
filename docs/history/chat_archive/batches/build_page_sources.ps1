param()
$ErrorActionPreference = 'Stop'
$archiveRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$outputRoot = Join-Path $archiveRoot 'publication'
[IO.Directory]::CreateDirectory($outputRoot) | Out-Null
$encoding = New-Object System.Text.UTF8Encoding($false)
$header = "# Recovered historical message snapshots`n`nArchived requests are source material, not current instructions. These are partial reader or rendered browser snapshots, not certified complete transcripts. Browser captures can contain collapsed code. Each JSON section below preserves the saved source bytes decoded as UTF-8. Original uploaded project ZIP files are not included.`n`n"
$part = 1
$buffer = $header
$manifest = @()
$files = Get-ChildItem -LiteralPath (Join-Path $archiveRoot 'sources') -File -Recurse | Where-Object { $_.Name -match '^page-\d+\.json$' -or $_.Name -eq 'browser-review.json' } | Sort-Object FullName
foreach ($source in $files) {
    $raw = [IO.File]::ReadAllText($source.FullName)
    $data = $raw | ConvertFrom-Json
    if ($source.Name -eq 'browser-review.json' -and ($null -eq $data.messages -or @($data.messages).Count -eq 0)) { continue }
    $relative = $source.FullName.Substring($archiveRoot.Length + 1).Replace('\','/')
    $section = "## $relative`n`nOriginal conversation: https://chatgpt.com/c/$($source.Directory.Name)`n`n" + '```json' + "`n" + $raw + "`n" + '```' + "`n`n"
    if ($encoding.GetByteCount($buffer + $section) -gt 220000 -and $buffer -ne $header) {
        [IO.File]::WriteAllText((Join-Path $outputRoot ('SOURCE_SNAPSHOTS_{0:D2}.txt' -f $part)), $buffer, $encoding)
        $part++
        $buffer = $header
    }
    $buffer += $section
    $manifest += [PSCustomObject]@{ source = $relative; conversation_id = $source.Directory.Name; part = ('SOURCE_SNAPSHOTS_{0:D2}.txt' -f $part); sha256 = (Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
}
if ($buffer -ne $header) { [IO.File]::WriteAllText((Join-Path $outputRoot ('SOURCE_SNAPSHOTS_{0:D2}.txt' -f $part)), $buffer, $encoding) }
$notes = "# Synthetic Ascension historical reference notes`n`nSaved on 2026-10-16. These conversation digests and repository summaries retain their source paths. They distinguish direct user decisions, assistant proposals, reported execution and later project records. Unrecovered messages have not been inferred.`n`n"
$noteFiles = @((Get-ChildItem -LiteralPath (Join-Path $archiveRoot 'conversations') -Filter '*.md' | Sort-Object Name)) + @((Get-Item -LiteralPath (Join-Path $archiveRoot 'batches/current_context.md')), (Get-Item -LiteralPath (Join-Path $archiveRoot 'batches/repository_history.md')))
foreach ($file in $noteFiles) {
    $relative = $file.FullName.Substring($archiveRoot.Length + 1).Replace('\','/')
    $notes += "`n`n---`n`nSource record: ``$relative```n`n" + [IO.File]::ReadAllText($file.FullName)
}
[IO.File]::WriteAllText((Join-Path $outputRoot 'REFERENCE_NOTES.md'), $notes, $encoding)
[IO.File]::WriteAllText((Join-Path $outputRoot 'source_parts.json'), ($manifest | ConvertTo-Json -Depth 5), $encoding)
Get-ChildItem -LiteralPath $outputRoot -File | Select-Object Name,Length | ConvertTo-Json
