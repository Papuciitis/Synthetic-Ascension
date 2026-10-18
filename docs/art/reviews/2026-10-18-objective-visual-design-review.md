# Objective visual design review — 18 October 2026

## Verdict and scope

The objection is justified. The current forms do not yet feel integrated into this game's world. The Breach is the clearest failure: a decorated raised container with a hairline split communicates a collectible reliquary more strongly than an enemy-producing rupture. Its completed form remains visibly split. Changing that split from red to teal and adding a check does not communicate sealing.

The six painted forms are implemented. None should be called visually approved from these images. Wardstone and the Wager's scales have useful identities worth retaining; Breach needs a replacement composition. Functional verification does not establish visual fit.

Reviewed the actual pixels of **all 29 supplied current screenshots and all six source PNGs**: 15 frozen Segment 3 objective views and 14 final Segment 2 building/vault/hazard/cache-context views. Read the vision, current roadmap status, README, production art helper/shader, objective scripts, staged previews and both additional capture manifests. These are real terrain/HUD integrations but not played fights. No Godot process, gameplay change, new art, commit or push was made by this review chat.

**Coverage limit:** The Dangerous Alley Cache endpoint pictures were inspected, but no tagged cache reward pickups were present. Both the additional full native pass and cache-only pass record one failure, exit 1 and zero save writes; their useful images do not turn those runs into all-pass results. Do not infer a general production cache bug from this staged result. Building, both vault forms, cache context and the adjacent ritual hazard were inspected at both supplied sizes; their Reduced Motion/flashes-off variants were not supplied. The review of supplied evidence is finished; cache reward appearance and the live/state gaps listed below remain unverified.

## What the images actually show

### Breach — replace, highest priority

Evidence: `breach-normal.png`, `breach-small.png`, `breach-reduced.png`.

- The low round object sits in the upper part of each circular footprint. At small scale its mass reads as a black-and-brass puck; its red seam becomes a tiny vertical accent. The circle is more immediately legible than the source of danger.
- The right-hand completed object has the same silhouette and visibly open slit as the open object. Its teal seam even suggests an energized or beneficial opening. The checkmark supplies the completion meaning externally.
- The central object looks like another breach. Source confirms it is decorative: `build_presentation()` installs one at the objective root in addition to the three actual sites. This is a production affordance problem, not merely a screenshot annotation. Remove this duplicate or replace it with clearly non-interactive district signage. Do not add a fourth site.
- The bottom working sample's boundary/progress is cut off by the viewport in every condition. That clipping is a staging/layout fault; it does not prove the production asset is incorrectly cropped. The repeated mass-to-origin mismatch in fully visible sites is a separate production issue.
- The source's bright chains, many bevels and thick front wall make an intact treasure object. The dangerous interior occupies too little of the useful silhouette. At gameplay size the chain work turns into metallic texture noise.

Replace with a low rupture embedded in paving/soil: two separated irregular ground lips, a clearly visible dark cavity, a few broken containment clamps, restrained interior vermilion. The completed image must physically close or cap that cavity, with engaged clamps and a dead seam. Preserve the current world origin, spawn spread and seal radius; an illustrative crack is not a new damage footprint or collision obstacle. Do not depict enemies squeezing through a precise hole smaller than their actual spawn distribution.

### Wardstone — retain identity, rework integration

Evidence: all `sanctuary-*` views, left and lower-center.

The upright narrow stone is distinct and its base is much closer to a believable foot than the low props. Its occupied height is roughly one-and-a-half player heights in the normal view; it can remain a modest landmark. Keep the split obelisk/halo idea, simplify tiny metal detail and use terrain-compatible stone values. The bright narrow core can remain an identity accent.

The small capture edge and large active sanctuary edge convey different real areas, which is useful. But the outer sanctuary is faint enough to disappear into the moss at small size while the now-completed inner capture ring remains conspicuous. After capture, give the active sanctuary edge priority and quiet the old capture ornament. Keep a static anchored indicator; add a clear base/clamp change rather than relying only on the check.

Its two-second capture resets on leaving; it does not bank partial attunement like Relay. Activation also grants a checkpoint, healing, an outward defensive pulse and a Rite safeguard. Do not reuse a durable-progress visual for its incomplete capture. The sanctuary's persistent enemy slowing needs a stable area cue distinct from that one-time pulse.

### Exit Rite — retain threshold, rework perspective and hierarchy

Evidence: all `sanctuary-*` views, right.

The gate communicates a destination better than the generic shrines do. However, the source is strongly frontal, with a tall empty arch and little projected ground depth. In this overhead terrain it reads like a miniature façade placed on paving. It is roughly twice the visible player height, yet much of the channel zone surrounds its front and sides: a viewer could reasonably expect to walk through the door instead of stand anywhere in the large circle.

Use a more overhead threshold with legible feet and a ground ritual pad visibly related to the whole true channel zone. Keep its hollow interior. Simplify the cloth/bands into large readable shapes. The pale progress arc is presently the brightest, heaviest graphic in the panel; separate the exact boundary from progress and durable thirds using lighter weight and distinct filled seal shapes. Safeguards must have a different shape/placement from durable thirds. Do not imply an exit is ready while locked, or an unused safeguard is a completed channel third.

Only channeling at about half progress is shown here. Locked, newly ready, draining, complete, zero/maximum safeguards and durable-third recovery are unreviewed visually.

### District Relay — rework strongly

Evidence: all `relay-*` views.

The three small receivers are thin, dark and difficult to identify against moss; the larger center receiver and connecting lines attract attention instead. Source confirms the center is a separate decorative presentation, while the three components perform the action. That distinction is insufficiently explained by size alone.

Keep the receiver/network concept, widen its few essential prongs and lens, remove subpixel wire/jewelry detail and give the component base a clearer contact shape. Make the center a visibly different passive junction with no invitation to attune, or remove its prop while retaining truthful network cues. Completed components should have an obviously shuttered/disconnected receiver plus a static completion mark. Working components can visibly align a latch or segments; do not make an untouched node look already silenced through general darkness. Connections belong below actor silhouettes and must not look like attack beams.

Each component takes 1.1 seconds and preserves partial progress on leaving. Its stored partial indicator should remain steady, while Breach and Vigil need a distinct draining cue when their progress actually falls.

### Ward Vigil — rework strongly

Evidence: all `vigil-*` views.

The blue basin is readable as a device, but its mass sits above the center of a very large ring, making the area feel detached from its source. The broad low source image is tilted toward the viewer, with a deep front wall and detailed teeth. It needs a flatter ground construction and less metallic trim. The large thin boundary plus thick progress arc becomes a large diagram over the terrain.

Keep the hold-area identity: a low ward engine or embedded plate, with one strong central form and stable inward-facing boundary marks. Holding should visibly engage a static brace/closed ring motif; draining should show broken/receding segments and an outward/downward marker plus the existing explicit text. Current holding/draining device silhouettes are essentially identical; blue/orange boundary hue and captions carry the distinction. Use shape differences at rest. There are two staged examples here, not evidence that production spawns two vigils.

### Wager Shrine — retain scales, rework communication

Evidence: all `wager-*` views.

The balance is the strongest immediately recognizable action metaphor in this packet, and the ivory central shape survives minification better than Relay's lens. Keep it. Simplify fine chains and cloth print; give the base a matching contact treatment. Its spent version becomes a grey silhouette with a dark ring and risks reading as an unlit interactable, rather than settled.

Source verifies that standing spends Followers as tiers rise, stepping out settles, and unaffordable tiers can be refused to protect reconstruction. The static staged `COVENANT • 43%` label communicates odds but not the next payment or the crucial exit-to-settle action. Preserve tier pips, distinguish paid tiers from the next dwell progress, and show a compact truthful prompt: current stake/odds, next cost when applicable, and “Step out to settle.” A closed collection tray, lowered/locked beam or covered bowls should make the spent form unmistakable without color. Show refusal explicitly without a looping warning. These are presentation proposals, not changes to prices, odds, timer or settlement rules.

The staged view manually sets the tier and art state while keeping the player elsewhere; it is not evidence of a live purchase or successful settlement. In production the next purchase occurs every 2.2 seconds, so a static tier label alone cannot communicate the approaching financial commitment.

## Formerly omitted forms — additional direct visual review

The following judgments use the final images in `docs/art/reference/2026-10-18-objective-review-omissions/` and its `manifest.json`. The top-right explanatory cards and underneath state labels are review staging, not proof the ordinary game presents those exact instructions persistently. An earlier in-progress capture briefly showed roofs remaining over actors; the final interior/reward pairs show the correct cutaway. The earlier capture is not a production roof-fade finding.

### Cursed Vault — create a distinct physical identity, P1

Evidence: `cursed-vault-states-1280x720.png` and `cursed-vault-states-960x540.png`.

The closed version is a translucent purple disk, channeling adds a purple progress arc, and opened/spent becomes a faint outline. There is no visible vault body, container, reward chamber or physical opening. At small size the closed disk resembles a generic placed spell, while the spent circle can pass for another usable area. The staged words “CLOSED” and “OPENED / SPENT” provide meanings the actual shapes do not. This is a missing visual identity, not an alignment problem in the six painted assets.

Give it a compact recessed locked strongbox or civic reliquary with a recognizable lid and reward aperture, distinct from Breach's irregular rupture. Closed: intact locked cover. Channeling: clearly releasing fasteners and a separate truthful progress cue. Opened: lid displaced, cavity visibly empty/spent after payout. Keep the 64 px activation edge and the existing three-second hold/exit decay. It must not imply a click-only chest or an instant free pickup.

Because opening gives a guaranteed Manifestation while summoning a hunter/wedge and sealing healing for 45 seconds, make the cost legible *before* the hold finishes. Pair a compact reward symbol with an explicit warning and healing-lock symbol; do not bury the price in decorative runes or make purple alone mean danger. The packet manually stages the opened flag and does not demonstrate actual vault reward presentation or the cost sequence. Request one genuine open/payout/cost transition before approving those cues.

### Rite Last Chance — same vault family, explicit sacrifice variant, P1

Evidence: `exit-rite-last-chance-1280x720.png` and `exit-rite-last-chance-960x540.png`.

Here the little purple disk intersects the Rite's large gold perimeter near its upper-right side. The gate, nested center sigils, thick outer arc, durable diamonds, safeguard pips and “LAST CHANCE” caption all compete. At 960×540 the vault's three dots are tiny; they do not explain that *every* safeguard will be spent. The overlapping circle can be mistaken for part of the exit ceremony or a helpful attached buff.

Use the same physical vault language as the ordinary Cursed Vault, with a distinct three-seal sacrifice fixture and a persistent nearby cost prompt: “Guaranteed Manifestation • spends all safeguards • no healing for 45 s.” Match the three-seal shape to the Rite's actual safeguard identity without copying its durable-third marks. Show those seals broken/emptied on purchase; show spent state on the vault. Unlike ordinary Cursed Vault, this variant does not add the hunter/wedge encounters, so do not copy that extra cost warning.

Preserve the existing placement at radius + 32 px opposite the player and its unlock at 85% channel. Do not move the real target inward just to tidy the composition: crossing the Rite edge and the small reachable overlap are gameplay. Use a clear silhouette, draw order, label separation and boundary styling to disentangle the two zones. Add a boundary-crossing interaction sample, since these stills do not establish whether the player understands the cost or the trade-off under pressure.

### Searchable Building — retain architecture, rework the invitation and encounter states, P1/P2

Evidence: all six `searchable-building-{exterior,interior,reward}-{1280x720,960x540}.png` images.

This form already belongs to the world better than an isolated imported shrine: it uses the same paving, generated walls and roof as adjacent architecture. The roof cutaway in the final interior view exposes a recognizable enclosed encounter with actual enemies and consistent actor shadows. Retain this world-based form.

The exterior is nevertheless almost indistinguishable from the neighboring building. Its entrance reads as a rectangular missing piece of roof/wall, without a clear threshold, reason to enter, or indication that this particular room is searchable. A distant navigation arrow does not supply a local action cue. The repeated bright roof tiles dominate the approach; inside, the wall brick detail competes with relatively small dark enemies, and the floor is nearly the same paving as the street. It reads as an empty walled court more than a searched room. The reward view visibly adds a small pickup near the player, but the room itself barely communicates the transition from guarded to cleared.

Give the existing real doorway a modest threshold frame, overhead plaque/lantern or recognizable search mark using the same world materials. On approach provide the action “Enter and clear security,” since entering starts the encounter rather than opening a shrine channel. Inside, a quiet floor-value separation and a few sparse appropriate service-room elements can establish place without blocking the existing walkable encounter space. Keep enemy silhouettes clearer than masonry detail. Make remaining security and cleared state explicit, then make the real floor reward easy to spot. Clear the invitation after completion; preserve any visible uncollected loot. No collision, spawn count, doorway size or room-clear rule change is implied.

This is one actual generated parcel. It does not establish every procedural doorway, interior or authored Segment 1 room. Segment 1 Loading Office, Service Warehouse and Maintenance Kiosk use related building/IndoorVolume behavior but different architecture and rewards; carry the state-language guidance forward and inspect their own entrances before calling them approved. Guided story navigation, NPCs and opening illustrations are outside this world-objective art review.

### Ritual Interference — adjacent hazard, not a completable objective; rework state language, P1

Evidence: `ritual-interference-hazard-1280x720.png` and `ritual-interference-hazard-960x540.png`.

The entire visual is a very large, thin green double circle with four ticks, covering much of the screen. Its interior is ordinary terrain; there is no visible center or death/revival motif. Green, a clean circle and cardinal ticks resemble a beneficial sanctuary or an objective area far more than “enemies killed here rise again.” At small size it remains a readable circle, but its meaning remains absent. This semantic collision affects the Wardstone/Vigil grammar as well.

Preserve the true 420 px effect boundary. Distinguish hazards with a broken/toothed contour and a small static corpse/return symbol or similar unambiguous warning; a stable “Killed enemies rise once” cue is more valuable than another glow color. Keep any interior markings sparse so actors and hostile tells remain readable. At an actual affected corpse, display a local return mark and honest resurrection countdown through the 1.6-second interval; remove it when the revival is no longer possible. Never add a completion check or holding-progress language to this hazard. The provided still contains no marked corpse or resurrection, so those transitions are not visually reviewed. Duration/expiry also needs a quiet end cue, distinct from successful objective completion.

### Dangerous Alley Cache — context reviewed, reward appearance unverified

Evidence: `dangerous-alley-cache-endpoint-1280x720.png`, `dangerous-alley-cache-endpoint-960x540.png`, folder README and `cache-manifest.json`.

These show ordinary street paving at an intersection between roofed buildings and mossy ground. No distinct stash, reward pickup or endpoint marker is visible. The player is outside the framed endpoint context, so these views also cannot establish local pickup-to-player scale. Without the staged heading, I would read this as an ordinary junction rather than a deliberate optional destination.

Mechanics specify one or two loose tagged item pickups at a dangerous alley endpoint, completed by collecting the tagged reward. There is no authored chest body to critique. In this seeded staged sample the expected pickups were absent even after streaming and extra settling; therefore their visibility, outlines, rarity color and exact placement cannot be judged. The empty images establish the observed absence, not whether streaming, staging, pickup lifecycle or production generation caused it. Investigate that finding separately before approving new art.

Once actual reward presence is established, retain the street-based identity. Use a modest spatial destination cue—a service recess, discarded wrapping or opened supply staging around the actual pickup—and a clear item silhouette/contact cue that works on both moss and pale stone. Keep the reward visible through nearby roof edges and wall detail. Any dressing must remain secondary to the real collectible; an unopenable decorative chest would introduce another false interaction. The approach cue should point to this optional pocket, not compete with the primary objective navigation. After collection, remove the reward invitation and leave a quiet exhausted-site cue only if it helps orientation. Verify with the real tagged pickup and normal collection event, not a painted replacement.

Priority: resolve the missing reward evidence before visual sign-off; then P2 for destination dressing and pickup readability, potentially P1 if actual gameplay reproduces an unreadable or absent reward. No production root cause or code fix is claimed here.

## Shared causes and visual language

### Confirmed placement evidence

`ObjectiveWorldArt.configure()` scales by full canvas height and uses `offset.y = -0.35 * canvas_height`. A centered Sprite2D therefore puts the world origin at source coordinate `(0.5W, 0.85H)` for every image. There is no measured per-prop contact anchor. This is confirmed code behavior; the exact corrected anchors require an integrated prototype.

Measured source alpha bounds below use alpha >= 128, with right/bottom exclusive. Bounds identify padding, not the correct physical foot:

| Source | Canvas | Opaque bounds x0,y0,x1,y1 | Height used by production |
| --- | --- | --- | ---: |
| Wardstone | 1145×1374 | 283,13,869,1298 | 142 world px |
| Exit Rite | 1145×1374 | 19,2,1130,1366 | 184 |
| Relay | 1201×1309 | 260,29,981,1288 | 122 center / 83 sites |
| Vigil | 1536×1024 | 246,33,1280,940 | 105 |
| Breach | 1536×1024 | 80,71,1462,968 | 92 center / 100 sites |
| Wager | 1312×1199 | 153,10,1170,1188 | 120 |

These canvases have different proportions and margins. Breach's opaque mass is about 135 world px wide at a nominal height of 100; Relay sites are about 46 wide at a nominal height of 83. One nominal-height rule cannot establish consistent object scale. Horizontal opaque bounds are broadly centered: this is not evidence of a massive left/right alpha-padding error. The more serious perceived centering issue is vertical ground-footprint placement and composition.

For the Breach, the lowest opaque pixel currently falls about 9.5 world px below the origin; for Vigil about 7.1 below. Thus “the entire sprite is above its ring center” would be inaccurate. The important question is where the *center of its contact footprint* lands. The substantial front wall and generic 85%-height pivot put most of these low forms above that center. For an upright stone, a base-contact anchor near the bottom is sensible; for a low crack or plate, place the center of its ground footprint at the gameplay origin. A hanging cloth tip is never a reliable anchor.

Recommend per-asset source-pixel metadata: contact-foot/ground-footprint center, intended occupied width or height, ground footprint bounds, and optional canopy/foreground split. Compute the draw offset from the chosen anchor, keep all gameplay nodes and radii fixed, and inspect with a temporary origin cross. Use separate treatment for upright and embedded forms. Do not auto-center alpha bounds or use their bottom edge universally.

### Material, perspective, lighting and edges

Confirmed from images: the set shares charcoal/brass/ivory, but its highly finished chipped bevels and jewelry density differ from the player's compact, strongly outlined sprite and the terrain's broad muted, weathered surfaces. At small size, those details collapse to dark masses with scattered bright metal accents. The colors are not generally oversaturated across the entire prop; the stronger mismatch is detail frequency, isolated contrast and UI edge weight. Saturating or glowing them more would worsen it.

The low objects show large top ellipses and substantial frontal walls; the gate is almost frontal. The resulting camera language is inconsistent within the set. Normalize projected depth against the actual pavement and player, using a common overhead angle. Keep upright height where meaningful, with top planes appropriate to the camera.

Terrain and player show environmental/contact shadows; these props lack a convincing shared directional contact treatment. Source previews contain soft background-looking haze around the low forms, but alpha measurement is necessary before calling that a baked rectangular background: measured corners are transparent (one Wager corner is alpha 1), and alpha 16/128 bounds are very similar. Do not diagnose an opaque rectangle. Use a small terrain-aware contact shadow below the base, a consistent cast direction where warranted, and sparse grit/edge breakup. A contact shadow must not become another glowing pad or hide the true boundary. Evaluate both moss and pale paving.

Retain deliberate outlines and a few broad highlights that survive minification. Match the existing world style through simplified painted masses and restrained warm metal; do not apply a hard pixel filter to a detailed source and assume it becomes compatible pixel art. Choose final occupied gameplay size before deciding detail.

### Boundaries, hierarchy and occlusion

The exact rings are useful gameplay information. Keep their true centers and radii: Ward capture 56, modified sanctuary from `get_stability_radius()` (baseline 220), Rite script radius 168, Relay 96, Vigil 190, Breach 132, Wager 118 world px. Rite's scene resource starts at 92 but `_ready()` synchronizes it to the exported script radius; do not use the old resource number to redesign the visible edge.

Use a consistent thin exact boundary with modest dark support; reserve the stronger progress accent for current activity. Keep completed status legible while reducing completed-site visual competition. Progress can be inset or otherwise distinctly styled if the exact interaction edge stays honest. Do not project the circular interaction footprint into an ellipse merely to match the painted object: it must still describe the actual distance test. Remove ornamental ticks that convey no state; retain useful cardinal or state shapes. Never shrink radii to fit the sprite.

Current world labels, repeated giant arcs, checks and top-right objective text create competing explanation layers. The small top-right panel is cramped under the backpack in these staged views; examine ordinary HUD layout before moving it based solely on staging. Keep a stable task summary, local action/state near the active site, and clear world geometry. Labels must not be the only way to tell a closed object from an open one.

The helper uses relative `z_index = 4`; primary objective parents use 35 and Wager uses 34. This is more consequential than reading 4 in isolation. The source establishes fixed layering, but these staged images do not show actor overlap. Test front/back actor traversal before prescribing a particular z value. Ground cracks/shadows should draw below feet; tall portions can occlude actors behind while preserving those in front; essential hazards must remain visible. Do not put an entire opaque low prop permanently above actors merely to keep its artwork visible.

## Coherent directions

1. **Weathered city containment — recommended.** Embedded street infrastructure, broken clamps, repaired paving, dark stone and restrained brass. Upright ward/exit landmarks; receivers as machines; breach as an actual rupture. Broad painted masses, limited trim, one meaningful state accent. This matches the present city and supports synthetic-occult escalation.
2. **Ritual civic machinery.** More substantial authored devices, clear mechanical moving/locked states, institutional materials. Good for Relay/Vigil/Wager, but needs disciplined scale and must not turn every objective into a shrine.
3. **Abstract occult seals.** Mostly flat engraved ground diagrams with a few raised elements. Strong overhead readability and inexpensive state variants, but risks making all actions interchangeable circles and loses the world's material identity if used everywhere.

Use direction 1 as the shared foundation, borrowing mechanical state changes from 2. Direction 3 should supply sparse boundary grammar, not replace every physical prop.

## Order of work

| Priority | Objective/system | Decision | First concrete change |
| --- | --- | --- | --- |
| P0 | Breach | Replace composition | Embedded open rupture versus physically closed seal; remove decorative fourth duplicate |
| P0 | Placement | Rework | Ground-footprint anchors for low props, base-contact anchors for upright ones; preserve mechanic origins |
| P1 | Common integration | Rework | Match camera, broad material values, contact shadows and boundary weight in real terrain |
| P1 | Vigil | Rework | Ground device and static hold/drain shapes tied to actual area |
| P1 | Relay | Rework | Readable component silhouettes, clearly passive central junction, physical silenced state |
| P1 | Exit Rite | Rework | Overhead threshold plus honest channel zone; distinct thirds and safeguards |
| P2 | Wardstone | Keep identity/rework finish | Simplify stone/metal and prioritize active sanctuary over completed capture ring |
| P2 | Wager | Keep scales/rework states | Paid-tier/next-cost/settle prompt; structurally spent silhouette |
| P1 | Cursed Vault / Last Chance | Add physical identity/rework cues | Intact versus opened vault; explicit reward/cost; Last Chance consumes the actual safeguard identity |
| P1 | Ritual Interference hazard | Rework | Warning shape and corpse-return cues distinct from beneficial hold zones |
| P1/P2 | Searchable Building | Keep architecture/rework affordance | Mark real entrance, quiet interior contrast, guarded/cleared/reward states |
| Evidence first, then P2 | Dangerous Alley Cache | Retain street/pickup identity | Resolve missing real-pickup evidence, then add restrained destination/pickup cues; no false chest interaction |

## One-Breach integrated prototype, before bulk regeneration

Make exactly one candidate breach site in the actual generated terrain with the real player/HUD and existing radius. Produce open, halfway sealing, interrupted/decaying and sealed states sequentially at the same origin. Include the existing version beside the candidate in a comparison sheet, but judge the candidate alone in a real gameplay frame as well. No decorative fourth breach.

The art brief is a shallow irregular wound through paving with a readable dark cavity; only a few broken metal restraints; broad low-value stone; one restrained red interior accent. Sealed means an intact cap or closed lips held by engaged restraints, without a glowing open teal wound. Shape must explain completion in a still frame. Use a neutral temporary silhouette first if needed to establish occupied width and footprint anchor before requesting final paint.

Capture 1280×720 and 960×540 on paving and moss, each with normal settings and Reduced Motion/Combat Flashes Off. Add temporary origin cross/radius overlays for inspection, then remove debug overlays for the aesthetic judgment. Include player in front, behind, on center and crossing the boundary; include a real spawn and a crowded fight sample later. Parent is assembling evidence; this review does not authorize or run a new game instance.

### Image-based acceptance checklist

- [ ] At unzoomed small-window size, an unfamiliar viewer can point to the dangerous source and the place to stand without reading the heading.
- [ ] Open versus sealed is obvious in grayscale and with all animation frozen; sealed has no open cavity. A check supplements the physical change.
- [ ] Sealing and decay have distinct static progress/direction cues; no bright flashing or hue-only dependence.
- [ ] Ground footprint aligns with the actual interaction origin; a cross lies within the intended contact patch. Upright anchors are assessed separately.
- [ ] The true boundary matches entry/exit behavior. Decorative cracks, shadows and progress do not imply another radius.
- [ ] Player remains readable on all four sides, and ground elements do not cover actor feet or essential attack tells.
- [ ] Contact edge/shadow belongs to both moss and paving; no sticker halo, unexplained hover gap, or rectangular matte is visible.
- [ ] At gameplay scale, broad stone shapes and restrained metal survive; source-resolution detail is not required to identify the object.
- [ ] The objective is easier to read than background dressing but does not outshine player/hazard focus through a huge high-value ring.
- [ ] Frame contains exactly the three real breach sites when showing the whole objective; working sample is not clipped by presentation staging.
- [ ] Real spawn evidence agrees with the proposed source imagery. Crowded movement, hazard layering and readable state changes receive a separate played-fight check.
- [ ] Judge this prototype in the actual game before any mass regeneration. A technically correct anchor is only one acceptance item.

## Reviewed-image register

All entries below were opened through `view_image` and inspected. Full capture root: `.superpowers/sdd/2026-10-18-playtest-feedback/abilities-objectives/captures/`.

| Panel | 1280×720 normal | 960×540 small | 960×540 Reduced Motion + Flashes Off |
| --- | --- | --- | --- |
| Sanctuary | [x] sanctuary-normal.png | [x] sanctuary-small.png | [x] sanctuary-reduced.png |
| Relay | [x] relay-normal.png | [x] relay-small.png | [x] relay-reduced.png |
| Vigil | [x] vigil-normal.png | [x] vigil-small.png | [x] vigil-reduced.png |
| Breach | [x] breach-normal.png | [x] breach-small.png | [x] breach-reduced.png |
| Wager | [x] wager-normal.png | [x] wager-small.png | [x] wager-reduced.png |

Source PNGs inspected individually: [x] wardstone_v1.png; [x] exit_rite_v1.png; [x] relay_v1.png; [x] vigil_v1.png; [x] breach_v1.png; [x] wager_v1.png. Alpha bounds measured directly using Pillow; no image edits were performed.

Additional final packet, each opened individually through `view_image` after the parent reported it ready:

| Form/state | 1280×720 | 960×540 |
| --- | --- | --- |
| Cursed Vault closed/channeling/spent | [x] cursed-vault-states-1280x720.png | [x] cursed-vault-states-960x540.png |
| Rite Last Chance | [x] exit-rite-last-chance-1280x720.png | [x] exit-rite-last-chance-960x540.png |
| Searchable Building exterior | [x] searchable-building-exterior-1280x720.png | [x] searchable-building-exterior-960x540.png |
| Searchable Building interior | [x] searchable-building-interior-1280x720.png | [x] searchable-building-interior-960x540.png |
| Searchable Building reward | [x] searchable-building-reward-1280x720.png | [x] searchable-building-reward-960x540.png |
| Ritual Interference hazard | [x] ritual-interference-hazard-1280x720.png | [x] ritual-interference-hazard-960x540.png |
| Dangerous Alley Cache endpoint | [x] dangerous-alley-cache-endpoint-1280x720.png | [x] dangerous-alley-cache-endpoint-960x540.png |

Total reviewed: **15 original + 14 additional = 29 screenshots**, plus **6 source PNGs**. The cache pair is context/absence evidence, not a reviewed cache reward sprite. Both additional manifests and their README were read.

Additional acceptance checks: vault closed/opened differs by physical shape in a frozen grayscale frame; Last Chance cost is understandable before commitment and distinct from ordinary vault cost; building entrance is discoverable without the staged heading, interior enemies outrank wall texture and clearance leaves a readable reward; ritual hazard cannot be mistaken for sanctuary and its affected-corpse cue matches the actual resurrection lifecycle. Repeat at small size and with Reduced Motion/flashes off, since these additional twelve images do not supply that settings comparison.

Representative published current views: [Breach](../reference/2026-10-18-abilities-objectives/breach-normal.png), [Sanctuary / Rite](../reference/2026-10-18-abilities-objectives/sanctuary-normal.png), [Relay small](../reference/2026-10-18-abilities-objectives/relay-small.png), [Vigil reduced](../reference/2026-10-18-abilities-objectives/vigil-reduced.png), [Wager small](../reference/2026-10-18-abilities-objectives/wager-small.png).

Additional examples: [Cursed Vault small](../reference/2026-10-18-objective-review-omissions/cursed-vault-states-960x540.png), [Last Chance small](../reference/2026-10-18-objective-review-omissions/exit-rite-last-chance-960x540.png), [Building exterior](../reference/2026-10-18-objective-review-omissions/searchable-building-exterior-1280x720.png), [Building interior](../reference/2026-10-18-objective-review-omissions/searchable-building-interior-1280x720.png), [Ritual hazard](../reference/2026-10-18-objective-review-omissions/ritual-interference-hazard-960x540.png), [Empty planned cache endpoint](../reference/2026-10-18-objective-review-omissions/dangerous-alley-cache-endpoint-960x540.png).

Reduced-setting frames preserve the important drawn rings/marks in this frozen packet. They do not establish motion quality or prove the settings distinguish all live state transitions. Dense-combat occlusion, approach discovery, full Rite state readability and human reaction time remain untested here.
