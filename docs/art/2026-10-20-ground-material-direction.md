# Ground material direction and S7 rework

**Latest native review:** [Linux L2 review](reviews/2026-10-20-linux-l2-lead-review/README.md)
keeps the moss replacement and care foundation, but requests clearer local lawn,
chunk-boundary inspection and a wet/dry-earth correction. The broad blue carpet
is fixed in sampled S7; wet-mud ribbons remain. One [quiet wet-earth candidate](../../assets/world/ground/city_care/wet_earth_v1/README.md)
is supplied conditionally after bound-layer/repeat/cache inspection. No complete
ground or street acceptance is implied. Earlier source decisions below retain
their original scope and are superseded where the native review identifies a fault.

20 October 2026. Direct human steering asks for distinct backgrounds for lawn, open/kept wild and neglected wild ground, appropriate dirt variation, and investigation of blue greenery around S7. The human explicitly requires the lead to challenge off-target coworker results. This is an art direction and production contract; the requested materials are not yet implemented or accepted in gameplay.

## Visual family

Use differences in plant structure, surface wear, moisture and occupation, not a collection of recolours of the same leaves. Blend them through actual irregular terrain and usage. Preserve the uneven medieval city and procedural wilderness.

| Use | Desired appearance and placement | Initial source decision |
| --- | --- | --- |
| Tended lawn | Short, fine, unevenly maintained grass; quiet colour and a little wear near homes and used paths. No modern mower stripes or perfect sports turf. | One new short-lawn source. Existing dense wild textures are not lawns. |
| Open/rough wild grass | Uneven grass and soil patches, occasional low growth and open ground; less deliberately maintained than a house garden. | Reuse `ground_grass_01.png` provisionally with appropriate scale/contrast. |
| Neglected/overgrown ground | Ranker weeds, thatch, localized dense clover/ferns and exposed soil at abandoned or unmaintained edges. | Selected existing `ground_grass_02.png` and wild dressing, mixed with rough grass/soil. Do not carpet every traversable area with giant leaves. |
| Dry earth and worn yard/path | Muted compacted or loose soil, restrained pebbles, wear following real use and entrances. | Existing `ground_dirt_01.png` is a candidate. A worn-route mask/scale treatment must establish use; a separate path source is needed only if this fails native review. |
| Wet soil | Local darker moist ground near drainage, sheltered edges and canal infrastructure. | Existing `ground_mud_wet_01.png` is a candidate; dry/wet distinction must remain visible at the actual camera. |
| Damp moss/soil | Low muted olive/brown-green moss and damp mineral/soil substrate. Distinct from lawn and tall leafy groundcover. | One new restrained source replacing the rejected S7 blue leaf-carpet presentation. |

Existing `ground_grass_dry_01.png` mostly repeats the rough grass's composition with changed colour; it does not independently establish a new management state. `ground_dirt_path_01.png` visibly depicts flagstone paving despite its filename and must not be presented as an earth-path asset. Mossy brick is another paving material, not the cause of S7's blue greenery.

The same base may serve several soil conditions with wear/moisture masks and restrained tint/scale. Do not generate an entire catalogue before one visible use fails. Conversely, do not keep a poor-looking source simply because it exists.

## S7 finding and firm rework decision

Root personally inspected the [S7 scene](reference/2026-10-19-city-foundation/native-s7/exterior.png), [moss source](../../assets/world/ground/ground_moss_01.png), all three grass sources, dirt, wet mud and the misleadingly named dirt path. The S7 scene uses seed4, Canal Service Routes. Its base is moss and exploration is mud. Underpass Veins uses moss in exploration instead.

The moss PNG is itself blue/teal/purple dense broadleaf groundcover. The [theme tint](../../core/systems/world/proc/SegmentThemePicker.gd:331) reinforces it slightly; the renderer does not invent the blue. [WorldArt](../../core/systems/world/WorldArt.gd:22) maps moss to source layer12. Its [ground material policy](../../core/systems/world/ground/GroundSplatRenderer.gd:95) leaves that layer/tint unchanged; the [shader](../../core/systems/world/ground/ground_splat.gdshader:84) samples it and applies world tint. The S2-specific quiet palette is disabled in S7.

**Reject the broad blue leaf-carpet treatment.** It is too saturated, too uniformly busy and semantically unlike low temperate moss. Its distinctiveness does not make it suitable. S7 should retain a cool damp identity through subdued green moss, wet soil, water-stained stone, practical drainage and contained growth. Changing hue alone without addressing broad-leaf scale and repetition does not close the finding.

## Minimal asset packet

After the existing garden/cot/hearth handoffs, the asset-only support chat is assigned two original opaque overhead material masters under `assets/world/ground/city_care/v1/`: `cared_lawn.png` and `damp_moss_soil.png`. Keep exact prompts, original source paths/bytes, hashes, actual dimensions and alpha verification. Inspect repeat behaviour at a realistic scale; a seamless-generation prompt is not evidence of seamless output.

Both sources must have no patch outline, border, isolated prop, tree, large leaves/flowers, cast shadow, vignette or directional whole-image lighting gradient. Production owns their irregular boundaries. Their detail/value family should stay quiet beneath actors and match the accepted temperate daylight direction. The asset chat has no code, engine, import/bake or Git lane.

The existing cot and cold household hearth sources were personally reviewed by the lead and provisionally retained for native fitting. That source verdict does not establish domestic-interior completion or permit delaying the ordinary-house task for a speculative furniture pack.

### First ground source review

The two requested masters now exist: [short lawn](../../assets/world/ground/city_care/v1/cared_lawn.png) and [damp moss/soil](../../assets/world/ground/city_care/v1/damp_moss_soil.png). Root personally viewed the originals and both320px repeat previews; an independent visual reviewer also inspected the160px and native-wrap views. **Provisionally keep both for integration.** No further source generation is warranted before a native scene trial.

The lawn has continuous fine short growth and a muted slightly dry olive colour. Moss has broken mineral earth and low green patches, with no blue broadleaf carpet. No dominant hard tiling seam or baked lighting gradient appeared in the reviewed repeats. Broad mottling does recur; the moss grit is more noticeable at320px. Do not spread it uniformly over every open area or increase sharpening. Runtime grading must not flatten lawn and moss into the same green field. These are source-level decisions only: irregular blending, actual ground selection, actor readability and S7 replacement remain unverified in gameplay.

## Production boundaries

Preserve semantic terrain IDs, generation RNG, material ownership, organic coverage, physical routes, rewards and navigation. Distinguish household care by actual parcel usage and available ground, not by globally replacing wild grass or using `not civic` as a home classifier.

The renderer has eight active coverage slots. A ninth semantic material currently aliases another slot of the same overgrowth/paving class. Do not add lawn/neglect terrain IDs merely to obtain different pixels. Prefer a small family/material presentation policy and a bounded local care mask that only affects eligible vegetated ground. The currently unused blue channel of `light_map` is an implementation candidate, not a preapproved solution. Correct stream reset, deterministic reproduction and no paving/threshold overwrite are required.

The [WorldArt baked-array path](../../core/systems/world/WorldArt.gd:145) preferentially loads `ground_materials.res`; its existing validation checks dimensions/format, not source freshness. Updating a PNG alone may leave old runtime pixels. Production must verify the selected layers and derived resource when it integrates new sources. Rebuild/import work remains in the sole monitored engine lane and must respect the current memory guard.

## Review gates

- Native normal/small views show tended, open wild and neglected ground distinctly without relying solely on flower/tree props.
- Tended ground is local to plausible occupied home plots; outer vegetation remains procedural and irregular. Transitions follow terrain, paths, walls and use, without rectangular halos or repeated garden islands.
- A S7 damp-green/soil/paving boundary has no cyan/purple botanical carpet and retains its cool wet identity.
- Dry and wet earth differ visibly in an occupied scene; an imperceptible recolour is insufficient.
- Ground edges and detail remain subordinate to player/enemy silhouettes, pickups and attack cues.
- Correctness checks retain routes, terrain identities and deterministic reload. Passing tests does not close visual findings.

## Concurrent street review

Root personally viewed [environment-v2's small street](reference/2026-10-20-s2-street/environment-v2/service_lane-1-960x540.png). Provisionally keep stronger wall/roof balance and the fitted neighboring annex relationship. Continue the ground-care and complete-place work. The [manifest](reference/2026-10-20-s2-street/environment-v2/manifest.json) identifies the two parcels as **passage** and **workshop**, so this view cannot demonstrate a real home garden.

The constrained capture uses one frozen production ChunkManager chunk, without Game, HUD, player, objectives, entry or combat. It is useful low-memory local composition evidence. It is not normal Game, whole-world streaming, playable-street or whole-concept acceptance. The sole production owner has been told these specific keep/rework decisions.
