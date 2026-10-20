# Linux theme atmosphere — 20 October 2026

This packet records physical district daylight, broad passing
cloud, modest damp-ground air and actual environment light response. It
complements the [structural roof/contact work](../2026-10-20-linux-scene-depth/README.md)
and [domestic purpose/material work](../2026-10-20-linux-domestic-interiors/README.md).
Atmosphere does not establish the missing planes, contacts or architectural
purpose by multiplying the whole image darker.

<!-- RECORDED_ATMOSPHERE_SUMMARY_START -->

Counts below are read from retained monitor results/assertion footers.

| Final focused native check | Passed / failed |
| --- | --- |
| ThemeAtmosphereDryReceiverTest | 6 / 0 |
| ThemeAtmosphereReceiversTest | 35 / 0 |
| ThemeAtmosphereTest | 92 / 0 |

All eight explicitly selected actual-Game/authored runs have exit0, no monitor diagnostics, zero fixture failures and zero saves.

| Native sample | Run label | PNG size |
| --- | --- | --- |
| [s2-small](s2-small/exterior-profile.png) | atmo-s2-small-final | 960×540 |
| [s2-normal](s2-normal/exterior-profile.png) | atmo-s2-normal | 1280×720 |
| [s3-small](s3-small/exterior-profile.png) | atmo-s3-small | 960×540 |
| [s3-normal](s3-normal/exterior-profile.png) | atmo-s3-normal | 1280×720 |
| [s7-small](s7-small/ground-before-profile.png) | atmo-s7-small | 960×540 |
| [s7-normal](s7-normal/ground-before-profile.png) | atmo-s7-normal | 1280×720 |
| [s7-reduced-fight](s7-reduced-fight/ground-before-profile.png) | atmo-s7-reduced-fight | 960×540 |
| [authored-contexts](authored-contexts/s1-institution.png) | atmo-authored-contexts | 960×540 |

Fourteen physical profiles are data/test coverage. Native district art samples are only S2 service courtyards, S3 checkpoint lanes and S7 canal services, plus the separately authored S1 and Hub controls.

Weather-only diagnostic PNGs are retained explicitly at8samples/second; actors/Game remain paused.

The [Reduced Motion occupied video](s7-reduced-fight/atmo-s7-reduced-fight.mp4) uses 34 captured frames over 6.230 measured wall seconds, with 25 real weapon fires, 27 hits and 6 maximum active projectiles. Inspection pauses remain disclosed; full decode is clean.

<!-- RECORDED_ATMOSPHERE_SUMMARY_END -->

The [audit](../../../design/2026-10-20-theme-atmosphere-audit.md) assigns fourteen
procedural profile families. S2 courtyards use open, slightly warm daylight;
S3 inspection lanes have cooler broken cloud. S4 masonry and sheltered civilian
routes differ in exposure; S5 gate court stays pale. S6 workshop and ruined
services use neutral or drier wind-exposed light. S7 underpass/canal services
have diffuse sky and low air only on actual damp receivers. S8 rail loading
ground is open and dry, while muster space has cooler cloud. S9 outer approach
is clear and windy beside less exposed service yards; S10 departure court is
pale. S11+ retains the existing courtyard family fallback. The generated
`profile-catalogue.json` copies numeric profile literals and their source hash;
fourteen data definitions do not establish fourteen native visual acceptances.

The presentation uses neutral, readable ambient fill. Direct-light strength
also changes real roof material slope/ridge factors and `city_sun_shadow`
alpha from their retained baselines. It preserves roof/cutaway modulate,
geometry, source textures and coverage. Environment receivers are filtered by
actual World2D and canvas, cached and deduplicated by material identity; normal
player, enemy, pickup and HUD materials keep their owners. Full reset restores
raw material overrides, including null defaults, rather than assuming a default
uniform was explicitly set.

Broad cloud is anchored in world coordinates. Ground air renders below actors,
uses the real GroundSplat coverage/light/noise/material winner, and permits
wet-earth5, moss12 and their actual visible stained fragments. It retains the
host's local stainG>.01 condition. Dry earth, paving, a missing/wrong-world host,
and unsupported stain identity remain clear. Conservative actual indoor shape
bounds suppress air even through an open roof cutaway. Room streaming/removal
invalidates a bounded lazy mask; it does not rebuild the whole world per frame.
These indoor/no-host/default/reset/world/canvas controls come from focused native
render fixtures using actual component shapes and materials. The S2 Game
entry/exit has mist0; S7 Game samples are outdoors. They do not independently
prove every streamed S7 interior's mist boundary.
There are no new magical flies, glow or lightning emitters. No gameplay RNG,
save, physics, damage, encounter or balance policy belongs to this change.

Each paired profile/`legacy-daylight` still uses the same paused actual Game,
camera and actors. The ablation reinstates the preceding daylight shader only;
it retains the current profile's roof/shadow direct-light factors and omits the
former randomized blue flies from both states. It is **not a recreation of the
entire historical runtime** or a one-variable clear/overcast material comparison.
Pan plates retain fixed presentation phase and sample one corresponding actual
texel centre, with fractional coordinates/residuals recorded. This bounded
composite pixel control does not prove every world pixel or all cameras.

Optional weather samples advance presentation phase at eight samples/second
for three seconds while the actual Game and actors remain paused. They are
diagnostic still sequences, not live combat footage or a performance test.
The separate Reduced Motion clip uses real production input/attacks, ordinary
enemy AI, projectiles and normal HUD in a controlled population with player god
mode, ambient spawner/encounter beats disabled and streaming frozen after the
explicit reload. Paired still inspection pauses are disclosed in its metadata;
encoding uses measured frame wall times and can hold across those gaps. That
clip does not independently exercise elite, equipment or health pickup cover.
The [entity visibility packet](../2026-10-20-linux-entity-cover/README.md) is a
separate contract and capture set.

Authored context evidence uses actual segment1 Game, not the procedural
preview's segment>=2 clamp. The institution context disables procedural
atmosphere while the live VisionRig retains its own copied vignette material,
Rite signal and detected indoor strength. Its opening is marked completed and
ambient combat/player physics are muted in this isolated fixture. Actual Hub
uses the production completed-S2 arrival state, fixed crowd seed and staged
overview camera; mandatory choice UI is cleared only in the fixture. Hub owns
its dusk CanvasModulate and practical PointLight2D nodes, with no procedural
atmosphere/binder or leaked prior Game owner. This is a stationary ownership
regression, not prologue/traversal or all Hub interactions.

The process history deliberately retains invalid attempts alongside useful
RED/GREEN checks:

- The initial physical profile and actual receiver API checks fail before their
  implementations. Final focused native checks are retained independently.
- `atmosphere-core-green` prints84/0 and exits0, but the monitor reports invalid
  `SubViewport.own_world_2d` and leaked canvas/world resources. It is a failed
  fixture attempt; a real separate World2D and proper cleanup precede clean
  core87/0 headless and92/0 native checks.
- The first native receiver25/1 samples a legitimately unstained cell centre.
  The later225-pixel unchanged-ground stain-on/off scan measures actual visible
  stain contribution; production eligibility was not broadened for that probe.
- The next core91/1 exposes a real unset-uniform `float(null)` error. Actual
  RenderingServer shader defaults and exact raw-null restoration fix the
  source-default case, with separate focused default/reset controls.
- The first dry-guard6/0 is an insufficient RED probe: the unwanted term at
  canal opacity.038 falls below an8-bit output step. The separate valid5/1
  raises only the diagnostic fixture to the shader's permitted.06 ceiling,
  giving false clean-G0 delta.003922 and real-stain positive delta.027451.
  Matching the host's G>.01 guard then passes6/0; canal data stays.038.
- The first actual S2 small run restores the roof and writes no save, but its
  world probe starts on a pixel boundary: after pan it floors into row269
  instead of270. The retained failing pair has delta.047059; the corresponding
  row270 gives.003922. The tool correction selects the first actual pixel
  centre through the inverse captured canvas transform, records residuals and
  keeps the same.012 tolerance. That first label remains a failed run.

Commands, actual exits, stop reasons, full diagnostics, resource time series and
all three logs are retained when the packager is explicitly executed. Original
`source_hashes` and `source_untracked` move losslessly into deduplicated
`process/sources` records; only the unrelated machine-wide Git status is
omitted, and each original result JSON hash is preserved. Earlier focused
snapshots precede final integrated frontage/roof sources and are not relabeled
as later integrated-main regressions. Same-machine prepared Linux UID/import
cache baselines do not prove fresh-clone imports.

[Code commit bindings](code-commit-bindings.json) compare exact Git blob bytes
at `de93d886a2b6392b1ff21d46147c3dd0cbf9287e` with all eight final launch
source records using read-only Git commands. All six scoped runtime paths match
all eight launches (48/48). Across 28 scoped runtime/tool/test files, 223 of 224
launch comparisons match. The one explicit exception is the authored run's
unused procedural `ThemeAtmospherePreview.gd`, recorded before the bounded
texel-centre correction. Its actual `AuthoredAtmospherePreview` script and
scene match the commit. The native runs precede this commit: this binds their
recorded source content retrospectively and does not claim a rerun of the
committed checkout or bind every project asset/import.

Native PNGs are copied without resizing or repainting. Raw fight frames,
shader caches, userdata and unrelated captures are excluded. Only an explicitly
supplied final occupied video and its encoding/full-decode sidecars are copied;
video hashes bind the actual metadata, dimensions and measured timestamps.
Optional declared weather-only PNGs are retained only with
`--include-weather-samples`. `evidence-index.json`, generated at packaging,
is the authoritative bundled-file list. No frame budget, balance, continuous
human-play, broad climate simulation or all-theme visual acceptance is inferred.
