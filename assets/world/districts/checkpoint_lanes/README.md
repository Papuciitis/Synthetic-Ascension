# Checkpoint Lanes — original guard-loggia modules

19 October 2026. Two built-in imagegen originals support the S3 guard-office family. The complete generated PNG bytes are preserved here; no scripted bitmap edits, composites or background removal were performed.

- `guard_arch_open.png`: 1536×1024, transparent outside and through the entry. Opaque masonry bounds `(152,37,1232,941)`. The measured clear span at source row 883 is x477–1056, 580 px wide. Displaying that span at the actual 128 px doorway produces about 72 px of side masonry, hence the planner's 80 px return reservation. The centre opening begins at source y270. Runtime UV/region placement fits existing doors; it creates no physical geometry.
- `guard_arch_closed.png`: 1143×1376, transparent exterior, opaque iron-grille/backing and solid sill. Opaque bounds `(71,65,1002,1245)` fit the planned 128–160 px closed bays. This is visibly a secured inspection window, not an additional usable door.

[Exact prompts, tool mode and original output paths](provenance.json); [SHA256 and read-only alpha/anchor measurements](anchors.json). Primary style reference is selected S3 concept 03; the existing city arcade supplied camera/material consistency. The compact watch mass, roof pitch, masonry returns and support/cutaway geometry are drawn by `CheckpointOfficeForms`; the game never pastes a complete concept scene over its physical map.

The initial prototype uses the project's 64 px cell scale, rectangular 192 px facade and safe 112 px irregular treatment. Its watch has 128×128 px support, 16 px fitting margin, 96 px upright lift and a further 32 px roof pitch. These are the historical v1 proportions. Shared slate, lamps and sun/shadow language are reused; see the implementation audit for that candidate's verification limits.

## Visual refinement v2

`guard_quiet_infill_v2.png` is a new opaque 1254×1254 original for the supported infill/watch surfaces. [Exact prompt, source path, hash, material bounds and UV/display scale](infill-v2-provenance.json) record the built-in generation. The returned original is copied unchanged. Runtime geometry supplies plinths, corner returns, watch window/eave depth and real cardinal thresholds; the texture has no painted doors, light source or symbols. Both original arch masters remain unchanged. Native acceptance is recorded separately from material generation.

The designer's second revision raises the wall head32 px and insets the rear eave32 px, retaining the old ridge/top/bottom envelope. A 100×128 px front joins a continuous28px masonry side within the same128px support; cap pitch stays32px. An exact lower-body coverage union removes redundant cap-covered triangles without enlarging coverage or the global32-triangle capacity. N/E/W thresholds visibly join their original64px sill and48px of the already clear apron, with short grounded jamb returns rather than detached bright end bars. No physical floor/collision is added.
