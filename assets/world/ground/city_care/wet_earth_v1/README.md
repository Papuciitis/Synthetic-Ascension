# Quiet wet-earth trial source

20 October 2026. One original built-in image_gen generation, no edit or source
post-processing. [Exact prompt and original path](prompts.json),
[source measurements and SHA256](manifest.json).

**Provisional source candidate, not an integrated fix.** The lead inspected the
actual L2 S7 plates: the old wet material forms repeated light/dark ribbons at
960 and 1280. Its source also has strong directional structure. This does not
prove that source art is the sole cause: Linux must inspect the bound layer,
repeat, UVs and cache before choosing a replacement. This single candidate is
supplied for that bounded comparison, not a new terrain or district family.

[wet_earth.png](wet_earth.png) is opaque RGB, 1254×1254, original source bytes
unchanged. SHA256:
`46d180c754c9c531c88e445dbcb119f435c1d3e7d3340ecac5118d57842f619d`.
It uses neutral brown fine mineral earth and sparse small stones, without
large leaves, painted shadows, furrows or broad parallel ruts. It is more granular
than the older painterly dry soil; native filtering may help, but it must not
be sharpened into noisy grit. Its dampness and wet/dry distinction remain
unverified. Do not present it as a puddle or glossy water material.

The lead viewed the original, 192px and 384px repeat sheets, native wrap joins
and comparison against old dry/wet earth. No dominant stripe/ribbon repeats
appeared in those previews. Broad mottling and granular detail remain visible;
the source is not certified perfectly seamless or aesthetically accepted in-game.
See [QA](qa/README.md). QA copies are inspection aids, not production textures.

## Linux trial

- First verify the existing semantic mud layer5 and sampling/cache inputs in
  the same natural S7 crop. Preserve source identity evidence before changing it.
- If the existing input still produces bands, compare this candidate at the
  current 384 world-px repeat, then inspect native 960 with actors and orange
  cues beside the existing dry earth and the kept moss/soil. Keep material scale
  and grading restrained; do not brighten all ground or hide the problem with blur.
- If selected, replace the presentation source for semantic mud5, not its
  terrain ID or coverage slot count. Preserve the old PNG. Rebuild/import and
  bind the validated 14-layer array; update the manifest and relevant cache/
  terrain checks. Do not add another semantic ID merely to trial different pixels.
- Publish the same S7 crop plus a real dry-earth control and a short occupied
  comparison. Reject it if it reads as loose gravel, makes dark actors disappear,
  has obvious seams or fails to look meaningfully different from dry soil.

No Windows Godot/import/cache bake or runtime-code change was performed for this
asset. Linux owns the integration and native judgment under the
[L2 lead review](../../../../../docs/art/reviews/2026-10-20-linux-l2-lead-review/README.md).
