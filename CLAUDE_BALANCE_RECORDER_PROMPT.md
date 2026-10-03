# Claude handoff prompt

You are working on Synthetic Ascension, a Godot 4.7 GDScript horde-survivor
roguelite. Review and harden its existing core Balance Recorder so recorded
gameplay can support economy, player/enemy HP, damage-scaling and pacing decisions.

The idea and core scope are already approved. Do not restart brainstorming or
ask for approval of the concept. Inspect the current repository and existing
implementation first; do not build a second recorder. Preserve unrelated work,
keep changes focused, and make clear local commits. Do not push automatically.

## Read first

- `README.md` and applicable `AGENTS.md` instructions.
- `docs/BALANCE_RECORDER.md` — current operation, schema meanings and limitations.
- `docs/superpowers/specs/2026-09-16-core-balance-recorder-design.md` — core scope.
- `docs/superpowers/plans/2026-09-16-core-balance-recorder.md` — implementation and verification record.
- `docs/design/balance recorder thoughts.md` — broader long-term goals; these
  are not all requirements for this core version.

## Existing implementation

- `autoload/BalanceRecorder.gd`: automatic capture lifecycle, runtime events,
  player/build/Threat snapshots and bounded background writes.
- `core/systems/telemetry/BalanceLedger.gd`: exact totals, segment accounting,
  enemy cohorts, gameplay clocks and bounded history.
- `core/systems/telemetry/BalanceCaptureWriter.gd`: JSONL events, JSON summary,
  Markdown report and CSV segment export.
- `core/systems/telemetry/BuildInfo.gd`: version, commit, branch and seed,
  including linked Git worktrees.
- Observational hooks in `RunEvents`, `Global`, the player, `EnemyWorld`, and
  the game scene. Existing gameplay hooks retain their semantics.

## What must be trustworthy

1. Economy: actual gains/losses by reason; gross purchases AND sales inside a
   combined trade, including zero-net exchanges; opening/closing wallet per
   segment. Refunds, trade undo and save synchronization must not inflate earned
   income. Preserve large integers exactly and flag unexplained discontinuities.
2. Combat: distinguish post-defense damage, actual HP removed and overkill.
   Keep intentional HP costs, healing, overflow, healing locks, deaths,
   reconstructions and rescues separate. Prevent double-counted or stale-handle kills.
3. Scaling: current player stats and their contributions; equipment, augments,
   Ascension choices and temporary multipliers; enemy archetype, elite status
   and HP after deferred elite/boss configuration; Threat and density context.
4. Time: gameplay, pause, hub and loading time stay separate. Enemy time-to-kill
   starts at its first observed damaging hit, not spawn. Label rate denominators.
5. Lifecycle: retain failed/incomplete sessions; close before save/reset mutations;
   preserve hub spending. Resumed sessions have separate capture IDs linked by
   run key, without claiming the recorder observed missing history.
6. Reliability: bounded buffers, aggregation for frequent combat events,
   background file writing, visible dropped-history/write-failure indicators,
   and correct finalization even if only some report files can be written.

Captures are local and Git-ignored. The recorder must not change gameplay balance,
consume gameplay RNG, alter saves or upload data. Detailed ability/chain ancestry,
every loot/shop offer, automated players and dashboards are future scope.

## Your task

Inspect git status/log and review the implementation against these requirements.
Identify concrete gaps or bugs with file/line evidence. Reproduce important bugs
with focused tests, fix them, and verify compatibility. Avoid speculative
refactoring and tests that merely repeat implementation details. Do not change
economy prices, combat formulas or difficulty to make measurements look better.

Run the relevant recorder, combat, healing, save and build-identity suites, then
`ScriptParseAuditTest` last. Confirm actual exit codes and assertion summaries;
distinguish deliberate failure fixtures from unexpected diagnostics. Never run
Godot, even headless, during a human playtest; an idle editor alone is different.

Baseline: 11 functional suites passed 299 checks; the parse audit checked 395
scripts but emitted resource-leak diagnostics at shutdown. The recorder load
test retained exact totals for 100,000 hits and preserved 40 transactions under
slow disk writing. Reverify claims against your checkout.

Deliver a concise summary of verified behavior, fixes, tests, remaining
limitations and commit IDs. Explain where the user finds a capture and which
file to open first. If the core already meets its requirements, say so with
evidence rather than inventing more implementation work.
