# Synthetic Ascension — city art direction, 18 October 2026

The user selected the daylight combination in `04-approved-daylight-hybrid.png`, responding “yess” to the generated result. Its two preferred source studies are `02-city-becomes-machine.png` and `03-porcelain-directorate.png`. The earlier dark rainy direction was explored, but later mixes became too dark; the user explicitly rejected that drift and reattached these exact two references.

## Latest user refinement — Mediterranean / European city with later machinery

The user said study 07 felt like a desert city and clarified the target: “Greece/Rome/Mediterranean + medieval Europe + early cyberpunk + early Warhammer 40k + medieval sci-fi/steampunk.” This more specific brief governs further development of the earlier approved palette. Keep daylight and pale/dark contrast, but avoid uniform cream paving, dry tan weathering, cloned ceremonial blocks and decorative gold circuits.

Study [08 — Mediterranean-medieval-industrial city](08-mediterranean-medieval-industrial-city.png) translates that refinement at the existing north-up gameplay-view style. Ancient civic arcades, reused stone and water infrastructure form the base; medieval European rooflines, shutters, balconies and varied inhabited frontage supply the city fabric; later iron/copper pressure plant, cables, analog terminals and surveillance supply early cyberpunk/steampunk layers. Early 40k supplies exceptional civic weight and crude industrial authority rather than copied faction imagery or skull-covered buildings. The city's ordinary life remains visible before later synthetic-occult escalation.

Use temperate cues: street trees and courtyard greenery, cool damp joints, working drains, copper patina, slate mixed with muted clay roof tiles and repaired lime plaster. Compress ground detail around broad quiet walking surfaces; keep thick tree/roof forms from hiding actors. The user called study 08 good but identified the remaining AI-generated “over-lined” look, then asked how to produce it in the game. This supports the direction while requiring simplified production art; it is not an instruction to preserve every illustrated seam or implement the whole city immediately. [Exact revision prompt](MEDITERRANEAN_REVISION_PROVENANCE.md).

### Production translation

Keep the existing 2D game and build a small reusable environment kit. Existing systems already provide blended ground, modular walls/windows/corners, shared building/door/interior footprints, shaded roof forms, entry-driven roof fading and seeded street generation. The work is coherent asset authoring plus deliberate building/district composition and targeted placement/layering changes.

First milestone: one playable street block containing a civic arcade, an attached house, a service alley and enterable interior. Author a restrained set of paving/curb/drain materials; plain/window/door/arcade/corner wall bays; slate/clay roof sections and chimney; a purposeful pipe riser and utility cabinet; and limited vegetation. Use three broad value groups, strong outer architectural silhouettes, soft low-contrast internal seams, grouped material texture and selective crisp detail at entrances/interactables. Keep the strongest outlines for actors and important gameplay objects. Generated source components require selection, consistent perspective/light, alpha/edge cleanup and repainting; the concept image itself is not a tile set.

Place architecture and fixtures from the same real doorway/footprint data as collision and interiors. Roofs and façade depth must leave approach corridors and actor visibility honest. Later expand coherent civic/residential/service placement rules, preserving seeded reload behavior and drawing batches. Validate the first block with native exterior traversal, roof/interior transitions, crowd/projectile/tell readability at 960×540, chunk reloads and the normal/reduced settings. Build footage and exact scene comparison should lead the next decision, not another empty illustrative screenshot.

## Earlier agreed palette and initial direction

A modern-medieval civic city: pale limestone/plaster and older arched architecture, slate streets, practical ironwork, and municipal copper/brass services. Daylight and readable open shadows preserve contrast without a night filter. Broad ivory and slate ground areas, faded sage municipal markings, drains, repairs and meaningful service connections replace bland repeated paving and shapeless moss patches. Rich detail sits around landmarks and edges; combat space remains quieter.

Red-orange belongs to exposed synthetic understructure and danger. Small jade indicators and violet apparatus are selective accents. Brass behaves as aged metal, not continuous glowing lines. The city can grow stranger as the run advances, while retaining recognizable public infrastructure. The selected hybrid's large exposed machine trench is a concept motif, not a prescribed new collision layout or an exact production Breach design.

This is an accepted **visual direction**, not an implemented game screenshot. The generated scenes use a more oblique/isometric camera than the present game. Production work must reconcile projection, actor scale, silhouettes, accessible state language and real movement/hazard footprints in actual Game samples. Do not infer new mechanics, enemies, architecture collision or pixel-perfect assets from the illustration.

## Files

- [01 — initial dark containment city](01-containment-city.png): an explored atmospheric option; not the final lighting target.
- [02 — city becomes a machine](02-city-becomes-machine.png): user-preferred slate/ivory/brass/red source.
- [03 — porcelain directorate](03-porcelain-directorate.png): user-preferred daylight, pale ground and faded sage source.
- [04 — approved daylight hybrid](04-approved-daylight-hybrid.png): the agreed combined direction.
- [05 — actual game view paint-over](05-actual-game-view-paintover.png): requested follow-up at the current overhead camera, street layout, three-site composition and player/HUD scale. Compare the [unaltered current Game reference](05-actual-game-view-before.png).
- [06 — architectural game-view target](06-architectural-game-view-target.png): a stronger conceptual redesign with full civic building masses, composed streets, institutional infrastructure and daylight depth at a north-up gameplay camera.
- [07 — actual building concept translation](07-actual-building-concept-translation.png): applies the selected architecture/material language to the two-building scene from a fresh native Game capture. Compare the [actual building exterior](current-game-captures/searchable-building-exterior-1280x720.png).
- [08 — Mediterranean / medieval / industrial revision](08-mediterranean-medieval-industrial-city.png): latest, more specific cultural and climatic direction after the user rejected the desert-city impression of 07.
- [Exact generation prompts and provenance](PROVENANCE.md).

## Actual-view translation

Study 05 directly edits the current three-Breach Game screenshot, using it as the sole image reference to avoid the earlier isometric drift. The approved palette is expressed through pale limestone, medium slate service surfaces, faded sage civic marking and restrained brass. The center moss patch becomes flush paved civic ground; the existing lower-right wall retains its L-shaped footprint. It is still a generated concept paint-over, not a newly rendered engine screenshot or pixel-identical preservation of the player/interface. Some local staging text is removed and output resolution is increased.

Independent visual comparison found the north-up axes, normalized three-site locations, actor scale and HUD composition closely aligned. Before production use, keep drawn curbs flush/shallow so they do not imply new collision; quiet the small cracks and patterned slate for dense combat; avoid connecting all breaches with brass as if they were Relay nodes; and replace the placeholder fleur-de-lis with a setting-appropriate civic mark. These are implementation considerations, not new mechanics or finalized lore. Study 05 has not yet received separate user approval.

The [exact paint-over prompt and source record](ACTUAL_VIEW_PROVENANCE.md) are saved separately.

These concept files are kept outside runtime imports through `.gdignore`. No game code, terrain resources, actor assets or gameplay values were changed by their creation.

## Closing the gap to the concept

The user found the surface-only treatment insufficiently close to the selected city concept. Study 06 therefore changes the place: full pale civic institutions and slate-roofed modern-medieval blocks frame the fighting space; broad ground zones establish a designed plaza; substantial brass plant follows building foundations; roof planes, short façade reveals and large directional shadows provide depth. Damage and red synthetic machinery are concentrated around a perimeter failure instead of distributed uniformly.

This is a proposed environment layout, not a preservation of the existing sparse block geometry and not new runtime content. Keep the compact actor/camera language; building occlusion, roof fading, exit routes, level generation and collision would need deliberate production work. A useful first implementation would be one representative built-up block in the existing renderer: building shapes and movement space first, then materials and service infrastructure, then daylight/shadow hierarchy, then objectives and crowded-fight review at small size. Replacing ground textures alone cannot deliver the selected concept's architectural character.

The user also explicitly authorized taking fresh screenshots inside the actual game where buildings are present. Six fresh native captures are saved under [current-game-captures](current-game-captures/README.md): an existing multi-building street, a searchable building exterior and the same interior with the roof faded, each at 1280×720 and 960×540. They are frozen controlled views of existing generated S2 architecture, with real player/HUD scale and five genuine local security enemies in the interior. Native exit 0, zero save writes and no logged diagnostics are recorded in the linked capture evidence; no human-playtest claim is made.

Study 06 is a proposal, not separately approved. [Exact architectural study prompt](ARCHITECTURAL_TARGET_PROVENANCE.md).

## Building-backed translation and production priorities

Study 07 uses the fresh exterior capture as its camera/place reference. Its two adjacent buildings, separating lane, entrance approach and compact player establish the same general scene; individual image-generated contours and building/actor positions are approximate, not a collision-preservation certificate. The roof gains a ridge, large plane values, skylights and selective hardware; pale façade depth, a recessed arch, windows and service connections make the entrance part of recognizable civic architecture. Slate/ivory frontage replaces broad shapeless moss. Daylight shadow masses unify buildings and ground.

To reproduce this direction in the game, prioritize one representative street block: an authored family of roof planes, corners, shallow façade layers, doorway frames and windows; coherent broad civic paving/service surfaces and intentional planting; substantial foundation-mounted service hardware; then matching contact/directional shading. Use the existing roof fade for interior readability and keep actor routes/door clearance honest. Shrink roof-detail frequency and ground wear where they compete at small size. The rendered concept still exaggerates some façade depth and ornament; resolve that with actual moving actors before applying the kit throughout procedural districts. No production geometry, camera, materials, character or gameplay values were modified here.

Study 07 is a design proposal, not separately approved. [Exact building study prompt/source record](BUILDING_VIEW_PROVENANCE.md).

