# City continuation — lead art review

20 October 2026. Received Linux production tip
`fd80106aed28ff49a3a7163299c6f82e29ccf322` after the human's push.
The integrated runtime target is `de93d886a2b6392b1ff21d46147c3dd0cbf9287e`;
the later commits retain tests/evidence and status. This packet is
**qualified WIP KEEP, with the corrections below**. The complete street,
ordinary gameplay, performance and full concept fidelity are unaccepted.

The target remains the [accepted city concept](../../concepts/2026-10-18-city-directions/08-mediterranean-medieval-industrial-city.png)
and its [implementation direction](../../concepts/2026-10-18-city-directions/IMPLEMENTATION_HANDOFF.md):
temperate, uneven medieval development, inhabited domestic spaces and restrained
industrial character. The samples are closer, especially material weight and
roof depth. The actual street still reads as isolated buildings among broad
ground gaps, and its sparse rooms lack the concept's inhabited character.
Fourteen atmosphere profiles do not establish fourteen finished districts.

## Keep and correct

| Area | Decision and reason |
| --- | --- |
| S7 ground | **KEEP** subdued green moss and selected supplied wet earth. The [native replacement](../../reference/2026-10-20-linux-wet-earth/s7-candidate-small/ground-before.png) removes the repeated ribbons; the [real dry-earth control](../../reference/2026-10-20-linux-wet-earth/s7-dry-three/ground-before.png) establishes a useful difference. Fine grit is acceptable in this sample. No more ground source generation is requested. |
| Household care | **KEEP** the stronger useful lawn core and original fitted bed/tree. The [actual two-chunk view](../../reference/2026-10-20-linux-ground-core/seam-core/ground-before.png) is improved but restrained at960. Organic continuation across owning-chunk x=0 remains **OPEN**; a soft sampled edge and reload stability do not prove continuation. Preserve wilderness and untended homes. |
| Domestic materials and use | **KEEP** the stronger rough masonry, original cot/hearth fit and functional sleep/cook/work/storage props. The [bed home](../../reference/2026-10-20-linux-domestic-interiors/bed-small/interior-whole.png) and [fruit home](../../reference/2026-10-20-linux-domestic-interiors/fruit-small/interior-whole.png) now have purposes. **REWORK composition**: isolated props around large slab-floored boxes still feel staged rather than inhabited. Keep the darker masonry character; do not globally return to pale placeholder walls. |
| Roof and paving | **KEEP** the [connected irregular roof planes](../../reference/2026-10-20-linux-scene-depth/roof-pair-small/connected-roof-planes.png), coherent tile direction, actual-outline casts and softer connected footways. They improve the former broad roof bands. Preserve asymmetric growth and S3's custom treatment. Tile detail should remain subordinate to actors. |
| Domestic frontage | **REWORK within the same home**. Plaster is less stretched, but the huge dark opening still reads like an unfinished garage recess; the long blank upper band and repeated shutters remain weak. Finish the visual entry with existing header/reveal/materials and group the frontage around domestic use. Preserve the physical doorway, collision and clear approach. |
| Theme atmosphere | **KEEP for selected S2/S3/S7 views**. [S2 daylight](../../reference/2026-10-20-linux-theme-atmosphere/s2-small/exterior-profile.png) and [subdued S7](../../reference/2026-10-20-linux-theme-atmosphere/s7-small/ground-before-profile.png) support the intended city. Authored S1/Hub ownership is retained. No further weather or district expansion is requested. Cloud multiplication also affects actors/tells, by roughly10% at the selected maximum; this is a presentation treatment, not environment-only physical cloud lighting. |
| Entity depth | **KEEP the sampled body/icon correction**. [Covered façade](../../reference/2026-10-20-linux-integration/native/facade-covered.png), [front controls](../../reference/2026-10-20-linux-integration/native/facade-front-controls.png) and [actual cutaway](../../reference/2026-10-20-linux-integration/native/roof-player-inside-cutaway.png) show useful occlusion/restoration. **V1 stays OPEN** for tells, projectiles, remaining frames/callouts/fallbacks and ordinary moving encounters/collection. |

## Next Linux packet — bounded continuation

1. **L3: compose one convincing household, then verify the second fixture.**
   Reuse the existing four purpose props. Form a sleeping corner using the
   supplied [plain rush mat](../../../../assets/world/domestic_interiors/rush_mat_v1/README.md),
   and a coherent cooking/work/storage relationship, while keeping the central
   combat route clear. The mat is flat floor décor, with no new cover/collision.
   Finish the same home's visible entry rather than ordering a larger prop pack.
   Return matched small/normal native views with the player and a short actual
   entry/contact/exit sequence. Preserve loot identity/claims and pathing.
2. **V1: close the remaining visible cue/depth failures in one moving occupied
   street sample.** Include a tell/projectile crossing a relevant foreground
   surface, exposed controls and ordinary pickup collection. Disclose any
   disabled streaming, spawner, scheduling or collection behavior; frozen
   actors alone cannot establish this acceptance. Keep the functioning
   body/icon treatment. Do not duplicate the whole capture suite.
3. **Measure the changed rendering cost on Linux without capture readback.**
   Profile representative movement/streaming with ordinary occupied density,
   including shared cover and footways. The controlled integration records
   cover refreshes around 3.5–12.6 ms with a 78.678 ms peak and 23 peak candidates;
   three data textures are uploaded/rebound each refresh. Footway edge work
   also runs per shaded pixel. These are material frame-budget concerns, not
   a measured ordinary-play regression. Report frame/refresh cost and bound
   refresh work if needed before adding more density or claiming performance
   acceptance.

For the still-open L2 boundary, include a small actual cross-boundary control if
the implementation now supports natural continuation; otherwise record the
remaining limit explicitly. Do not restart lawn/moss/soil design.

Use the same actual S2 homes: seed 16102026/chunk(0,3), row-house 944996572
and seed 17/chunk(-3,5), row-house 2128236757. Keep irregular lots and household
care versus wilderness. No new district family, whole-city renderer or broad
asset pack is requested. Run checks appropriate to changed runtime; unchanged
systems do not need another full evidence dump.

## Evidence and implementation limits

The lead viewed the selected care/soil controls, both domestic homes at both
sizes, matched roof planes, daylight/ground profiles and combined entity plates.
Three clips were reviewed as six sampled frames each:
[bed household](motion-review/domestic-bed.jpg),
[fruit household](motion-review/domestic-fruit.jpg) and
[S7 Reduced Motion](motion-review/atmo-s7-reduced.jpg).
[Sample times and hashes](motion-review/review-samples.json) retain that limited
scope. These sheets are review aids; original Linux images/videos are unchanged.
There was no continuous human play, comfort certification or Windows engine run.

[Selected artifact verification](selected-artifacts.json) binds 135 selected
files to exact incoming Git blobs. This is not verification of every file in
the large packet. A [current-checkout publication check](publication-check.json)
also matched all 77 explicitly bound integration inputs, the 14 ground sources,
their import sidecars and the derived cache, plus the mat's unchanged original
bytes and the three sampled sheets/source clips. This is byte verification,
not an engine test. Three independent read-only reviewers checked visibility,
domestic/roof/paving and atmosphere implementation. Scoped final-source
comparisons cover 14 relevant visibility/runtime/tool inputs and 13 relevant
domestic/roof inputs against retained bindings; these counts overlap and are
not a complete dependency audit. No important scoped correctness blocker was
found. They did not run another engine or certify aesthetic completion.

The [integration evidence](../../reference/2026-10-20-linux-integration/README.md)
honestly retains earlier launch HEADs, uncommitted atmosphere inputs, original
failures and final scoped source bindings. It does not relabel old launches as
new ones. Domestic 336/0 and reward 43/0 exercise the two household fixtures;
final footprint 11/0, care 125/0 and parse 557/0 launched at de93d886.
The 6318/0 procedural correction is justified: the old assertion intersected an
L-shaped building's empty bounding-box notch. The new test checks actual
occupied outlines and includes transformed positive overlap controls. It did
not remove an assertion to hide a rendering defect.

Furnishing intentionally adds **six HALF_COVER cells**, so this includes a
physical/pathing/projectile change. Eligibility exclusions, connected usable
floor and entry routes were reviewed. Actual chance/claim and full-factory
reward controls match for the two fixtures; this is not a proof of every future
loot policy. Keep those guards when changing composition.

Combined entity stills use frozen scheduling/streaming after reload, staged
noncollecting pickups, some nonwalkable staging points, a fixed camera and
god mode. Roof entry/exit uses actual input/Area2D signals, but these plates
remain controlled rendering checks. Atmosphere evidence covers native S2/S3/S7,
selected paused weather and authored S1/Hub preservation, not all profiles,
normal moving weather encounters or every cue combination. OpenGL on Intel UHD
620 is the recorded backend; no cross-renderer capacity claim follows.

Incoming packet references:
[ground core](../../reference/2026-10-20-linux-ground-core/README.md),
[wet earth](../../reference/2026-10-20-linux-wet-earth/README.md),
[domestic homes](../../reference/2026-10-20-linux-domestic-interiors/README.md),
[scene depth](../../reference/2026-10-20-linux-scene-depth/README.md),
[atmosphere](../../reference/2026-10-20-linux-theme-atmosphere/README.md),
[integration](../../reference/2026-10-20-linux-integration/README.md).

## Exchange

This review is Windows' acknowledgment of fd80106a. Linux should fetch/merge
`origin/enemy-world-work` and record the actual received feedback commit in
its owned LINUX_STATUS before the bounded continuation. The human's push
worked; historical authentication failures are not current publication blockers.
Windows keeps source art/review; Linux keeps implementation, imports, captures
and performance checks. A pushed review is not Linux's acknowledgment.
