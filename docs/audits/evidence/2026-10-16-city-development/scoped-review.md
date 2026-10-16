# City development scoped review

Verdict: no open actionable P1/P2 findings in the final scoped implementation. Accepted feature evidence: 1,287 passing checks across eight clean suites. Remaining broader regression/import work and clean graphics-cache recapture are coordinator-owned and pending.

## Scope and behavior

Reviewed the 2026-10-16 plan plus subsequent Binding Echo/pending-continuation clarifications against CityDevelopment, development-only Global/SaveData hunks, Development and its menu/base/merchant entry points, Game Binding lifecycle, native player reach/size hunks, recorder/comparison flag, pacing probe, focused tests and preview. Unrelated dirty changes are excluded.

The implementation buys exactly one capped rank per Research, retains earlier choices, isolates active snapshots from profile purchases/retargeting, and awards genuine first city clears. Missing legacy snapshots add no bonuses; impossible active ranks are limited to profile purchases. Fresh bag capacity is seeded once; persisted capacity survives load. Transfusion excludes the free trained level. Pending defeat permits profile preparation while preserving the failed snapshot; acceptance snapshots the prepared next attempt.

Binding Echo persists its ordinary reward queue, consumption marker and deal sequence. Genuine S5 settlement controls the extra reward; duplicate callbacks cannot refill it. Game saves before closing, maintains one pause owner across both screens, rejects stale callbacks, separates popup lifetimes, and restores the prior pause. Developer entry consistently skips early Binding pause. The final deferred/coalesced layout refit and initial Close focus introduce no actionable P1/P2 issue.

## Addressed findings

- Impossible snapshot ranks: clamped to profile purchases while preserving a valid distinct prior training target.
- Unguarded Echo trigger: Research and the extra reward require genuine pending/current S5 settlement.
- [P2] Claimed marker prevented genuine S5 advancement: current S5 now advances while preserving an existing queue/table and grants no new Binding. Runtime recovery and ordinary cadence regressions pass.
- [P2] Mandatory early pause froze later developer segments: scenes/game.gd:60 excludes debug_dev_segment. The real developer-route regression passes.

## Accepted evidence

All listed logs are under `.godot/city-development-checks`; corresponding result records show exit 0 and empty diagnostics:

| Suite | Passing checks | Log prefix |
|---|---:|---|
| AugmentBinding | 64 | green |
| CityDevelopment | 351 | green |
| CityDevelopmentBindingUi | 25 | green |
| CityFarmingExperiments | 51 | first |
| AscensionRuntimeSafety | 21 | finalfeature |
| CityDevelopmentUi | 86 | finalfeature |
| CityDevelopmentPacingProbe | 159 | finalfeature |
| ScriptParseAudit | 530 | finalfeature |

The final UI run supersedes earlier selector-fixture failures. The popup fixture embeds its subwindow for the native input path; no speculative production selector change was made. Queue evidence covers actual cards, between-choice reload, stale callbacks, world/input freeze, prior pause restoration and production developer entry. Initial regressions and the S5/Game failures were observed before their fixes.

Visually inspected the final 1280x720 arrival and training captures, the actual 640x480 EXPAND arrival, and the 640x360 KEEP content bottom/Binding Echo capture. Text, purchase controls and Close fit their panels; lower options remain available by scrolling. `docs/art/reference/2026-10-16-city-development/capture-info.json` records 12 captures, actual window/content dimensions and zero bounds failures. Preview exits 0 with zero capture failures, but its log contains three GLES shader-cache initialization errors. These are explicitly excluded from the clean-suite claim; coordinator is isolating a fresh short APPDATA path for recapture.

## Limits

This reviewer launches no engine processes. Seven affected regressions, import validation and graphics recapture remain pending at this handoff. The separate PeeP overlay Prepare next attempt entry belongs to another chat and is not required for the reviewed MainMenu preparation route; exclude that unrelated work from this commit. Controlled stationary-crowd evidence establishes mechanics, not full city pacing or human enjoyment; the agreed human comparison remains outstanding.

## Coordinator closure

After this independent review, the coordinator completed all seven affected suites with exit0: CityContinuation92/0, SegmentCompletionPersistence38/0, AttemptReset18/0, SaveMigrationMatrix34/0 (expected future-version warning), AscensionCityPacing624/0, PauseMenuFlow38/0, ReliquaryCore87/0 after the lore-owned catalogue fixture correction. Shared import exited0with no diagnostics. Fresh short process-local APPDATA/LOCALAPPDATA renderer recapture exited0with no diagnostics,12captures and0bounds failures; normal arrival and smallest KEEP lower options re-inspected. Source unchanged; no further correctness fixes. This addendum records coordinator execution, not an additional independent engine run.
