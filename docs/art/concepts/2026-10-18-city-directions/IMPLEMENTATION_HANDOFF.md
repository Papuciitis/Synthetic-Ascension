# City environment implementation handoff — 18 October 2026

## Human request and authorization

The human requested a separate implementation chat to preserve the designer conversation's context: “Alright, so your context doesn't get fucked, spin up another chat where we will start implementing this.” Start the agreed first playable-block work in that new chat. This authorizes a first-block implementation, not a full-city replacement, renderer conversion, mechanics rebalance or blanket commit/push.

The human accepted the latest concept's general direction but explicitly said it still has an AI-generated “over-lined” look. Production art must simplify that defect. They approved a direction, not every illustrated seam, façade depth, decorative symbol, building footprint or device in the concept.

## Project and current state

Workspace: `C:/Users/NaurisKrišjānis/Desktop/code_project/SA_proj/.worktrees/enemy-world`.
Saved Codex project: Synthetic Ascension, id `7e89b7ee-f14b-4e63-8b5d-ee799bd615ba`.
Observed branch `feat/authoritative-enemy-world`, HEAD `dd4d0dfc2c1cbe13ed2d0e4c01e20b03516a1823`. Recheck current state rather than assuming this remains HEAD.

Read AGENTS.md, docs/SYNTHETIC_ASCENSION_VISION.md, latest relevant docs/SYNTHETIC_ASCENSION_DIRECTION_AND_ROADMAP.md entries and README.md. The game is a 2D top-down horde-survivor roguelite. Its ordinary institutional city becomes synthetic-occult as a run escalates; combat/build readability matters.

The checkout contains extensive unrelated dirty/untracked files (item definitions, baked character frame resources, project.godot, README/history, imported reference sidecars, tests and others). Preserve all unrelated work. The city concept folder is currently untracked and must remain accessible; a fresh worktree will not automatically include it. Do not revert/reset/stash everything or commit all changes. The new chat is intentionally created in the existing local project; inspect before deciding any later isolation.

## Governing visual reference and user corrections

Primary: `docs/art/concepts/2026-10-18-city-directions/08-mediterranean-medieval-industrial-city.png`.
Read `README.md` and `MEDITERRANEAN_REVISION_PROVENANCE.md` in that same directory. Inspect actual pixels using view_image.

The human's exact desired blend: “Greece/Rome/Mediterranean + medieval Europe + early cyberpunk + early Warhammer 40k + some medieval sci-fi/steampunk.” Earlier attempts became too dark, then too beige/desert-like. Retain bright, open daylight with useful pale/dark contrast. Use temperate evidence, not a desert palette.

Assign influence by layer:
- Greek/Roman/Mediterranean civic bones: arcades, public halls, courts, stone and water infrastructure.
- Medieval European city fabric: varied slate/clay rooflines, shutters, balconies, patched plaster, attached houses and inhabited frontage.
- Early cyberpunk/steampunk retrofits: coarse cables, analog terminals, surveillance, pumps, pressure plant and service machinery fitted to older buildings.
- Early 40k weight: occasional imposing institution, heavy portal and industrial authority; no copied faction iconography or identical skull-covered space cathedrals.

Prefer cool grey/chalk stone, lime plaster, dark slate, muted terracotta, aged iron/copper patina and selective brass. Keep trees/green courtyard pockets, damp joints, working gutters and everyday use. The ordinary city should still read as a place people inhabit.

Simplification is essential: strong broad silhouettes and roof planes, grouped texture patches, soft low-contrast internal edges; describe selected stones/tiles rather than outlining every unit. Reserve strongest contours/contrast for actors and important interactions. Ground must stay quiet under combat. No dense golden circuit decoration on every street, cloned ceremonial blocks, uniformly distressed surfaces or full-screen glow.

## First implementation milestone

One finished playable street block in the real game/camera, using a small reusable kit:
- A civic arcade/public building.
- An attached house or guild/service frontage.
- A service alley and an enterable interior.
- Broad paving/service surfaces with restrained curb/drain treatment.
- A limited set of useful industrial and vegetation elements.

Build the architecture and open movement routes first, then the coherent materials/hardware and shared lighting. Do not attempt the whole procedural city at once. The first review deliverable is running Game footage/screenshots and a reproducible playable scene/location, not another AI whole-scene mockup.

Suggested kit families: plain/window/door/arcade/corner wall bays, slate/clay roof sections and chimney, paving/curb/drain materials, pipe riser/utility cabinet and restrained tree/planting. Derive exact asset count from the first block; do not generate a huge pack before one example integrates well. Generate draft raster components separately through built-in image_gen when appropriate; curate/correct projection, light, transparency, scale and excessive detail. No stock or downloaded artwork was used in the concepts.

Keep the existing north-up 2D gameplay camera, compact outlined player/enemy scale, real movement/door/collision logic and roof/interior behavior. Concept façades exaggerate depth; translate them into coherent roof masses and shallow wall faces without concealing actors or narrowing actual approach routes. No combat, reward, objective-radius, balance or save-rule changes are requested.

## Existing implementation to build on

- `core/systems/world/ground/GroundSplatRenderer.gd`: ground material blending/stamps.
- `core/systems/world/WorldArt.gd`: world art/material catalogue.
- `core/systems/world/chunks/ChunkBlockVisualCatalog.gd`: modular walls/corners/windows and shallow three-quarter wall treatment (current KIT_HEIGHT 28).
- `core/systems/world/chunks/ChunkBlockRenderer.gd`: shared rendering/batching.
- `core/systems/world/proc/SiteParcelsImpl.gd`: shared building footprints/doors/interiors.
- `core/systems/world/proc/chunkgen/ChunkGenDistrict.gd`: district content and protected movement routes.
- `scenes/world/buildings/RoofOverlay.gd` and `roof.gdshader`: rectangular/irregular roofs, gable shading, doorway notches, eave shadows and entry-driven cutaways.
- `scenes/world/volumes/IndoorVolume.gd`: actual entry/security/clear/reward behavior.
- `docs/art/2026-09-27-building-art.md`: older asset inventory and dimensions; use as implementation context, not a superseding aesthetic direction.

Building/decoration placement must derive from actual footprints/doorways. Preserve seeded regeneration and chunk reload behavior. Use shared rendering/batching; do not make every brick, pipe joint or light its own costly object.

## Fresh actual-game references and capture workflow

Six native current Game captures are under:
`docs/art/concepts/2026-10-18-city-directions/current-game-captures/`.

Inspect its README.md and manifest.json:
- city-street-junction-1280x720.png / -960x540.png
- searchable-building-exterior-1280x720.png / -960x540.png
- searchable-building-interior-1280x720.png / -960x540.png

These are actual generated S2, seed 16102026, north-up camera rotation 0, zoom 1, source viewport 1920x1080, controlled/frozen references. Interior has real roof alpha 0 and five actual local enemies. They are not generated art or human-played fight evidence. One code-controlled capture run completed native exit 0, six images, no logged diagnostics and zero save writes.

Reusable isolated scratch capture machinery and logs:
`.superpowers/sdd/2026-10-18-city-concept-captures/`
including CityConceptCapture.gd/.tscn, run-capture.ps1 and run-results.json.
The former exterior's camera center was (544,18944), player (608,19296); interior same camera, player (544,18976). Junction center/player (3616,19488). These are reference positions, not a requirement that the new block use those locations.

Native engine:
`C:/Users/NaurisKrišjānis/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64.exe`.
At handoff only the pre-existing editor PID 29136 was observed. Recheck before launching; never run beside a human playtest or another worker's engine/import session. Do not kill their processes. Use isolated APPDATA/LOCALAPPDATA, recorders/profile-write controls and native rendering for pixels; preserve actual exit codes and inspect full logs. Use hidden background helpers when appropriate.

## Required acceptance for the first block

- Native exterior traversal around all building sides and through actual doors; no decorative/collision mismatch.
- Real interior entry, roof fade/cutaway and exit restoration; correct visibility of actors and interior content.
- Actual populated moving fight with player attacks/projectiles/tells; frozen screenshots alone are insufficient for this milestone.
- Normal 1280x720 and small 960x540, plus Reduced Motion/Combat Flashes Off.
- Quiet texture/edge hierarchy, clear silhouettes and meaningful architectural/cultural identity at unzoomed gameplay size.
- Stable seeded reload/chunk behavior and appropriately scoped regression checks for any changed placement/layering paths.
- Honest before/after comparison and performance observation on this Intel UHD compatibility-rendering setup; do not claim improvement from art screenshots or retune balance.

The objective-family rework is separately implemented/reviewed. Preserve its physical states, exact footprints, subtle boundaries and accessibility cues. See `docs/audits/2026-10-18-objective-visual-rework.md` and `docs/art/reviews/2026-10-18-objective-family-designer-final-review.md`. Do not reopen or regenerate that entire objective family as part of this city-block task.

## Start in the new chat

Acknowledge this handoff briefly, inspect current code and concept pixels, use applicable development skills, then proceed toward the first playable block. The human has already supplied the purpose, aesthetic corrections and bounded first milestone; do not restart those questions or ask them to reattach existing references. Keep routine implementation decisions moving. Any scope expansion, whole-city rewrite, destructive action or external publication is separate from this authorization.

