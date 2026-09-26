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
  `bullet_shared` (batched pool quad, grayscale, tinted per instance),
  `needle_bullet`/`tracer_bullet` (reserved for per-discipline layering),
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
