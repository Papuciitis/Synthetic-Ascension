# Atmosphere and scene-depth audit

20 October 2026. Read-only implementation investigation, with this scratch note
as its sole write. No runtime edits, engine runs or Git operations. The latest
direct user request authorizes developing climate/light/atmosphere across the
game while retaining the bright temperate medieval-industrial city, readable
combat, checked local commits and the existing publication boundary. Proposed
profile values and weather choices below are implementation/design candidates,
not previously approved climate canon or native acceptance.

## Finding

The current environmental atmosphere is substantially identical in every Game.
The fourteen themes select different terrain, gentle floor/ground tints and
layout parameters, but no theme supplies ambient illumination, cloud cover,
weather, wind or haze. The strongest screen-wide lighting cue is the same
camera-relative warm multiply/vignette everywhere. Universal blue additive
fireflies further make ordinary places share a supernatural ambience.

This supports the user's observation that shadow additions alone have left the
game flat. An atmosphere change can establish exposure, sky condition and local
air, but architectural planes, contact, source scale and inhabited composition
must supply the actual volume. The concept-fidelity audit explicitly requires
both and rejects a universal brightness/filter change as the sole answer.

## Governing evidence and ownership

- `docs/SYNTHETIC_ASCENSION_VISION.md`: immediate combat readability and a world
  that responds to escalation; later strangeness is legitimate, but the vision
  does not assign magical weather to the named city districts.
- Full `docs/audits/2026-10-20-concept-fidelity-and-chat-audit.md`: retain bright
  temperate daylight, limestone/plaster, slate/clay, industrial retrofits,
  connected inhabited frontage and real massing; reject the excessively magical
  studies. A complete theme needs real structural/route identity beyond tint.
- Latest relevant roadmap entries: L2's subdued S7 moss and household-care
  foundation are provisionally kept; broad blue leaf carpet was rejected; wet
  earth, stronger local lawn and L3 domestic material/purpose work remain live.
- `docs/art/concepts/2026-10-19-segment-directions/COMMON_BRIEF.md` and README:
  all fourteen procedural themes are one city, with distinct useful
  infrastructure. They are concept targets, not implemented canals, viaducts,
  rail yards or an approved collision layout. Avoid night/noir drift, desert
  beige, bloom and random industrial/magical ornaments.
- New user steering permits atmosphere work beyond the previous narrow street
  slice. It does not make unimplemented district structures exist, erase the
  L2/L3 findings, or transfer Hub/S1 gameplay/architecture ownership.

## Source-backed implementation map

| Component | Current behavior | Consequence |
| --- | --- | --- |
| `core/systems/world/proc/SegmentThemePicker.gd:10` | Fourteen exact IDs across S2-S10; seeded alternatives at S4/6/7/8/9. S11+ falls back to `service_courtyards`. | Resolve atmosphere from selected exact theme ID, not segment number alone. Do not invent Beyond-the-Wall weather/biome canon. |
| `core/systems/world/proc/SegmentThemeData.gd:8` | Family, terrain, tint and density/layout fields; no climate fields. `apply_to_chunk_manager()` applies family/tint. | Add a separate immutable presentation-profile catalogue, or a narrowly explicit profile reference; keep generation values and RNG unchanged. |
| `core/systems/world/SegmentProcBuilder.gd:115,260` | Selects actual theme, generates plan, then applies theme rules. | This is a reliable selected-theme handoff. A new profile must not reroll the theme. |
| `core/systems/world/ChunkManager.gd:286` | Adds `WorldAtmosphere` in native `_ready`, before theme application; headless skips it. | Configuration must handle theme arriving after creation and subsequent segment resets. Headless tests alone cannot prove appearance. |
| `core/systems/world/atmosphere/WorldAtmosphere.gd:4` | One world-canvas ColorRect at absolute Z1400, follows camera; HUD CanvasLayers remain outside it. | Keep HUD separate. Replace the fixed art treatment with bounded profile behavior; do not claim this quad creates geometry or true plane lighting. |
| `world_atmosphere.gdshader:10` | Same grade `(1,.97,.92)`, shade `(.34,.31,.36)`, strength `.62`, screen light center `(.58,.42)` for every theme. | Camera-relative edge darkening can dim useful material separation and actors regardless of their real surface/exposure. It is not world-space cloud cover. |
| `scenes/game.tscn:37` | Floor is modulated `.72`; Fog is hidden; Fireflies and VisionRig always instantiate. | There are several multiplying/darkening owners. Measure final composition instead of adding another global wash. Hidden Fog is not functioning climate. |
| `core/systems/backgrounds/AtmosFireflies.gd:17` | Every Game has up to28 additive blue flies, alpha `.12`, independent randomized drift, no theme/reduced-motion gate. | Remove their universal city role. Natural nonemissive dust/pollen/insects belong only where physically justified; no need for a new magical particle family. Its private RNG does not consume Global RNG, but current motion is nondeterministic. |
| `scenes/vision/VisionRig.tscn:13` and `VisionRig.gd` | Lightweight mode disables indoor Fog/LoS rendering, uses indoor vignette `.22`, owns Exit Rite distortion and gameplay entity visibility outside lightweight mode. | Keep this owner intact. Climate must not alter indoor visibility, hidden entities, rite state, alpha_seen or reveal rules. Do not conflate atmosphere fog with FogOfWar. |
| `core/systems/world/WorldDepthStyle.gd:1` | Fixed top-right light; all projected shadows use southwest `(-.72,.50)`. | Keep sun azimuth coherent across profiles initially. Rotating only a weather light would contradict trees/buildings/actors and baked artwork. |
| `scenes/world/buildings/RoofOverlay.gd:182` and `roof.gdshader` | Existing lit/shaded roof slopes and eaves; nonrectangular footprints skip the simple gable. Some material quieting is S2-specific. | Profile sun/fill can complement actual plane shading. Irregular roof-plane structure still requires its own geometry-aware work. |
| `scenes/world/buildings/city_stone.gdshader` | Compresses source masonry into a narrow `.50-.67` cool range. | Atmospheric contrast cannot restore lost material grouping. Coordinate with L3 masonry work instead of hiding it under darker fog. |
| `WorldArt.gd` and GroundSplatRenderer | Original/derived ground material catalogue; semantic terrain IDs, moisture/stain and care masks; district tint affects ground. | Weather must not change terrain IDs, care ownership, ground cache, semantic wet/dry materials or generation. Keep muted S7 moss green. |
| `scenes/game.gd:318` | S1 uses Level1Builder but still instantiates ordinary Game atmosphere/flies. | Give authored S1 an explicit safe environment context; never accidentally treat S1 as S2 because picker fallback returns Service Courtyards. |
| `scenes/hub/HubWorld.gd:147,662` | Separate dusk CanvasModulate `(.58,.54,.62)` plus practical PointLight2Ds under lamps/braziers. | Hub owns an authored sheltered market-light treatment. Preserve it; no procedural city profile or second multiplying atmosphere should leak into it. |

## Proposed profile catalogue: all fourteen exact theme IDs

These are physical presentation proposals tied to existing identities, not
fourteen different seasons or storms in one short city journey. Different
exposure, shelter, moisture and working infrastructure can establish local
atmosphere under one coherent temperate sky. Broad weather should remain
plausible across neighboring districts.

`D` below is relative direct-sun contribution to environment plane/shadow
contrast, not a multiplier over every actor/HUD pixel. Fill is maintained near
neutral daylight. Cloud/mist/dust opacities are conservative initial bounds,
subject to native review, with zero emission where there is no physical source.

| Segment / exact ID | Physical light/air identity | Candidate profile and meaningful effects |
| --- | --- | --- |
| S2 `service_courtyards` | Open inhabited courts, warm neutral clear daylight; cool shade under eaves. | D1.0, neutral high fill, sparse broad cloud modulation at most6%; mild wind; no haze/rain/default particles. Distinct sunlit roofs and quiet shaded ground are the baseline. |
| S3 `checkpoint_lanes` | Cooler, more enclosed inspection approaches under broken/high cloud. | D.72 with high neutral-cool fill; broad slow clouds at most10%; no street fog or blue glow. Guard-room recesses are structural shade, not a black screen edge. |
| S4 `collapsed_ward` | Exposed broken masonry and dry mineral ground in daylight. | D.9, neutral fill, light drifting cloud; occasional neutral mineral dust only over real exposed scrub/rubble, at most2.5% veil locally. No invented burning ruins. |
| S4 `civilian_cutthrough` | Sheltered inhabited small lanes with sun breaks and reflected plaster light. | D.95, near-neutral warm fill, low cloud modulation; gentle wind and normal greenery; no routine airborne effects. Practical lamps only at actual fixtures. |
| S5 `inner_district_gate` | Weighty gate structures around a clear encounter court, cooler overhead sky. | D.8, high fill, broad cloud variation at most8%; sheltered air, no encounter-obscuring dust/mist. Real portals provide local depth. |
| S6 `industrial_cutthrough` | Working workshop/service environment in softened daylight. | D.78, neutral slightly warm fill; restrained neutral haze only when attached to an actual chimney/vent emitter. Current absent emitter anchors mean zero smoke, not a floating global smoke sheet. |
| S6 `ruined_services` | Abandoned plant and scrub, drier and more exposed than working services. | D.88, neutral fill, moderate wind; sparse localized dust at most2.5%; no working-stack smoke without a working source. |
| S7 `underpass_veins` | Open daylight outside, cooler sheltered arch/service pockets and damp substrate. | D.5 outdoors with generous cool-neutral fill; maximum2% local ground mist on meaningful damp ground; overhead shelter must come from actual geometry when built. No claim that global fog implements a viaduct. |
| S7 `canal_services` | Humid/damp water-service district with diffuse bright sky. | D.6, high cool-neutral fill; broad cloud modulation at most10%; at most4% shallow localized mist over actual damp/mud/drainage context. Existing moss/mud justify dampness; a continuous canal is still absent. Avoid cyan/blue wash. |
| S8 `rail_yard` | Exposed broad loading ground, dry airflow and open sun. | D1.0, neutral fill, few clouds; strongest broad wind among inner yards, sparse neutral dust only over actual dry earth. No fake trains/steam to compensate for absent rail topology. |
| S8 `military_staging` | Open controlled muster ground with a cooler broken-overcast feel. | D.75, high neutral-cool fill; slow broad clouds, moderate wind; no confetti/embers/fog. Real tents/barracks remain separate structural work. |
| S9 `outer_wall` | Most exposed grass/scrub approaches, moving air, clear broad daylight. | D1.0, neutral high fill, low cloud coverage, stronger wind; no blanket haze. Continuous wall mass/shadow is separate work. |
| S9 `siege_services` | Wall-side repair/service yards, exposed stone and working logistics. | D.82, near-neutral fill, intermittent broad cloud; sparse dust only at real dry service ground, localized steam only at an actual emitter. Do not introduce flames/war weather from the label alone. |
| S10 `gate_district` | Largest civic departure axis, imposing masses in clear readable daylight. | D.85, high neutral fill, broad calm sky; leave boss court and essential tell colors clear. No climactic full-screen storm by default; Exit Rite keeps its own authored distortion. |

All14 IDs should have explicit complete profiles and tests, including both A/B
alternatives; no accidental inheritance of an industrial emitter into a ruined
or civilian theme. Unknown ID and S11+ retain a neutral known fallback and an
honest unresolved beyond-wall identity. S1 and Hub use explicit separate contexts.

### S1 / Hub / DonJon contexts

- **S1 Institution:** exterior admission stone/service courtyard stays readable
  daylight, secured interior wings derive shade from authored rooms/roof state.
  An explicit `institution` presentation context can remove universal flies and
  avoid procedural fallback; no floor/layout/LoS reauthoring in this packet.
- **Hub:** retain its authored dusk and actual practical pools. A sheltered
  market can contrast with the city journey without adding procedural rain or
  a second sky grade. Changes to its unique UI/lighting require a separate
  deliberate review; the profile resolver should return an explicit bypass.
- **DonJons:** inherit outdoor theme sky in their real courtyard; enclosed rooms
  retain their roof/cutaway and VisionRig owners. Do not apply outdoor mist,
  rainfall or wind to revealed indoor floors without spatial shelter handling.

## Reusable implementation boundary

1. A small immutable atmosphere-profile catalogue keyed by actual theme ID and
   explicit S1/Hub context. Useful fields: sky/fill color, direct color/amount,
   environment contrast, cloud coverage/opacity/scale/speed, wind vector/strength,
   ground-haze amount/color/speed and emitter-kind/budget. No new terrain IDs,
   segment selection, seed mutation or save fields. Values are transient
   presentation data.
2. WorldAtmosphere owns one persistent bounded world presentation component per
   viewport. Configure it after selected-theme handoff and reset all fields when
   context changes. Retire the heavy common warm vignette as the source of
   district identity. Preserve the HUD's separate canvas.
3. Cloud fields must be anchored in world coordinates with a low-frequency shape,
   stable phase and a bounded local presentation clock. A cloud must stay over
   the same roof as the camera pans; screen-center darkening is not sunlight.
   Modulate environment direct contribution subtly; maintain ambient fill.
4. Connect profile direct/fill values to actual environment plane/material
   owners. Do not replace PlayerVisualController, enemy batch or pickup materials
   (they compose hurt/elite/cover/lock behavior). Air effects should remain below
   or conservatively weaker than essential combat presentation. Full-screen
   overlays above all tells require native occupied comparisons and hard opacity
   bounds, not assumptions.
5. Treat haze as shallow/local damp-air evidence, not a uniform gray curtain.
   Initial implementation can omit rain: roof shelter, splash/receiver and wet
   surface evidence do not yet exist as a complete weather contract. Do not add
   a heavy rain system merely to give every row an effect.
6. Gate/remove universal blue flies in ordinary daylight. If particles are used,
   draw a small bounded batch of neutral dust/pollen/insects only where source and
   terrain justify it; use coordinate/time hashing or a private explicitly
   seeded presentation generator, never `Global._rng`, global `seed/rand*`, or
   resource-generation RNG.
7. Reduced Motion freezes cloud drift/wind decoration and disables drifting
   particles; retain the static light/material identity. Never freeze engine
   time or combat simulation. No lightning, flicker or broad pulses are needed.
   Keep existing combat-flash settings, silhouette/elite/accessibility colors,
   hidden-loot eligibility and VisionRig/Exit Rite behavior intact.

## Why structural depth and atmosphere must develop together

- The current cast shadows already establish one sun direction. Broader sky
  fill/direct ratios should reinforce that direction; rotating a lone lighting
  filter would contradict painted and projected shadows.
- A roof needs distinct broad planes, eave contact, masonry returns and an
  attached foundation before haze can make it feel solid. Current irregular
  roofs skip the simple gable, so their plane problem cannot be solved by a
  vignette. Prefer geometry-aware roof sections or supported plane normals.
- Broad cool shade on a south-facing wall and a narrower contact darkening under
  eaves are different signals. Increasing every dark texture edge creates busy
  tiling instead of volume. Coordinate structural surface hierarchy with L3
  masonry rather than multiplying already compressed stone colors.
- Ground brightness and contact shadows must leave enemy silhouettes, loot and
  attack shapes readable. Grime/care/moisture remain semantic material cues;
  weather does not replace their actual masks or correct wet-mud repetition.
- Actual canopy/building per-pixel cover remains the visibility owner. Atmosphere
  may not turn an occluded enemy into a different reveal mechanism or darken an
  entire actor just because it is indoors.
- Missing street frontage, canal/rail connections or inhabited objects remain
  missing after a successful profile pass. Label the pass as climate/light/depth
  improvement, not all-theme environment completion.

## Bounded initial comparison and verification

**Native first:** same exact Game seed, theme, camera, zoom, HUD and actor
placements before/after, clear tips naturally. S2 seed16102026 home944996572
chunk(0,3), S3 an exact current guard-loggia sample, S7 seed4 Canal Services with
the existing actual damp-moss/wet-earth crop; record exact S3/S7 identities rather
than inventing coordinates. Produce normal1280x720 and small960x540 plus a
Reduced Motion / Combat Flashes Off sample. Include dry-earth and clear-sky
controls, player/enemy/elite/health/loot art, roof cutaway and one short occupied
moving sample. Freeze presentation phase only for paired stills, disclose it.

Compare broad roof/wall/ground value separation, actor-vs-ground silhouette,
wet/dry/care distinction, objective/attack colors, and whether S2/S3/S7 feel like
different exposures within the same city. At least one cloud moving sequence
must show slow coherent movement without frame-wide pumping or sliding with the
camera. Sampling timings are not performance acceptance; record actual frame and
resource cost on the compatibility renderer.

**Data/behavior tests:** all14 exact IDs and both alternatives resolve complete
distinct profiles; S1 and Hub bypass/explicit context; unknown/fallback stable;
climate changes do not alter global RNG state, terrain/route/roof/collision
hashes, authoritative enemy counts, visibility rules or save writes; profile
switch resets previous effects and material instances; world anchoring survives
camera pan and streaming; reduced motion stops weather motion while combat
continues; cloud/haze bounds hold and particles remain bounded. Tests should
exercise the resolver/configured materials and actual visual component, not grep
source strings or mirror the profile table.

Preserve focused WorldCover/player/enemy/pickup/roof tests when changed rendering
paths intersect them, plus appropriate ground/city checks and parse audit last.
Review actual S1/Hub as regression contexts even if their authored lighting is
deliberately retained. All14 data profiles can be checked before native rollout,
but three native themes do not establish final aesthetic acceptance for all14.

## Next implementation handoff

Wait for root's isolated worktree and explicit file ownership after the current
visibility packet commit. A sensible independent slice owns the profile
catalogue, WorldAtmosphere component/shader, an isolated atmosphere preview/test
and the minimal selected-theme handoff. Structural kit, shadow projection,
ground-care/material sources, VisionRig and Hub remain coordinated owners;
avoid parallel writes to them without root's allocation. No new bitmap is
currently necessary. Local commits only after relevant checks and source/native
evidence; remote publication remains with root under the current user direction.
