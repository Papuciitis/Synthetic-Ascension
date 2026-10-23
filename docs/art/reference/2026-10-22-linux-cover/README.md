# Shared world cover continuation — 22 October 2026

The shared-cover correction and pickup-density improvement are integrated.
Focused native checks are clean. The live home-r3 phase is accepted within its
staged scope; tree R8 has clean parser, unchanged native 33-check fixture and
live covered/exposed transitions with a matched camera comparison. Root accepts
the bounded density improvement. Tiny equipment-ring discoverability against
foliage remains open, and the interrupted original full route remains unaccepted.
The records below preserve earlier failures and their original source bytes.
See [EVIDENCE](EVIDENCE.md), the [run index](evidence-index.json),
[cost summary](cost-summary.json) and [source bindings](sources/source-bindings.json).

The candidate replaces delayed offscreen revalidation with an exact comparison
of every loaded solid face, roof plane and descendant roof form before spatial
gather. Arbitrary transform/polygon changes can therefore widen cached reach on
the next refresh. Structural subtree changes trigger a roof rescan. Hidden forms
remain in the conservative reach. A later bounded fix retains one owned signal
subscription across repeated rescans and index resets.

The actual merge base with production planning commit `d14d71c3` is
`1797bc673d6cdb464c848b0329846d766ebffbfb`. The retained cover commits are
`ef94384b` (invalidation implementation/test), `4ca8057f` (validation counters),
and `d707ed29` (watch ownership/test). The native candidate profile ran before
the last commit with its WorldCover change explicitly dirty; its launch hash,
not the later commit date, identifies the measured runtime bytes. Local tools
and import sidecars are separately represented in the original launch maps.

The invalidation suite's clean 77/0 result compares exact semantic records and
coverage strengths against a fresh uncached provider after offscreen shape,
root/ancestor transform, nested addition/removal, hidden-to-shown and return-out
changes. It also checks unchanged snapshot reuse and a control/index round trip.
The clean watch lifecycle result is 52/0. It checks that one disconnect releases
each subscription after structural/index/membership churn, that one reconnection
still discovers nested forms on the next refresh, and that provider destruction
releases subscriptions. Reparenting, roof-plane replacement and rotation/scale
have supporting code paths but are not separately executed cases in those two
finite suites. These results establish neither every possible mutation nor
framebuffer readability in actual moving play.

## Cost observations

The static headless provider probe uses one unchanged composed fixture, five
rotated-order rounds of 48 synchronous refreshes and 0.5-second cooling between
variants. S2 has 56 roofs/112 forms/94 faces; the synthetic heavy S10 case has
94 roofs/188 forms/1788 faces. Each variant produces identical static records,
visits 4 roofs/6 faces and records one snapshot build/259 reuses. It has no
foreground texture sources, bound consumer materials, Game AI or streaming.

| Static fixture | Legacy median µs | Pending median µs | Current median µs |
| --- | ---: | ---: | ---: |
| S2 | 421.0 | 576.0 | 1286.5 |
| Heavy S10 | 736.5 | 2233.0 | 3284.5 |

Per-round values are noisy. Pending and current differ only in watch code that
is not exercised during steady measurements: the sampled fixture reports no
structural events or renewals. There is no watch-related steady-speed gain and
no equivalent steady-cost optimization. The added exact validation has a cost.
Do not substitute the older 2.77→7.92 ms first-stream sample for these distinct
steady fixtures or for a whole-Game budget measurement.

Two actual native S2 profiles complete the same 50-cell planned route and three
stream activations with zero failures, diagnostics or save writes. The route SHA256
is `42aa099c266e7401be15076c300925ebbd24253dbcc1b8070b47e1f01c5bf414`.
They use a 960×540 window, 1920×1080 logical viewport, Compatibility/OpenGL3,
60 FPS cap, scripted movement/attack and god mode with ordinary live ambient
spawning, scheduling and streaming. They perform no framebuffer readback.

| Native observation | Baseline | Candidate |
| --- | ---: | ---: |
| Process samples | 1787 | 1946 |
| Cover refresh p50 / p95 ms | 1.632 / 3.486 | 2.058 / 4.207 |
| Wall frame p50 / p95 ms | 17.033 / 27.878 | 16.927 / 28.005 |
| Mean enemies | 21.6659 | 15.0 |
| Actual distance walked px | 3237.56 | 4196.95 |

Identical planned cells do not make these identical workloads: crowd populations,
actual movement and random states differ. The results qualify actual cost and
functional streaming; they establish no isolated performance improvement or
throughput claim. Capped frame periods are not GPU timings. Both use CPU affinity
0,1; setup's 25% runnable duty ends at the Game-ready marker before sampling.
The thermal/memory/start-gate controls and raw records are retained. Native peak
temperatures are 82°C baseline and 80°C candidate; no machine power settings
were changed by this packet.

After the timing window, repeated idle preflight waits near 68–70°C prompted
an optional 70°C start gate for later correctness checks only. The timing runs
retain their 65°C gate. Runtime stops remain 90°C or three consecutive samples
at 85°C, with the same two-core/25% setup duty. Each original thermal/command
record states its own protocol; a first wrapper sample can precede Godot launch
and is not labelled as the engine's actual start temperature. Unlaunched thermal
wait timeouts are retained as preflight outcomes, never test successes.

## Source and evidence limits

Each completed run retains its original command, Git state, source hashes,
untracked-source list, resources and diagnostics in `run-results.json` (compressed
when large), plus stdout/stderr/engine logs and the outer thermal record. An empty
tracked Git-status string is not a clean-source claim: local tools and generated
import sidecars can still be listed separately. The source-binding index names
exact matching scoped bytes and any unavailable earlier draft snapshots.

Recorded launch asset/import-sidecar hashes are preserved and indexed separately
from the static reference closure. A reference closure is a source-derived set,
not a trace of which resources were actually loaded. Dynamic paths and missing
generated import hashes stay disclosed. No later filesystem hash is presented as
a contemporaneous launch measurement; generated `.godot/imported` bytes are only
included if already recorded by the original run. User shader-cache files are
not packaged.

The ignored local wrapper changed after the cost runs. Those earlier records
retain their exact commands, thermal/resource metadata and engine logs, but do
not contain a contemporaneous hash/copy of the launcher implementation. A
packaging-time harness copy does not establish those historical launcher bytes.
Later import/launcher samples, if supplied, identify their own capture time and
finite scope; they do not repair the missing historical measurement.

The moving captures use finite launcher samples taken immediately
before launch (repeat afterward with a fresh label/output filename):

```bash
python3 capture_selected_imports.py --project /tmp/sa-wp2-cover --label moving-visual-before --out /var/tmp/sa-city22/cover/moving-visual-imports-before.json --launcher /home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/guarded_engine.py
```

The current moving probe supports exact 15/20/30/60 FPS render caps, default 60. Its
manifest records the actual cap and physics tick setting; physics/AI stay live.
The original selected 30 FPS full visual run thermally stopped; it is not an
FPS/performance comparison. New explicit home/tree phases use a hard 30-second
simulation deadline, at most 12 route frames plus 3 named plates and paced
post-route encoding. They retain all AI/physics/live producers but explicitly
omit ordinary collection, mandatory streaming boundary and player fire/hit
claims. The default full route keeps its inherited assertions. Earlier
source snapshots in this packet remain bound to their own recorded hashes.

The first watch attempt was refused during thermal preflight before Godot
launched. The second launched but failed to parse an inferred Variant; its owned
process was then terminated. Neither is behavioral RED. The third is the actual
expected lifecycle RED, followed by the clean GREEN. The chronology preserves
these different outcomes rather than counting assertion footers as clean runs.

Native enemy/pickup/cue/player fixtures and the new moving visual probe are
separate gates. The former assert controlled material compositing; the latter
must show the actual live published batch bodies/icons and real house entry/exit.
The historical [partial pixel review](VISUAL_REVIEW.md) covers the interrupted
original full run, whose seven opening frames do not show a tree crossing.
Later home and tree results, exact reviews and remaining readability limits are
in [the current evidence index](EVIDENCE.md). Atlas-fragment telemetry alone
does not establish visual acceptance. Boss-owned/custom surfaces and exotic
families remain outside the bounded ordinary-consumer claim.

Large records are deterministically compressed above 128 KiB. The
[compression map](compression-map.json) binds original byte counts/SHA256 to
delivered copies; [manifest](manifest.json) inventories the payload. Original
scratch records are unchanged. Inspect packed JSON with `gzip -dc file.json.gz`.
