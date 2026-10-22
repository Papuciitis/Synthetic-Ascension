# S2 bed home cutaway, current source (lead review item 2)

The reviewed slate-roofed S2 bed home 944996572 (seed 16102026, chunk 0,3) was captured natively with
`tools/dev/CityDomesticInteriorPreview.tscn --review=normal` (opengl3, GL Compatibility, Mesa UHD 620).

- `s2-944996572-before-db3c603f/`: the integrated production tip `db3c603f`, before the masonry fix. Its cutaway walls had
  fallen back to the pale city-ashlar relief. Phase 1 tied warm masonry to clay roofs, and this home has a slate roof.
- `s2-944996572-after/`: `f0242415`, "keep warm domestic rubble behind every home's cutaway". It restores the checked
  prefix's warm rubble for every ordinary home, whatever the roof. Furniture, the mat and cot sleeping corner, the
  hearth and crate work wall, the props' contacts and the central circulation are unchanged.

Each folder's `provenance.json` records:
- the exact command and renderer;
- the commit, and `git status --porcelain` (empty: a clean worktree);
- the sha256 of the scoped sources and of every output PNG;
- the run result.

The PNGs are the unedited 1280x720 native outputs, a subset of each run's frames.
Checks on the fix commit: DomesticWallMaterialTest 166/0, CityDomesticInteriorTest 693/0, DomesticCompositionTest 151/0,
DomesticRewardStabilityTest 111/0, S2PaleMasonryTest 71/0, CityBlockKitTest 1314/0 (all completed).

Only S2 homes are supported by this preview tool: S3, S4 and S8 sample homes refused with explicit errors. A non-S2
home cutaway needs a preview extension and is still open.
