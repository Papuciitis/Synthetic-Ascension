# Breach v2 integrated prototype review — 18 October 2026

**Evidence revision notice:** The initial capture revision reviewed below has been superseded by refined frames written to the **same image paths**. The initial findings and independent addendum are preserved as historical review. In particular, their “no visible spawned enemies” statements do **not** describe the current files. The scoped re-review at the end records the latest decision and SHA-256 identities of the seven replacement images actually reopened.

## Initial decision — superseded by the scoped re-review below

**GO for the restrained material and ground-footprint direction. REVISE before approving bulk objective regeneration or calling the Breach finished.** This is a substantial improvement over the raised, decorated v1 container. The dark cavity is now an actual opening, the completed version is physically filled, the footprint belongs much more convincingly to the terrain, and the interaction graphics no longer dominate the scene.

Two remaining gates matter: the open form only partly communicates an active dangerous source at gameplay size, and the supplied spawn panels contain no visible spawned enemies. These frames support a static art decision, not a live combat-readability sign-off. Do not regenerate the rest of the objective family merely because this capture manifest reports zero failures.

## Evidence and scope

Independently opened and inspected all **18** PNGs under `docs/art/reference/2026-10-18-objective-rework-prototype/`, plus `breach_open_v2.png` and `breach_sealed_v2.png`. Read `PROVENANCE_V2.md`, `capture-info.json`, the current art helper, Breach presentation code and staging script. The earlier objective visual review and project vision supply the criteria.

These are frozen, controlled samples in the actual generated Game with its HUD, seed `16102026`, segment 3, zoom 1.0. Normal is 1280×720; small is 960×540; reduced is 960×540 with Reduced Motion and Combat Flashes Off. The source viewport is 1920×1080. Single-site panels deliberately place the other two real sites outside the camera; the context panel supplies all three. This is not evidence that ordinary production layout has only one site.

The manifest records 18 captures, zero failures and zero save writes. It does not establish absence of renderer/resource warnings. The parent separately reports native exit 0 and shutdown texture-leak warnings; this review did not inspect that native log or diagnose those warnings. No Godot instance was run for this review.

## Findings

### Terrain fit and contact: go, with ordinary limits

The grey-olive stone, dull iron and broad dark cavity fit both the moss and pale paving much better than v1's jewelry-like rim. At integrated size the many source texture details collapse into a few useful rock clusters. There is no conspicuous bright metal sparkle, broad glowing pad or obvious rectangular sticker in these frames. The low irregular silhouette leaves useful visual space around the player.

The cavity/filled footprint now sits credibly around the interaction circle's center rather than appearing perched above it. Context frames on paving and the central moss frames both support that judgment. The small dark edge gives sufficient contact; it does not look suspended. This is visual acceptance of the sampled placement, not a measured contact-anchor proof: no temporary origin cross or footprint overlay is shown.

Code confirms a Breach-specific `(0.5, 0.5)` footprint anchor and occupied-width normalization, rather than the former common bottom-biased pivot. Current sizing is nominal 100 multiplied by width factor 1.65, approximately **165 world px occupied width**; the source prompt's “110-pixel” wording must not be read as the current world-space size. At the reviewed window scaling this is approximately 110 screen px at 1280 and 83 at 960. Those actual sizes, rather than the large source preview, are the useful art standard.

### Open versus sealed: go

The open form has a broad black cavity. The sealed form replaces it with continuous fitted stone; it contains no red or teal open seam. This difference remains obvious in both small variants without relying on the completion check. The same surrounding rock silhouette makes the state change read as closure of this site rather than replacement by an unrelated collectible.

At small size, the sealed version reads more as repaired rubble/paving than an engineered containment cap. That is acceptable for quiet completed scenery. The source's three iron restraints are much less legible in the Game than in the source preview, so do not claim the detailed locking mechanism itself has been proven readable. The filled-versus-empty mass is doing the successful work.

### Dangerous-source identity: revise, without restoring ornament

The cavity clearly reads as a hole or rupture, which solves the most serious v1 semantic failure. It does **not yet strongly identify an unnatural enemy-producing failure of containment** when the labels and rings are mentally removed. At 960, the red interior fissure and broken clamps almost disappear; an ordinary collapsed paving trench is a plausible reading. The restraint has improved integration but has also subdued the distinctive danger.

Keep the broad cavity and low rubble. Try one stronger structural cue that survives the actual 83 px footprint: for example, one clearly displaced/broken restraint silhouette paired with a broader, still dim inner fissure. Judge that single change at small size before adding detail. Avoid a bright whole-object glow, decorative metal trim, flames or another ornate circular rim. A real visible emergence may supply much of the missing meaning, so valid spawn evidence should inform how far the static art needs to change.

### Boundary, progress and player hierarchy: mostly go; direction cue needs a small-size check

The quiet outer edge leaves the player and cavity more prominent. The inset gold arc is distinct from the exact interaction edge. Completed-site boundaries recede substantially, and the context view contains exactly three physical forms with two open and one filled site. Code confirms the exported 132 px interaction radius, a progress radius inset by 6 px and no decorative center copy.

Sealing and decaying retain persistent upward/downward chevrons in normal, small and reduced frames. They therefore do not depend solely on animation or hue. However, both samples use the same gold arc at the same staged fraction, and the chevron is tiny at 960. Pairwise inspection can identify the change; quick recognition during a fight remains unproven. Verify this first in a moving/crowded sample; if it is missed, increase the persistent direction cue's shape/weight or add a concise local state word rather than making the whole ring brighter.

The player remains readable in the shown forward overlap, behind the completed patch and in the context sample. Code explicitly puts the ground art below actors (`z_as_relative = false`, `z_index = -11`). These few placements do not replace a traversal check on all four sides or establish enemy/hazard layering under crowding.

### Spawn evidence: not accepted

All three files named `breach-spawn-*` were actually inspected. **No spawned enemy is visible in any of them.** They look like the open-site panel with different staging text. The capture script checks an array of three spawned nodes while enemy services are frozen; a populated array is not proof that enemies render, emerge legibly, or remain distinguishable from the cavity. Frozen services are consistent with the parent's reported staging diagnosis, but this review does not claim an independently verified runtime root cause.

Replace these three panels with actual visible source-pour evidence and inspect the replacement pixels. Show at least one emergence/near-source moment and separation from the rim on both window sizes; include Reduced Motion/Flashes Off. The current files cannot support claims about spawn readability, enemy occlusion, source-to-enemy association or a crowded fight.

## Image checklist — actual pixels inspected

Checked means opened and visually inspected, not that every acceptance criterion passed.

| Panel | 1280×720 normal | 960×540 small | 960×540 reduced | Main observation |
| --- | --- | --- | --- | --- |
| Open | [x] `breach-open-normal.png` | [x] `breach-open-small.png` | [x] `breach-open-reduced.png` | Broad open cavity; quiet danger identity |
| Sealing | [x] `breach-sealing-normal.png` | [x] `breach-sealing-small.png` | [x] `breach-sealing-reduced.png` | Player visible over footprint; inset arc and up-chevron |
| Decaying | [x] `breach-decaying-normal.png` | [x] `breach-decaying-small.png` | [x] `breach-decaying-reduced.png` | Down-chevron persists; small distinction needs live judgment |
| Sealed | [x] `breach-sealed-normal.png` | [x] `breach-sealed-small.png` | [x] `breach-sealed-reduced.png` | Physical filled cap; no open colored wound |
| Context | [x] `breach-context-normal.png` | [x] `breach-context-small.png` | [x] `breach-context-reduced.png` | Exactly three sites; paving fit and completed-site hierarchy |
| Spawn | [x] `breach-spawn-normal.png` | [x] `breach-spawn-small.png` | [x] `breach-spawn-reduced.png` | **No visible spawned enemies; invalid spawn evidence** |

Source inspection: [x] `assets/world/objectives/painted/breach_open_v2.png`; [x] `assets/world/objectives/painted/breach_sealed_v2.png`; [x] `assets/world/objectives/painted/PROVENANCE_V2.md`.

## Next decision point and limits

Retain this direction for the single Breach prototype. Obtain valid visible emergence evidence, make one focused danger-silhouette adjustment if the source remains too anonymous, and check sealing versus decay during an actual moving fight. Then decide whether the material/anchor grammar is ready to extend to the next objective. Other objectives still require their own silhouettes and state mechanisms; this review does not authorize making them all shallow ground cracks or copying these rings indiscriminately.

No claim is made about full-run discovery, human reaction time, animation quality, high-density enemy overlap, a completed three-site objective transition, accessibility beyond these frozen settings samples, performance, save correctness, alpha-edge measurements or warning-free shutdown. These limits do not erase the demonstrated gains in terrain fit, physical closure and visual hierarchy.

## Independent pixel-review addendum — initial capture revision

A second reviewer independently opened all 18 prototype screenshots, both v2 PNGs and the old `2026-10-18-abilities-objectives/breach-normal.png`. **GO for the centered ground-footprint and restrained weathered-material direction; REVISE before bulk-producing the other props.** The new hole and filled cap differ by broad occupied shape and value even at 960×540. The small-size rock clusters fit the paving and moss, the actor stays clear in the shown center/behind/front samples, and the subdued exact circle plus inset progress has a useful hierarchy. Carry these principles forward, while giving upright landmarks their own base anchors and projected height.

Three focused corrections should precede using this as the final family reference:

1. **Preserve an unmistakable active-source cue at the actual small size.** In `breach-open-small.png` and `breach-context-small.png`, the cavity survives but the ember fissure and broken iron restraints nearly vanish. Without the text, it can read as ordinary damaged paving. Give one broken restraint a legible outer silhouette and/or make the existing deep inner fissure a few broad, muted strokes that survive downsampling. Keep the black opening dominant; avoid surrounding glow, extra jewelry or a brighter entire rock rim. Reassess after visible emergence is captured, since that may supply the missing source association.
2. **Strengthen the persistent sealing/decay distinction before reusing it.** At 960, the opposite chevrons are only a few screen pixels, while the gold arc otherwise looks the same. The direction can be found in a deliberate comparison, but it is easy to miss at a glance. Use a larger, heavier static direction shape or a concise local “Sealing”/“Losing seal” cue with the current quiet ring. Increasing the whole ring's brightness would undo the improved hierarchy. Reduced Motion preserves the cue, but does not make it easier to recognize.
3. **Correct the shared lighting brief.** `WorldDepthStyle.gd` explicitly specifies a top-right light and southwest projection (`Vector2(-0.72, 0.50)`); `PROVENANCE_V2.md` explicitly requests upper-left light. The source's left-biased edge highlights are visible in the large previews, although the mismatch is subdued at the integrated footprint and there is no conspicuous opposite cast shadow. For every next asset, specify upper-right illumination, lower-left face/contact shade and a compact southwest cast where height warrants it. Do not mirror this Breach merely to fix light; that would also reverse the agreed form. If repainting it, preserve geometry/anchors and change only the directional shading, then compare at gameplay size.

The open/closed distinction is strongly value-and-shape led; a separately rendered grayscale view was not supplied, so this is a grayscale-readability assessment rather than a recorded grayscale capture check. No temporary origin-cross image, full four-side traversal, crowded fight or valid visible spawn is established by this packet. The three `breach-spawn-*` files contain no visible enemies and are excluded from source/emergence approval. No engine, code, asset or Git mutation was performed by this reviewer; this addendum is the only authored change.

## Scoped re-review — refined capture revision, 18 October 2026

**GO for the refined Breach's small-size source identity, static sealing/decay distinction and visible source-to-enemy association. The two visual blockers from the initial revision are resolved in the inspected replacements.** The accepted material and anchor language can guide the next objective candidates; those candidates still need their own integrated visual review. This is not blanket approval of their art or a human combat-readability sign-off.

Only the seven replacement screenshots identified below were reopened for this re-review. No new engine, source-asset or code inspection was performed. The renewed manifest reports 18 captures, zero failures and zero save writes; the remaining eleven replacement images have not received a second independent pixel inspection in this scoped pass.

- **Source identity: go.** `breach-open-small.png` now retains a clearly visible, restrained inner fissure across the dark cavity, with broader broken hardware at the lips. It reads as an active containment failure at 960×540 instead of anonymous damaged paving. In the context frame, the open fissures and physically filled completed patch remain distinct, while the ground material and quiet outer rings keep their earlier integration. The added accent does not become a broad glow or displace the player's silhouette.
- **Sealing versus decay: go.** `breach-sealing-small.png` presents a continuous gold progress arc and the local word “SEALING”; `breach-decaying-small.png` presents visibly broken arc segments and “LOSING SEAL.” The difference is immediately available in a frozen 960×540 comparison and no longer rests on the tiny chevron alone. The clamp treatment reinforces the physical action. The word/segment combination supplies useful redundant shape and text information without restoring the former heavy full-ring graphic. A paused-state frame was not among this scoped selection, so “SEAL PAUSED” has not been independently reviewed here.
- **Visible emergence: go for the supplied stills.** All three refreshed `breach-spawn-*` images now contain visible enemy bodies at and around the cavity. The small and reduced frames make the nearby silhouettes particularly easy to separate; the normal frame has closer source overlap, but actors remain legible and the inner fissure is still visible. This supports source-to-enemy association and correct below-actor ground layering. It does not demonstrate the timing of emergence, moving crowd separation or a played fight. The production history of those enemies is supplied by the parent run, not inferred from a still image.

The initial lighting note remains: current low-form highlights are subtly left-biased, while future briefs must match the world's top-right light. This is not a remaining blocker for the reviewed low Breach direction. No new grayscale image, full traversal or crowded fight was supplied in this scoped pass.

Selected replacement image identities (SHA-256; all beneath `docs/art/reference/2026-10-18-objective-rework-prototype/`):

| Image reopened | SHA-256 |
| --- | --- |
| `breach-open-small.png` | `629ab9a06196d3dbcf69f04fd35e32bcd625c3fd9801bb5b0df534d9010e99ce` |
| `breach-sealing-small.png` | `cd4caf3e37fe1e5788a0706c0089c3667a7716446b593e332152f8fb2721fe9b` |
| `breach-decaying-small.png` | `d3386e80b724b687ed94f155464ceefa053cbf4a65718770c9ca05d4e9c25c5e` |
| `breach-context-normal.png` | `af03d59c9198d2fd6d93c404a3fa1124c364f1851df4e6fe418be1ef9b4a817b` |
| `breach-spawn-normal.png` | `09f8ea9e77f538ea0daa24b4a5e4768e469e0bf135d126b6149b5616c56dbd43` |
| `breach-spawn-small.png` | `b5d83024b7ed2714e9a572c5ea6b7e710de95c312f83d10432dcec5175ba6bec` |
| `breach-spawn-reduced.png` | `8ddc06148e80be7a3b5704ad7aa97a5ef102410a78b6a5edf40ae2eedc108072` |

The parent reports native exit 0 for this capture but recurring shutdown texture warnings, followed by a clean cursor-only A/B fix verification. This reviewer did not inspect those logs. **The cursor-only result is not a final Game test pass; the full-Game final rerun remains pending.** This report establishes only the selected visual results above. Only this report was edited during the scoped re-review.
