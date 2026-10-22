# Full diagnostic bodies for the eight runtime_diagnostics suites (lead review item)

These are the full diagnostics, command, start time and elapsed time of each suite's final run. They are copied from the
queue's run-results and launcher records. The assertion footers were zero-failure, but the process classification was
`runtime_diagnostics`, not `completed`, so assertion success is not reported as a clean run. Contents:
- fixture warnings: `[ChunkManager] Player not found`, and SegmentProcStartupTest's unassigned-cover-scene error from
  its own fixture;
- exit-time ObjectDB/resource leaks in three native render suites;
- ScriptParseAuditTest's exit-time RID/ObjectDB leaks from loading every script.

None of these is newly introduced by phase 1 as far as this lane knows, but no baseline comparison was run.
