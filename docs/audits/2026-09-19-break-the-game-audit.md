# "Try to break my game" audit, 2026-09-19

Adversarial pass over the run-critical systems: what a player, a damaged
save or an unlucky timing can do that the game does not intend. Each row
says how it was checked. **Fixed** rows are in commit `fix(runtime):
release slow-motion at run end, share the reconstruction survival rule,
harden loads` with a test; **proposed** rows are not coded; **not
verified** rows need a rendered or human session.

Companion documents: the loot degenerate-loop pass
(`2026-09-19-loot-loop-pass.md`, the item-economy attack surface) and the
progression-tree audit (`2026-09-19-progression-tree-audit.md`).

## 1. Breaks found and fixed

| # | Break | How it happens | Evidence | Fix and test |
|---|---|---|---|---|
| B1 | The whole session runs in slow motion after a run ends | Deadshot (Q, 35% for 0.6 s) and JUDGEMENT (V, 20% for 1.5 s) set `Engine.time_scale` with a real-time budget that only the runner's `_process` counts down. `game.end_run` pauses the tree first, so a death with no Followers left, or any scene change, during the slow left the engine at 0.2-0.35 for menus and the next run. | Code read: `AscensionRunner.set_time_slow`, `_process`, `_exit_tree` (no reset); `game.end_run` (pauses before anything else). | `_exit_tree` calls `end_time_slow`; `end_run` sets the clock to 1.0 after pausing. `AscensionRuntimeSafetyTest`: a runner leaving the tree mid-slow hands back real time. |
| B2 | "Safe" balances that end the run | `player.die` charges the reconstruction cost and reconstructs only if the balance is *above* zero afterwards. The Hub warned only when `after < cost` and the wager shrine allowed a stake when `followers - stake >= cost`, so a balance exactly equal to the cost passed both and the next death was final. | Code read: `player.die`, `HubShop._trade_validation`, `WagerShrineObjective._can_afford`. | One rule, `Global.reconstruction_survivable(balance)` over `reconstruction_cost_for(balance)`, backs `compute_respawn_cost`, the Hub warning and the stake floor. `LootLoopTest` sweeps every balance 0-399 at three segments and three death counts; `SecondaryObjectiveTest` pins the stake boundary. |
| B3 | Damaged saves carry impossible items | Item instances are typed sub-resources; nothing clamped a negative rank or a meter above one on load, so a hand-edited or damaged save fed `potency`, the stat curves and the price helper values the merge law never produces. | Code read: `Global.apply_save`, `ItemScaling.rebuild` (runs on every container at load). | `rebuild` normalizes rank to >= 0 and the meter to [0, 1); `LootLoopTest` pins it and that a damaged meter is never worth more than the next rank. |
| B4 | One load error disables every later autosave, silently | `apply_save` sets `_suppress_autosave = true` and clears it only at its last line; a runtime error anywhere in between leaves the flag set for the session. | Code read. | A deferred release backs the normal one. Not unit-tested (would need an injected load failure); the release is one line. |
| B5 | The tree opens over a corpse | The tree hotkey only checked management mode, so the Ascension screen opened (and bought or refunded) while the player was dead or the reconstruction card was up. | Code read: `hud._unhandled_input`. | The hotkey does nothing while the bound player is dead. |

## 2. Breaks found and left as proposals

| # | Finding | Evidence | Proposal |
|---|---|---|---|
| P1 | Free rental of any tree node between rooms: refunds are 100% of the recorded price and the tree opens mid-run. | Loot pass section 2; `LootLoopTest` proves neutrality (no Follower creation) and the code read proves no gating. | Hub-only refunds with the V4 shrinking share (loot pass L1-L2). |
| P2 | The rarity soft cap defers to the asked band, so the vendor (R1-R4 at segment 1), the wager shrine (R7-R10 for 85 Followers) and authored loot never meet it. | Loot pass section 3. | Loot pass L3-L5. |
| P3 | Equip-feeding through the router destroys a differing Manifestation without a prompt. | `InventoryRouter._equip_from_bag` / `_move_between` pass `allow_rule_loss = true`; pickups pass `false`. | Loot pass L6. |
| P4 | Set VFX churn is the worst frame cost the simulator sees. | Campaign 3 (headless, so no rendering): the eight worst p99 frames are Lattice and Gravemarch melee builds and Gravemarch magic builds, 16-30 ms at p99 and up to 75 ms max; Lattice builds run a 4.5 ms p95 median against 1.4 ms for the other sets. `LatticeEchoBuffer` spawns up to 19 VFX nodes per triangle (marks, spokes, pulses, arcs, cleaves); Mass Arrest's magic path spawns ten impacts plus a wave and a pulse per slam. | Pool the set VFX (one scene per kind, reused) and cap simultaneous pulses; confirm with a rendered `PerformanceFlightRecorder` capture of Endless Lunge and Mass Grave at seg6, because headless frame times include node churn but not draw cost. |
| P5 | **Fixed**: `ItemScaling.rebuild` drops them with a warning naming the slot (`LootLoopTest`). Items whose `ItemData` no longer exists load with `data == null`. | Code read: every container guards `data == null`, `compute_item_value` returns 0, the bag key skips them; a null-data item in the vendor snapshot is offered for 0 Followers and lands in the bag as a dead stack. | Drop null-data instances in `ItemScaling.rebuild` (with a warning naming the slot) instead of carrying them. |
| P6 | **Fixed**: the run RNG's state rides the save (`SaveData.attempt_rng_state`, `RunRngPersistenceTest`). Save-scum drops. | `Global._rng` is not part of the profile, so quitting before a kill re-rolls its drop. | Persist the run RNG state with the attempt, or derive drop rolls from a per-enemy seed. Low priority: not a loop, and the wager shrine already seeds its outcome. |

## 3. Attacks that held

Checked by code read or by the suites named; none produced a defect.

- **Followers below zero.** The setter clamps at zero and every
  transaction clamps the change; the Hub refuses a trade that would go
  negative (`LootLoopTest`, `ExchangeIdentityTest`).
- **Item conservation through every move.** The router conserves items
  on every refused move: full bag, full stash, wrong slot, locked target,
  invalid container, eject rollback (`InventoryRouterTest`, 111 checks).
  Guaranteed rewards fall through equipped, feed, bag, stash and a
  protected world drop and are never lost.
- **Undo.** Snapshot copies are exact; undo is cleared on every state
  change that could make it stale; a trade and its undo both save at
  once, so quitting between them rolls nothing back (loot pass).
- **Refund cascades.** Refunding a node removes every dependent by
  requirement or reachability and returns exactly what was paid; 25
  buy/refund cycles change nothing (`LootLoopTest`).
- **Held Q through death, pause or the tree.** The runner's hold branch
  releases through the recovery rule when the key reads unpressed; the
  simulator's held-Q fix reproduces the same sequence.
- **Hit-stop versus Revelation slow.** `HitFeel` never clobbers a
  time scale it did not set and only restores its own; the runner's slow
  overrides and restores independently (code read; B1 covers the one
  gap).
- **Proxy deaths.** `enemy_defeated` carries a weak source reference and
  the kill hooks tolerate a freed source; the follower payout, Luck and
  Overtime mirror the actor path (`_finalize_proxy_death`).
- **Merge overflow.** Exponents are clamped to the float range; rank is
  an integer with no cap, and every consumer clamps negatives
  (`potency`, `sample_anchors`, `rank_price`).
- **Newer save version.** Loads best-effort with a warning
  (`SaveIntegrityTest` covers corrupt primaries, backups, unreadable
  slots, version round trips).

## 4. Not verified here (needs a rendered or human session)

- The pause menu and the mid-run tree screen stacking (the screen runs
  with `PROCESS_MODE_ALWAYS`, restores the prior pause state on close).
- Controller navigation of the Hub cart and the tree.
- Whether B1 also reached the hit-stop path in play (a run ending during
  a crit stop) before the reset in `end_run`; the reset covers it either
  way.
- P4's draw cost.
- Everything in the loot pass section 7.
