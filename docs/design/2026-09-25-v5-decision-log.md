# Ranged V5 handoff — decision log

Format: **D-n** — decision · reason · evidence · authority
(user direction / handoff / implementation assumption).

- **D-1** — V4 baseline verified intact despite raw-hash mismatch.
  The handoff hash `73926E2F…` matches the LF-normalized bytes of
  `data/ascension/tree_v4.json`; this checkout stores CRLF (file committed
  before `.gitattributes` normalization applied). No data drift. Evidence:
  hash computation 2026-09-25. Authority: verification, not a change.

- **D-2** — Tracking docs live at `docs/design/2026-09-25-v5-phase-checklist.md`,
  this file, and `docs/art/asset-manifest.md` (handoff-suggested path).
  Authority: handoff §13.4/§13.6 + repo dated-doc convention.

- **D-4** — **Firing-rate composition (handoff finding A):** V5 keeps the
  existing multiplicative cross-runner haste composition (the documented
  "explicit alternative ordering") with Spin Up additive *inside* the
  Barrage engine (1 + stage bonus), the `SHOT_HASTE_CAP = 2.5` unchanged
  for all sustained sources, and Burst's ×2 applied *after* the cap as an
  explicit, time-boxed window (`post_cap_haste_multiplier`). No global cap
  raise; V4 engines return 1.0 post-cap so the control never crosses 2.5.
  HUD/telemetry read the same engine state the scheduler uses. Authority:
  implementation decision within the handoff's stated latitude.

- **D-5** — **V5 refund policy (finding C):** per-rank receipts are exact;
  downgrades and gate cascades repay the recorded rank-2+ payments at 100%
  (RANK-06); a whole-node refund returns rank-2+ receipts exactly plus the
  V4 share policy on the rank-1 payment. Downgrades are Hub-only, matching
  the loot-pass refund rule. `refund_value()` shows the actual number in
  the UI before committing. Authority: RANK-06 + documented interpretation.

- **D-6** — **Spin Up accrual interpretation:** any gap ≤ 0.35 s between
  native inputs counts as continuous firing time (base ranged interval is
  0.22 s); gaps 0.35–0.75 s hold the stage; past 0.75 s one stage drops per
  0.5 s beyond the grace. Authority: implementation assumption where the
  spec's "hold without adding timer credit" wording is ambiguous.

- **D-7** — **Rank gates as code, not per-node JSON:** the V5 tree stores
  `max_rank`/`rank_costs`/`rank_effects` per node; the generic gate rules
  (rank 3: 2 other unique locals, rank 4: 4) live in AscensionLedger. The
  spec's `rank_requirements` JSON shape was marked illustrative. Authority:
  spec §1.1 "adapt to the existing ledger schema".

- **D-8** — **RANK-07 hub fix:** opening the Ascension screen from the Hub
  now invalidates the trade undo snapshot, like every other state-changing
  overlay; otherwise an undo could restore a Follower count from before
  tree purchases. This also closes the same pre-existing V4 hole.

- **D-9** — **OR09 travel credit caveat:** Running Barrage counts the
  runner's measured player displacement; a knockback source that moves the
  player would currently count as travel. No such displacement source was
  found in the current game; noted as a limitation, not fixed speculatively.

- **D-10** — **Attached-grenade target loss:** when the carrier dies before
  the fuse ends, the grenade drops grounded at the death position keeping
  its remaining fuse (min 0.10 s). The spec leaves this case open.

- **D-11** — **Big One fix expression (finding B):** `OR12 requires any of
  OR01 / OR04 / OR11 / ORQ` — the four genuine Shell producers. OR04 is
  reachable on a grenade build and produces Shells from blast kills, so a
  grenade build can still legitimately reach Big One through it.

- **D-12** — **ORC rolling window sources:** the 24-blast/8 s route counts
  owned Grenade/Shell/Mine blasts and excludes ORC and ORV roots
  ("ordinary OR sources only"). Authority: spec §4.5 wording.

- **D-3** — **Beka's appearance (user direction, 2026-09-25, mid-session):
  a black and white female cat — white nose, white neck/chest, white
  "boots" (paws/lower legs), black elsewhere (tuxedo-style).** This is the
  authoritative art reference for the Phase 4 memorial companion; the
  handoff's warning about inventing her likeness is resolved by this
  message. No photo or meow audio supplied yet — sprite from this text
  description is acceptable, but label it "text-described likeness" in the
  asset manifest, not a photo-verified one.
