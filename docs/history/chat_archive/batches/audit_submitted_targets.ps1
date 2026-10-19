param([string]$ArchiveRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$archive = (Resolve-Path -LiteralPath $ArchiveRoot).Path
$submitted = Get-Content -LiteralPath (Join-Path $archive 'submitted_links.json') -Raw | ConvertFrom-Json
$seen = @{}
$sources = @{}
$conversationMessages = @{}
$rawPages = 0
$browserCaptures = 0

function Add-MessageEvidence($conversation, $id, $role, $relativePath) {
    if (-not $conversation -or -not $id) { return }
    $key = $conversation + '/' + $id
    if (-not $seen.ContainsKey($key)) { $seen[$key] = @() }
    $seen[$key] += [ordered]@{ source = $relativePath; role = $role }
    if (-not $conversationMessages.ContainsKey($conversation)) { $conversationMessages[$conversation] = @{} }
    $conversationMessages[$conversation][$id] = $role
}

foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $archive 'sources') -Recurse -Filter '*.json')) {
    if ($file.Name -notlike 'page-*.json' -and $file.Name -notlike 'browser-review*.json') { continue }
    $page = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
    $relative = $file.FullName.Substring($archive.Length + 1).Replace('\', '/')
    $conversation = $null
    $contentFound = $false
    if ($page.thread.id -and $page.turns) {
        $conversation = $page.thread.id
        foreach ($turn in $page.turns) {
            foreach ($item in $turn.items) {
                if ($item.type -notin @('userMessage', 'agentMessage')) { continue }
                Add-MessageEvidence $conversation $item.id $item.type $relative
                $contentFound = $true
            }
        }
        if ($contentFound) { $rawPages++ }
    }
    if ($page.messages) {
        $conversation = if ($page.conversationId) { $page.conversationId } else { $page.conversation_id }
        foreach ($message in $page.messages) {
            if ($null -eq $message.text) { continue }
            $ids = @($message.ids)
            if ($message.id) { $ids += $message.id }
            foreach ($id in ($ids | Where-Object { $_ } | Sort-Object -Unique)) {
                Add-MessageEvidence $conversation $id $message.role $relative
                $contentFound = $true
            }
        }
        if ($contentFound) { $browserCaptures++ }
    }
    if ($contentFound -and $conversation) {
        if (-not $sources.ContainsKey($conversation)) { $sources[$conversation] = @() }
        $sources[$conversation] += $relative
    }
}

$unique = @($submitted.links | Group-Object conversation_id, message_id | ForEach-Object { $_.Group[0] })
$rows = @($unique | ForEach-Object {
    $link = $_
    $key = $link.conversation_id + '/' + $link.message_id
    $found = $seen.ContainsKey($key)
    $hasSource = $sources.ContainsKey($link.conversation_id)
    [ordered]@{
        conversation_id = $link.conversation_id
        message_id = $link.message_id
        status = if ($found) { 'found' } elseif ($hasSource) { 'missing_from_partial_source' } else { 'no_chat_source' }
        submitted_urls = @($submitted.links | Where-Object { ($_.conversation_id + '/' + $_.message_id) -eq $key } | Select-Object -ExpandProperty url)
        evidence = if ($found) { @($seen[$key]) } else { @() }
        available_sources = if ($hasSource) { @($sources[$link.conversation_id]) } else { @() }
    }
})
$found = @($rows | Where-Object { $_.status -eq 'found' })
$withinSources = @($rows | Where-Object { $_.status -ne 'no_chat_source' })
$uniqueMessageIds = @($submitted.links.message_id | Sort-Object -Unique)
$conversationCounts = @($conversationMessages.Keys | Sort-Object | ForEach-Object {
    $id = $_
    $roles = @($conversationMessages[$id].Values)
    [ordered]@{
        conversation_id = $id
        unique_message_ids = $conversationMessages[$id].Count
        user_messages = @($roles | Where-Object { $_ -in @('user', 'userMessage') }).Count
        assistant_messages = @($roles | Where-Object { $_ -in @('assistant', 'agentMessage') }).Count
        sources = @($sources[$id])
    }
})
$result = [ordered]@{
    schema_version = 2
    checked_at = '2026-10-16'
    scope = 'Actual message IDs in saved reader page-*.json and content-bearing browser-review*.json. Browser access receipts without messages are not sources. Absence does not mean a message never existed.'
    identity_rule = 'Use conversation/message UUID pairs. Browser fallback turn keys and relative indices are not stable identities and cannot prove continuity or completeness.'
    submitted_link_count = $submitted.links.Count
    unique_conversation_message_pair_count = $unique.Count
    found_pair_count = $found.Count
    absent_pair_count = $rows.Count - $found.Count
    unique_message_id_string_count = $uniqueMessageIds.Count
    absent_message_id_string_count = $uniqueMessageIds.Count - @($found.message_id | Sort-Object -Unique).Count
    source_conversation_count = $sources.Keys.Count
    reader_page_count = $rawPages
    browser_capture_count = $browserCaptures
    unique_recovered_message_count = $seen.Keys.Count
    target_pairs_in_source_conversations = $withinSources.Count
    missing_target_pairs_in_source_conversations = @($withinSources | Where-Object { $_.status -ne 'found' }).Count
    conversations = $conversationCounts
    pairs = $rows
}
$utf8 = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText((Join-Path $PSScriptRoot 'submitted_target_audit.json'), ($result | ConvertTo-Json -Depth 15), $utf8)
$lines = @(
    '# Submitted target message coverage audit', '',
    'Checked 2026-10-16 against saved reader pages and actual DOM message captures. Browser-access receipts with no messages are excluded. Specific UUIDs, rather than relative browser turn indices, establish a match.', '',
    ('- Submitted links: **' + $result.submitted_link_count + '**.'),
    ('- Unique conversation/message pairs: **' + $result.unique_conversation_message_pair_count + '**; **' + $result.found_pair_count + ' found**, **' + $result.absent_pair_count + ' absent**.'),
    ('- Unique message ID strings ignoring conversation identity: **' + $result.unique_message_id_string_count + '**; **' + $result.absent_message_id_string_count + ' absent**. Repeated UUIDs across different conversation links are kept separate in the pair count.'),
    ('- Actual sources: **' + $result.source_conversation_count + ' conversations**, **' + $result.reader_page_count + ' reader pages**, **' + $result.browser_capture_count + ' browser captures**, **' + $result.unique_recovered_message_count + ' unique conversation/message IDs** after deduplication.'),
    ('- Within conversations with content sources: **' + $result.target_pairs_in_source_conversations + ' supplied pairs**, **' + $result.missing_target_pairs_in_source_conversations + ' absent**. Other targets have no saved conversation content.'), '',
    'A reported hasMore=false, empty missingTurnIndices array, or contiguous fallback-turn keys does not establish full coverage. Browser indices renumber when older messages prepend. The first Game Development Tools conversation has 22 distinct captured message IDs (11 user and 11 assistant) across its actual browser messages and original reader tail; that count does not arise from adding relative indices.', '',
    'Machine-readable detail: [submitted_target_audit.json](submitted_target_audit.json). Rebuild with [audit_submitted_targets.ps1](audit_submitted_targets.ps1). Original inventory: [submitted_links.json](../submitted_links.json).', '',
    '| Conversation | Supplied message | Result |', '|---|---|---|'
)
foreach ($row in $rows) {
    $status = switch ($row.status) { 'found' { 'Found in saved content' } 'missing_from_partial_source' { 'Missing from partial content' } default { 'No saved chat content' } }
    $lines += '| [' + $row.conversation_id + '](https://chatgpt.com/c/' + $row.conversation_id + ') | [' + $row.message_id + '](' + $row.submitted_urls[0] + ') | ' + $status + ' |'
}
$lines += @('', 'These are snapshot counts. Refresh after recovering more content. Missing messages remain gaps until their contents are read.')
[System.IO.File]::WriteAllText((Join-Path $PSScriptRoot 'submitted_target_audit.md'), ($lines -join [Environment]::NewLine), $utf8)
[pscustomobject]$result | Select-Object submitted_link_count, unique_conversation_message_pair_count, found_pair_count, absent_pair_count, source_conversation_count, reader_page_count, browser_capture_count, unique_recovered_message_count | ConvertTo-Json
