# Worn plaza bed underlay: source-only causal correction

The S6 native image is rejected despite its clean instrumented run. Preserved image SHA256 is `5b0c4f534b071ffcc1281797c341ea01c1df514e32ebcb9390c8bc89935991af`; old raw records and all original helpers remain unchanged. `causal-source-evidence.json` binds the inspected image, capture metadata and actual source files.

The actual natural S6 seed 4 entry court at chunk `(0,-1)` has bed cells `(23,19,3,2)`. Its captured focal material is district yard index 6 with care 1.0; the care mask has exactly those six cells. `ChunkGenStamp` deliberately records the urban island in `_ground_planting_rects`. After floor stamps, ChunkManager calls `GroundSplatRenderer.paint_planting`, and the shader paints a green cared bed/margin there. The worn bed's rough boundary has zero vertex alpha and exposes that underlay. Actual piece counts contain no kerb node; the inspected soil texture has no green rectangular border. Player and prop shadows are separate local silhouettes, not the green perimeter.

The minimal runtime patch keeps the existing island rectangle, bed topology, prop/low-cover owners, routes, seeds and every original generator stamp. Tended state still subtracts the bed from repaving. All four worn states repave the full existing island at the plaza's own index (7 or 9), so planting eligibility excludes those cells and the retained planting metadata cannot create a care owner there. The existing earth/wet/weedy polygon then feathers onto paving. No GroundSplat, policy, shader, art, new pass or outside-island changes.

Frozen runtime before: `6c3f5d62de0677fbb0b605f5804e65f1d09117b22fc168e938e52f41b3667284`.
Frozen proposed after: `c1635b11e42ea5d220cc06074771f90b7024ceba807da49f8f6cf243a53d7324`.
Runtime patch: `ebc74e69a6c1579472c4fc5ecca2e4d41eae537245a026754ad3ccc41724993b`.
Corrected focused test: `dc54cb0d2fbd4a4d05fddf02524c7ed82c82501d84ed708050e6a2cafba3b56f`.

The test reuses three instances of the existing real S6 fixture (off/on/repeated), then isolates the five maintenance-state underlay contracts over the same actual bed and original floor arrays. Final natural physical/half-cover arrays are held constant; the pinned S6 fixture has no centrepiece. It paints the real GroundSplat floor/care APIs and checks all bed cells plus all cells outside the original islands. Routes, foliage/landmark generation, floor prefix and original physics remain controls. This state override is a unit-test technique only; native views use naturally generated themes and seeds.

`assertion-manifest.json` enumerates all 37 checks and the exact 8 allowed RED failure labels/diagnostics. Predicted RED footer is `PlazaBedUnderlayTest: 29 passed, 8 failed`; predicted GREEN is `PlazaBedUnderlayTest: 37 passed, 0 failed`. These are unrun predictions, not acceptance evidence. Footer JSON keys are `passes`, `failures`, `states`, `fixture`, `save_writes`; each state records `state`, `material_ok`, `care_ok`, `outside_ok`, `bed_cells` with material/care per cell.

Independent source review by `/root/street_native_prep_22` found and corrected one initial fixture-only problem: disabled-pass variants omitted mark_ring bits. The frozen corrected test clones natural physical/art owner arrays while retaining original floors. No further concrete GDScript/type or causal-contract blocker was found. Neither reviewer ran an engine.

Root's proposed execution sequence, after confirming no pinned plaza engine remains:

1. Inspect `runtime.patch`, `test.patch`, `assertion-manifest.json`, and `root-underlay-red-green.py`.
2. Install **test.patch only** in `/tmp/sa-wp2-plazas`; do not apply runtime.patch yet.
3. Run the root executor dry run, then its explicit `--execute` mode. No executor has been run by the preparer.

```bash
python3 -B /home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/plaza-bed-underlay-fix/root-underlay-red-green.py
python3 -B /home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/plaza-bed-underlay-fix/root-underlay-red-green.py --execute
```

The executor guards all seven runtime hashes plus installed test bytes. It runs the real focused RED through the existing guard at 65 C start / 25% duty and requires exactly the predicted footer, eight exact diagnostics, expected failing fields, normal expected nonzero exit, no extra errors and no save writes. Only then does it write the exact frozen proposed runtime bytes. It runs focused GREEN, then fresh three-helper scoped parse and bounded discovery with new labels and output JSON. Any unexpected result stops the sequence. If GREEN is unclean, it restores original runtime bytes after owned guard cleanup; if GREEN is clean and later discovery fails, it retains the fixed source for investigation and reports the failure. The executor records source and raw/guard hashes and never marks native visual acceptance. It creates no commits.

Fresh labels are `city22-plaza-underlay-red`, `city22-plaza-underlay-green`, `city22-plaza-bed-tools-parse-r2`, `city22-plaza-bed-discovery-r2`. Old labels/output files are refused. All engines are headless, at 65 C start, 25% duty, max-wait 900; timeouts are 600/600/300/900 seconds respectively. Full argument arrays appear in the dry run.

Fresh discovery reuses the original unchanged `PlazaBedDiscovery` helper and writes `plaza-bed-underlay-fix/plaza-bed-discovery-r2.json`. The separate `plaza-bed-helpers-r2-meta.json` expects the fixed Presentation hash; original metadata and overlay evidence are untouched. The r2 native driver explicitly replaces the one historical old Presentation hash with this reviewed new binding while retaining all other seven-file source guards.

The new native observer extends the original unchanged `PlazaBedGamePreview` and adds only real per-bed-cell material/care evidence and a gate requiring plaza 7/9 plus care 0 in every discovered worn bed cell. Actual Game, camera, native plan/node checks, HUD, unload/reload and rendering settings are inherited unchanged.

After clean executor/discovery output, root may inspect and invoke:

```bash
python3 -B /home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/plaza-bed-underlay-fix/plaza-bed-native-r2.py --validate-only
python3 -B /home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/plaza-bed-underlay-fix/plaza-bed-native-r2.py --start-temperature 65 --duty-percent 25
```

Native labels are `city22-plaza-bed-native-r2-s6/s7/s8`; outputs are `/var/tmp/sa-city22/plaza-beds-r2/s6/s7/s8`. The old S6 bug image remains intact. Required visual review: working/military patches read as flat useful earth without a raised green garden frame; damp ground blends naturally; the actual expected plan/node, all bed-cell underlay and reload contracts pass. Original full parse-audit shutdown diagnostics remain separately unresolved. No whole 27,000-check rerun is requested.
