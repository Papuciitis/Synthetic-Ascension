# Core balance recorder

The recorder starts automatically when you enter gameplay and continues through
the hub. Play normally; no console command or overlay is needed. Returning to
menus, loading another save, starting a new attempt, ending a run, or closing the
application finalizes the current capture. Editor Stop / process termination
can bypass shutdown; periodic output remains available.

## Find a capture

- Running from the project: `balance_captures/YYYY-MM-DD/<capture-id>/`.
- Exported game: `user://balance_captures/YYYY-MM-DD/<capture-id>/` (Godot's
  application user-data directory).
- The Output panel prints `[BalanceRecorder] Recording to ...` with the full
  directory. Capture files are ignored by Git; commit code, share selected
  captures separately.

Each directory contains:

| File | Use |
|---|---|
| `report.md` | Read the economy, combat, survival, and enemy-scaling summary. |
| `segments.csv` | Compare segment totals in a spreadsheet. |
| `summary.json` | Read full totals, per-segment breakdowns and recording health. |
| `events.jsonl` | One JSON object per line: time windows, wallet transactions, builds, pressure and lifecycle. |

Reports are refreshed every 15 simulation seconds and at boundaries. History
batches are submitted once per simulation second. Disk writes run on a worker.
The recorder holds at most two submitted batches and 8,192 pending history
records. If disk cannot keep up, exact ledger totals continue; skipped history
is counted in `dropped_records`, and sequence gaps locate missing detail. File
errors appear as `[BalanceRecorder] Capture incomplete` warnings and in
`writer_failures` / `last_error` when a summary can be saved. `artifacts_complete`
is false if the current report batch only partially succeeded; `summary.json`
is the authority for that status. An `outcome`
of `recording` means the final boundary has not been saved, not a completed run.

## Interpret the numbers

- `schema_version` 2 captures carry `metadata.recorder_revision` (the
  recorder's contract), `metadata.balance_revision` (the item/encounter tuning
  state, 1 until the balance plan's profiles are active), `tuning_stages`,
  `tuning_hash` and `metadata.features`: which measurements this recorder
  makes. A feature that is false (or a field absent from an older capture)
  means unavailable, never a measured zero.
- Health reconciliation (`summary.health`): every actual HP change is recorded
  once at its owner as a canonical change (`RunEvents.balance_health_changed`),
  by category (`hit`, `heal`, `cost`, `adjustment`, `rescue`, `respawn`) and
  source. Each life starts at the observed HP (capture start or reconstruction,
  never counted as healing), sums the signed changes, and compares the result
  with the sampled HP once per second. `unexplained_checks` and
  `unexplained_hp_delta` say how often and by how much a sampled HP disagreed
  with the records; the expectation resyncs to the sample so each gap is
  measured once, and nothing is ever invented to balance it. Costs (tree
  payments, Death Rattle's held beat) are the single source of `hp_paid`.
  Healing takebacks (Scar Tissue, Slow Heart) are adjustments attributed to
  their rule, never enemy damage; Slow Heart's release and the Regeneration
  Ring heal under `item:curse_slow_heart` / `item:ring_regeneration`. Stat
  refreshes that move maximum HP, preserve full health or clamp are
  adjustments from `player:stats`. Hits and heals are aggregated per second
  in the `metrics` window (`health_changes`); costs, adjustments, rescues and
  reconstruction are discrete `health_change` events.

- A capture represents an **observed session**, not necessarily an entire
  attempt. Resuming produces a new capture ID. `metadata.run_key` combines save
  slot and world seed to link sessions. It does not prove an uninterrupted
  timeline or allow double-counting replayed progress after save reloads.
- `seconds_gameplay` is simulation time with a living player outside pauses and
  the hub. It includes travel. `seconds_paused`, `seconds_hub`, and
  `seconds_loading` are separate; `segments.csv` carries all four. `wall_seconds`
  is actual elapsed time. Simulation time follows `Engine.time_scale`, so
  hitstop and world-time slows (Deadshot, JUDGEMENT) shorten gameplay seconds
  relative to the wall clock; the per-second sample records the current scale.
  `Engine.time_scale`, debug modifiers, version, commit, race, style and loadout
  accompany captures; compare like-for-like sessions.
- Enemy HP removed is clamped to remaining health. Enemy overkill is
  post-defense damage minus actual HP removed. The directly player-credited
  subtotal requires the damage source to be the current player; other/unknown
  sources still contribute to total enemy HP removed. Legacy actors that bypass
  the authoritative EnemyWorld damage event are outside damage coverage.
- Player raw incoming damage, post-defense damage, HP actually lost, overkill,
  evasion/invulnerability counts, intentional HP spending, healing, overflow,
  healing locks, deaths, rescues and reconstruction are separate. Reconstruction
  and changes to maximum HP are not counted as healing. Contact damage is a
  combined swarm source; other incoming hits use their immediate source (the
  actor's spec id, or the archetype of the EnemyWorld handle it is bound to).
  Two outcomes come from advancement-tree rules: a lethal hit that a rule
  intercepted (the player is left at 1 HP) counts the HP it removed under
  `player_hp_lost`, its excess under `player_overkill`, and once under
  `intercepted_hits`; a swing a rule made miss counts under `missed_hits` like
  an evasion. Damage a rule inflicts on the player (Danger Close, a No Brakes
  skid) is a hit from the source `self_damage`; intentional payments stay
  under `hp_paid`.
- Damage attribution (`totals.attribution`, `attribution_coverage`): every
  enemy hit is grouped twice over the same HP removed, by origin (what
  initiated the chain: `native:melee`, `ascension:MOV` for a BLINK strike and
  every descendant it generated, `status:burn`, `set:gravemarch:6`,
  `augment:tesla_aura`, `manifestation:<rule>`) and by immediate source (the
  payload that landed: `ascension:MOV3:afterimage`, `set:gravemarch:6:mass_arrest`).
  Never add the two tables. Provenance comes from the payload only: the tree's
  tags, or a telemetry-only object the set, augment, Manifestation, status and
  legacy-bullet emitters attach; a payload with none is `unknown` even when
  the player owns the node, and a same-frame batch of unlike projectiles is
  `mixed` with its raw damage breakdown. Kills are credited once to the hit
  that emptied the bar. `casts` counts a cast id the first time it is seen,
  never its pellets or ticks. Tables cap at 512 keys (overflow to `other`).
  Not attributed by this revision: a Manifestation echo that re-fires the
  player's native attack (it lands as native), spells, and the Manifestation
  rules that damage through their own projectiles rather than the shared
  helpers; those show as native or unknown, never as a guessed source.
- Enemy HP is observed at registration or capture entry and refreshed when
  elite promotion or boss configuration changes it. Time-to-kill starts
  at the first observed damaging hit and ends at defeat, excluding pause/hub
  time. Means include only defeated enemies with an observed hit; unfinished
  enemies are not zero-second kills. Elite archetypes have separate rows.
- Wallet opening + earnings - spending + adjustments + debug grants equals
  closing. `wallet_discontinuities` flags unobserved/mismatched changes.
  Refunds, undo, and system synchronization are adjustments; developer
  funding (`dev_grant`, `developer_grant`: the overlay's route loader and
  grants) is `followers_debug`, never earned income; both keep their
  operations in the reason ledger. Buy/sell exchanges use their gross values, including even
  exchanges. Undo stays an explicit adjustment, so operation totals still show
  purchases that were subsequently reversed. Decimal strings preserve integers
  beyond JSON's reliable numeric range (2^53 - 1), including seeds and Followers.
- Full build snapshots contain equipment rolls, rarity, polarity,
  Manifestations, augments and levels, Ascension ownership/equipped state,
  Doctrine rules, final player stats and the existing stat contribution ledger.
  Changes within one frame are coalesced. Hub loadouts are checked each second;
  player stats are unavailable until gameplay resumes. HP and current Threat
  pressure are sampled once per second.
- Samples are observation only. Each runner reports through a pure
  `get_balance_snapshot()` (the `effects` key of a sample): stable multipliers,
  `composure_ready`, and `conditional_guards` (Reliquary Guard, Red Line,
  Composure, Bastion's Plate / Last Hit / Guard) with their readiness and
  resources. A one-hit guard is never reported as a persistent multiplier.
  The runners' `get_*_multiplier()` getters are combat operations (the
  Manifestation one spends Composure, Reliquary Guard's arms its latch) and a
  sample never calls them; an effect with a multiplier that has not opted into
  the pure report is listed under `unreported`, never assumed to be 1.0.
  Captures written before this change carry the old `effect_multipliers` key,
  whose values were taken through the consuming getters.

## Upgrade effort and benefit

Item operations are reported by their owners after they succeed, inside an
operation scope (`BalanceItemContext`) that the caller opens: a pickup
(`ground`, `drop`, `world_drop`, `exploration`), a player move through the
router, a trade or its undo in the hub shop, a guaranteed reward, or a
developer grant (`debug`). Every report carries the scope's operation id and
source, so "remove from bag, place in equipment, merge" is one operation.
The reports are:

- `merged` from `ItemInstance.merge_from`, the one real merge path (feeds,
  bag and equipment merges, consolidation): destination rank, meter, roll,
  progress and flat contributions before and after, the consumed material's
  rank, meter and quality before the auto-swap, the merge mass, whether the
  rank swapped to the destination and whether it ranked up, and the container
  and slot the destination lives in.
- `equipped`/`unequipped`, `bagged`/`unbagged`, `stashed`/`unstashed` from the
  containers, `dropped_to_world` from the router, `purchased`/`sold` with the
  item's own value from the shop, and `undo` naming the trade it reverses.
- `item_generated` from `ItemGenerator` with the drop context: a vendor item
  is an offer, never an acquisition; other sources are drops, aggregated by
  item id, polarity and rank gap when an equipped copy could absorb them.

Each item gets a capture-local id (never saved) that survives moves and
merges, since the destination object survives a merge. Equipment operations
link to the player's stat snapshot and active set mean ranks before, and an
`upgrade_effect` record after the next stat recompute. Comparisons use the
instances' own flat contributions; nothing is previewed by equipping. The
shop's item-level values ride inside the existing `trade` transaction with
the operation id, and the undo's `trade_undo` transaction names the trade.

The ledger derives, per segment and overall: drops and offers, compatible
drops with their value, acquisitions by source (a player move is never one),
purchases and sales with values and the undone counts (an undone purchase is
not counted twice; `net_purchases` is what remains), merges by container, the
mass and meter gained on equipped items, rank-ups on equipped items with the
gameplay time between them, organic income per minute (excluding trades,
undo, vendor refreshes, reconstruction, adjustments and debug grants) and the
mean purchase expressed in minutes of that income, which is unavailable, not
zero, when nothing organic was earned. Debug grants are listed apart.

## Exit and pressure

The owners of the exit and pressure state report what they did, through
telemetry-only signals nothing may react to:

- `ExitRite` reports unlock/lock and reveal, rejections (a locked rite's
  backlash), actual channel entry and leave, a lapse past the grace as one
  started/ended pair with the hold it drained, death retention as a
  `progress_lost` event with the exact hold lost, seals, waves (with the
  spawn count requested), the last-chance vault, safeguards granted, used and
  drained, and completion. Its pure `balance_snapshot()` (hold, progress,
  lapse, seals, waves, safeguards, floor) rides every 1 Hz sample and every 5
  Hz incident sample.
- `ThreatDirector.balance_snapshot()` reports the pressure components with
  the same terms the director uses: elapsed and injected unseal seconds
  (separately, summing to the clock it uses), kills since unseal and the
  excess past the buffer, the time and kill parts of Overtime, dominance, the
  final HP/damage/speed/spawn/elite values and whether a cap or the power
  contrast hold is binding. `add_overtime_pressure(seconds, contributor)`
  emits one `overtime_pressure_injected` per injection; Overtime Gospel tags
  its slot and item instance, so two equipped copies are two contributors.
  The injection changes nothing: the final Overtime is exactly the
  pre-instrumentation calculation.
- The spawner reports every resolved request (`spawn_request_resolved`) by
  source (ambient, burst, burst_at, beat, interior, authored, forced) and
  outcome: `spawned` with the count, or the gate that refused it as the
  spawner itself decided it (paused, no_player, culled, rite_pressure,
  refill_hold, alive_cap, no_batch, type_cap, filtered, missing_scene,
  no_capacity, invalid_spawn_position, spawning_disabled, scene_missing,
  special_cap, placement_failed). Its `balance_snapshot()` reads pending
  reservations, population, cap and gates without reserving anything.
- `EncounterDirector` reports beats started, ended and aborted (with placed
  and wanted members), escalations and specialist responses; its snapshot
  lists the formations alive by beat id with its own member counts.

The ledger derives, per segment: status (not_unlocked, unlocked, channeling,
unfinished, completed), unlock-to-first-channel time, attempts (an attempt is
an actual channel entry; proximity is not one), channel seconds, progress
lost by cause (lapse, death, other), seals, waves and their enemies, deaths
while channeling, deaths within ten gameplay seconds of a reconstruction,
reconstruction spending beside Followers earned, time from each
reconstruction back to the channel, reinforcement counts, spawn requests by
source and outcome (also aggregated into each metrics window), and Overtime
injections by contributor with the director's own injected total beside the
ledger's sum. A sudden rise in pressure is never attributed to a contributor
without its injection event.

Not measured: the Exit Encounter Controller proposed by the balance plan does
not exist yet, so its fields (planned reinforcement waves, recovery
protection) are unavailable rather than zero. Placement failures inside the
ambient ring pick are reported as `invalid_spawn_position` only when the
spawner refuses the position itself. There is no proxy-to-actor promotion
path in this build to count.

## Incident history

The recorder keeps the last five gameplay seconds in a bounded ring: at most
2,048 compact events (resolved incoming attacks with raw/adjusted/applied and
outcome, every health change with HP before/after, refused heals, healing
locks, phase changes, ability activations, dashes, Manifestation resource
spends and fills, life transitions) and at most 32 cheap state samples taken
at 5 Hz during live gameplay (HP, armour, position, dash and protection state,
enemies within 240 px by archetype through the bounded spatial query, pressure
components, exit-rite progress, life age and the build index). The ring ages
by the gameplay clock, so a pause never expires the last fight; wall time is
carried separately. Both caps apply independently and whatever they discard
is counted as overwritten, never hidden.

Nothing is persisted per tick. On death the recorder freezes a
`death_context` record inside `die()`, before the reconstruction card, the
respawn or any scene change can touch the player: the exact terminal health
change and the resolved-damage record that followed it, the chronological
history, the state at that instant (not a one-second-old sample), the pure
effect snapshot, the build index (with one copy of the build), the segment
phase, exit state, life id, reconstruction age and the health residual. The new
life starts with an empty ring whose first record is the reconstruction.
`BalanceRecorder.capture_incident(reason)` writes the same context as an
`incident_context` record on request; the performance overlay's manual
incident button calls it while a capture is live. Each persisted incident is
held under a 2 MiB serialized ceiling: the oldest events go first, then the
oldest samples, never the terminal event or the latest state, and the trim is
reported in the record and in the summary's `incidents` block.

## Developer controls

The `BalanceRecorder` autoload exposes:

```gdscript
BalanceRecorder.set_enabled(false) # finishes the current recording
BalanceRecorder.set_enabled(true)  # arms recording for the next gameplay entry
BalanceRecorder.get_summary()      # copy of the current/last ledger, no disk read
BalanceRecorder.capture_directory # absolute path of the current/last capture
BalanceRecorder.capture_incident(&"manual") # freeze the recent history now
```

Headless runs are excluded by default. A dedicated headless fixture can set
`record_headless = true`, set `report_directory` to an isolated destination, and
call `begin_gameplay(player)`. It must call `end_capture()` / `flush_reports()`
before inspecting output. This does not modify player saves or enable debug
cheats. Recordings contain gameplay data only and are never uploaded.

## Scope

This version supports balance investigation with exact aggregate combat and
wallet accounting, a timeline, and segment reports. It does not assign complete
ability/chain ancestry, record every loot/shop option, simulate a player, choose
balance targets, or supply a comparison dashboard. A high damage number alone
does not establish that an upgrade caused it: inspect enemy density, Threat,
elapsed time, build and debug context together.

## Verification

Run `BalanceLedgerTest`, `BalanceCaptureWriterTest`, `BalanceRecorderTest`,
`BalanceIncidentHistoryTest`, `BalanceExitDiagnosticsTest`, `BalanceUpgradeDiagnosticsTest`,
`BalanceHealthAccountingTest`, `BalanceSnapshotPurityTest` and `BalanceAttributionTest`
with the repository's normal headless test commands. The writer suite
deliberately targets an invalid directory to verify failure reporting; its
expected filesystem error must be followed by a passing assertion. Existing
combat, healing, save, and BuildInfo suites cover compatibility. Run
`ScriptParseAuditTest` last after changes.
