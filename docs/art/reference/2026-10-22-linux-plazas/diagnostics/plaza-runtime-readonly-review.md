# Plaza source review, 23 October 2026

Scope: seven runtime scripts against recorded1797bc67 baseline snapshots, including earlier committed candidate hunks and linked offline builder geometry/atlas declarations. No runtime edits, engines or Git actions by reviewer.

Finding: no actionable source blocker found.

- Fill resolution consistently passes the resolved style to texture, offsets and diagonal compatibility; thickness/lift/coping and variant counts match the builder. Batch ownership stays per chunk.
- Worn Dressing instances and renderer batches retain their own texture references while the shared cache advances to one state. Transition preparation keeps strong local references across yields until warm_state takes ownership; tended releases worn caches. No new resource self-cycle found.
- Feather geometry has 2n+1 vertices and colors, valid indices 0..2n, one annular band plus inner triangle fan. A source-only 10,000-case seed/size calculation retained radial order and noncollapsed inset. This is not engine raster proof.
- Flat edge patch extent plus outward shift is at most 29 px from a 64 px cell center; largest edge debris extent is 19.5 + 5 px. Existing ring/half-cover physics is unchanged, and low clutter is below actors and outside actor cover.
- All seven current runtime hashes match the frozen overlay candidates. All 11 current stage source/UID hashes and 72 relevant ruin/moss import+source hashes match the stage manifest.
- Nonblocking documentation qualification: builder calls a generic 16% kerb albedo darkening soot/oil. Runtime has no oil decal item or machinery ownership claim; do not describe these baked generic blotches as a verified operating oil source.

Original full parse audit remains 564 compiled / 0 compile failures with 8 exit diagnostics, 772 objects / 548 resources in the plaza checkout. The same-checkout seven-file production overlay reproduces it exactly; main baseline is clean. This excludes those seven runtime changes as the failure cause in that checkout and does not establish first cause. Sorted diagnostic is separate and cannot substitute for original audit.

Headless bed discovery is clean and native queue validation passed against final raw+guard/helper/source bindings, engines_started0. Three natural fixture candidates exist: S6 seed 4 entry_court (0,-1), S7 seed 1 wardstone_court (4,3), S8 seed 2 exploration_reward (-1,-15). Actual-game native bed images/reload checks remain separate pending root execution/review.

## Frozen runtime source hashes

```json
{
  "core/systems/world/ChunkManager.gd": "d404c7dbfe92e766378cf4552c8d24a71beb3e192dc2fe77705bcb0f63d4d574",
  "core/systems/world/chunks/ChunkBlockRenderer.gd": "9d70d3c320b7cd89dbf748dac66ad5ac764774594196e58803381da687dce6ff",
  "core/systems/world/chunks/ChunkBuildData.gd": "517ccd6eeca2f9c713073fb939d748778a636993e790f9e56aa3f120f3b51618",
  "core/systems/world/chunks/PlazaEdgeKit.gd": "baee634f650e26d4d5ae670904c801ab1c1914755665ee349d83824458a11cb1",
  "core/systems/world/proc/chunkgen/PlazaPresentation.gd": "6c3f5d62de0677fbb0b605f5804e65f1d09117b22fc168e938e52f41b3667284",
  "scenes/world/buildings/CityBlockRoofForms.gd": "ed2afa9ae8bd179cffd58aa10e3366cb0a697e14aba572e0423b2845b6616fc0",
  "scenes/world/plazas/PlazaDressing.gd": "5f57a20ed7007b76b144398ce15cb47dfc3cc2ee3d6056499955f2d0c4c17222"
}
```
