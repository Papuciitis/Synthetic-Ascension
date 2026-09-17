# Core balance recorder

Approved scope: record normal play for economy, player/enemy HP and damage,
pressure, build changes, and saved run reports. No balance changes or automated
player. Implementation and local commits were authorized in the conversation.

- Start automatically when the game scene binds its player. Keep recording
  through the hub; close before loading another save, resetting an attempt,
  returning to menus, or shutting down. A resumed game creates a new capture
  linked by save slot and world seed, explicitly marked as a partial observation.
- Count combat at authoritative resolution, distinguishing post-defense damage
  from HP actually removed and intentional HP costs. Count enemy defeats once
  across materialized and data-only enemies. Measure first-hit-to-death time
  using gameplay seconds, excluding pauses and hub time.
- Record actual wallet deltas and reasons. Keep system synchronization, refunds,
  and undo separate from earned/spent totals; reconcile opening plus all deltas
  with closing balance. Preserve large integer values in exported JSON.
- Retain one-second combat totals, periodic player/Threat snapshots, discrete
  wallet/build/lifecycle events, and per-segment summaries. Do not retain a
  dictionary for every hit or every frame. Bound queued history; any loss or
  write failure must be visible, never silently called a complete recording.
- Write local JSONL history, JSON summary, Markdown report, and segment CSV.
  Background writes use immutable batches; shutdown drains pending work.
  Development captures live in ignored balance_captures; exports use user://.
- Existing event semantics and save format remain compatible. Default headless
  tests do not automatically create captures; integration tests explicitly start
  a recorder against isolated files and real production combat.
- Core attribution is enemy archetype and immediate source. Detailed ability
  ancestry, per-offer loot decisions, automated comparisons, and dashboards are
  later scope. Reports state coverage and timing definitions.

Verification: ledger accounting and clocks; overkill and healing with real
player; materialized/proxy defeats and handle reuse; segment/reset transitions;
writer round trips, I/O failure, backpressure, and large integers; capture cost
under repeated hits; existing combat/healing/save tests and script parse audit.
