# Balance Recorder Correctness and Diagnostics Implementation Plan

> For agentic workers: implement this approved scope in tested stages with local commits. Use superpowers:executing-plans if available; otherwise follow the same sequence directly. No plugin installation or renewed approval of the idea is required. This document is a handoff for Claude, not evidence that these changes already exist.

**Goal:** Make the existing balance recorder trustworthy and able to explain which upgrades, effects, health costs and encounter conditions caused a run's outcome.

**Architecture:** Extend the existing runtime adapter, ledger and asynchronous writer. Add pure diagnostic snapshots, explicit health-change accounting, bounded damage attribution and a short incident history. Preserve current combat and progression behaviour throughout these instrumentation stages.

**Tech stack:** Godot 4.7.x, GDScript, local JSONL/JSON/Markdown/CSV artifacts, existing scene-based tests.

**Spec:** Sections 2-7 below define the additional requirements. Evidence and related work:

- [September 18 playtest addendum](../../audits/2026-09-18-gravemarch-playtest.md).
- [Existing item/set/economy/exit balance plan](2026-09-17-item-set-exit-balance.md), also supplied as a commented `.gd`.
- [Original recorder design](../specs/2026-09-16-core-balance-recorder-design.md).

**Inspected baseline:** `16a53a5671a6`, branch `feat/authoritative-enemy-world`. Recheck the current repository before implementation and preserve any newer work.

## 1. Execution order and constraints

1. Read the playtest addendum, then this file, then the existing balance plan.
2. Complete the correctness stages here before collecting a new balance baseline. Complete the diagnostic stages before the full before/after playtest comparison.
3. This extends and replaces overlapping recorder work in Task 1 and section 8 of the existing balance plan. Implement each feature once; do not create a second recorder or duplicate subscriptions.
4. Commit instrumentation separately from item, set, economy and encounter tuning so captures can identify which changes are active.

Global constraints:

- No Ascension redesign, item tuning, spawn tuning or changed effect costs in this document's implementation.
- Recording must not consume resources, advance RNG, modify cooldowns, change event ordering or alter combat outcomes.
- Follow README.md: never launch Godot, including headless, during a human playtest. Check for a running playtest before tests; do not stop the user's game.
- Preserve saves, unrelated changes, capture auto-start/stop behaviour, headless opt-in and explicit partial-session coverage.
- Keep existing raw captures unchanged. Missing historical fields mean unavailable, not zero.
- Use existing signals and authoritative resolution paths. Do not infer combat by scraping floating text, UI labels or scene names.
- Worker threads receive immutable, JSON-safe data, never live nodes or resources.
- No network services, database, dashboard, replay engine or automated balancing system.
- Make small verified local commits; do not push automatically.

## 2. Correctness: passive observation

### Confirmed problem

BalanceRecorder's snapshot calls `ManifestationRunner.get_damage_taken_multiplier()`. That calls `ManifestationState.consume_composure()`, spending the next-hit ward. Reliquary Guard's getter also arms a pending-hit latch. These are combat operations, not safe inspection methods.

### Required implementation

Add `get_balance_snapshot() -> Dictionary` to the relevant runners. Add `get_balance_snapshot() -> Dictionary` to ManifestationState for its resource state. Snapshot implementations must read fields or explicitly pure helpers; they must not call consuming getters as a shortcut.

For defence, distinguish stable damage multipliers from conditional protection:

- `passive_damage_taken_multiplier`: stable multiplier, if known.
- `composure_ready`: whether the next-hit reduction is banked.
- `conditional_guards`: entries with effect ID, readiness, remaining duration and resource count where available.
- Power/Haste multipliers may be included only through verified pure accessors.

Do not report a conditional one-hit guard as persistent 100% damage reduction. Leave unavailable values null and report coverage rather than invoking combat to discover them.

Audit every function reachable from the new snapshot API. Readiness checks must not reset a timer, arm a latch, spend a shard, generate a popup or draw random numbers. Paused and dead snapshots have the same restriction. Keep the existing consuming path for actual incoming hits.

## 3. Correctness: reconcile every health change

Keep existing combat/healing totals and add a separate health reconciliation ledger. Every actual HP mutation gets one canonical change record at the mutation owner, including direct assignments outside player.gd.

Proposed new event contract in `autoload/RunEvents.gd`:

```gdscript
signal balance_health_changed(player: Node, change: Dictionary)
```

The runtime adapter stamps capture sequence, player-life ID, gameplay seconds and wall elapsed seconds. The change dictionary contains:

```gdscript
{
    "category": "cost", # hit, heal, cost, adjustment, respawn, rescue
    "source_id": "manifestation_pair:death_rattle",
    "hp_before": 50.0,
    "hp_after": 37.0,
    "max_hp_before": 340.0,
    "max_hp_after": 340.0,
    "requested": 13.0,
    "reason": "held_beat"
}
```

`hp_after - hp_before` is authoritative. Emit after the assignment and before callbacks can cause a different mutation; guard against recording the same mutation twice. Initialization starts a new life baseline, not fake healing. Max-HP changes include their actual HP delta, even when that is zero.

Extend `BalanceLedger` with `record_health_change(change: Dictionary) -> void`. It updates reconciliation and incident history, not the existing hit/healing counters a second time. Existing resolved-damage/heal signals continue supplying their established metrics. Intentional costs must also reach the existing paid-health accounting once.

Required health coverage:

- Ordinary and intercepted damage, applied healing, blocked healing and overflow.
- Death Rattle payments with a stable source ID.
- Scar Tissue and Slow Heart healing takebacks, separately from enemy damage; later returned health is separately sourced healing.
- Maximum-HP changes, full-health preservation and clamping during stat refresh.
- Reconstruction and rescue restores; actual death transitions.
- Developer health changes labelled as adjustments, with their reason.

Preserve Death Rattle's present behaviour. A blind replacement with `player.pay_health()` changes semantics: that helper also checks god mode and pauses melee regeneration, whereas the current pair directly subtracts HP. Share reporting or extract a helper only after testing those differences; retain the current nonlethal floor, payment timing, callbacks and display behaviour.

Reconcile each life using initial HP plus the signed canonical changes. Compare the expected result to sampled HP; show a residual and missing-coverage count when they differ. Never invent a balancing adjustment to force equality. Use a float tolerance of `max(0.001, 0.00001 * max_hp)`.

## 4. Damage attribution

Answer both questions independently:

- What directly dealt this damage? Basic attack, ability, set effect, item, Manifestation, augment or status.
- What initiated the chain? For example, BLINK remained the origin of a later generated strike.

Create `core/systems/telemetry/BalanceAttribution.gd` with `from_payload(payload: Variant) -> Dictionary`. Normalize existing AscensionTags and add telemetry-only provenance where paths currently omit it. Preserve gameplay tags, proc power, ownership and trigger eligibility.

Provenance fields: `origin_id`, `emitter_id`, `family`, `style`, `generation`, and `cast_id` when known. IDs use authored identifiers, for example `ascension:MOV`, `set:gravemarch:6`, `item:acc_firestone`, `status:burn`; absence is explicitly `unknown`.

Requirements:

- Aggregate actual HP removed, overkill, resolved hit/tick counts and kills at authoritative enemy resolution. Do not add emitted damage that never hit a target.
- Preserve ancestry through generated attacks, pooled projectiles, status ticks and proxy/full enemy representation changes. Clear stale provenance on pool reuse.
- Do not attach every descendant to the player's basic attack merely because the player owns its source node.
- Root and immediate-source tables are alternate groupings of the same damage. Never add the tables together.
- Each grouping, including unknown/mixed rows, must sum to the authoritative HP-removed total within float tolerance.
- HitLedger can combine hits. Do not assign a mixed batch entirely to its last projectile's tags. Preserve a compact contribution breakdown where exact attribution is possible; otherwise use `mixed` and report that coverage gap. Do not change combat batching, armour application or proc order to improve telemetry.
- Credit kills once. A mixed lethal batch remains mixed unless its actual killing contribution is known. Damage assistance is not an extra kill.
- Count casts/activations separately from descendants where the cast boundary is observable. Do not equate pellets or ticks with ability uses.
- Cap aggregate source keys at 512 per table; retain overflow under `other` with an overflow count. Per-cast IDs belong only to bounded recent context, not an unbounded whole-run map.

## 5. Last-seconds incident history

Create `core/systems/telemetry/BalanceRecentHistory.gd`, a RefCounted bounded buffer:

```gdscript
func push_event(record: Dictionary) -> void
func push_sample(sample: Dictionary) -> void
func snapshot(now_gameplay_seconds: float) -> Dictionary
func reset() -> void
```

Retain five gameplay seconds, with at most 2,048 compact events and 32 state samples. Sample cheap state at 5 Hz during live gameplay; keep build details by build index instead of repeatedly copying inventories. Pauses must not age out the last fight. Track wall time separately.

Events cover incoming resolved attacks, healing, health costs/adjustments, ability activations when available, guard consumption, healing locks and life transitions. Repeated identical healing events may be coalesced within a simulation step if exact totals and ordering around damage are preserved.

State covers HP/max HP, armour, position, dash/protection availability, nearby counts by archetype, pressure components, exit/channel progress and time since reconstruction. Use existing cached enemy counts or bounded queries; do not scan every enemy for every damage event.

On death, persist `death_context` through the existing writer with:

- The exact terminal damage/cost event, including source, raw/adjusted/applied amounts, pre-hit HP and outcome when available. A one-second sample is not the terminal hit.
- The chronological recent history and latest pure state/build references.
- Segment phase, exit state, life ID, reconstruction age, health reconciliation residual and history coverage.

Also expose `BalanceRecorder.capture_incident(reason: StringName) -> void` for the existing developer console/test path; no new UI is required. Persist incidents only on death or explicit capture, not every normal tick.

Freeze the old life's context before reconstruction or scene cleanup. A new life resets its buffer after the death context is queued. Both the event and sample limits apply independently; if dense activity truncates the five-second history, report retained duration and overwritten counts. Snapshot copies passed to the worker must not change as the live ring advances.

## 6. Exit and pressure explanation

Add events at the current ExitRite, ThreatDirector, spawner and EncounterDirector owners. This instrumentation works before the proposed new exit controller exists. When that controller is implemented, connect it to the same event contract.

Capture:

- Exit unlock/reveal, distance to exit, first approach, actual channel entry/leave, progress and required hold.
- Progress changes with reasons: channel, lapse, death retention, recovery protection, completion. Record exactly what exists in the current version; future controller fields remain unavailable until implemented.
- Nearby enemies and living/pending exit reinforcements by type, using stable handles so representation changes cannot double-count them.
- Spawn requests accepted/rejected and their reason, with ambient/exit/world-source origin. Aggregate repeated rejects into windows.
- Overtime's time and kill components, dominance modifier, external pressure injections and final capped HP/damage values.
- For Overtime Gospel, tag the injecting item slot/instance and extra seconds. Two equipped copies are separate contributors. Report injected clock time and final overtime separately, without adding the injection twice.
- Reconstruction anchor, protection duration and time back to channel when observable.

Derived report fields: unlock-to-first-channel time, channel attempts, progress lost by cause, completion/failure/unfinished status, deaths within ten gameplay seconds of reconstruction, and reconstruction spending relative to combat income. Define an attempt as actual entry through exit/completion/death; proximity alone is not an attempt.

Never infer a source of pressure merely from a sudden total increase if the contribution event is missing. Spawn suppression and recorded pressure must describe actual runtime behaviour, not the proposed balance plan.

## 7. Upgrade effort and benefit

Emit events after successful item operations, with an operation ID and source context. Distinguish offered, generated/dropped, acquired, merged, equipped, sold, discarded and undo; an item displayed in a shop is not an acquisition.

Record item ID, capture-local instance ID, slot/container, polarity, roll, rank and meter before/after, consumed item ranks/meters/quality, merge mass, and before/after flat contributions. Capture-local IDs must survive moves and remain associated with the destination through merge; they need not alter the save format.

At equipped upgrades, link before/after player stat snapshots and active set mean rank. Evaluate hypothetical item comparisons through pure stat/profile helpers, never by temporarily equipping an item or invoking combat. A stat change is not measured DPS.

For shops, record item-level purchase/sale values inside the existing transaction, alongside its total actual wallet delta. Keep refunds and undo tied to the original operation. Do not count an undone purchase twice toward upgrade pace.

Aggregate compatible drop counts by item ID, polarity and rank gap; record detailed discrete acquisitions/merges. Avoid persisting every nearby pickup every frame. Include auto-feeds into equipment, bag and stash, not only manual UI merges.

Report gameplay time between equipped rank increases, partial progress, compatible material value, organic combat income per minute and shop cost expressed in those earnings. When there is no observed combat income, the time-to-afford value is unavailable, not zero. Explicitly distinguish prepared fixtures and debug grants from earned progression.

## 8. Metadata, output and performance

- Advance capture `schema_version` from 1 to 2 for these contracts. Keep `recorder_revision`, `balance_revision`, enabled tuning stages and tuning hash separate. Recorder-only changes must not claim item-balance revision 2.
- Include feature coverage flags for pure snapshots, health reconciliation, source attribution, incidents, exit detail and progression. An omitted feature cannot appear as a measured zero.
- Keep current filenames. Add concise sections to `report.md`, corresponding machine-readable fields to `summary.json`, and only stable summary columns to `segments.csv`. Incident payloads stay in `events.jsonl`.
- Report attribution coverage, health residuals, truncated incident history, dropped records, write failures and artifact completeness. Preserve existing wallet reconciliation.
- Keep counter aggregation and the asynchronous queue. No synchronous per-hit writes or whole-scene snapshot per hit. Reuse compact records/storage where practical.
- Maintain bounded queue and incident storage by count and serialized size. Set an initial 2 MiB incident payload ceiling; on overflow trim oldest context while preserving terminal event/latest state and record the omission. Never discard exact aggregate totals to satisfy a history cap.
- Compare recorder disabled, current core recorder and the extended recorder on the same deterministic workload. Report recorder callback and frame-time p50/p95/p99, memory trend, queued bytes and output size. A single maximum callback duration is insufficient evidence of performance.

## 9. Implementation stages and verification

New test scripts use the existing `_check` scene-runner pattern and have matching `.tscn` files. The interfaces below are proposed additions, not existing methods to assume callable today.

### Stage 1: Pure snapshots

**Modify:** `autoload/BalanceRecorder.gd`, `core/systems/manifestations/ManifestationRunner.gd`, `ManifestationState.gd`, `effects/manifestations/pairs/ReliquaryGuard.gd`, and pure diagnostic accessors in `core/systems/items/ItemEffectRunner.gd` / `core/systems/ascension/AscensionRunner.gd` as needed.

**Create tests:** `tools/tests/BalanceSnapshotPurityTest.gd` and `.tscn`.

- [ ] Build a real player fixture with ward, one ready Composure guard and a shard. Capture readiness, shard count, guard latch, cooldowns, HP and gameplay RNG state.
- [ ] Fail the current implementation by requesting 100 recorder snapshots. Assert every recorded field of gameplay state and RNG is unchanged, including paused/dead cases.
- [ ] Implement `get_balance_snapshot()` and replace unsafe calls. Resolve one actual landed hit afterwards: the appropriate guard is consumed once, and repeated diagnostic calls still consume nothing.
- [ ] Run the new test, BalanceRecorderTest and ManifestationPairBehaviourTest; commit `fix(telemetry): make balance snapshots observational`.

### Stage 2: Health accounting and source labels

**Modify:** `autoload/RunEvents.gd`, `autoload/BalanceRecorder.gd`, `core/systems/telemetry/BalanceLedger.gd`, `BalanceCaptureWriter.gd`, `core/actors/player/player.gd`, `effects/manifestations/pairs/DeathRattle.gd`, `effects/manifestations/logic/ScarTissue.gd`, `effects/items/logic/curses/SlowHeartCurse.gd`, `effects/items/logic/RegenerationRingEffect.gd`.

**Create tests:** `tools/tests/BalanceHealthAccountingTest.gd` and `.tscn`.

- [ ] Test an opening HP of 100, a 30 HP hit, 10 applied healing and a 5 HP payment: final HP and reconciled HP are both 75; hit loss is 30, healing 10 and paid HP 5, each counted once.
- [ ] Test real Death Rattle payments at low HP, including its 1 HP floor and existing regeneration/god-mode semantics. Confirm no evasion roll, damage proc or duplicate popup is introduced by instrumentation.
- [ ] Test healing followed by a takeback: 20 healing then a 15 adjustment leaves net +5 HP while retaining both events. Test max-HP clamp 100 -> 70 records an adjustment of -30, not enemy damage.
- [ ] Implement the canonical health event and reconciliation ledger. Source ring healing as `item:ring_regeneration`; retain generic/unknown for genuinely uninstrumented sources.
- [ ] Add schema/revision/coverage metadata and legacy-unavailable handling. Run BalanceLedgerTest, BalanceRecorderOutcomeTest and the new suite; commit `fix(telemetry): account for health costs and adjustments`.

### Stage 3: Outgoing attribution

**Create:** `core/systems/telemetry/BalanceAttribution.gd`; `tools/tests/BalanceAttributionTest.gd` and `.tscn`.

**Modify:** recorder/ledger/writer; `core/combat/hits/HitLedger.gd`, `HitProfileAdapter.gd`, `core/systems/enemy_world/EnemyCombatService.gd`, `core/combat/projectile/ProjectileSimulationManager.gd`, and the existing set/item/status emitters that currently lack provenance. Consume the existing `core/systems/ascension/AscensionTags.gd` contract without changing its gameplay meaning.

- [ ] Test a 100 HP target receiving 30 basic damage then a 100 damage BLINK-rooted strike: basic removes 30, BLINK removes 70 with 30 overkill; HP removed sums to 100 and kills to one.
- [ ] Test a BLINK descendant retains its root while changing emitter, and a pooled projectile reused for a different attack does not inherit BLINK. Test mixed-source same-frame hits and proxy promotion.
- [ ] Add normalization and propagation; aggregate source tables in the existing ledger. Unknown/mixed events remain visible and count toward totals.
- [ ] Run attribution and existing projectile/enemy-world lifecycle suites; commit `feat(telemetry): attribute damage to abilities and effects`.

### Stage 4: Incident history

**Create:** `core/systems/telemetry/BalanceRecentHistory.gd`; `tools/tests/BalanceIncidentHistoryTest.gd` and `.tscn`.

**Modify:** recorder, ledger and writer; player resolution context at existing events, without changing established subscriber signatures unexpectedly.

- [ ] With an injected gameplay clock, push events through seconds 0..10. At time 10 only seconds 5..10 remain, subject to the caps. Pause and verify that gameplay history does not expire.
- [ ] Overfill 2,048 events and 32 samples; assert bounded storage and explicit lost-context counts. Test the serialized incident byte ceiling and immutable queued snapshots.
- [ ] Cause a known lethal hit between periodic samples. Assert exact terminal source/amount, prior costs/heals, old life ID and death context survive immediate reconstruction and capture shutdown.
- [ ] Implement the buffer and `capture_incident(reason)`. Run the new suite plus BalanceCaptureWriterTest and BalanceRecorderOutcomeTest; commit `feat(telemetry): preserve bounded death context`.

### Stage 5: Exit diagnostics

**Modify:** `core/systems/world/ExitRite.gd`, `autoload/ThreatDirector.gd`, `core/systems/spawner/spawner.gd`, `core/systems/encounters/EncounterDirector.gd`, `EncounterBeats.gd`, `effects/manifestations/logic/OvertimeGospel.gd`, recorder/ledger/writer.

**Create tests:** `tools/tests/BalanceExitDiagnosticsTest.gd` and `.tscn`.

- [ ] Test a channel entry, interruption, re-entry, death with retained progress, and eventual completion. Verify attempt counts, progress-loss reasons and completion status against actual ExitRite state.
- [ ] Inject 20 and 25 extra overtime seconds from two Gospel instances: contributors sum to 45 extra clock seconds, and the final pressure remains exactly equal to the pre-instrumentation calculation.
- [ ] Test pending spawn reservation, rejection, placement failure and proxy promotion; telemetry must match actual counts without creating new reservations.
- [ ] Implement observation hooks and reports. Run the new test, ExitRiteTest and ThreatDirectorPressureTest; commit `feat(telemetry): explain exit pressure and recovery`.

### Stage 6: Upgrade diagnostics

**Modify:** `data/items/ItemInstance.gd`, `Inventory.gd`, `BagInventory.gd`, `StashInventory.gd`, `core/systems/inventory/WorldDropSpawner.gd`, `core/actors/enemy/modules/EnemyDrops.gd`, `ui/screens/HubShop.gd`, relevant transaction hooks in `autoload/global.gd`, recorder/ledger/writer.

**Create tests:** `tools/tests/BalanceUpgradeDiagnosticsTest.gd` and `.tscn`.

- [ ] Test one compatible auto-feed that increases only fractional meter: record it once with correct before/after values. Repeat for manual merges, bag/stash feeds and a higher-rank incoming swap.
- [ ] Test a shop offer without purchase, a completed purchase, and undo. Only the completed, non-undone acquisition contributes to net acquisition counts; actual wallet totals still reconcile.
- [ ] Assert instrumentation never rerolls, changes destination Manifestation, changes locks, consumes an extra item or updates equipped stats by applying a preview.
- [ ] Implement capture-local identities, source contexts and reports. Run the new suite, AuditClosureTest, SaveIntegrityTest and existing wallet tests; commit `feat(telemetry): measure upgrade effort and benefit`.

### Stage 7: Regression, load and handoff

**Modify:** `tools/tests/BalanceRecorderLoadTest.gd`, existing writer/outcome tests and recorder documentation. Update `docs/audits/2026-09-18-gravemarch-playtest.md` only by appending implementation/validation status; preserve the original evidence.

- [ ] Run identical seeded scripted actions with recording disabled and enabled; compare HP, damage outcomes, inventory, wallet, cooldowns, RNG and enemy state. Exclude wall-clock performance from deterministic state equality.
- [ ] Exercise high-rate healing/hits, repeated deaths, full queues, write failures, shutdown, scene changes and save resume. Inspect bounded memory and loss reporting.
- [ ] Load schema-1 captures without claiming the new fields were measured. Verify schema-2 artifacts round-trip and all totals reconcile.
- [ ] Run the relevant suites above, then ScriptParseAuditTest last, respecting the human-playtest restriction. Inspect reported failure counts, not just process exit codes.
- [ ] Record performance comparisons and remaining attribution/health coverage gaps; commit `test(telemetry): verify diagnostic coverage and recording cost`.

Windows test command shape, after resolving the available Godot executable and confirming no human playtest:

```powershell
& $godotPath --headless --path . --import
& $godotPath --headless --path . 'res://tools/tests/BalanceSnapshotPurityTest.tscn' --quit-after 3000
```

Use the corresponding concrete scene name for each suite. New scripts need the import step. No engine validation is required merely to read or hand off this document.

## 10. Done means

- Recording is passive, and the real ward/death-cost regressions have automated coverage.
- Damage tables reconcile and distinguish origins from immediate effects, with unknown coverage visible.
- A death report explains exact lethal context, recent healing/costs and any truncated history.
- Exit and progression reports answer the questions in sections 6-7 without changing those systems.
- Old captures remain readable; new captures declare their recorder and balance revisions separately.
- Runtime and storage remain bounded, with measured performance and explicit failure reporting.

Claude's final report should list commits, tests, known coverage gaps, recording overhead and any unperformed human playtests. Continue the existing balance plan using this improved baseline; do not claim the September 18 capture itself has become complete retroactively.
