# Segment materials, weathering and atmosphere

Art lead direction, 21 October 2026. Requested by the human for the complete
segment set, alongside curation and a few missing usable assets.

**Make one temperate city with distinct materials, uses and exposure.** Fix the
blanket grey paving through surface selection and placement first. A stronger
colour filter over the same setts will not establish a district. Keep the
crooked routes, unequal plots, shared walls and visibly developing medieval city.

This packet supplies direction and source assets. It changes no game shader,
scene, placement, collision or generator. The later Linux runtime at
`3d1be8b0039ce96e65959958b0da10a799f8fcfb` remains held as described in the
[current lead review](../reviews/2026-10-21-linux-phase1-lead-review/README.md).
Its parked mood/weathering work should be checked against this brief before
integration. A source palette or decoded mask is not native aesthetic acceptance.

## References and deliverables

- [Accepted city reference](../concepts/2026-10-18-city-directions/08-mediterranean-medieval-industrial-city.png)
  and [complete segment plates](../concepts/2026-10-19-segment-directions/README.md).
  The lead viewed the common reference and selected plates; a delegated visual
  reviewer viewed all eighteen. Preserve their material/use distinctions while
  simplifying their dense tiny outlines at gameplay size.
- [Asset curation](ASSET_CURATION.md): exact existing paths, incoming versus
  integrated status, placement rules and small remaining needs.
- [New support pack](../../../assets/world/material_support/v1/README.md): fourteen
  data-only art profiles, an importable colour palette and four grayscale masks.
  The [palette board](../../../assets/world/material_support/v1/qa/palette_board.svg)
  shows material colour roles, not rendered lighting.

## Material direction for every procedural theme

All rows keep both slate and muted clay roofs. Change their emphasis and age;
do not assign a different roof hue to every district. Swatches in the support
pack are proposed sRGB midtone targets, not colours sampled from the paintings
and not shader multipliers. Retain natural variation within each role.

| Segment / exact theme ID | Ground and walls | Weathering with a cause | Light and air |
| --- | --- | --- | --- |
| S2 `service_courtyards` | Warm grey worn setts on used routes; olive lawn/earth in household pockets. Warm lime plaster above rough masonry. Clay and slate roofs, faded green shutters | Swept thresholds, boot wear, restrained damp at wall feet. Useful flower/herb plots and fruit trees beside some homes; other homes untended | Clear neutral-warm daylight, cool eave shade. Usually clear air |
| S3 `checkpoint_lanes` | Cooler stone inspection routes, compacted earth margins. Pale limestone, dark green iron, dull brass | Worn inspection paths, boot scuffs, rain below ledges, maintained upper stone | Cooler neutral fill and deeper sheltered recesses; slow broad cloud shade, no routine mist |
| S4A `collapsed_ward` | Broken paving, warm soil and dry scrub. Chalky exposed stone, old brick and dark broken timber | Pale fresh fractures against older faces. Rubble/growth collect at abandoned edges; keep a usable route | Open daylight with passing cloud. Mineral dust only beside real disturbed rubble |
| S4B `civilian_cutthrough` | Warm worn setts and irregular tended pockets. Patched cream plaster, clay, faded shutters, undyed cloth | Repairs of different ages, rubbed doorsteps, splash beside a fountain/washhouse | Warm reflected daylight in sheltered lanes; calm clear air |
| S5 `inner_district_gate` | Larger cool worn flags in the approach; unequal old edges. Substantial pale limestone, dark iron, small dull bronze/plum cloth accents | Rain below parapets, polished approach wear, strong portal contact; cleaner upper stone | Pale diffuse sky, substantial structural shade with readable fill. Clear encounter court |
| S6A `industrial_cutthrough` | Brown-grey packed yard earth and limited loading setts. Weathered lime/stone, restrained red brick, iron and dull copper | Soot above operating vents/stacks, oil at machinery feet, rust below fittings, handling wear on working routes | Neutral soft daylight; small attached smoke/steam plumes from operating equipment |
| S6B `ruined_services` | Broken routes, brown soil, neglected grass. Damaged lime, exposed brick, grey timber and oxidized iron | Long abandoned runoff, settled debris, weeds at idle equipment. Roof leaks and dark protected feet | Open slightly cooler daylight and wind. Abandoned stacks produce no smoke; sparse local dry dust only |
| S7A `underpass_veins` | Quiet olive damp earth/moss beside routes. Cool neutral pier stone, matte iron; dry exposed stone stays distinct | Damp pier feet, mineral runoff beneath arch joints, moss at persistent shaded seams | Daylight outside, cooler sheltered pockets beneath actual overhead structures. Restrained local mist/droplets; no blue wash |
| S7B `canal_services` | Olive wet banks and soil, worn quay stone. Water-stained limestone, aged copper, dark desaturated green water | Waterlines, silt at drainage, algae at wet edges; upper masonry remains dry and lighter | Bright diffuse daylight. Tiny mist patches only over actual water/drains. Quiet ripples; no cyan carpet |
| S8A `rail_yard` | Dry grey-brown loading ground and ballast, rails in coherent runs. Dusty stone/brick, rust umber, old timber | Wheel/handling wear, coal beside storage, oil beside equipment; rough sparse grass outside the working route | Open sun and moving air. Sparse surface dust; steam requires real equipment |
| S8B `military_staging` | Packed earth and worn muster routes. Cool stone barracks, faded sage canvas, dark iron | Boot lanes, maintained supply groups, faded canvas tops; local mud at entries | Bright broken-overcast feel; moderate wind through real cloth. No routine haze |
| S9A `outer_wall` | Rough grass, scrub and worn approaches. Exposed limestone, weathered timber and subdued green | Bleached/worn upper stone, darker protected feet, irregular wilderness beyond traffic | Bright exposed daylight, stronger wind and broad wall casts. Clear air |
| S9B `siege_services` | Stone grit, repair dust and compacted logistics routes. Patched masonry, worked timber, oxidized metal | Pale dust beside stone handling, loading abrasion, rust below hoists; local old burns only where justified | Neutral daylight, passing cloud and occasional attached repair dust. No automatic battle fog/fire |
| S10 `gate_district` | Worn civic flags and clear approach routes. Pale monumental limestone, slate, deep green cloth, restrained brass | Maintained central route against older stained gate edges and worn mechanisms | Calm imposing daylight; readable portal depth and clear boss court. Exit Rite keeps its own effects |

### Protected contexts

S1 `institution` retains its authored institutional material/light owner. The
Hub retains its authored sheltered warmth, market dusk and practical lamps.
The procedural resolver currently disables itself in both contexts; the pack
records them as references, without automatic overrides. DonJon is a cross-cutting
building family: open courts inherit district daylight; enclosed rooms keep
their own visibility/cutaway/interior owners. S11+ currently resolves to Service
Courtyards. Beyond-the-Wall plate 18 remains exploration, not a newly approved biome.

## Surface treatment and scale

1. **Ground has use and maintenance.** Routes, courts and loading pads get their
   own selected hard or compacted surface; soil/rough grass continues into open
   land. A maintained household lawn has a useful coherent core, a worn approach
   and an irregular transition. A kept wild patch has trimmed access and low
   mixed growth; abandoned ground has broken edges and encroachment. Wilderness
   remains locally varied and procedural. No universal lawn rectangle, planter
   rim, grey paving halo or formal round square. Preserve soil/grass continuity
   across chunk boundaries.
2. **Ground is quieter than walls.** Initial scale guide: setts roughly 8–20
   world pixels across, larger flags 24–64; confirm against the actual actor,
   door and camera rather than treating these as locked dimensions. Avoid a
   strong black joint around every tiny stone. Broad warm/cool stone variation
   and one lower-contrast joint system carry paving. Vertical domestic masonry
   keeps coarser blocks, darker mortar, chipped edges and credible thickness.
3. **Stains have an origin.** Capillary damp rises roughly12–44 world pixels
   from an actual wall foot; roof leaks start under a real gutter/ledge; soot
   rises from a working vent; rust flows down from metal fixings. Wear follows
   an actual walked or handled route. Dry dust collects on ledges and working
   ground, not uniformly across every roof and facade.
4. **Weathering preserves form.** Start with a 10–25% local value change at
   strongest deposits, and substantially less over most surfaces. This is an
   artistic trial range, not a measured runtime limit. Retain plaster colour,
   readable mortar and large roof planes. Roof lichen belongs near shaded
   eaves/valleys; soot belongs downwind of the chimney in roof UVs. A roof mask
   must move/fade with the roof. Do not paste frontal runoff on horizontal ground.
5. **Domestic life survives the cutaway.** Keep the checked cot/hearth/mat,
   work and storage groups, stronger rough stone and warm reflected corners.
   Floors may be boards, flags or restrained terracotta by household purpose.
   Leave the entry, hearth working side and main movement route clear. Additional
   work/shop props should establish a trade rather than fill every free cell.

## Shader and atmosphere direction

Use the existing top-right sun and shared cast direction. Theme variation changes
direct-versus-fill balance and local shelter, never the direction of each sprite's
painted light. Eave/contact shade gives weight; long dark casts must not swallow
dark enemies. Lamps use a small warm source and nearby spill, without a new global
orange grade. Do not add vignette, chromatic aberration, exposure pumping or bloom
to establish district identity.

The support profiles propose restrained starting values for existing atmosphere
fields. Typical cloud opacity is 0.025–0.09, using broad slow world-anchored shade;
S7 mist starts at 0.015/0.025 only where a real receiver supports it. These numbers
need native tuning. Global weather continuity wins at a theme seam: blend the sky
gently, keep one moving cloud field and attach material state to the same world
positions after streaming. Reduced motion must retain the static material identity.

Keep the actor, pickup, objective, attack tell and HUD colour owners authoritative.
The current world-atmosphere shader multiplies actors as well as scenery; this
brief does **not** claim that it already isolates environment colour. Keep its
multipliers close to neutral until ownership is corrected. Darkening all ground
or adding blue fill cannot substitute for local shade and moisture. No all-screen
mist over a dry court; no fog inside closed rooms; no generic particles at a rate
that hides combat. Existing `particle_kind`/`particle_density` profile fields do
not by themselves implement particles.

### Fit the existing interfaces

| Existing owner | Appropriate work | Limit to respect |
| --- | --- | --- |
| `DistrictGroundPolicy.gd` / `GroundSplatRenderer.gd` | Material roles, `source`, `layer`, `repeat_px`, `mid`, `tint`; kerb/gutter/joint/AO and local verge/stain intent | `mid.a` is texture weight. Do not turn it into opacity. Correct blanket paving through semantic roles before tint |
| `ThemeAtmosphereProfiles.gd` | `environment_tint`, `ambient_fill`, `direct_light`, cloud and mist settings | S1/Hub are authored exclusions. Keep near-neutral actor multiplication; particles need a real owner |
| `WorldDepthStyle.gd` | Cast shade, length/softness and contact balance | Length/penumbra affect built geometry; changing a live uniform alone does not rebuild it |
| `roof.gdshader` | Slope balance, ridge/eave and material midtone/contrast | Retain actual roof geometry, fade and existing light orientation |
| `domestic_stone.gdshader` / `city_stone.gdshader` | Tint/brightness/curve/grain and the latter's joint lift | Preserve coarse stone. No pale-white placeholder wash |
| Facade material cache/composer | A future surface-specific weathering adapter or offline atlas bake | It currently caches warm/pale by roof material; there is no existing per-theme facade-preset API |

Current mist damp receivers recognize semantic IDs 5/12 and suppress paved winners.
Wet-looking urban paving does not automatically produce a valid mist receiver.
Keep the light-map's B=care and A=openness channels intact; they are not free
weathering channels. The JSON profiles are a design interchange file, **not** a
drop-in runtime resource or an unimplemented facade API.

The incoming ground shader already has a reported 3–4 ms GPU regression at 1080p.
Resolve that before adding work. Prefer offline mask baking into selected material
variants/atlases, or a bounded local owner with at most one selected mask. Do not
add more fullscreen passes, noise octaves, ground texture branches, per-frame
texture writes or image readback for these effects. Local source masks carry no
performance acceptance claim.

## Production handoff and return

Keep the broader city goal. For the first material comparison, use four current
contexts: S2 household street, S6A working ground, S7B damp ground and S9A exposed
margin. They expose maintained/dry/damp/exposed conditions with the current library.
Only call them a canal edge or wall approach where the structural fixture has a
real implemented owner; the corresponding incoming structure sources are still
held candidates, not established native evidence.
After that comparison works, carry the same rules across the remaining themes;
do not create fourteen unrelated weather systems.

Linux should fetch and normal-merge `origin/enemy-world-work`, acknowledge the
received commit in its owned status, and preserve its parked branches. Confirm
the asset paths/status in the curation before using them. No Windows handoff file
is an acknowledgment from Linux. Return source-bound native images at 960 and 1080,
same seed/camera before/after, one occupied moving pass through a real home and a
theme/stream boundary, and CPU/GPU cost without capture readback. Include reduced
motion, clear/damp controls and visible actor/tell contrast. Resolve existing
entry/cover/ground blockers before claiming full integration acceptance.

**Keep** a change when the material/use distinction reads at ordinary gameplay
size, the city remains coherent, and actors/cues stay clear. **Rework** it if the
only difference is a screen tint, all land becomes paving, stains float without
sources, S7 goes blue, every household becomes equally manicured, or weather hides
combat. Passing technical checks is necessary evidence; it does not establish
that the result looks close to the concept.
