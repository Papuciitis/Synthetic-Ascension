# Asset manifest

Era: 2026-09-25 handoff. One entry per asset need. Fields per handoff §13.4:
Identity · Need · Brief · Provenance · Files · Verification · Status
(needed / sourced / generated / prepared / integrated / verified / blocked).

Status counts are maintained by hand; keep entries honest — an unused image
in a folder is not integrated art.

## Entries

### beka — memorial companion (item icon + world sprite + idle/sleep frames)
- **Identity:** item `beka` (rare Offhand companion, Phase 4); UI icon,
  world companion sprite, sleep/purr and meow-pulse animation.
- **Need:** everything — no asset exists yet.
- **Brief:** black and white female cat, tuxedo pattern: **white nose,
  white neck/chest, white boots (paws/lower legs)**, black elsewhere.
  Icon suggestion (handoff): Beka resting on a folded blanket. Match the
  game's sprite scale and top-down-ish camera; transparent background.
- **Provenance:** colouring from the user's direct message 2026-09-25
  ("black and white female cat, with white nose and white neck, with white
  boots"). No photo/audio reference supplied; likeness is text-described.
- **Files:** none yet.
- **Verification:** pending.
- **Status:** needed.

### precision-vfx-reference — approved WIP direction image (2026-09-25)
- **Identity:** style reference for the whole Precision effect family and
  the "2.5D" shallow-depth environment look. Not a runtime asset.
- **What it shows (user-supplied image, described for recovery):** top-down
  stone-paved courtyard with moss/vegetation between slabs and low ruined
  walls whose caps and side faces read as shallow height; ~15 dark armored
  knight enemies casting soft drop shadows. The player stands center in a
  thin double aim-ring. Precision effects in near-white cores with pale
  warm-gold glow and small muted violet accents at impact centers:
  straight needle-like beams with elongated diamond/rhombus nodes along
  the shafts, a multi-segment pierce chain crossing three enemies in a row
  (left), branching lines to separate targets, one heavy wide beam to the
  right ending in a large radial needle-burst impact, smaller star-burst
  impacts on other victims, one curved ricochet/return trail (bottom
  right) with diamond pips along the path, and diamond "spark" motes
  floating along trajectories. No rune circles, no filigree, no large
  purple halos — matches the handoff §8 Precision language exactly.
- **Provenance:** user message 2026-09-25 ("one of the first image
  references to the 2.5d thing with the precision vfx… everything is
  w.i.p."), followed by: **this image is only a first prototype — the
  actual current reference set lives in the ChatGPT browser chat history
  and must be requested there** (start with the "JSON lasīšana" chat per
  handoff §13.1) when the Phase 2 visual pass begins.
- **Files:** none on disk. Retrieve the authoritative references from
  browser ChatGPT before generating any Precision VFX asset; the
  description above is a fallback anchor only.
- **Status:** prototype reference recorded; authoritative set pending
  browser retrieval at Phase 2 start.

### ranged-visual-identity — retrieved from ChatGPT "JSON lasīšana" (2026-09-26)
- **What was retrieved (screenshot of the chat's final summary, captured
  via the user-authorized browser automation before the permission
  classifier stopped further scrolling):**
  | Discipline | Core fantasy | Shape language | Motion | Payoff |
  |---|---|---|---|---|
  | Precision | Manufactured killing magic | needle / line / diamond / bracket | instant, straight, exact | piercing / perfect alignment |
  | Barrage | Mana pushed beyond safe throughput | dart / aperture / broken ring | accelerating, repeated | projectile storm / overheating |
  | Ordnance | Sealed synthetic magic used as artillery | shell / charge / pressure ring | arcing, delayed, heavy | detonation / chain reaction |
  Shared rule: **"Synthetic magic always looks constructed."** Precision
  constructs perfect geometry; Barrage constructs too quickly and starts
  breaking down; Ordnance constructs containers ruptured on purpose.
- **Open questions GPT posed there (user's answers not yet retrieved):**
  literal heat vs abstract destabilization for Barrage; conjured solid
  charges vs pure energy payloads for Ordnance. Earlier messages of the
  chat (and any reference images) are still unread — scrolling was blocked.
- **Consequence for the authored texture set:** Precision set matches.
  Barrage should move toward darts/broken rings (tracer acceptable
  interim); Ordnance shell telegraph should read as a pressure ring
  (current hollow diamond is interim), grenade as a conjured solid charge.
- **Status:** partial retrieval; the remainder needs either the Bash
  permission rule for the GUI driver or a manual look by the user.

### ranged-vfx-authored-set — 12 procedural textures (2026-09-26)
- **Identity:** runtime VFX components in `assets/textures/vfx/ranged/`:
  `bullet_shared` (batched pool body for the native weapon and enemy shots:
  warm-white bolt, gold sheath, soft dark halo; drawn MIX with a 45%
  per-instance tint — re-authored 2026-09-27 after a hard-edged block
  placeholder read as "white blocks" in play),
  `needle_bullet`/`tracer_bullet` (Precision / Barrage bodies, selected by
  root tag),
  `diamond_mote` (Barrage fragments), `beam_core`+`beam_cap` (Deadshot /
  Judgement / Firing Squad lines), `impact_burst` (generated impacts),
  `grenade_body`/`mine_body`/`shell_marker` (Ordnance silhouettes),
  `aura_ring` (Hot Core's true damaging radius), `spin_glow` (Spin Up
  stage muzzle glow).
- **Brief/provenance:** authored as geometry in
  `tools/design/build_ranged_vfx.py` (reproducible, license-free) against
  the user's WIP reference and the retrieved identity table (needle/
  diamond/gold-white for Precision; violet only as small accents). Not AI
  generated, not sourced — the shapes are exact math.
- **Files:** PNGs + Godot .import; bound in ProjectileSimulationManager
  (pool texture), AscensionRunner (_draw: beams, bursts, billboards),
  BarrageEngineV5 / OrdnanceEngineV5 (collect_draw_points).
- **Verification:** contact sheets reviewed on dark and light grounds;
  alpha real (no baked checkerboard); parse audit + full suite battery
  green. NOT yet reviewed in rendered gameplay — headless cannot render;
  needs the next human run at gameplay zoom.
- **Status:** integrated (rendered-review pending). Known follow-ups from
  the identity table: Barrage darts/broken-ring rework, Ordnance
  pressure-ring telegraph, once the chat's remaining references are read.

### curse-relic-icons — 8 authored icons (2026-09-26)
- **Identity:** UI icons for curse_slow_heart, curse_sour_providence,
  curse_tithe_bones, curse_jinxed_coin, curse_ashen_ballast,
  curse_hollow_reliquary, curse_leadfoot_vigil, curse_starving_crown.
- **Need (found by the audit):** every curse .tres shipped with NO icon —
  blank in the inventory bar, shop grid, tooltip and ground loot. This was
  the catalog's only missing binding.
- **Brief:** 32x32 pixel icons, one family language: bold dark silhouette,
  ember/bone/gold accent, shared broken murky-violet rim so a curse reads
  as a curse at a glance.
- **Provenance:** authored procedurally
  (`tools/design/build_curse_icons.py`); license-free, reproducible.
- **Files:** `assets/textures/items/curses/curse_*.png`, bound in each
  .tres (`icon = ExtResource("90_icon")`).
- **Verification:** contact sheet reviewed; item suites green
  (EffectRunner 239, BurdenSystem 74, ScalingV2 27). Rendered inventory
  check pending the next human run.
- **Status:** integrated (authored placeholders open to a later art pass).

### audit conclusion (2026-09-26)
All 33 item defs now carry icons. Ground loot, inventory, shop and tooltip
all read `data.icon` directly, so one binding covers every surface. No
null or misassigned world sprites found; Oakheart's shared placeholder is
intentional. Beka's set (icon + sit/sleep) is text-described likeness,
provisional until a photo arrives.

### online sourcing candidates — CC0 only (2026-09-26, D-13)
Per the user's direction, no GPT-generated art; the next quality pass
sources licensed packs online. Rules: **CC0 only** (no attribution debt),
verify the license ON the pack page before download, keep provenance per
file here. Search hubs (verified reachable, US search):
- OpenGameArt CC0 filter — item icons and roguelike sets:
  https://opengameart.org/content/rpg-items-pixel-art ,
  https://opengameart.org/content/03-pixel-art-items ,
  Kenney's all-CC0 index: https://opengameart.org/content/all-cc0-uploader-kenney
- itch.io CC0 catalogue — https://itch.io/game-assets/assets-cc0
  (cats, top-down: https://itch.io/game-assets/free/tag-cats/tag-top-down —
  "five 32x32 pixel cats with 4-directional walks" fits Beka's tuxedo
  brief if recolored black/white; check each pack's license line)
- Top-down shooter VFX: https://opengameart.org/content/assets-for-top-down-shooter
  (CC0 bullet + ammo sprites), Jettelly Muzzle Flash Pack 01 (CC0
  spritesheet): https://jettelly.com/game-assets/muzzle-flash-pack-01 ,
  CGHEVEN muzzle/impact VFX (CC0, PNG sheets): https://cgheven.com/top-20-free-muzzle-flash-vfx-assets-in-2025/
- Existing in-repo baseline stays Kenney CC0; recolors/edits of CC0 are fine.
Downloads deferred to a supervised pass: the user reviews fit at gameplay
zoom before anything replaces an authored placeholder.

### beka + dignity — user-supplied art (2026-09-26)
- **Files:** `companions/beka_sit.png` (61x64), `companions/beka_sleep.png`
  (50x48), `items/offhand/beka_icon.png` (32x32),
  `items/rings/dignity.png` (32x32, the standard's banner with the paw
  motif — it doubles as the in-world dropped standard).
- **Provenance:** supplied by the user 2026-09-26 (their own generation,
  per their offer); trimmed/downscaled in-repo from 1254px masters
  (originals at repo root: beka_stand/beka_sleep/beka_face/banner_icon).
- **Likeness:** matches the D-3 description (tuxedo, white nose/chest/
  boots) — supersedes the "text-described likeness" placeholders.
- **Draw sizes decoupled:** BekaCompanionEffect, the hub alcove cameo and
  DignityEffect draw at fixed WORLD heights (34/24/44 px), so art
  resolution can change freely from here.
- **Still procedural:** Trauma's icon (generation failed on the user's
  side); the curse-icon set; everything else in the earlier sections.

### batches 1-2 — user-supplied VFX + accessory icons (2026-09-26)
- **Batch 1 (attack VFX, 10 files):** needle/tracer bullets (identity
  atlas rebuilds from them), barrage dart, grenade/mine bodies,
  pressure + broken-heat rings (ring normalized onto the damage edge),
  spin glow, impact burst (renderer loads art, procedural bake kept as
  fallback), judgment_mark (NEW — Precision V5 draws it over exposed
  Weak Points and Firing Squad positions).
- **Batch 2 (accessory icons, 8 files):** Trauma (stitched ember heart —
  retry wording worked), Plot Armor, Second Breakfast, The Missing Pālis,
  Firestone, Oakheart, Crusher's Ring, Ring of Regeneration.
- **Provenance:** user-generated 2026-09-26, processed in-repo (trim,
  LANCZOS downscale, alpha verified; originals at repo root under
  "ChatGPT Image Sep 26 ..."). Batches 3 (set icons) and 4 (hub props)
  pending on the user's side.

### batches 3-4 — user-supplied set icons + hub props (2026-09-26)
- **Batch 3 (18 set icons):** Conduit (copper/teal machines), Gravemarch
  (funeral iron + bone + ember), Lattice (pale crystal in gold). One
  family language per set; installed over the .tres icon paths.
- **Batch 4 (8 hub props):** statue, merchant stall, gear rack, ascension
  obelisk, gate arch, crates, Beka's alcove cushion, lamp posts —
  masters in assets/textures/hub/, placed by HubWorld._prop() at fixed
  world heights (statue 130, stall 96, obelisk 104, rack 72, crates 56,
  arch 96 over the departure gate, cushion 30 under the cameo, lamps 84
  at the walk-loop corners). This answers the playtest review's "no
  visual furnishing" finding at the placement level; composition tuning
  is a rendered-pass concern.
- **Provenance:** user-generated 2026-09-26; originals at repo root.

### hub composition reference (2026-09-26, user-supplied mockup)
`docs/art/reference/2026-09-26-hub-composition-reference.png` — the
rendered-pass target for the courtyard: a circular paved plaza around a
glowing rune obelisk/fountain centerpiece, station bays as real
structures (stall, forge-like gear corner), banners, trees, and warm
lamp pools. Its "generated in code" panel matches the existing
floor → prefabs → props/lighting build order in HubWorld. Current prop
placement (batch 4) is the first step toward this; plaza shape, banner
rows and greenery are open work.

### batches 5-6 — curses + batch-4 item icons (2026-09-26)
Batch 5: the eight curse relics, each inside the family's thin broken
murky-violet ring (fresh GPT session anchored on beka_stand + trauma +
bonekey samples). Batch 6: 7-Mile Boots (one boot glowing with
distance), Grandma's Bazooka (knitted rose cozy), IDFK (blank-tagged
cube, question-mark wisp), Bazinga (jester box, golden sound rings) —
replacing the day-one placeholders. THE ART PROGRAM IS COMPLETE: every
item, curse, set piece, companion, attack VFX and hub prop now carries
user-supplied art; remaining visual work is rendered-pass composition,
not assets.

### batch A — pixel-art bullets, beams, burst motes (2026-09-27)
- **Files (10):** `vfx/ranged/bullet_player.png` (72x16), `bullet_enemy.png`
  (72x16), `beam_core.png` (64x32, replaces the procedural gradient),
  `beam_cap.png` (96x96, replaces the procedural starburst);
  `vfx/motes/mote_hit_spark.png`, `mote_ember.png`, `mote_star.png`,
  `mote_sparkle.png`, `mote_dust.png` (64x64, white, coloured by each
  burst's ramp), `sigil_cast.png` (96x96).
- **Provenance:** user-generated 2026-09-27 from the prompts in
  `docs/art/2026-09-27-pixel-art-vfx-batches.md` (Batch A); originals kept
  in `incoming/batch-a/` (a `.gdignore` keeps the editor from importing
  them). Processed in-repo: bullets cropped to the 4.5:1 quad aspect with
  the head at the leading edge, everything premultiplied box-downscaled,
  alpha verified, zero alpha on every canvas edge.
- **Bound in:** ProjectileSimulationManager (four families: 0 player body,
  1 needle, 2 tracer, 3 enemy body — enemy shots map to family 3 at
  upload; the two bodies draw untinted, needle/tracer keep the 45% tint;
  `bullet_shared.png` stays as the fallback body); the six
  `assets/vfx/world/bursts/Burst_*.tscn` (texture swap, scale_amount x8
  for the 64 px motes, 0.85 for the sigil). The Kenney particle PNGs are
  now unreferenced.
- **Known follow-up:** spitter (green) and herald (orange) shots used to
  differ by tint; with the baked enemy body they all fire the same red
  bolt. Two extra enemy bodies in a later batch restore that read.
- **Verification:** projectile battery + parse audit green headless
  (Identity 7, SlotReuse 17, Overflow 17, PooledRecycle 8, HandleCombat 25,
  EnemyTimeBase 4, ParseAudit 435); in-game look is the user's call.

### batch B — the pixel-art VFX kit (2026-09-27)
- **Files (10, `assets/textures/vfx/kit/`):** `crescent` (128), `ring` (128),
  `ring_large` (256), `ring_dashed` (128), `disc` (64), `spokes` (96), `fan`
  (64), `claw` (128), `bolt` (128x32), `streak` (64x16). White / pale grey
  sprites, tinted at draw time by each effect's own colour.
- **Provenance:** user-generated 2026-09-27 from the Batch B prompts in
  `docs/art/2026-09-27-pixel-art-vfx-batches.md`; originals in
  `incoming/batch-b/`. Processed in-repo (premultiplied box downscale, alpha
  verified); the fan, bolt and streak keep their origin or full span on the
  left edge by design.
- **Bound through:** `core/systems/vfx/VfxKit.gd` (class VfxKit): static
  draw helpers (`draw_ring`, `draw_ring_dashed`, `draw_disc`, `draw_spokes`,
  `draw_fan`, `draw_claw`, `draw_crescent`, `draw_bolt`, `draw_streak`)
  that place each sprite by the measured content extents and fall back to
  the primitive they replaced when the PNG is missing. Converted effects
  (32 scripts; glow+core primitive pairs became one tinted sprite, additive
  materials became normal blending): MeleeSlash, MagicImpact, SpokesBurst,
  Shockwave, ShockRing, PulseRing, CleaveArc, ArcLine (Line2D with the bolt
  texture stretched between two points), TeslaArc2D, TeslaPulseRing,
  HexBlinkBurst, ReflectPop, PerfectBurst, ParryWindow, SpiritSlash,
  SpiderExplode, EnemyMuzzleFlash, ChargeWindup, HeraldPulseRing,
  BomberHazardRing, EliteModifierMark (vampiric ring + fast streaks only),
  SpeedStreak, GateUnlockBurst, WardstoneAttuneBurst, WardstoneIdleAura,
  ProvidenceBurst, RetaliationNova, ShardLaunch, RegenerationRing, Bazinga,
  SevenMileBoots, Dignity.
- **Known differences:** dashed rings are always ten dashes (Herald had 14,
  Bomber 18); spoke bursts always fourteen spokes; the Spirit Slash and
  Tesla arc no longer wobble per frame (the Tesla bolt mirrors on each
  regeneration instead). `dash_count` / `spokes` / glow exports remain but
  no longer drive the drawing.
- **Verification:** parse audit 436 green; SetVfxPool (21, two checks
  updated for normal blending and the two-point textured bolt),
  EliteModifier 110, WorldIdleRedraw 24, StyleParity 39, ItemEffectRunner
  239, ItemBatch3/4, ManifestationSystem 162, EnemyAreaCombat,
  EnemyHandleTargeting, PerformanceRootCauseFix 29, BalanceRevision 10 all
  green headless. In-game look is the user's call.

### batch C — telegraphs and auras, kit part 2 (2026-09-27)
- **Files (10, `assets/textures/vfx/kit/`):** `cone` (128), `hexagon` (128),
  `plates` (64), `crack` (128x48 strip), `chevron` (32), `shield_arc` (64),
  `ring_wavy` (128), `ring_hex_wavy` (128), `fangs` (32), `splash` (64).
- **Provenance:** user-generated 2026-09-27 from the Batch C prompts;
  originals in `incoming/batch-c/`. Processed as Batch B (the cone and
  shield arc keep their apex / centre of curvature at the left edge; the
  crack spans the full strip width).
- **Bound through:** VfxKit `draw_cone`, `draw_hexagon`, `draw_plates`,
  `draw_crack`, `draw_chevron`, `draw_shield_arc`, `draw_ring_wavy`,
  `draw_ring_hex_wavy`, `draw_fangs`, `draw_splash` (constants measured at
  processing; primitive fallbacks). Converted (17 scripts): EnemyShootCone,
  EliteModifierMark (shielded hexagon, armoured plates, splitting crack,
  fast chevrons), FrontShieldVisual, ReflectShieldWindow, StaminaCoreAura,
  HexMarkAura, SpiderBite, SpiderExplode (droplets -> splash), SunderTear,
  PilgrimsMomentum, RedLine, AnchorRite, Loom, ReliquaryGuard, PlotArmor
  (now draws in local space via to_local), OakheartShield,
  HereticalCartography. Progress arcs, gauge ticks and stakes stay
  code-drawn on purpose.
- **Known differences:** chevrons are sized by the old V's span and keep
  the existing geometry (tip nearest the player, pointing along the
  heading); the hex mark's corners sit at the ring radius (the old polyline
  pushed them to 1.28 r); wavy rings roll at the old crest speed; the
  spider bite's dark puncture dots are gone.
- **Verification:** parse audit 436; SetVfxPool 21, EliteModifier 110,
  ManifestationSystem 162, ItemEffectRunner 239, ItemBatch3/4,
  EnemyAreaCombat, EnemyHandleTargeting, WorldIdleRedraw 24, StyleParity
  39, PerformanceRootCauseFix 29, BalanceHealthAccounting 34, all green
  headless.

### batch D — bodies and glyphs, kit part 3 (2026-09-27)
- **Files (11, `assets/textures/vfx/kit/`):** `missile` (48x24), `shard`
  (48x24), `spiderling` (48, rotated 45 degrees at processing so the head
  points +X; carries its own greens), `bracket` (48, corner anchored
  top-left), `triangle` (96), `plus` (48), `flame` (48, own fire colours),
  `coin` (48, own gold), `clock` (96, hand baked up), `lattice_mark` (48),
  `lattice_mirror` (48, delivered separately as d11).
- **Provenance:** user-generated 2026-09-27 from the Batch D prompts;
  originals in `incoming/batch-d/`. Sizes raised from the plan's 32 px so
  thin points survive the downscale.
- **Bound through:** VfxKit `draw_missile`, `draw_spiderling`,
  `draw_shard`, `draw_bracket`, `draw_triangle`, `draw_plus`, `draw_flame`,
  `draw_coin` (squash_x for the spin), `draw_clock` (+ a streak for the
  sweeping hand), `draw_lattice_mark`, `draw_lattice_mirror`. Converted
  (17 scripts + 1 scene): MagicMissileProjectile (Sprite2D body + streak-
  textured Line2D trail), SpiderlingVisual (+ the legacy Sprite2D in
  PoisonSpiderling.tscn hidden), PoisonSpiderling tail, CartographyMark,
  SigilMark, FloatingPlus, PairShatter, PairSlipstreamMote, ShardForge,
  ShardSplinter, TitheEmbers, ManifestationShardProjectile, Firestone,
  PilgrimsToll, DebtCollector, DeathRattle, LatticeMarkVfx.
- **Known differences:** Death Rattle's brackets are single corners
  (no bottom arm); the Debt Collector face takes the ring's ward red at
  the ring alpha; ember dots became small flames without the hot-to-ash
  tint; the lattice mark's first tick may sit up to 90 degrees from the
  old +X tick.
- **Verification:** parse audit 437; SetVfxPool 21, ManifestationSystem
  162, ItemEffectRunner 239, ItemBatch3/4, EnemyAreaCombat,
  EnemyHandleTargeting, WorldIdleRedraw 24, StyleParity 39,
  EliteModifier 110, all green headless. In-game look is the user's call.

### World walls — three-quarter kit (2026-09-27)

- **Files:** `assets/world/walls/kit/wall34_00..15.png` (one piece per
  connection mask, 256 x 368 = 64 x 92 px at 0.25), `wall34_window_h/v.png`,
  `wall34_fill_ne/se/sw/nw.png` (64 x 64 = 16 px corner fills for solid
  blocks).
- **Provenance:** procedural, `tools/design/build_wall_kit.py`, sampled
  from the brick band of the existing `wall_stone_straight_h/v.png`. Hand-
  made strips in `assets/world/walls/source/` (W1/W2 of
  `docs/art/2026-09-27-world-look-art.md`) replace the band when present.
- **Bound through:** `ChunkBlockVisualCatalog.KIT_TEXTURES` / `KIT_FILLS`
  (behind `three_quarter_walls`), `ChunkBlockRenderer` (Y-flipped quads,
  wall shadow offset), `CoverWall.gd`, `Level1Builder._rebuild_wall_visuals`.
