# Linux domestic interiors — 20 October 2026

This bounded packet records sleeping, cooking, work and storage purpose in the
two kept actual S2 homes, explicit domestic masonry, and the separate upper-field
and entry finish. It follows the [domestic brief](../../2026-10-20-medieval-gardens-and-domestic-interiors.md)
and [concept-fidelity audit](../../../audits/2026-10-20-concept-fidelity-and-chat-audit.md).
Purpose/masonry/reward policy is the checked commit `4c4a6cb2`. The separate
frontage/tool commit is `276e5e152e2a4d718149e044c16dcc21d938c514`. Root checked all
eight staged finish/tool/test SHA256 values against all four final native launch
records before committing. The [file binding](process/finish-commit-binding.json)
names those eight paths and recorded hashes; the packager also compares their
current bytes. Other integrated ground/scene sources retain separate ownership.

<!-- RECORDED_DOMESTIC_SUMMARY_START -->

Packaged recorded checks and inspected capture labels:

| Check | Passed / failed |
| --- | --- |
| CityDomesticInteriorTest (domestic-policy-green) | 336 / 0 |
| DomesticWallMaterialTest (domestic-final-DomesticWallMaterialTest) | 68 / 0 |
| DomesticRewardStabilityTest (domestic-final-DomesticRewardStabilityTest) | 43 / 0 |
| DomesticFrontageFadeTest (domestic-jamb-fade-green) | 16 / 0 |
| DomesticFrontageFinishTest (domestic-frontage-final) | 55 / 0 |

| Native capture | Monitor seconds | Stills / fight frames | Occupied recording seconds |
| --- | --- | --- | --- |
| [revision1-bed-small](revision1-bed-small/interior-whole.png), revision1 | 49.798 | 7 / 0 | 0.0 |
| [bed-small](bed-small/interior-whole.png), revision2 | 62.989 | 9 / 21 | 3.21207 |
| [bed-normal](bed-normal/interior-whole.png), revision2 | 70.175 | 9 / 21 | 3.153794 |
| [fruit-small](fruit-small/interior-whole.png), revision2 | 63.703 | 9 / 21 | 3.105047 |
| [fruit-normal](fruit-normal/interior-whole.png), revision2 | 68.841 | 9 / 20 | 3.090632 |

All listed native runs have exit0, no monitor diagnostics, zero fixture failures and zero saves. Earlier checks retain their own exact source snapshots; they are not relabeled final integrated-source regressions.

<!-- RECORDED_DOMESTIC_SUMMARY_END -->

| Actual home | Seed / chunk / building ID | Kept physical form |
| --- | --- | --- |
| [Bed home, small](bed-small/interior-whole.png), [normal](bed-normal/interior-whole.png) |16102026 / (0,3) /944996572 | Irregular open hall spanning two existing volumes; south two-cell door. |
| [Fruit home, small](fruit-small/interior-whole.png), [normal](fruit-normal/interior-whole.png) |17 / (-3,5) /2128236757 | Rectangular room-first footprint and north two-cell door; any generated partitions remain authoritative. |

Each final capture keeps seven named architecture stills, two occupied stills,
the original `capture-info.json`, an `occupied.mp4` and its original encoding and
clean-decode sidecars. Stills are copied byte for byte with their names intact.
The silent lossy H.264/yuv420p videos use recorded frame wall times; the first
observed frame covers any leading capture gap and the last frame holds to the
measured recording stop. No repaint, resize, interpolation, montage or raw fight
frame PNG bulk is bundled. The encoding sidecars retain every source image hash.
Their scratch paths are provenance and do not imply those files are bundled.

The [revision1 seven-plate run](revision1-bed-small/interior-whole.png) remains
separate. Final revision2 uses the inherited production-input/BFS route followed
by actual input to center the resolved goal within8pixels, with a180physics-tick
timeout and failure if blocked. It never teleports along the route or changes
collision, roof counters or player speed to pass. Actual desired/resolved/player
positions remain in the manifests, including contact endpoints.
Some frozen revision2 metadata repeats the initial mistaken “23–41px off center”
qualification. [Metadata qualifications](metadata-qualifications.json) records
the correction from the actual revision1 route: 22.933–22.998pixels off goal,
with about41pixels separately measuring valid collision support distance. The
original metadata, PNGs and video bindings remain unchanged.

The review uses the actual Game, a fixed whole-home camera at zoom(1,1), normal
HUD and natural neighboring detail. It stages the player outside once, disables
ambient spawning/encounter beats, freezes streaming after an actual stable
reload, and uses god mode. The optional controlled occupied phase adds real
ordinary/armoured enemies with live AI, attacks and projectiles for a short
recorded route. Its explicit post-comparison actor teardown permits the final
architectural exit; it is not a fake kill or proof that the encounter was cleared.
These are controlled native samples, not continuous human play, combat comfort,
balance/performance approval, or acceptance of every generated street/layout.

The four household groups use existing original art at measured uniform scales:

| Prop | Original source datum, pixels | Uniform scale | Estimated ground size, world pixels |
| --- | --- | --- | --- |
| Cot |(530,1345), transparent midpoint between front feet |60/632 ≈0.0949367 |60×107.184 |
| Cold cooking hearth |(800,805), south stone-base contact |120/1465 ≈0.0819113 |120×45.379 |
| Small table/work surface |(512,795), visible front-foot baseline |64/771 ≈0.0830091 |64×26.895 |
| Crate/storage |(210,456), local datum in existing420×464 AtlasTexture |64/420 ≈0.1523810 |61.562×23.771 |

The hearth remains an inert cold prop; there is no new fire/light/hazard or
interaction/loot rule. Original cot/hearth RGBA bytes, hidden RGB, faint alpha
residue and aspect remain intact. The existing table and crate are reused; no
new furniture pack or asset generation occurred in this integration. Ground
footprints are measured estimates, not alpha-traced colliders.

[Measured households](measured-households.json) records each actual local layout,
source datum/scale/hash, visible/ground bounds, six added cells, physical
approaches/contacts/projectile hits, roof sequence and reload evidence. The
original perimeter/windows/doors/partitions/volumes/IDs retain their ownership.
Furniture intentionally adds six streamed `HALF_COVER` cells when all four props
fit; this is not an unchanged complete blocker set. The existing coarse low-cover
collision/projectile contract is used, and its default random prop art is
suppressed only for those owned cells. Protected routes remain connected; a
partial/no-fit layout omits unavailable groups instead of filling a doorway.

Furnishing requires actual S2 noncivic `row_house` use and a known connected
single-item ambient reward owner. Multi-item, encounter/security, forced/area-
large and unknown owners are excluded. Material presentation has its own guard:
eligible domestic perimeter/window/partition/corner cells use a separate rough
stone material while reviewed S3/civic and other building uses retain theirs.
The upper finish repeats the original clean plaster region at two source texels
per world pixel with no anisotropic stretch. New piers/header/lintel and the
inherited domestic jamb junctions use disjoint opaque faces during fractional
roof fades; the original opening width/baseline, alternate north door and roof
cutaway remain controlled separately.

[Reward comparisons](reward-comparison.json) retain the actual seeded chance,
count, full item identity/mods/manifestation, claim/secondary transition and run
RNG results for both homes, plus a separate guaranteed single-item factory
comparison. The baseline disables only the six new walkability exclusions
synchronously because production loot placement queries that grid. No physics
frame runs during the switch; blocker/broad-phase and RNG/claim state are
restored. Legal positions may differ, although they happened to match in the
recorded two fixtures. Pure planner RNG checks alone are not used to claim full
reward preservation. The actual retained rolls are `curse_leadfoot_vigil` and
`conduit_heart`, respectively, with exact data in the original stdout/JSON.

[Source bindings](assets/source-bindings.json) distinguish recorded launch PNG,
import and resource hashes from files present at packaging. The original
cot/hearth manifest, exact Linux import sidecars and crate AtlasTexture resource
are retained without copying the large source PNGs. Source PNG hashes are:

- Cot: `22549e75329ee9164f9f41fbefcdea2e6b028309a7c358362b4c11a2fc69c143`.
- Hearth: `fd6a6434311135e5c7b09ca6b2c3c3ca47333c33b78fed69f826527c9bc7e26b`.

The [process summary](process/summary.json) labels failed setup/import/parse
attempts, clean feature REDs and clean checks independently of historical folder
names. In particular, the initial runtime setup timed out before a usable UID
map; the first interior attempt printed229/52 amid missing cot/hearth loaders;
and the first frontage “green” attempt was interrupted after a bool inference
parse failure. None is presented as valid GREEN or clean feature RED. Prepared
same-machine Linux imported resources/class/UID cache enabled the later baseline;
this packet does not prove clean-clone importability.

Feature REDs retain initial absent-adapter0/1, frontage30/8, reward policy321/15,
new-detail fractional fade2/6 and inherited jamb fade8/4. The earlier three-point
fade GREEN8/0 did not test inherited jambs; the later16/0 includes both literal
jamb failures and two preserved upper-cap controls. All commands, exits, stop
reasons, diagnostics, resource time series and stdout/stderr/engine logs remain.
Full original source-hash/untracked records move losslessly to deduplicated
`process/sources`; only machine-wide Git status is omitted, with the original
result JSON hash retained. [Scoped inputs](process/scoped-inputs.json) bind each
run to its recorded snapshot; a null means unrecorded, not unchanged content.

`evidence-index.json` lists every bundled file with size/SHA256. [Comparisons](comparisons.json)
list source changes between revision1 and final review, and check deterministic
same-home layouts across sizes. Final captures also include separately checked
ground and scene roof work, so they are not a one-variable furnishing/material
ablation. Resource samples are observations from scripted runs with first-use
preparation, not a matched frame-budget benchmark. The purpose/masonry/reward
commit remains separate from the later frontage/tool slice in
[packet provenance](packet-provenance.json).
