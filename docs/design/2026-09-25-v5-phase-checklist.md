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

### Checkpoint 4 — Optional Heat, attribution, hybrids
- [ ] Named burn attribution + strongest-rate refresh
- [ ] BR03 Hot Core tiers, world-space aura, Meltdown, Overclock
- [ ] Q mutations, forks, keystones, revelations, Axioms, sinks adapted
- [ ] Foreign Witness adapters (§5.4)
- [ ] Cross-Core matrix (§5.1–5.2) incl. RM7 Rune Bomb, Mine producers
- [ ] Remaining spec acceptance cases; deferred items reported separately

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

## Current checkpoint

**Now:** Phase 1 Checkpoint 4 — hybrids/foreign completion. Named burn
attribution (EnemyStatusService.apply_named_burn + tagged ticks) is done;
foreign BR01/BR07/BRQ/BR11/BRC adapters are in BarrageEngineV5 but only
the native path is test-covered so far.
**Next task:** hybrid/foreign regression suite (HYB-01..05 V5 variants,
foreign witness adapters), then Checkpoint 5 capacity/balance evidence.
**Test state (2026-09-25):** V5 suites 63+37+33+23 all green; V4 battery
(Barrage 38, Precision 47, Ordnance 63, Hybrid 41, SharedRules 32, Runner
29, Screen 20, Status 19, Combat 38) all green; parse audit 422/422.
