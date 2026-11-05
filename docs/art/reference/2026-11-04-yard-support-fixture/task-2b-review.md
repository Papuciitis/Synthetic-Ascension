# Task 2b independent SPEC + QUALITY review

Status: closed for the bounded opt-in implementation at the pins below.
Read-only review of production and test
sources; this reviewer launched no Godot instance, changed no production/test
source, and made no commit. Base project commit for the original renderer and
shader is `d7cfb52f`.

## Findings and verdict

No actionable production or final test/tooling defect found. SPEC PASS and
QUALITY PASS for the bounded default-off prototype, qualified by the isolated
fixture scope below. The final current-source renderer, helper, Map, retained
data subset and native pixel checks pass. Actual Game appearance, traversal,
streamed reload and cost remain separate unpassed gates; this is not default
activation or trailer-readiness approval. Whole-project parse is outside this
fixture review and remains separately guarded/pending at this closing snapshot.

The original `ground_splat.gdshader` is byte-identical to `d7cfb52f`:
`git hash-object --no-filters` and the original commit blob both give
`8619a16bcd034c85e771f6141c969a18584feac0`; working-file SHA256 is
`64c8d2fa214bc30e1d58d3dfea5ea0719113f6ae09689f6ebe1b3d403f1314b9`.
This comparison does not rely on line-ending normalization.

## Reviewed contracts

- Canonical parser rejects noncanonical signs/leading zeroes, invalid field
  counts, conversion overflow and out-of-range axes. Requested coordinates and
  seed are explicit; enabled policy must be one of the two supported S7 families.
  Requests survive inactive policy; missing/invalid manager environment settings
  leave the normal path unchanged. Manager reads once per splat and paints after
  existing household care.
- Default mode retains the original Shader object. New mask, texture and Shader
  resource are lazy. Shader switching copies all original shared uniforms; the
  original shader source/resource is never mutated. Unsupported/missing/duplicate
  source hooks fail closed.
- Selection requires one unambiguous household at the exact target coordinate
  and seed. Max composition precedes the Map replacement. The Map exclusively
  owns the independent bytes and clips against real `material_at` semantics and
  exact existing care bytes. No original cover/light/slot/RNG mutation was found.
- `_fill`, wrapped reuse and world reset clear mask spans. Positive domestic
  care and planting clear affected bytes, including writes that do not increase
  already-positive care. Independent dirty uploads do not depend on old `_dirty`.
- Generated shader samples unwarped cell coordinates, vetoes zero-centre support
  and positive care, limits the addition to yard role 4, and reuses the existing
  S7 material sample/repeat/grade. Existing care code is unchanged. Debug view 3
  exists only in the generated resource.
- Fixture builder uses fresh ignored roots, unchanged named production files,
  actual minimal class metadata and only two explicit asset-loader leaf doubles.
  Native mode enforces the original 14-layer cache hash/size and actual imported
  city textures/mip metadata. Original baseline renderer and shader are copied
  from `d7cfb52f`; only the validated baseline class-name removal and shader-path
  redirect occur. Both viewports use identical global coordinates and assets.
- Launcher validates executing-launcher and source/asset/stub/guard pins, records
  unfiltered logs/native exits, isolates profiles, launches hidden with retained
  handle, preserves the fixed data/native limits and refuses concurrent engines.
  Limits are sampled safeguards, not a peak-memory or hard-time guarantee.
- Existing subset retains the 13 data cases and omits the three manager
  integration checks explicitly. Its cleanup scheduling changes fixture lifetime;
  it cannot establish original-batch performance or whole-suite success.

## Evidence reviewed before final continuation

- `task2b-red-1`: actual absent-API assertion, 0/1, native exit 1; no parse error
  or guard stop. Correct RED scope.
- `task2b-green-3`: actual renderer 72/0, exit 0, no diagnostics/stop, sampled
  55 MB private. Current production renderer/factory hashes match that run.
  Its renderer test predates three later domestic-care overlap assertions.
- `task2b-green-3/subset`: private-memory stop at sampled 65 MB; incomplete.
- `task2b-regression-1/subset`: timeout at 30.63 s, sampled 56 MB; incomplete.
- `task2b-native-1` and `task2b-native-parent1`: startup refusals; no pixels.
- `task2b-native-parent2`: parent reports 43/1 plus two setup diagnostics, exit 1,
  no guard stop. Despite useful pixel measurements this is a FAILED run. The
  arbitrary planner-count assertion and pre-tree viewport transform are being
  corrected in test setup; no production change was needed. The failed evidence
  is preserved and is not used as acceptance.

## Final continuation independently inspected

Read final per-suite receipts, logs and parent sequence result, and verified
all 24 `task2b-final-data/source-pins.json` artifacts and all 36
`task2b-native-final/source-pins.json` artifacts against their SHA256 pins.
Every unchanged repository-source pin also matches the current working file.
The final production hashes remain the ones reviewed before execution.

| Final evidence | Actual result | Sampled private MB / elapsed seconds |
| --- | --- | --- |
| task2b-final-data/renderer | 75/0, native exit 0, no diagnostics/stop | 53 / 1.26 |
| task2b-final-data/support | 82/0, native exit 0, no diagnostics/stop | 43 / 1.36 |
| task2b-final-data/map | 69/0, native exit 0, no diagnostics/stop | 43 / 1.33 |
| task2b-final-data/subset | 60/0, native exit 0, no diagnostics/stop | 52 / 2.83 |
| task2b-native-final/native | 46/0, native exit 0, no diagnostics/stop | 241 / 8.50 |

The current 75-check renderer log explicitly passes real later-household-care
overlap, preservation of its fractional bytes, and presence of actual fractional
care. The final 60-check subset uses the labelled cleanup scheduling and still
omits the three manager integration checks; no full-suite or old scheduling
performance claim follows from that result.

Native test corrections were reviewed at `YardSupportNativeTest.gd`:
`viewport()` now adds the viewport to the tree before setting canvas transform;
the planner gate requires six unique controls plus uncontrolled positive yard
support, explicitly checks uniqueness/remaining support, and returns failure
cleanly if insufficient. The late-care search explicitly asserts that it found
a real positive support cell. These close the setup/nonvacuity issues from the
failed prior run.

Final native receipt/pixels report 10 potential cells above 60, six distinct
controls and four remaining uncontrolled cells. Positive yard pixels changed:
**3299**. Default-off, enabled-empty, disable, reset, zero-mask, alpha, late-care,
late-floor and each road/lane/footway/courtyard/indoor/care control changed:
**0**. The current/factory-generated shader SHA256 is
`98c0b162c874ea50a7fb3f0b60127e97cc82a1fade8b9833c7dcd7d89f211702`.
The generated-code pin matches both final data and native receipts.

Also viewed original `preview-after.png` and `mask-debug3.png`: visible real
material pixels and a local nonrectangular support field agree with the fixture
contract. This synthetic layout has no household building/route and establishes
neither actual generated S7 composition nor doorway traversal. No new aesthetic
acceptance is implied.

## Production pins reviewed

| Repository path | SHA256 |
| --- | --- |
| core/systems/world/ground/GroundSplatRenderer.gd | f74134fd9f5cf0a4b0b0ff87ab39faaebb38e7328aa5570d8c180328c3bd591b |
| core/systems/world/ChunkManager.gd | d753fc81d2e41697fd85e196b12b8fbf151802086d08c3862e7a83ade296aabc |
| core/systems/world/ground/YardSupportPreviewShader.gd | f535a599ff996283002f25efc6308184ae1d4bfdb3b21b074eaa1019af189423 |
| core/systems/world/ground/ground_splat.gdshader | 64c8d2fa214bc30e1d58d3dfea5ea0719113f6ae09689f6ebe1b3d403f1314b9 |

## Final reviewed tooling pins

| Repository path | SHA256 |
| --- | --- |
| tools/tests/YardSupportRendererTest.gd | 17a94c4f7ea6543d5e51a38e81823236b0b1cb8a2807f8da4bf4e8a77d8b1ec6 |
| tools/tests/YardSupportRendererTest.tscn | 7b9f754d2b5aad7ca3ef7b9293e4c90d2c75f523d5cae2422403eb38fdd0e18f |
| tools/tests/build_yard_support_renderer_fixture.py | 2d429782f1cff3cb5141f57fcab5e3f36a4917f605ec33c9eb8e32801d88139b |
| tools/tests/run_yard_support_renderer_fixture.ps1 | 2c047b78e36e1fbc27f30df641f37723ccc56fb771c5b57402a47cf27d205058 |
| tools/tests/YardSupportGroundDataSubsetTest.gd | ca95626216f3a4d399dff88887a59511fbc346463860dd4bcc5ef06e9f955711 |
| tools/tests/YardSupportGroundDataSubsetTest.tscn | 918e30a27347d9451b8473230d4c56144645245b4fa5770ff14500311344caa3 |
| tools/tests/YardSupportNativeTest.gd | bd6776d646bee0345abf308dd10e2170aa6defd6fb022816edf24352d35a05d3 |
| tools/tests/YardSupportNativeTest.tscn | 47ec4a860fae12d767eff1bae6009b5e92f050dc5a249713123ba90468c388b2 |
| tools/tests/YardSupportNativeParseTest.gd | 27f38492793e1a082fde64968e07d5e962ef4f9fabbe6ade4d421cc1938017ff |
| tools/tests/test_yard_support_renderer_fixture.py | c6bda2914a9fbf2b779a3c96f9283ed6f9b5295d35dc5b3f3c61df2eb712dfdb |
