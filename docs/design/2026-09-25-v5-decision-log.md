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

- **B-1 (blocker)** — **Browser ChatGPT is unreachable from this session
  (2026-09-26).** The session has no browser-control or computer-use tools
  (checked the tool registry directly), so the signed-in ChatGPT window in
  Firefox cannot be driven, per handoff §13.1's warning that the handoff
  itself cannot grant missing tool access. Consequences: (1) asset
  generation via GPT and (2) history retrieval (authoritative Precision
  references, "JSON lasīšana"/"Game Shape Improvement" chats, the user's
  requested "what did the handoff miss" GPT consult) are deferred, not
  skipped. Fallbacks in use: WebSearch/WebFetch for licensed (CC0) asset
  research — the repo already uses Kenney CC0 packs — and text-described
  references recorded in the manifest. **To unblock:** run a session with
  Claude desktop computer use enabled, or move ChatGPT to Chrome with the
  Claude-in-Chrome extension connected. Exact ready-to-send GPT request is
  kept in the phase checklist's next-task section.

- **D-3** — **Beka's appearance (user direction, 2026-09-25, mid-session):
  a black and white female cat — white nose, white neck/chest, white
  "boots" (paws/lower legs), black elsewhere (tuxedo-style).** This is the
  authoritative art reference for the Phase 4 memorial companion; the
  handoff's warning about inventing her likeness is resolved by this
  message. No photo or meow audio supplied yet — sprite from this text
  description is acceptable, but label it "text-described likeness" in the
  asset manifest, not a photo-verified one.

- **D-13** — **No GPT-generated art assets (user direction, 2026-09-26):**
  "no gpt generating assets i mean" — the ChatGPT→Claude pipeline is not
  trusted for art, so nothing GPT generates ships as an asset. Sourcing
  order for the next art pass: (1) licensed online packs (CC0 — the repo
  already uses Kenney; OpenGameArt/Kenney searches), (2) the existing
  procedural generators (tools/design/build_*.py) as placeholders. GPT
  remains fine for *review text* (the integration-pass work order came from
  it); only its images are excluded. Supersedes the "ask GPT to generate
  VFX" fallback inside B-1.

- **D-14** — **Projectiles: simulation is authoritative, rendering has a
  budget (integration pass, 2026-09-26).** The GPT review's rule "gameplay
  events may never be deleted *or delayed* by renderer capacity" made the
  finding-E overflow queue wrong as a first resort: it delayed
  materialization at the old 4096 cap. Now `ProjectileSimulationManager`
  grows its SoA arrays on demand (doubling to `SIM_CAPACITY_MAX` 16384)
  with zero queueing, while the MultiMesh draws at most `RENDER_BUDGET`
  4096 instances — excess is *undrawn but fully real* (`undrawn` counter).
  The bounded queue survives only past the 16384 simulation maximum
  (pathological, loudly counted), and only its overrun drops. Verified by
  the reworked ProjectileOverflowTest (17), incl. exact damage from an
  undrawn projectile.

- **D-15** — **The Beka test flake was two RNG leaks, not Beka
  (2026-09-26).** Forensics (resolved-event log in the failing check):
  (1) `ItemInstance.from_data` rolls a random Manifestation from
  `Global._rng`; a rolled **ward** noun banks Composure (`time_since_hit`
  starts 999) and blunts the next landed hit by exactly 45% (30 → 16.5).
  (2) The equip stat recompute rewrites `Global.run_luck` from race/style,
  re-enabling lucky evasion (≤6%) that randomly voids a test hit.
  Rule for damage-asserting suites: equip via a `_bare()` copy
  (`manifestation_id = &""`) and re-pin `Global.run_luck = 0.0` inside the
  `_hit()` helper alongside spawn-protection/armor zeroing. Applied to
  BekaEffectTest, ItemBatch2Test, ItemBatch3Test; 60/60 soak clean. The
  game behavior itself is intended (drops do roll manifestations) — this
  is a test-determinism rule, not a game fix.

- **D-16** — **Authored segment milestones are named constants
  (2026-09-26).** The GPT review's `segment <= 10` audit found the run
  never hard-stops in Global (the reward cadence deliberately extends past
  9); the only authored milestones were bare literals in the proc-gen.
  Now `Global.MINIBOSS_SEGMENT = 5` / `Global.FINAL_SEGMENT = 10`, read by
  DistrictPlan and SegmentProcBuilder. A future run-length change is one
  edit plus content review, not a repo-wide literal hunt.

- **D-17** — **Cross-system invariants got their own suite
  (2026-09-26, InvariantsTest, 27 checks):** the V4 tree is pinned by
  sha256 (byte-identical control since the handoff began);
  refund(purchase(x)) restores the ledger's semantic state exactly and
  repays every follower at share 1.0, ranks and gate-neighbours included;
  no follower mutation path goes below zero; V5 Meltdown/lockout/re-overheat
  never writes `jam_left` (BRE2's authored shutdown is the only V5 jam
  writer, proven by owning it and completing a Burst); the Big One counts
  only true `call_shell` Shells — shell-tagged blasts that bypass
  `call_shell` and beacon-flagged shells never feed it. Item identity
  through a real trade + undo (one ItemInstance object, one container)
  lives in HubWorldTest (31); damage conservation through overflow in
  ProjectileOverflowTest (17).
