# Actual household feasibility — read-only investigation, 4 November 2026

**Recommendation:** prepare one small, asset-free GDScript derivation check first;
keep the yard trial off. An actual one-house kit is technically separable from
Game with a narrowly declared segment-context double, but it is **not qualified
for the existing 256 MB native tier**. Do not launch Game below its unchanged
1536 MB free RAM / 3072 MB commit startup gate. No engine, import, source change
or commit was performed for this investigation. This report is the only output.

## What is actually recovered

The familiar seed16102028 / `canal_services` camera `(-1632,1304)` is **not a
household target**. The retained `2026-10-22-linux-ground/captures/after/s7b/`
`survey.json` calls its kit at centre `(-1632,992)` a `passage`, chunk `(-1,0)`.
`CityBlockKit.ground_care_spec()` rejects every use except noncivic `row_house`.
The combined-production and 23 October care-edge captures reuse this camera;
their `building_id: 0` is not a recoverable household ID.

There are, however, real generated S7 household records in:

* `docs/art/reference/2026-10-22-linux-streets/sources/blobs/43938c18fa45cbc8ca3248d4bdbcf3bf22922c23789e5bcd10ff5a193c60390b-city22-street-continuity-part-08-part08-v1.json`
* Bound by `sources/run-bindings/city22-street-continuity-part-08-part08-v1-1.json`
  and the matching `runs/.../run-results.json.gz`, Git `b2982024`.

These are historical **actual generated headless test samples**, not synthetic
hand-authored parcels and not new native Game observations. The test creates
actual ChunkManager/parcel/kit nodes; `_buildings()` records their rect, use,
door anchor/direction, civic/irregular/infill flags. The sample's selected theme
is segment7, attempt seed16102028, plan seed1208827904, generation attempt1.
Plan seed, not attempt seed, is the manager's `world_seed`.

One useful sample is chunk `(-8,-4)`, role `dangerous_alley`:

| Recovered rect (chunk-local cells) | Recovered door x,y,dx,dy | Flags | Host-derived expected visual seed | Variant |
| --- | --- | --- | --- | --- |
| `(21,7,8,7)` | `(25,13,0,1)` | row_house; noncivic; rectangular; original | `1910440753` | 1, fruit-tree garden |
| `(3,6,8,8)` | `(7,13,0,1)` | row_house; noncivic; rectangular; original | `2052381668` | 0, kitchen bed |
| `(21,20,8,8)` | `(25,20,0,-1)` | row_house; noncivic; rectangular; original | `1928485795` | 3, untended: skip |

The ID column was calculated with a host Python port of the exact signed64
`SiteParcelsImpl._mix_seed`, using `coord*32 + rect.grow(-1).position`, salt77,
then `(mixed & 0x7fffffff)+1`. It is **not an observed ground-care spec** and
must be checked in actual GDScript before accepting a target. No new target was
activated. Door widths are omitted by the recorder; width2 is the normal source
default, not a recovered width. Garden contact, actual party edges/extra reach,
final care/semantic bytes and real doorway clearance were not saved in this JSON.

For the first candidate, the rectangular footprint before roof inset/notches is
source-derived local pixels `[(1344,448),(1856,448),(1856,896),(1344,896)]`.
At chunk origin `(-16384,-8192)`, a survey-style south-foot camera would be
`(-14784,-7336)`. These are arithmetic derivations, not captured camera/spec data.
The original `(-1,0)` chunk is not among this file's fifteen sampled chunks.

An additional retained survey proves a `row_house` exists in segment7,
seed16102026, `underpass_veins`, chunk `(2,9)`, centre `(5152,18848)`, camera
`(5152,19096)` (`2026-10-22-linux-ground/captures/after/s7a/survey.json`). It saves
neither rect nor visual seed nor doors/contact, so is less useful than part08.

## Source equivalence and limits

Current bytes equal the exact part08 launch hashes for:

* SiteParcelsImpl `fa315410...7503`, ChunkGenDistrict `b3d8a7e3...1a66`;
* CityBlockKit `8c1d11fd...8ffd`, RoofOverlay `8704de69...9a07`;
* CityStreetContinuityTest `4e696d66...8209`.

The raw launch `source_hashes` also match current ChunkGenImpl, DistrictPlan,
SegmentThemePicker, SegmentThemeData, SegmentProcBuilder and DistrictVisualProfiles.
This is strong geometry-input/source continuity; it is not current runtime proof.
ChunkManager differs by plaza resource warmup and the new default-off yard wiring.
CityFrontageDressing differs by explicit null initialization and prop-shadow
handling. The latter changes do not change its layout/seed/contact planner,
but visual identity of the whole current scene must not be inferred from history.

## Minimal recommended executable next step

Use a **new external tiny project**, `.gdignore` written first, with no Game,
autoloads, theme import or project-wide scan. Copy unchanged
`RectFacilityCarver.gd` and its only script preload `DonjonCarver.gd`; both use
engine geometry/RNG only. Add a generated harness containing the verbatim,
hash-pinned `_mix_seed` method extracted from current SiteParcelsImpl (explicit
method extraction, not a substitute SiteParcels/ChunkManager class). Feed the
recovered first row above and plan seed1208827904. Verify expected ID1910440753
in Godot's signed integer semantics. Optionally call actual
`RectFacilityCarver.carve_room_first` with the explicitly declared normal
row-house parameters and width2 to record physical door cells and partition
geometry. Keep the distinction: this **replays a recovered generated lot**;
it does not regenerate/select the complete district or recover omitted fields.

This can establish an explicit real-lot candidate and its actual source geometry
without hiding Game dependencies behind stubs. It cannot establish its true
garden contact or complete care spec. The 512/1536 startup, 64 MB private/30s
data tier is the appropriate first attempted tier, with the existing running
384/768 free-memory stops; any fit remains to be measured. No check was run here.
Stop on refusal/diagnostics rather than promote the tier implicitly.

Actual complete district selection is not presently a pure drop-in entrypoint:
`SegmentThemePicker.get_theme(7,16102028)` -> `DistrictPlan.generate` ->
`theme.apply_to_chunk_manager` -> actual ChunkManager generation ->
ChunkGenImpl/ChunkGenDistrict -> SiteManager/SiteParcelsImpl. DistrictPlan reads
Global's boss-segment constants; SegmentThemeData's apply method has a typed
ChunkManager parameter. ChunkGenImpl has typed ChunkManager/SiteManager fields.
SiteParcels preloads IndoorVolume, RoofOverlay and CityDomesticInterior, whose
typed ChunkManager path reconnects the broad world/combat closure. Existing
CityBlockKitTest, WorldFootprintTest and CityPlanMapProbe all instantiate actual
ChunkManager; none is the desired asset-free selection fixture. Do not implement
fake managers/volumes/carvers merely to make this chain appear isolated.

## Conditional actual one-house native path

The smallest actual visual entrypoint is `RoofOverlay.tscn` plus
`CityBlockKit.new()` and `configure(...)`, using an explicit recovered lot,
actual `DistrictVisualProfiles.resolve(&"canal_services")` plus `family_id`,
`visual_seed`, `building_usage`, and `shared_ground=true`. Add the roof to the
tree before configure so `RoofPoly`/`FrontEdge` onready fields exist. Pass null
indoor volume: RoofOverlay accepts Area2D/null and needs no IndoorVolume scene
for an exterior still. Configure roof, then kit, then call `ground_care_spec()`.
An actual kit will run actual facade/dressing planners and produce actual
contact data for this **isolated replay**, not the full generated street.

The direct visual closure reads only `Global.attempt_segment`, so a fixture-only
context owner declaring `attempt_segment=7` is a defensible, narrow **Global
context double**, explicitly listed in pins. It must not pretend to implement
loot/progression/Game services. Loading unchanged `autoload/Global.gd` instead
is unsuitable: `_ready()` loads spells/races/styles/weapons/items/sets/augments,
major choices and a VFX scene, and binds RunEvents; further SaveManager/other
service names appear throughout its parsed type closure. Direct-kit isolation
avoids that closure rather than stubbing it wholesale. No such double was made.

Required real visual dependencies, beyond the existing ground fixture:

* Global class metadata for actual RoofOverlay, ChunkBlockVisualCatalog,
  WorldBlockerGeometry, ChunkBuildData; engine-only fixture context for Global.
* CityFootprintGeometry, CityFacadeComposer, CityFrontageDressing,
  CityBlockFrontages, CityBlockRoofForms, CheckpointOfficeForms;
  ForegroundSpriteCoverage, WorldDepthStyle and CityWeathering.
* Actual ChunkBlockVisualCatalog pulls actual PlazaEdgeKit even though the kit
  mainly needs `KIT_HEIGHT`/`three_quarter_walls`. Do not replace that catalog
  with two constants while calling the closure unchanged.
* RoofOverlay's six source roofs/damage PNGs; domestic wall34_10; catalog wall,
  wall-kit, props and plaza-kit textures; weathering runoff. Actual WorldArt
  adds its seven floor decals and three landmarks if its leaf is restored.
  Retaining the existing disclosed WorldArt leaf avoids those ten eager assets
  but makes this a leaf-doubled fixture, not a wholly original loader closure.
* Dynamic selected textures under `assets/world/city_block/`, `facades/v1/`,
  `dressing_v2/`, `domestic_gardens/v1/`; preserve original sidecars and imported
  bytes, rather than silently source-decoding differently from the Game.
* `city_ground`, `city_paving`, `domestic_plaster`, facade wall/module/coverage,
  roof, actor-cast and sun-shadow shaders/materials; facade-wall and damp shader
  includes; weathering plinth/stain shaders. Copy the six `sa_weather_*` globals
  from project.godot, including actual wall_base_damp/roof_lichen masks. Apply
  the production canal light/weather profile before construction if claiming
  matching material context; WorldDepthStyle alone defaults to generic daylight.

Side effects are bounded scene construction: texture/material caches, sprite
and polygon children, foreground registration/groups/metas, deferred cast draw,
roof fade signals/tweens if volumes are supplied, and chunk deco-clear metadata.
There are no collisions/encounters/rewards in CityBlockKit itself. Neighbour
props steer dressing and neighbouring footprints steer casts/paving, so a single
kit cannot recover the complete original street's composition. Omitting indoor
walls/furnishing is an exterior-only fixture limitation.

## Budget and camera constraints

A read-only literal-preload walk from actual CityBlockKit/RoofOverlay plus the
required actual ChunkBlockVisualCatalog found 136 files including 107 PNGs:
38 plaza-kit, 26 wall-kit, 18 wall, 8 props, 7 decals, 6 roof/damage, 3 landmarks,
1 runoff. This deliberately excludes dynamic loads, class dependencies and the
two shader-global masks: it is a **partial inventory, not a proven full closure**.
The source PNGs total23.14 MiB; base RGBA8 storage from PNG dimensions is135.67
MiB, or180.89 MiB with a full mip chain. Existing referenced imported CTEX bytes
total13.70 MiB;39 expected import sidecars/cache references are missing. These
are storage/format estimates, not process private-memory or GPU measurements.
Restoring only the Kit while retaining the disclosed WorldArt leaf removes its
ten decal/landmark preloads from that count. Missing eager imported resources
still require narrowly imported/copied original assets; broad project import
is not authorized by this recommendation.

Dynamic asset directory upper inventories (all PNGs, not all selected per house):
city_block16 /95.99 MiB base RGBA8; facade18 /21.35; dressing18 /9.79;
domestic_gardens3 /18.00. Do not add these figures blindly: actual selected
subset, importer compression, caches and shared GPU storage change residency.

The qualified 512-square native fixture peaked at241 MB private under a256 MB
ceiling: only15 MB remained. It also retained baseline/preview maps and many
saved controls. Neither adding this eager visual closure nor increasing output
to1280x720/960x540 has a defensible fit claim. A later single-renderer,
sequential before/after prototype might reduce baseline state, but must first
be separately measured and reviewed; never silently raise its cap or reuse its
46/0 result as larger-fixture qualification. The partial inventory suggests
additional tens to hundreds of MiB of texture capacity could be involved;
no hardware/private-memory guarantee is possible from these numbers.

Match the Game's **1920x1080 logical canvas**, zoom1, rotation0, then native
1280x720 and960x540 windows under `canvas_items` stretch. Do not use a1280x720
logical viewport at zoom1: that would enlarge world objects by1.5 versus the
retained normal Game crop. The known camera is a passage; use the recovered
house candidate only after its GDScript/spec verification. A still from this
isolated replay could meaningfully judge one actual kit's corner and source
materials at those scales, but would remain **one-house fixture art evidence**,
not normal Game appearance, stream rebuild, physical traversal or trailer proof.

The economical stopping point is this recovered-candidate packet. For final
acceptance, obtain the actual loaded household's ground-care spec, exact doors,
garden contact, semantics/care and nearby passage in current Game when its
unchanged startup gate permits; then capture matched normal/small originals
and mask and perform the existing doorway/reload checks.
