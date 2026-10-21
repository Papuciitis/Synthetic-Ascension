# City phase 1 — lead review and integration decision

21 October 2026. Received Linux `e4a1a8ba`, then
**`3d1be8b0039ce96e65959958b0da10a799f8fcfb`** during review.
The overall goal remains full concept fidelity across the procedural city.
The newer architecture is useful progress; the current phase is not accepted
as a finished city or as a replacement for the reviewed runtime baseline.

**Integrated:** the checked continuation through
`2d749ba0450b795d68e53b2bfb912b397bf6e10a`, plus the passive reference-import
exclusion from e4a1a8ba (local commit `01cddc60`).
**Held on the production branch:** the later general façade/roof kit and the
new phase-1 runtime through 3d1be8b0. Nothing is discarded or reset.
The holds below concern visual regressions, runtime contracts and missing
execution evidence. Broader city development is part of the user's goal.

## Art decision

The lead personally viewed all eight supplied before/after plates against
[concept 08](../../concepts/2026-10-18-city-directions/08-mediterranean-medieval-industrial-city.png).
An independent art reviewer reached the same central conclusions.

| Area | Decision |
| --- | --- |
| Architecture | **KEEP the direction:** fitted inward doors, window variety, attached frontage, joined roof masses, restrained chimney/lantern/dormer details and coherent building casts improve the repeated painted fronts. Preserve the useful modules while correcting the streets beneath them. |
| Medieval street relationships | **REWORK.** Repeated straight cross streets, round/oval squares, similar setbacks and isolated houses remain conspicuous. Bigger paved areas expose these patterns. Develop offset frontage lines, connected house groups, occasional passages and asymmetric courts around clear combat routes. Preserve uneven development and some open land; avoid turning every intersection into the same ceremonial square. |
| Ground hierarchy | **REWORK.** The after views have broad, largely continuous grey fields. Quiet carriageways, smaller household approaches, usable courts, working yards and wild margins need distinct spatial roles. Large mottled patches in industrial/rail views look like camouflage rather than use-worn ground. The care lozenges and hard material transitions need contact/context work. |
| S7 ecology | **REWORK the loss of the damp green setting.** In play-3/overview-3, tile joints and planter strips replace much of the olive ground context. Restore quiet moss/soil, damp banks, neglected yards and wild margins using existing materials. Retain the rejection of the cyan leaf carpet. The oversized pale setts also compete with the compact actor. |
| Theme identity | **REWORK placement and maintenance states.** Repeated tidy planter rims make ruined, industrial and military settings resemble one ornamental plaza family. Existing service/ruin/industrial sources can support appropriate use, wear and vegetation placement. Mood shaders may support those choices; they do not establish architectural or ecological identity. |
| Domestic purpose | **KEEP the checked prefix's mat/cot sleeping corner, grouped work wall, stronger masonry and clear central circulation.** That bounded request was addressed. Current phase-1 exterior collages do not show whether the every-home expansion retains those qualities in its interiors, especially slate homes. Return a current cutaway rather than another speculative furnishing pack. |

The eight incoming plates are copied unchanged in
[incoming-phase1](incoming-phase1/play-1.jpg):
[play 1](incoming-phase1/play-1.jpg), [2](incoming-phase1/play-2.jpg),
[3](incoming-phase1/play-3.jpg), [4](incoming-phase1/play-4.jpg);
[overview 1](incoming-phase1/overview-1.jpg), [2](incoming-phase1/overview-2.jpg),
[3](incoming-phase1/overview-3.jpg), [4](incoming-phase1/overview-4.jpg).
They are useful static survey composites. Their approximately 640×360 panels
reduce the original 1280×720 captures and cannot establish fine contact,
motion, entry or combat acceptance.

## Runtime and evidence gates for the held phase

Three independent read-only reviews covered domestic/street/plaza behavior,
visibility/performance and art. No Windows engine tests were run by those
reviewers. Their important findings are:

- **Coverage indexing weakens the live-transform contract.** At 3d1be8b0,
  `WorldCover.gd`'s `_roof_entry` caches reach without descendant roof-form
  transforms/polygons. An existing form moved or reshaped from outside cached
  reach into view can remain omitted: it is never gathered, so later geometry
  calculation cannot widen the reach. Ordinary offscreen root/face updates
  can also wait up to 30 refreshes. Add explicit invalidation and an
  offscreen-to-onscreen descendant test against an uncached control. This is a
  source-identified contract regression; static generated houses may avoid it.
- **The ground GPU issue remains open.** Linux reports UHD 620 SIMD16 register
  allocation failure and about +3–4 ms/frame at 1080p. Compiler/timing records
  are not bundled, so the magnitude is reported rather than independently
  measured here. Fix the register-pressure path and retain a small matched
  no-readback timing comparison. The older upload-reuse result cannot qualify
  the newer shader/index/sun combination. Chunk-local AO seams and the global
  index-3 road classification also need the acknowledged ground-role correction.
- **This changes gameplay geometry.** Infill adds physical buildings, doors can
  flip, and plaza centres add a declared 2×2 low-cover footprint. The street
  test's 197-chunk survey disables decoration and tolerates 17 pre-existing
  unreachable cases. The separate plaza test does enable decoration and checks
  blocker preservation outside its declared footprint, so there is useful
  combined static coverage. Retain that work and add a short current-source
  final-dressed traversal, including a narrow passage, actual entry/exit,
  collection and a streaming boundary. The README already leaves later rings,
  courtyard doors and a hitch open; these are not closed by a static collage.
- **Qualify the 74-suite claim.** Reconciliation of the eight summary logs gives
  74 unique latest suites with zero-failure assertion footers, but only 66 have
  a `completed` classification; eight retain `runtime_diagnostics`.
  Those include roof/guard rendering, coverage coordinates, streaming/startup
  and parse checks. Full diagnostic bodies, commands, monitor records and
  source maps are absent. Assertion success is not a clean-run result.
- **Bind a selected return to its actual source.** The phase packet has eight
  JPEGs, eight terse check summaries and a README. It has no individual PNGs,
  survey manifests, capture source hashes or raw process metadata. The assertion
  that after images use the tip is not independently reproducible provenance.
  Supply current unedited native PNGs and the actual command, renderer, commit,
  dirty-input record and scoped runtime/asset/import hashes. Retain original
  diagnostics for the eight affected suites. Do not rerun or duplicate every
  unchanged suite just to produce a larger packet.

The final every-home context fix `2c016df2` follows the furnisher's eligibility
predicates; no specific defect was found in that fix. The shared sun/contact
model is a sound visual direction. The held status is not a claim that all
new code is broken, nor permission to discard the architectural gains.

## Next bounded production return

1. Correct street/ground hierarchy in representative **S2, S7 and an industrial
   or ruined theme**, using the existing kit. Keep the improved façade/roof
   vocabulary. Show the same camera points at gameplay size and one overview.
   Preserve cared household plots, untended homes and wilderness.
2. Include one current genuine household cutaway and short final-dressed moving
   street route with entry, exposed/covered cues, collection and a chunk crossing.
   Disclose frozen/staged conditions accurately. Fix the identified cover
   invalidation and reported passage/door issues in this selected return.
3. Attach focused ground/index correctness and no-readback cost evidence,
   with source binding and the actual diagnostic details described above.
   Keep parked mood/weathering/district-wall branches separate until reviewed.

No further source generation is requested. Existing packs already provide
enough candidates for this pass. The frontal cypress and trapezoidal bridge
remain placement-specific sources; a dormer's roof attachment/scale needs
native judgment before widespread repetition. Processed kit PNGs must be
described as processed outputs, not untouched generation originals.

## Why the earlier continuation is integrated

The [household packet](../../reference/2026-10-20-linux-household-continuation/README.md)
binds its six final captures to b6b91d58. Independent review matched all 35
scoped files against Git and their six launch matrices, with no changes through
2d749ba0. Actual selected results include composition 51/0, reward 43/0,
procedural 6318/0, cohesion 32/0 and fade 24/0, with clean completed processes.
Both original homes retain four props and six furniture blocker cells; the
flat mat adds no collision. This is bounded two-home purpose/material acceptance.

The [moving-cue packet](../../reference/2026-10-20-linux-moving-cues/README.md)
matches all 30 owned cue blobs, including 29 recorded moving-run inputs.
Its live route reaches seven goals with actual spawning/scheduling/streaming,
ordinary delayed pickup collection and roof restoration. Native cue 67/0,
additional 39/0 and contact 3/0 records support this scoped KEEP. Boss/exotic
surfaces and continuous human play remain outside that result.

The [performance packet](../../reference/2026-10-20-linux-cover-performance/README.md)
has identical 2,389-input source maps in its forced-upload/reuse pair.
Uploads fall 5,784→222; 96.31% of snapshots reuse packing.
Collection remains dominant; frame p95 changes 20.662→20.360ms while p99 worsens
slightly and populations differ. KEEP fewer upload/bind calls, not a broad FPS
claim. These measurements do not extend to phase1's later rendering work.

The lead viewed the relevant native household/pale controls and moving stills,
plus six sampled frames from each of three clips:
[bed](motion-review/house-bed.jpg), [fruit](motion-review/house-fruit.jpg),
[moving cues](motion-review/moving-cues.jpg).
[Times and hashes](motion-review/review-samples.json) preserve that sampled scope.
[80 earlier selected artifacts](continuation-artifacts.json) and
[17 incoming phase artifacts](phase1-artifacts.json) match exact Git blobs.
This verifies stored bytes, not unrecorded execution provenance.

## Windows attempt and exchange

The user explicitly permitted local Godot review and requested RAM cleanup.
Nineteen old idle Codex helper processes were stopped; about 1.2 GiB of commit
headroom was recovered. No game/profile files or OS settings were changed.
One isolated **e4a1a8ba** cold import ran on installed Godot 4.7.1, then the guard
stopped its owned process at 905 MB private memory after 44.69 s.
It retained at least 856 MB available RAM. A later prepared-prefix walkthrough
was refused at preflight for insufficient physical headroom; no Game image was
produced. These attempts predate or exclude 3d1be8b0 and cannot validate it.
[Local attempt details and logs](windows-attempt/README.md) are retained honestly.

Linux should fetch and **normally merge** `origin/enemy-world-work` (the lanes
now diverge), acknowledge the received feedback hash in LINUX_STATUS, and use
the prioritized return above. Do not reset or force-push either lane.
The original scheduled L1–L3 review batch remains paused; this is a manual
review requested by the human, not an indefinitely expanded automation.
