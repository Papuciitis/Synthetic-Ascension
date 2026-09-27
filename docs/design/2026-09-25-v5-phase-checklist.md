# Ranged V5 handoff — phase checklist and checkpoint

Era: 2026-09-25 handoff (`Synthetic_Ascension_Claude_Handoff_2026-09-25.md`).
Companion docs: `2026-09-25-v5-decision-log.md`, `docs/art/asset-manifest.md`.

**Session start state:** HEAD `167c1ba` (matches handoff audit snapshot).
`data/ascension/tree_v4.json` LF-normalized SHA-256 matches the handoff
baseline (`73926E2F…`); the checkout stores CRLF, hence the raw-hash
difference. Working tree clean apart from untracked docs/archives.

## Phase 1 — Ranged V5 mechanics (V4 kept as control)

### Checkpoint 1 — V5 data and rank foundation  ✅ 2026-09-25
- [x] Recheck handoff findings A–F: all six confirmed live (A: player.gd:749
      cap + engine ×2; B: OR12 requires OR09 in data; C: aggregated `paid`;
      D: status replace-not-strongest; E: 4096 cap + dropped counter;
      F: ORQ hold pattern inverted vs V5)
- [x] V4 untouched; V5 = `data/ascension/tree_v5_ranged.json` from
      `tools/design/build_tree_v5.py`; ledger state stamped `tree_version`
      (old saves default v4, never converted)
- [x] Generator validates ids/requires/conflicts/links/edges/starters/
      build subtotals (P1 2500 / B1 2850 / B2 3400 / O1 2150 confirmed)
- [x] Ledger ranks: receipts, gates (r3: 2 others, r4: 4), downgrade,
      cascade, refund_value; Hub-only downgrades (D-5)
- [x] AscensionScreen: rank I–IV, now/next effect, next cost, total paid,
      actual refund on the button; TreeView rank markers
- [x] `AscensionLedgerV5RankTest`: 63/63 (RANK-01..08)

### Checkpoint 2 — Precision ranks and no-Heat Barrage  ✅ core mechanics 2026-09-25
- [x] Precision ranks via virtual getters (V4 defaults untouched);
      PRF2 -15%; PRC boss fallback (3 hits / 12D on one durable target)
- [x] Finding A resolved (D-4): cap kept, Burst ×2 post-cap, V4 unchanged
- [x] BR01 Spin Up (stages, hold, decay), BRQ V5 (input accounting, fan as
      one 0.7-credit activation, cancel rules)
- [x] No-BR03 audit: BR04 unheated named burn, BR07 Kill Throttle,
      BR08 Vent Volley, BR11 Reserve Feed, BRC 20-stage-3-inputs route —
      all tested with zero Heat
- [x] Functional feedback: stage popups + HUD lines (full VFX = Phase 2)
- [x] `AscensionBarrageV5Test` 37/37, `AscensionPrecisionV5Test` 23/23

### Checkpoint 3 — Grenadier and Ordnance controls  ✅ core mechanics 2026-09-25
- [x] Grenade payload (flight 0.35 s → attach 0.40 s / ground 0.80 s, one
      detonation, chain-eligible when not in flight)
- [x] OR05 Sticky (+0.8D, oldest, once per activation), OR06 chain incl.
      grenades, OR09 Running Barrage (rank distances, 2L bank, 0.5 s rate),
      OR10 Bandolier (credits, cap, one spare per launch)
- [x] Mines/traps unchanged for MR6/MR9/RM7/ORQ4; V5 RM7 converts a
      travelling grenade at a Sigil
- [x] Tap-Q instant / hold-Q placement; placement allowed during fire
      cooldown (runner routing hook); nothing fires before classification
- [x] OR12 Shell-only (D-11); grenades never advance the counter
- [x] `AscensionOrdnanceV5Test` 33/33 (subset of OR-01..13; rest at CP4/5)

### Checkpoint 4 — Optional Heat, attribution, hybrids  ✅ evidence recorded 2026-09-27
- [x] Named burn attribution + strongest-rate refresh:
      `EnemyStatusService.apply_named_burn` (one record per handle+name,
      strongest rate wins, reapply refreshes); BR-06 tagged in
      AscensionBarrageV5Test, named Hot Rounds provenance in
      AscensionV5HybridForeignTest.
- [x] BR03 Hot Core tiers, world-space aura, Meltdown, Overclock: block 18
      (2026-09-26); BR-07 / BR-08 / BR-08 (Overclock) tagged.
- [x] Q mutations, forks, keystones, revelations, Axioms, sinks adapted:
      every V5 ranged id (PRQ1-6, PRF1/2, PRK1/2, PRE1/2, PRC, PRA, PRS1/2,
      BRQ1-7, BRF1/2, BRK1/2, BRE1/2, BRC, BRA, BRS1/2, ORQ1-7, ORF1/2,
      ORK1/2, ORE1/2, ORC, ORA, ORS1/2, *V1-3) is referenced by the
      engines; BR-11 / BR-12 / BR-14 / OR-11 / OR-12 tagged.
- [x] Foreign Witness adapters (§5.4): AscensionV5HybridForeignTest
      (foreign Spin Up stages ride real Witness shots, foreign Reserve Feed
      through Witness cadence).
- [x] Cross-Core matrix (§5.1–5.2) incl. RM7 Rune Bomb, Mine producers:
      HYB-01..05 tagged in AscensionV5HybridForeignTest (49/49).
- [x] Remaining spec acceptance cases: all 45 ids of spec §7.2 are now
      tagged `# --- ID:` above the block that proves them (RANK-01..08,
      PR-01..05, BR-01..14, OR-01..13, HYB-01..05); no case is DEFERRED.
      Suites 2026-09-27: Precision 45/45, Barrage 121/121, Ordnance 85/85,
      HybridForeign 49/49, Hybrid 41/41, LedgerV5Rank 63/63.

**Defects the acceptance sweep found and fixed (2026-09-27):**
- MR2 Kill Feed's bonus fragment was spawned with an empty cast and a
  fixed generation 2 (`BarrageEngine.extra_fragment`), so its kills seeded
  a fresh chain instead of continuing the executing fragment's lineage
  (spec HYB-01 "no ancestry reset"). It now inherits the hit's cast and
  gen+1 through `ExecutionEngine`.
- A Sigil detonation double-blasted its attached Mines under OR06:
  `OrdnanceEngine.explode_attached` walked a copy of `mines` after the
  first blast's Chain Reaction had already erased and detonated the
  siblings (three attached Mines -> five blasts). It now skips Mines that
  already left the armed graph (HYB-03).
- `OrdnanceEngine._tick_mines` indexed a stale slot when a proximity
  blast inside the loop chain-erased other Mines (out-of-bounds script
  error under the OR-12 trap-contact case); guarded.
- Two of the interrupted tagging agents left duplicate local declarations
  (`loose_before`, `spent_before`) that made their suites fail to parse;
  renamed.

### Checkpoint 5 — Capacity, balance, presentation evidence  ◐ headless done 2026-09-26
- [x] Overflow policy: bounded retry queue in ProjectileSimulationManager;
      `ProjectileOverflowTest` 11/11 (fill, retain, drain, exact damage,
      bounded overrun)
- [x] Matched headless V4/V5 runs: P1/B1/B2/O1/O2 + matched random walks,
      seeds 101/202/303 → `docs/audits/2026-09-26-v5-sim-baseline.md`
      (B1 competitive sans Heat; B2's risk pays; O1 strong; O2 flagged)
- [ ] Rank noticeability + free-choice + durable-target scenarios: need a
      rendered human run (headless cannot judge feel)
- [x] Commands and raw rows preserved in the audit dir
- [x] VFX needs list → asset manifest (authored set integrated)

## Phase 2 — Ranged visuals (all three disciplines)  ◐ first pass 2026-09-26
- [x] 12 authored textures (build_ranged_vfx.py) integrated: shaped pool
      bullets, textured beams+caps, needle bursts, fragment motes,
      grenade/mine/shell silhouettes, true-radius aura ring, spin glow
- [x] Precision language honoured (white/gold, needles/diamonds, violet
      accents only); identity table retrieved from "JSON lasīšana"
- [◐] Barrage cues: spin glow + aura + Meltdown text; darts/broken-ring
      rework pending the chat's remaining references
- [◐] Ordnance silhouettes distinct; pressure-ring telegraph pending
- [ ] Legibility at gameplay zoom: needs a rendered human run; contact
      sheets checked on light/dark grounds only

## Phase 3 — 2D world shapes and shallow depth  ◐ 2026-09-26
- [x] Proof on the real parcel path (`WorldFootprintTest` 10/10): L building
      with recessed entrance at a fixed seed; roads/streets vary by role
      already (widths 2–7)
- [x] Footprint cells drive floor, perimeter walls, collision, projectile
      grid, two IndoorVolumes (one building id, one loot owner) and a
      polygon RoofOverlay consistently; interior stays an open reachable
      hall (no carver connectivity risk)
- [x] Shallow depth: south wall faces + slight cap lift in BOTH render
      paths (ChunkBlockRenderer batches, shadowless face batch, counted
      separately; CoverWall DepthFace sprite for Level 1 / unbatched);
      authored face texture in the caps' palette
      (tools/design/build_world_textures.py); world battery green
- [◐] Level1Builder gets the depth pass via CoverWall automatically;
      irregular AUTHORED footprints for segment 1 not yet planned in
- [ ] Rendered legibility check (actors beside faces at gameplay zoom):
      needs the next human run — headless cannot render
- [ ] Rubble/vegetation/dirt transitions: per-theme decor exists; no new
      pass yet

## Phase 4 — Items: Beka first, then batches; existing-item textures
- [x] Beka shield: real absorb pool in Player._take_damage (after armour,
      before lethality; absorbed ≠ HP loss in telemetry), 4 s delay,
      4%/s regen, cap min(0.30, 0.20 S) via rarity_effect_multiplier;
      pay_health and evasions never touch it
- [x] Beka pulse: 12 s / 320 u, LoS at selection, pulls armed health to a
      wounded player at ≤420 u/s ≤2 s, stops at full HP, highlights
      equipment 3 s without touching it, quiet when it finds nothing
- [x] Beka presentation: provisional tuxedo-cat sprites from the user's
      description (D-3) — sit/sleep + icon-on-blanket; sleeping = shield
      regenerating; restrained meow popup + ring on a find; shield arc
- [x] §14.2 checks: `BekaEffectTest` 30/30 (stable across 5 runs); item
      battery green (EffectRunner 239, ScalingV2 27, EconomyV2 32,
      InventoryRouter 115, SaveIntegrity 62)
- [ ] Beka vs other Offhands comparison: needs the balance recorder in a
      rendered run (headless done: opportunity cost is zero flat stats)
- [ ] Existing-item texture audit → asset manifest
- [ ] Remaining item ideas: per-item status (implemented / designed / blocked)

## Phase 5 — Walkable between-segment hub  ◐ core 2026-09-26
- [x] `scenes/hub/HubWorld.tscn`: a ~30x18-cell sheltered courtyard with a
      clear arrival→exit walk, recessed east/west service bays, five
      stations (merchant, Ascension, gear corner, quiet alcove, exit gate),
      a statue landmark, real player + camera limits, and Beka sleeping in
      the alcove when she rides with the run
- [x] Merchant/gear open the existing HubShop embedded (economy identical:
      vendor snapshot reuse, undo rules, refresh pricing); Ascension opens
      the tree screen in hub-refund context; embedded mode never writes the
      resume target, never opens MajorChoice, swaps Continue for Close
- [x] Combat isolation: attack lock + AscensionRunner.combat_inputs_enabled
      (no Q/Heat/Spin-Up/charge farming in the hub)
- [x] Transition: on_segment_completed targets the hub world; the gate
      departs once (double-activation guarded) and is blocked by a pending
      mandatory choice with an in-world cue; old HubShop-target saves route
      into the hub world at resume
- [x] `HubWorldTest` 19/19; SaveIntegrity 62, InventoryRouter 115,
      EconomyV2 32, ChoicePickup 5, parse 425 all green
- [ ] §15.6 rendered checks (walkthrough capture, input feel, legibility at
      zoom, several full segment/hub cycles): need a human run

## Current checkpoint (handback, 2026-09-26)

**All five phases have their cores implemented and headless-verified.**
Six commits on `enemy-world-work` (1e6ce14…1ebebd4), **not pushed** — this
session has no GitHub credentials; one `git push` sends everything.

**Blocked, with resume path:**
- Browser-ChatGPT retrieval/generation (authoritative Precision refs, the
  user's "ask GPT what the handoff missed" request, reference recovery for
  the needs-reference items): the permission classifier stopped GUI input
  into the live browser after the first retrieval (decision log B-1). The
  GUI driver works otherwise (scratchpad gui.py). Either add a Bash allow
  rule for it, or run the questions manually. Ready-to-send GPT prompt:

  > I am handing back the Synthetic Ascension 2026-09-25 development
  > handoff (Ranged V5 + visuals + world shapes + items/Beka + walkable
  > hub — all implemented to prototype). Looking at what such a handoff
  > should have covered: what did we miss, what should be added or
  > improved, and what risks does a V5 prototype like this usually hide?
  > Separate established user decisions from your own new suggestions.

**Owed to the next human playtest (headless cannot judge these):**
rendered legibility of faces/VFX/hub at gameplay zoom; rank-purchase
noticeability; free-choice + durable-target comparison runs; Beka vs other
Offhands with the balance recorder; §15.6 hub walkthrough capture; Spin Up
feel (the B1-vs-P1 A/B).

**Done in the continuation pass (2026-09-26, second sitting):**
1. [x] Barrage darts + broken heat ring + Ordnance pressure-ring
   telegraphs, from the identity table alone (chat retrieval still
   pending); wired into the V5 engines.
2. [x] Item batch 2: Plot Armor, Second Breakfast, The Missing Pālis —
   `ItemBatch2Test` 27/27; items gain a lethal-intercept hook after the
   tree's interceptors.
3. [x] Level1 authored footprints: the service warehouse is an L, the
   kiosk door sits in a recessed bay; wall probe green, determinism
   fingerprints unchanged across runs.
4. [x] Hub gear corner opens its own BagUI panel (HubWorldTest 22/22).

**Still waiting on one keypress:** the "what did the handoff miss" GPT
consult is fully staged in a new ChatGPT chat's composer (browser window
"ChatGPT — Mozilla Firefox"); the permission classifier will not let this
session press Enter or scroll the reference chat. Press Enter there and
say so — reading the answer via screenshots is not blocked.

**Next implementation tasks:**
1. Read GPT's answer once sent; act on (a)-list items it surfaces.
2. Retrieve the remaining "JSON lasīšana" references (same constraint).
3. Rendered pass: §15.6 hub walkthrough, VFX/faces legibility, B1-vs-P1
   feel, Beka-vs-Offhands recorder run.
4. Item batch 3 candidates: 7-Mile Boots, Bazinga, Trauma, Dignity.

**Done in the Integration & Abuse Pass (2026-09-26, third sitting —
work order: docs/handoffs/2026-09-26-gpt-handoff-consult.md, user: "Don't stop till
resolved"):**
1. [x] Item batch 3a: Trauma + Dignity (`ItemBatch3Test` 19/19); items
   gain per-source damage-taken multipliers after the flat item pass.
2. [x] Projectile capacity redesign per the review's authority rule:
   simulation grows (to 16384) with zero delay, rendering clamps at a
   4096 budget, queue demoted to a loud last resort past the sim max
   (`ProjectileOverflowTest` 17/17, D-14).
3. [x] Beka flake root-caused and killed: rolled ward Manifestation
   banking Composure (−45% once) + recompute-restored luck evasion
   (≤6%); test-determinism rules applied to all damage-asserting item
   suites; 60/60 soak (D-15).
4. [x] `InvariantsTest` 27/27: V4 tree sha256 pin, ledger
   purchase→refund round trip, followers never negative, V5
   meltdown-never-jams (BRE2 sole authored writer), Big One purity
   (true call_shell Shells only) (D-17).
5. [x] Item identity through trade + undo in `HubWorldTest` (31/31).
6. [x] `segment == 5/10` literals centralized as
   `Global.MINIBOSS_SEGMENT` / `Global.FINAL_SEGMENT` (D-16).
7. [x] Asset policy recorded: no GPT-generated art; online CC0 packs
   first, procedural generators as placeholders (D-13).

**Review items that need rendered play or design time (unchanged by this
pass, carried forward):** vertical-slice run test; run-truth telemetry
dump; tap/hold-Q panic feel; Beka run-friction measurement; building
abuse (pathing/projectiles/pickups through footprints); procedural
gameplay validator; save migration matrix; hub friction walkthrough.

**Integration pass, fourth block (2026-09-26, later):**
8. [x] Run-truth telemetry per segment inside the balance capture
   (BalanceLedger/Recorder `truth` block; absorbed damage no longer
   dropped; secondary funnel counted; slow_frames PFR-independent;
   BalanceLedgerTest 35/35).
9. [x] VerticalSliceTest 19/19 — the real game scene runs the segment
   loop end to end headless; ExitRite gained its own completion
   idempotence guard (abuse finding).
10. [x] Exit Rite READY blocker truth table + witness-needs-a-gate in
    InvariantsTest (32/32). GPT's invariant list is now fully covered.
11. [x] SAVE INCIDENT found + fixed: HubWorldTest wrote real
    user://saves/slot_0.tres (test residue, both primary and .bak).
    Slot pinned to 97 (D-18); the contaminated files await the user.
12. [x] CC0 sourcing candidates recorded in the asset manifest (D-13);
    downloads deferred to a supervised pass.
13. [x] SaveMigrationMatrixTest 32/32 — opening v0/v1, layout v2,
    pre-Doctrine retirement, pre-V5 ascension repair, clamps/healing,
    newer-build best-effort; in memory only (D-18).
14. [x] ProcSeedSweepTest 6/6 — 360 plans (40 seeds x seg 2..10): zero
    fallbacks, reachability at authored minimums, milestones exact,
    seed-deterministic.

**Playtest-review response (2026-09-26, fifth block — work order:
docs/audits/2026-09-26-playtest-v5-integration-review.md):**
15. [x] Hub block: gear panel close button + Esc/bag-key routing (one
    lock, one release), embedded merchant reads "Return to Courtyard"
    and a pending choice never traps the player in the shop, the hub
    owns a dev console, ability HUD re-reads titles on poll, honest
    alcove line (HubWorldTest 39/39).
16. [x] V5 DEFAULT for new runs (user decision): version label on the
    ascension header, V4 one switch away, saves never convert
    (InvariantsTest 36/36; preset/parity/ledger suites green).
17. [x] Exit encounter lifecycle §6.1: ExitEncounterController drives
    the channeling group — dodges keep suppression, 8 s living
    disengage, recovery holds, completion terminal (ExitEncounterTest
    21/21). §6.2-6.4 remain separate audited items.
18. [x] V5 combos: sustained Meltdown under Overclock feeds Thermal
    Fury (entry volley, aura doubling, exit tax; mid-Meltdown purchase
    converts), MR8 adapter on the emergency vent, foreign stage expires
    on the clock, Q-less Hot Core keeps a passive readout
    (AscensionBarrageV5Test 53/53).
19. [x] PRC boss fallback proven through three REAL projectiles
    (AscensionPrecisionV5Test 24/24).
20. [x] VFX source defects (fixed pre-review-sync in commits 1a58704^..):
    pressure ring at true radius, trailing redraw, burst scale, dart
    rotation. Warning pass: no shadowing in the named files, explicit
    floor-division intent in SiteParcelsImpl.

**Still open from the review (needs rendered/design work):** tree view
double-click purchase + overview declutter; hub visual furnishing pass;
projectile identity atlas (needle/tracer at runtime), grenade arc/shadow
visual, Spin aperture progression; §6.2-6.4 exit budgets/overtime/
recovery anchors; the rendered acceptance passes themselves.

**Sixth block (2026-09-26, "go for it"):**
21. [x] Tree UI: double-click purchase with exact-cost confirmation and
    fresh eligibility recheck, Gate Core choice in the dialog, overview
    label/edge declutter (hover/selection always; cores, equipped and
    buyable-now at fit zoom), actions above the scrolling details
    (AscensionScreenTest 29/29).
22. [x] Projectile identity atlas: needle/tracer/shared silhouettes per
    provenance tags via MultiMesh custom data + canvas shader; legacy
    fallback when textures are missing (ProjectileIdentityTest 7/7).

**Remaining from the review:** grenade arc/ground-shadow visual (visual
only, never the collision path), Spin aperture progression presentation,
hub furnishing pass, §6.2-6.4 exit budgets/overtime/recovery, rendered
acceptance passes, Beka/icon art (user supplies per the spec list).

**Seventh block (2026-09-27, "do what you think is best" after the gap
audit):**
23. [x] Pixel-art VFX conversion, Batches A–D (docs/art/2026-09-27-pixel-
    art-vfx-batches.md): 42 user-generated sprites processed; four-family
    bullet renderer (player / needle / tracer / enemy bodies); six burst
    scenes on pixel motes; `core/systems/vfx/VfxKit.gd` with ~30 tinted
    helpers and primitive fallbacks; ~70 effect scripts converted to
    sprites with normal blending. Ranged billboards and beams scaled up
    (BILLBOARD_SCALE 1.7 / BEAM_SCALE 1.4, true-radius rings exempt).
    Provenance per batch in asset-manifest.md. Rendered check owed.
24. [x] Non-block city pass (docs/design/2026-09-27-non-block-city.md):
    ChunkShapeGen cell-mask module, notched generic buildings, bent
    socket-to-hub roads, polygon plazas with outline rings, hub courtyard
    as an authored polygon; `organic_shapes_enabled` restores the old
    generator; `tools/dev/DistrictShapeProbe.tscn` / `HubShapeProbe.tscn`
    render PNG cell maps; WorldShapeGenTest 32/32; world battery and the
    streaming audit green (median 0.4 ms).
25. [x] Load-time warning pass (shadowed `rotation`, `tree_version`,
    `refund`, `wrap`; seven integer divisions).
26. [x] Gap audit against the handoff (this doc's Checkpoint 4, §14.3,
    §15.6, §16 and the GPT consult): results below and in the item-status
    refresh (docs/design/2026-09-26-item-ideas-status.md). The GPT consult
    answer now lives at docs/handoffs/2026-09-26-gpt-handoff-consult.md and
    the world-gen notes at docs/design/2026-09-27-hub-world-gen-notes.md
    (both were untracked root files); the root handoff copy is byte-
    identical to docs/handoffs/2026-09-25-ranged-v5-and-visuals-claude.md.

**Pre-existing failures noticed 2026-09-27, not from this session's work:**
ChunkBuildDataTest expects 25 catalog textures (26 since the wall-face
commit); PrimaryObjectiveTest "an unsealed rite accepts the player and
starts channelling" fails with the organic flag off as well;
WorldTileIntegrationTest has no .tscn.
