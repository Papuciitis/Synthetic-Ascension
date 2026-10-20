# QA only — do not use as runtime ground materials

These previews derive from the two unchanged parent source PNGs. This folder contains no additional material candidates and is excluded from engine import with .gdignore.

The lead provisionally kept both source masters for native integration after source/repeat review. Dry olive lawn character, broad repeated mottling and moss grit at320px remain explicit limits. No regeneration was requested; these QA images do not confer runtime acceptance or certify seamlessness.

| Check | Lawn | Moss / soil |
| --- | --- | --- |
| Native source pixels, wrap cross | [native](cared_lawn_native_wrap.png) | [native](damp_moss_soil_native_wrap.png) |
| 3 x3, 320px per repeat | [960 x960 preview](cared_lawn_repeat_320.png) | [960 x960 preview](damp_moss_soil_repeat_320.png) |
| 3 x3, 160px per repeat | [480 x480 preview](cared_lawn_repeat_160.png) | [480 x480 preview](damp_moss_soil_repeat_160.png) |

Native wrap previews are unscaled768 x768 corner assemblies; central x384/y384 lines are the wrap joins. Repeat previews reduce the source using Pillow LANCZOS, then paste exact periodic copies with no rotations, tint or seam repair. No source file was modified. No engine or native renderer was used.

The320-world-pixel repeat is taken from the current read-only WorldArt vegetation guide.320 and160 screen-pixel repeats represent1.0 and0.5 screen/world assumptions; neither reproduces confirmed native grading, preprocessing or camera state.

All previews were personally viewed. Broad repetition remains visible under inspection; moss has small native edge-structure discontinuities. No seamlessness or gameplay/aesthetic approval is claimed. See the parent [handoff](../README.md), [manifest](../manifest.json) and [measurements](measurements.json) for limits, hashes and exact methods.
