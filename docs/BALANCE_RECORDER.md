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

## Developer controls

The `BalanceRecorder` autoload exposes:

```gdscript
BalanceRecorder.set_enabled(false) # finishes the current recording
BalanceRecorder.set_enabled(true)  # arms recording for the next gameplay entry
BalanceRecorder.get_summary()      # copy of the current/last ledger, no disk read
BalanceRecorder.capture_directory # absolute path of the current/last capture
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

Run `BalanceLedgerTest`, `BalanceCaptureWriterTest`, and `BalanceRecorderTest`
with the repository's normal headless test commands. The writer suite
deliberately targets an invalid directory to verify failure reporting; its
expected filesystem error must be followed by a passing assertion. Existing
combat, healing, save, and BuildInfo suites cover compatibility. Run
`ScriptParseAuditTest` last after changes.
