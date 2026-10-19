# First playable city block — independent designer review

18 October 2026. Review of the supplied native capture packet; no new engine run.

## Decision

**REWORK REQUIRED before accepting this block as the city's architectural template.** It is a useful playable integration prototype and a visible improvement over the control. It remains materially short of [study 08](../concepts/2026-10-18-city-directions/08-mediterranean-medieval-industrial-city.png), especially in building volume, roof silhouette and the relationship between architecture and street.

Keep the current two-building implementation and refine it. Do not roll the kit across the city yet. The next pass should change the forms of these same buildings, rather than add another layer of decorative detail to the present roof boxes.

The governing direction is the user's temperate, daylit blend of Greece/Rome/Mediterranean, medieval Europe and early municipal industry/cyberpunk, with restrained monumental civic weight. The user approved 08's direction while explicitly rejecting its AI-generated “over-lined” finish. Acceptance therefore requires a cleaner translation of its architectural hierarchy, not a pixel-for-pixel copy of all its towers, seams and props. The existing north-up 2D camera and compact actor scale remain the right constraints for this milestone.

## What works

- The pale Roman arcade and shuttered domestic frontage give the buildings identifiable uses. They are more specific than the control's generic roof rectangles and bare door gaps, and those cues survive at 960×540.
- Cool limestone, dark slate and muted clay are a useful palette. This is closer to a temperate inhabited city than the earlier beige desert treatment. Keep that pale/dark separation.
- Actual openings remain visible in the frontage art. The exposed interior, security encounter and restored exterior demonstrate a real playable building sequence, rather than a scenic picture standing in for a level.
- The new frontage paving gives dark actors a clearer ground value in the sampled outside fight. The improvement is useful even though crowded combat still has readability limits.

## Findings, in priority order

### 1. Building mass and proportion are the main artistic blocker

In `normal-final/restored-exterior.png` and the unobstructed traversal `normal-final/frames/frame-0040.png`, the buildings read first as enormous rectangular tile fields with thin fronts attached to their lower edge. The civic arches communicate “arcade,” but their compressed height and limited recess make the structure resemble a stage front. The house has the same broad roof organization and shallow lower strip; changing slate to clay does not give it a sufficiently different building silhouette.

There is a light/shade division across each roof. It would be inaccurate to say that gable shading is absent. It does not supply enough visible volume, ridge/eave structure or silhouette variation to overcome the rectangular sheet. The small T-shaped chimney marks also read as flat symbols rather than masonry sitting on a roof.

Study 08's useful content is its hierarchy: occupied civic frontage, smaller attached domestic mass, distinct roof planes, deep thresholds and connected service structures. We need a restrained version of that hierarchy within the existing parcels. We do not need a new camera, a huge tower, a complete courtyard system or every line from the concept.

The implementation helps explain the result: `CityBlockKit.gd` uses a fixed 116-world-pixel facade height and fits texture wings around the real doorway; `RoofOverlay.gd::apply_city_material` repeats a material over the existing polygon, clips a facade allowance and adds a simple chimney. Those are integration choices, not proof of an import fault. The next art should be composed for its actual display proportions and projection instead of depending on a detailed source strip to become substantial architecture when scaled into that band.

### 2. Surface hierarchy still carries the “over-lined” problem

The slate has fewer, broader units than the control's dense shingles, which is progress. However, the uninterrupted repeated field is still prominent. Clay is the stronger problem: nearly every curved tile receives its own dark lower edge and highlight, making the material pattern the dominant feature of a very large roof.

Establish broad roof planes first. Keep the ridge, eaves, selected breaks and a few important joins crisp; reduce the majority of internal tile seams and repeated highlights. Do not solve this by uniformly blurring an otherwise flat composition. The goal is for the building to read before its material units.

The paving is calmer than the original ground in some respects, but still has substantial mottling and slab contrast. The exposed interior has a dark floor and a bright, densely jointed wall band. Those small wall joints pull attention when the exterior art disappears. Harmonize the interior's broad wall/floor values with the exterior, then add only enough restrained use cues to identify the room.

### 3. The frontage paving needs a physical join to the old street

`normal-final/frames/frame-0040.png`, `normal-final/restored-exterior.png` and the small fight frames show a cool rectangular paving carpet ending against the old moss/tan path. The fuzzy or scalloped boundary and abrupt change of slab scale do not read as a designed curb, gutter, repair or worn verge. At the lower edge, the sandy old strip visibly cuts across the new frontage treatment.

Keep the quieter, lighter street value, but explain where it ends. Use one coherent curb/gutter and a restrained repaired or worn transition, fitted to the actual street. Give existing doorways a short recess/threshold that agrees with the real opening. Avoid a separate decorative moat around every parcel.

### 4. The service alley and temperate identity need a few larger, purposeful forms

The passage between the buildings remains legible and usable in the traversal samples. Visually it is mostly a straight pale strip, a small pressure device, simple pipe/cabinet marks and repeated round shrubs. It does not yet read as the occupied waterworks/service place suggested by 08.

Connect the existing plant to one coarse, understandable service run and drain. Replace several isolated shrub dots with one controlled leafy mass or climbing pocket at a blocked edge. Retain a small domestic cloth/window-box group and a restrained civic marker. These choices would do more for climate, use and the old-city/new-machinery relationship than many additional little props. Keep the central street and the existing side passages clear.

### 5. Combat and cutaway evidence support continuation, with specific limits

The named exterior/interior/restored images and chronological samples show the roof/frontage hidden for the interior and present again after exit. Actor bodies and projectiles are visible on the exposed floor. The team did not establish a new kit-caused obstruction in the sampled route. This is bounded evidence of those states and positions, not every procedural door, wall-side overlap or fade frame.

The populated outside sample is more useful than `fight-ending.png` alone. In normal frame 0093 (2.983 seconds into the outside fight), and small/reduced frame 0100 (3.350/4.400 seconds), orange ground tells and bright effects remain salient. The player can merge into tightly overlapping bodies. A similar stacking problem is visible in the control. Do not treat that as a proven new paving regression, or claim the environment work has solved combat recognition. Different body arrangements across the runs also prevent attributing visibility differences solely to Reduced Motion or Flashes Off.

There is a truthful-cue follow-up: a pink bracketed interior pickup is drawn above the opaque restored roof. It appears in both `normal-final/restored-exterior.png` and `before/restored-exterior.png`, so it is pre-existing. In a later presentation pass, keep concealed loot spatially truthful, for example with a doorway-level “loot inside” cue rather than a floor item apparently sitting on a roof. It is not the reason to reject this new architecture.

Large narrative notification cards cover the upper architecture in several samples and also appear in the control. Use the already available unobstructed traversal frame 0040 for architectural comparison. A notification redesign is outside this art pass.

## Bounded next implementation pass

1. **Recompose these two buildings above their current footprints.** Preserve door centers, collision ownership, passage widths and roof/front fade ownership. Give the arcade a substantial occupied frontage and a coherent roof cap; give the dwelling a different, simple roof outline. Add believable eave/side-return/contact depth and one modest roof interruption per building. Accommodate taller projected fronts within the blocked parcel and fade treatment so they do not hide playable street space.
2. **Clean the material hierarchy and street join.** Reduce most roof seams and clay highlights, strengthen only structural edges, resolve the paving boundary with a coherent curb/gutter/repair, and bring exposed interior wall/floor values into the same family. Fit the actual doorway rather than painting a false closed door across it.
3. **Compose one service connection and one temperate planted pocket.** Reuse the current plant, useful shutters and cloth where possible. Add one connected pipe/drain group and one larger leafy mass at a blocked edge. Avoid a new catalogue of small decorative props or furnishings that constrict the room.

This is a revision of the same first block, not a district rollout, renderer rewrite, balance pass or request to regenerate the entire six-piece kit. Reuse the parts that support the revised composition; redraw or replace only the parts that cannot meet the needed proportions and detail hierarchy.

## Next acceptance gate

- A clean normal and 960×540 exterior should read immediately as two different occupied buildings. Architecture should register before individual roof tiles. The arcade, dwelling, connected service hardware and temperate planting should be identifiable without the report's labels.
- Show the same doors from the street and passage, the exposed interior, and the restored cover. Stronger building projection must preserve player visibility and the real route/opening. Check loot presentation separately from roof geometry.
- Supply entry/exit and populated outside/inside combat evidence at normal, small and reduced settings. Include a crowded middle stage with tells/projectiles, not just the last surviving enemies. Keep the current compact actor scale and show both an effect peak and a quieter recovery moment.
- Seek a human moving-combat readability check before claiming final comfort or smoothness. This sampled-frame review cannot establish those qualities.

Do not broaden the city kit until this block clears the architectural comparison.

## Evidence and provenance

The lead designer personally opened the following eleven requested native images, plus the nine additional images listed below, the six source assets and study 08. Two independent subreviews covered architectural proportion and chronological traversal/combat samples. Their complete checked registers are retained in the linked notes. Not all 682 captured frames were inspected.

### Requested images — personally inspected

| Run | Images |
| --- | --- |
| `normal-final` | `exterior.png`; `interior.png`; `restored-exterior.png`; `frames/frame-0093.png` |
| `small` | `exterior.png`; `interior.png`; `fight-ending.png` |
| `reduced` | `interior.png`; `fight-ending.png` |
| `before` | `exterior.png`; `interior.png` |

All are under [the first-block capture folder](../reference/2026-10-18-city-block/).

### Additional lead-designer samples

| Image | Capture wall time | Outside-fight simulation time | Purpose |
| --- | --- | --- | --- |
| `normal-final/frames/frame-0030.png` | 16.043 s | — | Rear/side route, roof silhouette and street join |
| `normal-final/frames/frame-0040.png` | 21.370 s | — | Unobstructed two-building frontage and passage |
| `normal-final/frames/frame-0050.png` | 26.703 s | — | Entered room, exposed wall/floor and five security actors |
| `normal-final/frames/frame-0058.png` | 31.060 s | — | Interior encounter and actor overlap |
| `normal-final/frames/frame-0065.png` | 32.133 s | — | Cleared interior and visible floor reward |
| `small/frames/frame-0100.png` | 42.574 s | 3.350 s | Populated 960×540 fight |
| `reduced/frames/frame-0100.png` | 40.162 s | 4.400 s | Populated Reduced Motion / Flashes Off fight |
| `before/frames/frame-0175.png` | 52.989 s | 5.200 s | Control crowd/effect and ground comparison |
| `before/restored-exterior.png` | Named state image | — | Confirm pre-existing roof/pickup presentation |

Times come from each run's `capture-info.json`; a frame number maps to the same zero-based metadata index. Enemy/projectile counts describe capture state, not a claim that every entity is visible in the image.

The source images inspected were `assets/world/city_block/civic_arcade.png`, `house_front.png`, `pressure_plant.png`, `slate.png`, `clay.png` and `paving.png`. The [asset inventory](../../../assets/world/city_block/README.md) and [generation prompts](../../../assets/world/city_block/PROMPTS.md) describe six new generations copied without source-pixel repainting. The absence of a selective cleanup/composition pass matters to this review; generation provenance is not an art-quality endorsement.

- [Independent architecture review](../../../.superpowers/sdd/2026-10-18-city-concept-captures/city-block-architecture-review-notes.md)
- [Independent chronological-frame review](../../../.superpowers/sdd/2026-10-18-city-concept-captures/city-block-motion-review-notes.md)
- [Implementation audit](../../audits/2026-10-18-first-city-block.md)
- [Recorded capture summary](../reference/2026-10-18-city-block/review-summary.json)

The four supplied runs record native exit 0, zero capture failures, no save writes and empty diagnostics. The scenario uses scripted movement, god mode, a controlled outside population and native combat; ambient spawning is disabled. Whole-run attack/hit/death totals include the interior encounter. These are implementation-record claims read for context, not independently rerun results or proof of artistic acceptance.

The walkthrough/fight MP4s were **not played back in this review**. Chronological native frames and their timestamps were inspected instead. Sparse traversal and roughly eight-frame-per-second combat readback can show states and changing overlaps, but cannot prove continuous fade smoothness, animation comfort, input feel or runtime performance. No benchmark conclusion is drawn from the capture timing.

Only review/scratch notes were authored. No production code, source art, scenes, engine import, Git operation or fresh capture was performed for this review.

## Architectural-gate addendum — forms-review-01

18 October 2026. **This addendum reviews the architectural correction packet; the original findings above describe the earlier four-run packet.** Street integration, interior palette and service/planting composition remain pending. This is not a new moving-combat acceptance review.

### Focused verdict

**Materially improved; one further roof-junction correction is needed.** The enlarged facade addresses a substantial part of the compressed-front problem. At both supplied sizes, the arcade's arch openings and piers have believable occupied height beside the player, rather than reading as a low decorative frieze. The civic and domestic frontage heights are now more distinct. Roof texture contrast has receded, and the chimneys have visible top openings and shaded sides instead of the old flat T-shaped marks. Retain those changes.

The civic roof still does **not clearly read as three connected architectural volumes**. In the 1280×720 exterior, the narrow raised left section occupies approximately x412–546, y153–353. Its straight lower end is a bright horizontal cap laid across the larger roof. The main hall's light/dark slope division is visible, but the ridge and its connection to that left section remain ambiguous. The low strip immediately above the arches adds another horizontal band. At 960×540, the raised left section (approximately x309–409, y114–265) particularly resembles an overlapping rectangular roof panel. The stepped outline is useful progress, but the planes still retain a stacked-rectangle reading.

The house shows a stepped extension at the right crop and a solid chimney. Its complete roof organization cannot be approved from this framing: the far-right wing is outside both exterior images. A later view containing both whole buildings is sufficient; this is not a request for another broad capture suite now.

### Single most important next shape correction

**Resolve the civic cross-wing and hall into one convincing pitched-roof junction.** Give the cross-wing two broad slope planes, an unambiguous ridge and a gable/hip end, then join it to the main hall with a consistent valley/contact shadow. Replace the impression of a bright capped slab sitting on another sheet. Keep this within the present footprint and retain the improved arcade height; do not add more roof modules or surface detail to solve this connection. Check that junction at 960×540 first.

### Evidence and limits

The lead designer and an independent architectural reviewer each opened these three fresh native images:

- [Exterior, 1280×720](../reference/2026-10-18-city-block/forms-review-01/searchable-building-exterior-1280x720.png)
- [Exterior, 960×540](../reference/2026-10-18-city-block/forms-review-01/searchable-building-exterior-960x540.png)
- [Interior, 1280×720](../reference/2026-10-18-city-block/forms-review-01/searchable-building-interior-1280x720.png)

The lead also reopened the earlier normal traversal frame 0040 and study 08 for comparison. Pixel coordinates above are approximate positions in the supplied files, not world measurements. The interior still confirms that the enlarged civic cover/front are absent around the shown actors and doorway. It does not establish fade continuity, every component's animation or all-side occlusion. The house's broad eave fascia is visible, but this gate's priority is the civic roof connection.

No engine or test run was performed for this addendum. The implementation chat's test and native-exit reports were not used as proof of visual quality. Production files remain read-only. The overall block remains under revision; the old claim that the arcade is only a compressed low band is superseded by this visible improvement.

## First-block architectural-gate addendum — block-review-02

18 October 2026. This is the current frozen architectural assessment. The original review and forms-review-01 above remain records of their earlier packets.

**GO for this first block as the architectural template to take into moving verification. No further blocking shape correction is needed before that check.** This supersedes the earlier static rejection of the compressed frontage and unresolved cross-wing. It does not approve city-wide rollout or establish moving-combat/fade acceptance.

The lead designer personally opened the small exterior **first**, followed by the normal exterior and both interiors:

- [Exterior, 960×540](../reference/2026-10-18-city-block/block-review-02/searchable-building-exterior-960x540.png)
- [Exterior, 1280×720](../reference/2026-10-18-city-block/block-review-02/searchable-building-exterior-1280x720.png)
- [Interior, 1280×720](../reference/2026-10-18-city-block/block-review-02/searchable-building-interior-1280x720.png)
- [Interior, 960×540](../reference/2026-10-18-city-block/block-review-02/searchable-building-interior-960x540.png)

### Focused findings

- **Civic roof junction:** at small size, the vertical ridge ends at a broad triangular gable around x219–319, y231–259, with a dark contact below it. The formerly bright rectangular cap now reads as a pitched end. The two slope values and continuous ridge give the left wing an understandable orientation against the hall. The roof remains deliberately simple, but it no longer needs another massing pass before moving verification.
- **Whole dwelling:** both exterior images now contain the full house. Its taller main clay roof and lower right-hand cross-wing give it a different organization from the civic hall, while the shuttered front and open doorway read as occupied domestic architecture. This is a useful restrained translation of study 08's civic/domestic contrast within the existing game camera. The broad plain fascia above the house front remains visually heavy; thinning or toning it later is non-blocking polish, not another gate.
- **Street integration:** the shown paving forms one continuous, quiet block surface. Its shallow straight perimeter/gutter gives the join a physical explanation and removes the former individual paving-carpet impression. The outlet is visibly connected down the civic right edge to the drain beside the street. Grouped foliage at the civic left corner establishes a stronger planted pocket than repeated isolated shrub dots. The entire lower perimeter and every road opening are outside these views, so their placement is not certified here.
- **Interior hierarchy:** broad muted floor slabs now sit below the player and five shown security actors in contrast. The wall joints remain visible but are less competitive, and the doorway stays clear at both sizes. The interior is sparse, yet its material hierarchy is coherent enough for this first playable block. Additional furnishing is not required to clear this gate.

Against study 08, the important achieved hierarchy is substantial pale civic frontage, distinct dark/clay roof forms, a domestic neighbor, quiet street and a small purposeful service/planting group. The concept's full density and fine ornament are not requirements for this clean north-up translation. **Proceed with the planned fresh entry/exit and populated combat verification on this block.** These four frozen images do not prove fade continuity, moving player recovery, crowded interior comfort or high-density effects readability. No engine/test run or production edit was performed for this addendum; recorded implementation exits/tests are not the basis of its visual verdict.

## Sampled moving-state addendum — revision-02 / small

18 October 2026. **No new environment-art blocker found in this small-window sample. The block-review-02 architectural GO stands.** This assessment covers six personally opened 960×540 PNGs from the new moving capture, not playback of either MP4 or approval of the still-pending normal/reduced packets.

Evidence root: [revision-02/small](../reference/2026-10-18-city-block/revision-02/small/). Frame phases and times below were checked against that run's `capture-info.json` using zero-based indices.

| Personally inspected image | Phase / measured wall time | Finding |
| --- | --- | --- |
| `interior.png` | Named interior state | Quiet broad floor is visible beneath the player and five security actors; civic cover/front are absent and the doorway remains legible. No legacy floor-stamp intrusion is visible in this shown room. |
| `frames/frame-0056.png` | Interior fight, 30.148 s | Four security actors remain in metadata; visible bodies, shadows and the small attack effect separate from the floor. This is a modest interior group, not a high-density indoor stress check. |
| `restored-exterior.png` | Named restored state | Civic roof forms, gable end and frontage are present again with the player outside. No new detached roof piece or opaque frontage covering the shown player is apparent. |
| `frames/frame-0075.png` | Outside fight, 38.835 s; fight simulation 0.333 s | Early populated sample: metadata records 26 enemies and five projectiles. Player, orange ground tells and colored projectiles are distinguishable against the quieter street. Architecture frames the fight rather than covering its center. |
| `frames/frame-0090.png` | Outside fight, 41.139 s; simulation 2.667 s | Bodies and orange tells overlap heavily. The player becomes hard to isolate within the group; no new paving/façade obstruction is evident. The known narrative card covers upper architecture. |
| `frames/frame-0110.png` | Outside fight, 44.224 s; simulation 5.667 s | Projectiles remain salient and the crowd has changed shape, but overlapping bodies still limit player recognition. This does not establish reliable recovery in continuous motion. |

The dark compact actors over the broad paving retain the improved hierarchy. These samples do not justify another architecture, floor or planting correction. The known HUD obstruction and player-in-crowd limitation remain; neither is demonstrated to be a new city-kit regression. No pink roof pickup is visible in the restored image, but this run's collection/state outcome does not prove the inherited loot-over-roof issue has been fixed.

The capture metadata identifies god mode, scripted input, disabled ambient spawning, controlled outside population and actual interior clearance. Aggregate fire/hit/death totals include that indoor encounter. Its recorded inside/outside roof alpha supports the named states, but the inspected PNGs cannot prove fade continuity or smoothness, human reaction comfort, performance, or streamed geometry identity. **Continue the planned normal/reduced checks with the cleared forms fixed.** No new engine run, production edit or additional review suite was performed here.

## Occlusion presentation addendum — occlusion-review-01

18 October 2026. **GO for the shown frozen behind-building treatment; no concrete visual blocker found.** This addresses the user's request for a shadowy indication behind buildings while retaining the cleared architecture.

The lead personally opened eight native PNGs under [occlusion-review-01](../reference/2026-10-18-city-block/occlusion-review-01/): `behind-building-before`, `behind-building-shadow`, `searchable-building-exterior` and `searchable-building-interior`, each with the `-960x540.png` and `-1280x720.png` suffix. The small before/after pair was inspected first.

In the matched control, the warm body/clothing and face are fully described above the slate roof, which clearly suggests a character standing on its surface. In the shadow version, the roof-covered body becomes a subdued cool dark silhouette. Its location and broad body shape remain discernible around x258–273, y113–146 in the small image and x340–365, y150–196 in the normal image. It communicates concealed occupancy without retaining the control's full-colour rooftop reading. The tiny head portion above the roof boundary remains coloured, consistent with the intended per-pixel treatment. The cue is deliberately restrained; these stills support finding the position, not a claim of effortless moving tracking.

The exterior-front views retain the normal warm player colours on the street. Both interior views likewise show the player in normal art with the roof/front cut away; no residual ghost treatment is apparent at those shown positions. These comparisons reveal no new architecture or interior-readability regression.

This is a single staged slate-roof overlap pose, not proof across every roof material, lighting condition, edge crossing or animation frame. No moving sequence was inspected for this follow-up, no engine was run and no production files were edited. Those eight views contain no cursor pixels; the subsequent cursor review follows below.

### Cursor follow-up — same packet

The lead personally opened `cursor-960x540-scale-1.0.png`, `cursor-1280x720-scale-1.0.png`, `cursor-960x540-scale-1.5.png` and `cursor-1280x720-scale-1.5.png`, and read `cursor-capture.json` in the same folder.

**GO for the smaller default cursor art.** Pointer, click hand and aim crosshair are distinct and legible against all three flat light/medium/dark backgrounds at both supplied window sizes. The dark border protects the pale fill on light ground, while the warm fill remains visible on dark ground. Their compact default footprint is appropriate for the user's reduction request. The manifest records 26×31 pointer/click textures and a 26×26 aim texture. These sheets are texture presentations, not captured interactive hardware-pointer use or hotspot/alignment tests.

**Enlargement preview evidence needs correction before claiming 1:1 size approval.** The scale-1.5 sheets are legible on their shown light/medium panels, but the dark panel is cropped and the glyphs are magnified beyond the registered texture dimensions. Read-only pixel inspection of the small sheets finds visible pointer bounds of 20×29 pixels at scale 1.0 and 46×66 at scale 1.5; the latter exceeds the manifest's entire 39×47 enlarged pointer texture. Consequently the scale-1.5 preview has additional magnification and is not the stated 1:1 draw. This is an evidence/preview discrepancy, not proof that the actual hardware registration is incorrect. No further production cursor-art change is justified by these samples; exact enlarged on-screen size and hotspot behavior remain unverified here.

## Cursor-preview correction — cursor-review-02

18 October 2026. **The enlargement-preview discrepancy is resolved. GO for the shown enlarged cursor size and legibility.** This supersedes the preview-size reservation for the earlier occlusion-review-01 sheets, which remain unchanged historical evidence.

The lead personally opened [the corrected 960×540 sheet](../reference/2026-10-18-city-block/cursor-review-02/cursor-960x540-scale-1.5.png) and [the corrected 1280×720 sheet](../reference/2026-10-18-city-block/cursor-review-02/cursor-1280x720-scale-1.5.png), and read the accompanying `cursor-capture.json`. All three light/medium/dark panels now fit in both images. Pointer, click hand and crosshair remain clear on each background, with an appropriate deliberate enlargement over the approved compact default.

Read-only pixel measurement finds visible pointer bounds of **30×43 pixels in both corrected sheets**, consistent with enlargement from the earlier default's 20×29 visible bounds and contained within the recorded 39×47 texture. The 39×39 aim texture is also recorded. The former extra preview magnification is no longer apparent.

This closes the cursor-sheet evidence issue, not an interactive hardware hotspot/tracking test. No engine or production edit was performed here. The newly reported occlusion-review-02 packet and final moving run were not inspected as part of this two-sheet correction.

## Next-pass recommendation — inhabited frontage and material integration

18 October 2026, following the user's new request to continue upgrading and consult the art chat. **The earlier architectural, shown occlusion and cursor approvals stand.** These are prioritized refinements of that accepted foundation, not newly discovered acceptance blockers. Keep this same block, its roof forms, actual doors/collisions, quiet floor and street, cutaway ownership and shadow cue.

The current gap from study 08 is increasingly about how parts meet and what the place is used for. The house's heavy plain eave band looks more abstract than its textured plaster below it; the fronts sit on an otherwise successful but very even paving field; the service connection is functional but visually thin; and the exposed civic room still has little evidence of a civic use. More individual tiles, roof appendages or scattered street props would have lower value.

### 1. Refine the dwelling's roof-to-wall junction

**Location:** the broad plain beige fascia beneath the main clay roof, roughly x803–1083, y409–435 in the latest 1280 exterior; the lower right wing needs the same trim language.

Reduce its visible blank height by roughly half. Resolve the edge into a thin dull gutter/cornice, a restrained underside shadow and the existing warm plaster below. Keep the clay roof masses, chimney and frontage proportions; change the junction, not the building's height or footprint. Carry the treatment around the short right-hand return so the two roof levels belong to one dwelling. Avoid a row of small brackets or exposed beam ends along every tile.

**Stop:** at 960×540, the roof looks supported by the occupied house rather than separated from it by a solid blank slab. Both roof levels share one trim treatment and the facade remains readable.

### 2. Anchor the two frontages to the street

**Location:** the civic pier/plinth bases and central opening, then the domestic doorway and wall base. Preserve the new continuous block paving and outer gutter.

Use a shallow, soft contact shadow immediately below the existing masonry bases and a small worn flush threshold at each real entrance. Give the civic entrance one broad, lightly worn stone apron, confined to about the first paving row; use a shorter domestic threshold. Retain the open center of each doorway and show no painted door across a real opening. Do not introduce raised steps, collision changes or a continuous hard black outline. Keep wear grouped near use points rather than mottling the whole street.

**Stop:** the frontage bases and doorway floors visibly meet the paving at small size, while the central fight surface retains its current quiet value and tells/projectiles remain stronger than the new wear.

### 3. Give the existing municipal service connection material weight

**Location:** the arcade's right-hand service edge, existing pressure plant, outlet and drain. Keep their current route and the passage width.

Consolidate the thin green-grey connection into one legible coarse run of dull aged copper with dark iron support, visibly terminating at the civic eave/plant and existing drain. Use one or two broad attachment points and grouped patina rather than many new joints or gauges. Add one low-contrast damp/mineral patch immediately at the outlet, confined to the service edge. Reuse the plant; do not add another machine or a pipe network across the street.

**Stop:** at 960×540, the eye can follow one connected water/pressure installation from architecture to drain without a caption. It reads as a practical retrofit to old stone, and its contrast stays below actor contours and combat tells.

### 4. Give the exposed civic interior one sign of use

**Location:** the back/north wall's broad central band between the existing returns, clear of the security label below it and the real entrances.

Add one shallow wall-mounted municipal records-board/cupboard group, about one window bay wide: a muted olive panel, dark wood or iron reveal, two broad panel divisions and a narrow supporting ledge are enough. Keep the whole group on/in the existing blocked wall band. Use no freestanding floor furniture, loot-like chest, bright indicator or new interaction cue. Preserve the quiet floor and current movement space.

**Stop:** the cutaway reads as a modest public records/security room rather than an empty test room, while the player, five local security actors and doorway remain as clear as in the current interior. One grouped feature is sufficient; stop before furnishing the perimeter with small objects.

### Scope and review stop

Priorities 1 and 2 offer the largest immediate gain. Then complete 3 and 4 within their stated caps. Once these four relationships read at native 960×540 and 1280×720, return a clean full-block exterior, exposed interior and a small populated fight sample. Recheck the front/inside/behind presentation if any changed art overlaps the existing cover. Do not expand the city, add a new roof system, redesign actors/objectives, or retune combat/save behavior in this pass. The user requested further refinement; the previous GO does not need to be revoked to do it.

### Current evidence personally inspected for this recommendation

- Six fresh native `occlusion-review-02` images: `searchable-building-exterior`, `searchable-building-interior` and `behind-building-shadow`, each at 960×540 and 1280×720. The approved front/inside/shadow distinction remains apparent in these shown states.
- Study `08-mediterranean-medieval-industrial-city.png` and `IMPLEMENTATION_HANDOFF.md`; current vision and latest relevant roadmap entries were consulted.
- Six actual moving-capture PNGs under [occlusion-moving/normal-corrected](../reference/2026-10-18-city-block/occlusion-moving/normal-corrected/), with zero-based metadata checked in `capture-info.json`:

| Frame | Phase | Wall time | Outside-fight simulation time |
| --- | --- | --- | --- |
| 0035 | Passage traversal | 18.686 s | — |
| 0058 | Interior fight | 30.952 s | — |
| 0073 | Outside after restoration | 36.456 s | — |
| 0076 | Populated outside fight | 37.453 s | 0.333 s |
| 0090 | Crowded outside fight | 39.631 s | 2.517 s |
| 0110 | Later outside fight | 42.732 s | 5.600 s |

These changing states support keeping the street clear: tells/projectiles are visible, while bodies/effects still merge around the player in the denser samples. The inherited pink pickup-over-roof presentation is also visible in frame 0073. These known limits do not call for an actor/loot redesign within this material pass. Neither MP4 was played back; no continuous-motion, performance or human-readability approval is added. Production files were read-only and no engine run was performed. Only this recommendation was appended.

## Four-item refinement critique — upgrade-review-02

18 October 2026. **Keep three refinements; make one small records-board correction before calling this four-item pass complete.** The architectural GO stands. This is a frozen south-front quality check, not moving acceptance or a new architecture rejection.

The lead personally opened the [960×540 exterior](../reference/2026-10-18-city-block/upgrade-review-02/searchable-building-exterior-960x540.png) and [960×540 interior](../reference/2026-10-18-city-block/upgrade-review-02/searchable-building-interior-960x540.png) first, then their [1280×720 exterior](../reference/2026-10-18-city-block/upgrade-review-02/searchable-building-exterior-1280x720.png) and [1280×720 interior](../reference/2026-10-18-city-block/upgrade-review-02/searchable-building-interior-1280x720.png) counterparts.

| Requested refinement | Stop-condition verdict |
| --- | --- |
| Domestic eave | **KEEP.** The broad blank slab has become a thin trim/underside edge. The main clay field now meets the lower wing coherently, and the front reads as supporting the roof. The dwelling retains its distinct mass without another decorative row. |
| Contact and flush thresholds | **KEEP.** The localized base contact and restrained worn aprons anchor both entrances while the openings remain visibly clear. The wear is quiet and limited to the frontage; the central street retains its accepted broad value. No new raised step is suggested by the shown aprons. |
| Municipal service run | **KEEP.** The coarser dull copper connection can be followed down the civic right edge to the existing drain at small size. Its supports and mineral area remain grouped; it communicates a practical retrofit without a new machine or scattered fitting noise. |
| Interior records group | **ONE CORRECTION.** Placement, scale and restraint are right: the group remains in the back wall band, leaves the security label/floor clear and does not compete with the shown actors. Its two pale inserts, however, look masonry-like within a narrow horizontal frame. At 960×540 they merge into the wall, giving a grille/trim impression rather than a clear records-board identity. |

**The one correction:** retain the current board's dimensions, outer olive frame and ledge. Replace the two masonry-like pale inserts with **opaque, muted warm-paper/ledger faces**, each with at most one or two broad dark record bands. Remove the brick-joint impression inside those faces; do not add fine writing, more compartments, glow, floor furniture or a new object. Stop when those two solid faces make the existing group read as a wall-mounted records board in the same 960×540 interior, with actors still registering first. A focused small interior check is sufficient for that correction.

Only these four PNGs were inspected for this pass. The packet's before/shadow pairs and alternate-orientation cupboard guard were not re-reviewed here; test/native-exit reports do not substitute for those pixels. No engine, production edit, additional agent or broad audit was used. Moving verification remains separate.

## User chimney correction — 18 October 2026

The user supplied a current cropped game image and said the chimneys “look whack.” **Rework their visual treatment.** Earlier approval established basic volume in the first block; it did not establish that these plain chimney shapes were a finished match for the painted roof materials. The user's current correction supersedes that limited positive assessment.

The supplied image was personally opened. The two stacks read as clean pale boxes perched on textured tiles. Their faces are almost unmodulated, the dark opening is a tiny slot, and there is little cap profile or convincing roof contact. Narrowly reading `CityBlockRoofForms.gd::_chimney` confirms a set of flat polygon faces and a small opening; the current geometry does not provide the projecting coping or grounded flashing the silhouette needs. This is a shape/material/contact correction, not a request for more roof forms.

### Focused correction for implementation

1. **Give each role a functional silhouette.** Civic: a compact weathered stone stack with a visibly projecting, shallow coping and one broad recessed dark flue. Domestic: a modest warm-grey rendered/brick base with one short terracotta pot and a readable dark mouth. Keep the forms near the current scale; avoid a new tall tower, multiple tiny pots or an elaborate machine. At small size, coping and flue should be clearer than individual masonry marks.
2. **Seat the base in the roof.** Use a low dark lead/aged-metal flashing skirt fitted to its supporting roof slope, with restrained contact darkening and one short cast shadow consistent with the scene's existing light. Tiles should appear to terminate against an installed stack. Keep all pieces attached to the host roof's cutaway/fade ownership.
3. **Match the painted materials.** Use broad warm/cool masonry planes, a small grouped soot stain near the flue and one or two low-contrast weathered patches. Break up the clean cream-box reading. Describe selected masonry courses only; do not outline every brick or add a thick perimeter stroke. The domestic clay pot should belong to the muted roof palette, while civic coping remains related to the pale public masonry.

**Procedural rule:** implement this through the shared roof/chimney helper with role, supporting plane and usable roof span as inputs. Derive placement and flashing from the actual generated roof geometry, with clearance from eaves, ridge junctions and passage/door projections. Skip an unsafe optional chimney when a suitable span does not exist. Do not dress the captured coordinates specially. Preserve seeded regeneration, valid alternative entrance directions and cover ownership; the south-painted-front limitation remains explicit.

**Stop condition:** in a native 960×540 view, each chimney reads as an installed flue with a cap/mouth and grounded base, rather than a pale floating cube. The two roles are related but distinguishable, their contact/shadows agree with their own roof planes, and roof texture/actors retain the stronger hierarchy. Show a varied generated roof placement as well as the original block; check the cutaway still removes the entire assembly. No chimney production change or engine run was performed in this designer chat.

## Records-board stop condition — upgrade-review-03

18 October 2026. **KEEP — the remaining records-board correction is resolved.** The lead personally opened only [the fresh 960×540 interior](../reference/2026-10-18-city-block/upgrade-review-03/searchable-building-interior-960x540.png) for this focused check.

The two opaque muted paper faces and broad dark record bands now separate from the masonry inside their olive frame. The group reads as a wall-mounted records/notice board at native small size, rather than a grille with wall joints showing through. It remains contained in the north-wall band, clear of the security label, doorway and fight floor. No further board detail or enlargement is needed. This closes the one outstanding correction in the four-item frontage/interior pass; the user's separate chimney rework remains open.

The normal-size counterpart, procedural-layout samples, roof comparisons and moving clips were not inspected in this single-image check. No engine or production edit was performed, and no procedural art-coverage or moving-readability approval is added.

## Chimney stop-condition critique — chimney-review-01

18 October 2026. **KEEP — the shown chimney treatment meets the user's correction brief. No further concrete chimney correction is required from this packet.**

The lead personally inspected these four native images, with the small exterior first:

- [Original-block exterior, 960×540](../reference/2026-10-18-city-block/chimney-review-01/searchable-building-exterior-960x540.png)
- [Original-block exterior, 1280×720](../reference/2026-10-18-city-block/chimney-review-01/searchable-building-exterior-1280x720.png)
- [Seed 17 horizontal generated layout, 1280×960](../reference/2026-10-18-city-block/procedural-review-02/seed-17-layout-0-1280x960.png)
- [Original-block interior, 960×540](../reference/2026-10-18-city-block/chimney-review-01/searchable-building-interior-960x540.png)

At small gameplay size, the civic stack now has a projecting coping, dark recessed flue and selected masonry/weathering planes. The domestic stack is smaller and distinguished by its warm clay pot and dark mouth. Their darker flashing skirts and short cast/contact shadows establish an installed roof base. They have moved beyond the earlier clean cream-cube treatment without outlining every brick or adding a large bright roof feature.

In the inspected generated-layout view, the visible repeated domestic stacks and civic stack sit on supporting roof fields with separation from the shown eaves and junctions. This is useful evidence that the treatment is reused beyond the original captured placement. It is one horizontal-layout inspection at zoom 0.4, not proof of every seed, size, entrance direction or gameplay camera. The small interior shows the civic chimney assembly absent with the cutaway roof; the neighboring house assembly remains with its opaque roof. Continuous fade timing was not inspected.

The chimney visual stop condition is closed for these shown states. No broader procedural/art-coverage, moving-combat or performance approval is added. No engine, production edit, additional agent or broad audit was performed here.

## Street, soil and vegetation direction — 18 October 2026

The user's new priority is the overall environment approaching study 08, with the buildings accepted as the foundation. **The largest remaining ground gap is surface zoning.** The current native block reads as one broad limestone carpet beside dark, noisy moss/grass. The inspected generated L layout repeats that continuous paving across the spaces between parcels, leaving the road hierarchy visually weak. Study 08 instead has worn road stone, lighter civic frontage, physical margins and contained leafy pockets. Aim for a maintained, weathered temperate public street.

### Bounded first ground pass, in priority order

1. **Separate actual roads from frontage paving.** Keep the broad light grey/chalk limestone slabs at building fronts and forecourts. Give real road arms a slightly darker, cooler blue-grey worn-sett treatment with smaller, softly grouped units. Let the material follow the road's full existing width and actual junction shape. Keep internal stone seams low contrast so actors/tells remain stronger; no separate outline around every cobble.
2. **Connect the two surfaces with a coherent margin.** Derive a narrow limestone curb and shallow dark gutter from the road/frontage boundary, carrying it through turns and branch mouths. Keep real door approaches and road connectors flush/open. This should explain the transition rather than draw boxes around individual parcels. Retain the useful local entrance aprons and existing outlet/drain connection.
3. **Give exposed earth specific locations.** Use muted grey-brown/umber soil at planted pockets, sheltered wall/verge recesses and limited worn cuts into unbuilt green ground. Group it into a few broad patches with broken edges. Paving remains dominant in this urban block; remove the tan sandy outline around every paved shape. Avoid uniform speckled dirt across the fight floor.
4. **Replace the continuous noisy green carpet with controlled growth.** Calm the broad unbuilt grass/moss values toward muted sage/olive, then concentrate reused foliage into a few parcel-corner or recessed-edge pockets. Place sparse weeds in protected joints and near damp margins; keep trodden road centers and door approaches visually clear. Group heights/tones rather than distributing identical shrub dots. Any larger foliage stays on existing blocked/unused edges and must not imply an obstacle across a real route.
5. **Make wear follow use and drainage.** Add a few broad softened foot-worn areas at actual doors, darker dampness immediately downstream of real outlets/gutters, and one or two quiet paving repairs near service edges. Blend transitions over a short irregular margin, preserving the curb where a curb is intended. Avoid a repeating dark wet line around everything, shiny puddles everywhere, random crack decals and full-floor distress noise.
6. **Keep open daylight and a restrained density hierarchy.** Use light neutral limestone, cooler road stone, moist brown earth and leafy greens as distinct broad families. Reduce the surrounding near-black mottled moss impression. Reserve deeper cool shade for building/plant contact and service recesses; keep selective warm stone/clay/copper accents. Adjust material values locally rather than applying a global warm/beige or dark filter. The street's contrast remains below actors, interactables and active effects.

### Procedural scope and stop conditions

Limit this pass to the existing block, its adjoining real road arms and their immediate verge transitions. Reuse existing stone/vegetation resources and surface tools; a new asset pack is not needed for this first composition pass. Derive surface ownership from real road, parcel/interior and door-connector masks. Reserve road/door clearance first; use seeded variation only inside eligible wear/soil/plant areas. Exclude interiors and blocked building footprints. L/T branches must open only where the actual arm reaches the edge. Keep collision, traversal, objective placement and other gameplay rules unchanged.

Return matched native normal and 960×540 views containing buildings **and** a road turn/junction plus a soil/green margin; a building-only crop cannot judge this work. At small size, road, frontage and planted edge should be distinguishable before individual stones or weeds. Show one different seeded L/T layout so surface bands follow its actual arms rather than a rectangular template. Include a populated fight sample over the road/frontage transition: player silhouettes, projectiles and ground tells must remain clearer than the paving pattern. Clean daylight, physically explained joins and a few purposeful green/damp pockets are the stopping point. Do not fill the street with props, golden circuit lines, decorative road emblems, dense outlined cobbles or random greenery to manufacture detail.

Evidence personally reopened: [study 08](../concepts/2026-10-18-city-directions/08-mediterranean-medieval-industrial-city.png), [latest small Game exterior](../reference/2026-10-18-city-block/chimney-review-01/searchable-building-exterior-960x540.png) and [Seed 17 L-layout inspection](../reference/2026-10-18-city-block/procedural-review-02/seed-17-layout-3-1280x960.png). The latter is a zoom-0.4 generator inspection, not full Game/fight evidence. No code, engine run or new asset was produced for this recommendation.

## Ground first-pass critique — ground-review-01

18 October 2026. **Continue with a focused correction; the ground pass is not yet visually accepted.** Road/frontage zoning is useful progress: the actual L and T street shapes now register immediately instead of disappearing into a single limestone surface. Keep that mask-based hierarchy and the accepted buildings.

The lead personally opened these five fresh native images:

- [Game transition, 960×540](../reference/2026-10-18-city-block/ground-review-01/street-ground-transition-960x540.png)
- [Game exterior, 960×540](../reference/2026-10-18-city-block/ground-review-01/searchable-building-exterior-960x540.png)
- [Game transition, 1280×720](../reference/2026-10-18-city-block/ground-review-01/street-ground-transition-1280x720.png)
- [Generated L junction](../reference/2026-10-18-city-block/ground-procedural-01/seed-17-layout-3-1280x960.png)
- [Generated T junction](../reference/2026-10-18-city-block/ground-procedural-01/seed-211-layout-4-1280x960.png)

### Bounded corrections, in priority order

1. **Make the road a daylight stone surface.** In the small transition, the dark blue-green road, strong cobble joints and dark inner perimeter together suggest a recessed channel. Lift its midtones closer to the limestone, keeping only a modest cooler/darker value step between the two materials. Flatten most joint shadows and reduce the apparent stone-unit size by roughly a quarter to a third. Prefer a tighter worn-sett grouping over large rounded cobble cells where an existing material allows it. Keep broad surface variation soft; a dark line belongs at the shallow gutter, not around every stone. Preserve the existing road width/mask and leave frontage values largely alone.
2. **Remove the continuous soft green halo.** The top/left Game edges and the entire inspection perimeter have a near-even blurred green belt. This reads as fog or an effect around the paved rectangle rather than planted ground. Retain a crisp physical paving/curb edge where appropriate. Put a few irregular muted earth patches and grass/weed clumps outside it at eligible recesses/corners, separated by substantial stretches of clean curb or simple unbuilt ground. Keep any transition feather narrow and local. Do not substitute a continuous brown soil ring for the green one, or blur the paving itself to disguise the join. Calm the old mottled green ground beyond these pockets as well, so the first few verge pixels are not the only changed area.
3. **Finish connector continuity.** The generated views still visibly close road mouths with transverse edge/cap treatment. Remove that treatment wherever the actual road arm continues beyond the local block; carry the road surface to the shared boundary. Keep caps only at genuine ends. This confirms the connector issue the implementer already reported and is fixing, rather than introducing a separate layout redesign.
4. **Keep drainage subordinate to the street.** Once the road is lighter, retain a thin gutter and shallow curb rather than a boxed dark frame. Use fewer grates at purposeful outlet/corner/low-point positions along eligible margins; avoid mechanically mirrored grates at identical intervals on both sides of every arm. Preserve the existing civic outlet connection. A small number of functional drainage cues is enough for this first block.

**Stop condition:** at native 960×540, the street reads first as a traversable daylight stone road beside a lighter limestone frontage, with low-contrast sett grouping. The margin reads as physical curb/earth/growth rather than a glowing rectangular belt. Generated L/T road mouths remain visually open at continuing connectors. The interior and accepted architecture stay unchanged. Return the same transition framing plus the L/T overview after these changes; then use the planned populated sample to check that actor bodies, projectiles and ground tells still dominate. No new asset pack, extra street props, global lighting rewrite or wider city rollout is needed to clear this correction.

This is a five-image frozen review against the already inspected study 08. It does not approve moving combat, collision, all seeds or performance. No production code edit, new asset, engine run or additional review suite was performed here.

## Ground revision and direct user steering — ground-review-02

18 October 2026. **This is the current ground assessment; ground-review-01 above is historical.** The user additionally requested shading/shadows/lights because the game looks flat, and explicitly preferred the earlier uneven old-city roads over the renewed block-like appearance. That changes the next priority from surface zoning alone to irregular street character and shared depth lighting.

The lead personally opened the current [small transition](../reference/2026-10-18-city-block/ground-review-02/street-ground-transition-960x540.png), [small exterior](../reference/2026-10-18-city-block/ground-review-02/searchable-building-exterior-960x540.png), [normal transition](../reference/2026-10-18-city-block/ground-review-02/street-ground-transition-1280x720.png), [generated L view](../reference/2026-10-18-city-block/ground-procedural-02/seed-17-layout-3-1280x960.png) and [generated T view](../reference/2026-10-18-city-block/ground-procedural-02/seed-211-layout-4-1280x960.png).

**Keep the improvements in 02:** road midtones are lighter, the old fog-like fringe is reduced, and the inspected continuing L/T mouths are open. Do not repeat the 01 endcap finding as an unresolved issue in these new views. The remaining perimeter still reads as a fairly continuous textured green border, and the road/frontage shapes retain ruler-straight, parallel-sided organization.

### Current bounded next pass

1. **Restore broad old-street irregularity.** The proposed surface-only approach is appropriate for this first block. Preserve the actual clear route, connectivity, footprint/door exclusions and shared chunk exits. Around that protected corridor, generate slow asymmetric changes in paved width, a few shallow bends/setbacks and occasional splayed junction corners or wider frontage pockets. Give each arm a few broad shape decisions over several paving units; avoid tile-by-tile jitter, a sine-wave border or equally wide sidewalks around every parcel. Let remaining space beside the fixed buildings form different wedges and recesses. At gameplay size, this must visibly alter the silhouette of the street, not merely add texture to the rectangular outline. This pass establishes street-surface character; it does not claim a completed organic whole-city topology.
2. **Break the border into physical pockets.** Keep substantial runs of clean stone edge, with a few exposed grey-brown soil and grass/weed pockets at protected recesses, outer bends and planted corners. Leave continuing road mouths and door approaches clear. Blend soil into growth locally; retain a definite stone edge where masonry is present. Remove the remaining uniform perimeter-belt logic rather than replacing it with a continuous dirt band. Keep the lighter road value and soften individual cobble joints as needed after the shape change.
3. **Add a shared high-daylight shadow treatment.** Align broad building/foliage shadows with the existing character/chimney sun direction (toward screen southwest), using the shared depth style rather than unrelated offsets. Use a restrained cool translucent cast shadow from real building/roof mass plus tighter contact shade at wall bases, eaves, arcade recesses and pipe attachments. Height differences should affect the projection. Keep the sunlit limestone clear and the road readable; begin with short-to-medium shadows, not full-street black coverage or a blurred rectangle around the block. Any cover-dependent shadow must behave consistently when its roof/front cuts away, while visible standing-wall contact remains grounded. Shadows must not paint over the player, active tells or HUD.
4. **Use a small amount of motivated fixture light.** Start with one subdued warm pool in an actually lit arcade/doorway recess and, if a real existing service fixture supports it, a restrained utility accent. Keep pools local to their source and nearby receiving surfaces; do not shine them through walls. Broad lit/shaded planes and recess/contact depth should do most of the work. The world remains open daylight, with normal actor colours preserved outside the already approved roof-occlusion treatment. No global darkening, dense point-light network, bright bloom or new decorative light catalogue is needed.

**Acceptance/stop:** use the same native 960×540 transition with a visible street turn, soil/green edge and building. Road width and edge rhythm should look uneven at first glance while the protected route stays continuous. Surface zones must remain recognizable, and the unbuilt edge must contain distinct pockets and quiet gaps. Building, foliage and actor shadows should agree in direction, make height/recesses legible, and leave combat clearer than the terrain. Show one L/T layout to confirm the rules vary with actual generated geometry and share open exits, then one populated Game sample over sun/shade. Keep buildings and gameplay fixed. Freeze the composition once these depth and street-shape relationships read; do not prolong the pass with more small surface ornaments.

No production file, new asset or engine session was created here. This is read-only designer guidance on five frozen current images and the user's latest direction, not a moving/performance approval. The implementation chat's proposed protected-corridor variation, shared sun/contact shading and restrained existing-fixture light agree with this scope.

## Ground/depth checkpoint — ground-review-03

18 October 2026. The lead personally opened [the current 960×540 transition](../reference/2026-10-18-city-block/ground-review-03/street-ground-transition-960x540.png). **Keep the shown depth/material improvements; one road-shape correction remains required for the user's uneven old-city direction.**

**KEEP:** the broad southwest building shadows now give the fronts physical weight and agree with the shown actor shadow. The road is lighter and quieter, its smaller stone units no longer dominate like the earlier channel treatment, and the mechanically repeated grate/frame pattern is absent. The green margin no longer has the earlier fog-like overlay. No additional lighting-system or material redesign is required before the next moving sample. The tiny service accent stays suitably subordinate in daylight.

**One required correction:** broaden the asymmetric variation in the paved road silhouette. In this frame the top and bottom edges are still mostly parallel with small ripples. Create one long, shallow widening/shoulder toward a frontage and a narrower stretch farther along, with the opposite edge's changes occurring at different positions. An extra shoulder around one compact character-width at small size is enough to make one deliberate shape decision visible; keep it within eligible free frontage/ground and preserve the protected continuous corridor. Avoid uniform waves, per-tile wobble or moving buildings. If the L/T inner corner is revised in the same profile pass, a restrained splayed pocket is appropriate; that unshown junction is not a separately discovered defect here.

**Stop:** at 960×540, a reviewer can see asymmetric widening and narrowing from the street outline before inspecting its stones, while the daylight surface and accepted shadows remain. Keep doors, shared exits and route clearance unchanged. Then proceed to the planned populated sample; no broader environment expansion is needed to close this bounded pass.

Only this one frozen view was inspected for checkpoint 03. Interior clipping, other layouts, moving shadow behavior, actor recovery and performance are not newly approved. No production edit, engine run or additional audit was performed.

## Ground/depth shape stop — ground-review-04

18 October 2026. **KEEP for the shown bounded street/depth pass. The road-shape correction from checkpoint 03 is sufficiently addressed; no additional shoulder-profile iteration is required before populated verification.**

The lead personally opened [the current 960×540 transition](../reference/2026-10-18-city-block/ground-review-04/street-ground-transition-960x540.png). Its upper road edge has a visible shallow widening near the dwelling and tighter stretches toward the central approach. The lower edge follows a different outline, so the paved strip no longer presents the same near-parallel boundaries as 03. This is enough visible asymmetry for the first surface pass. Increasing wave amplitude again risks an overly scalloped outline; freeze this profile while checking it with actors/effects.

Keep the current daylight road value, quiet stone units, grounded southwest building shadows and restrained warm doorway fixture. These support depth without reverting to a dark street. This is progress toward old-city surface character, not a claim that the underlying whole-city street topology has become organic.

Only the linked frozen transition was inspected for this stop. The revised L/T corner, cover/interior clipping and fixture fade are outside this image; no moving or performance approval is added. Proceed to the planned populated sun/shade sample, and reopen these values/shapes only if that reveals a concrete readability problem. No production edit, engine run or additional audit was performed here.

## Current road profile and stronger human visual target — 18 October 2026

The user explicitly said to **push further toward the concept's visual quality and be less cautious**, then supplied a cropped image of the civic outlet saying it also looks weird. These are current art instructions. Earlier KEEP decisions record acceptable individual steps; they are not a ceiling on the requested visual upgrade or full fidelity approval against study 08.

The lead personally opened the supplied crop, [ground-review-05 small transition](../reference/2026-10-18-city-block/ground-review-05/street-ground-transition-960x540.png), [current ground-review-06 small transition](../reference/2026-10-18-city-block/ground-review-06/street-ground-transition-960x540.png) and [current generated L view](../reference/2026-10-18-city-block/ground-procedural-05/seed-17-layout-3-1280x960.png). **KEEP the current 06 road profile for this pass:** its broader width variation and the sampled splayed L turn are sufficient to stop further profile tweaking. This is a current-image statement, not reliance on historical 04. The next worthwhile effort is the scene's physical/material integration.

### Required immediate correction: replace the flat floor outlet

In the user's crop, the long pale L-shaped run is an outlined strip across the pavement, ending in a small striped rectangle. It reads as a graphic laid on the ground. A narrow read of `CityBlockKit.gd` confirms this is a polyline continuing from the wall outlet onto the ground with a sharp right-angle turn. The earlier recommendation to strengthen its connection, and the later KEEP, were insufficient visual judgments. The user's current rejection supersedes that approval for this element.

**Replace the ground dogleg with a mounted downpipe ending directly over a flush catch drain at the wall base.** Give the vertical pipe a rounded shaded body, two broad collars/supports, a short believable elbow/spout and a small attachment shadow. Put a compact iron grate in a worn stone frame immediately below the outlet, with one restrained damp patch. Remove the long exposed pavement segment. Distinguish the pipe's elevated wall plane from the drain's horizontal ground plane. Keep the entire installation at the existing service wall edge, clear of the passage and doors; skip the optional fitting if generated geometry has no safe wall-base span.

### Coherent next streetscape upgrade

Use one substantial integrated pass on this same playable block, following these priorities:

1. **Make the arcade's depth visible.** Retain its accepted mass and actual doorway. Strengthen the inner jamb/soffit planes, controlled cool recess shade and warm stone catching daylight. Resolve the center opening's broad flat grey-green appearance into a convincing view into a recessed entry. Use the actual small sconce to motivate a restrained warm response on nearby stone. Preserve full character visibility and the real cutaway. A clear foreground pier, shaded arch depth and interior floor should read as separate planes.
2. **Compose one substantial inhabited green corner.** Build on the current civic-left planting with one coherent leafy canopy/ivy/stone-base group at the existing blocked corner, grounded by an irregular foliage shadow. Use a few large leaf/value masses and a visible supporting base/trunk where needed. Allow adjacent soil and worn paving to respond to this group. Retain long open street stretches. The goal is the temperate lived-in abundance of study 08, not a thin procedural green border or many identical shrub dots.
3. **Give the ground a convincing history at a larger scale.** Keep current routes and the broader 06 street outline. Compose a few broad worn-stone/repair groups, uneven curb remnants and a small service-damp zone tied to actual entrances, drainage and planting. Maintain the lighter limestone / cooler road relationship. Reduce the sense that one uninterrupted slab texture has been spread over every spare rectangle. Use soft grouped material changes, selected broken edges and deliberate clean gaps; individual joints stay quiet beneath combat.
4. **Unify the material and light response.** Tie stone, copper/iron, clay, foliage and ground together with the same sun direction and cool ambient shade. Let contact shadows, a few cast silhouettes, subtle material highlights and real recesses provide depth. Warm fixture light belongs to the arcade/service source, not a global colour wash. Keep open Mediterranean daylight. Judge whether simple procedural faces or lines are visually adequate beside the painted pieces; replace/repaint the small components that remain diagram-like instead of protecting them merely because their placement tests pass.

These recommendations permit a more ambitious visual composition within the existing footprint. Preserve the building/road gameplay layout, procedural derivation, regeneration and route clearance; keep optional dressing anchored to valid wall/roof/unused corner spans across seeds. This is not a request for a new city topology, physics system or full renderer rewrite. Appropriate reused art and a small number of purpose-made material/components may be used by implementation when needed to meet the requested fidelity; this designer chat has produced no new asset.

**New visual stopping point:** compare a coherent actual-camera full-block result directly with study 08. The scene should have a convincing foreground/midground relationship, occupied arcade depth, a substantial temperate planted group, physically installed service hardware and broad old-street material variation at 960×540. Character/tell priority and open daylight remain. Return one complete native scene after the integrated changes, plus its relevant cutaway/overlap and a populated sample, instead of requesting another approval after every tiny parameter change. The user's newer visual ambition governs further critique.

Only the four listed images/source crop and the narrow outlet implementation were inspected for this update. No production edit, engine run, new asset, continuous-motion or performance review was performed here.

## Human-authorized asset expansion and whole-scene checkpoint — ground-review-09

The human explicitly requested generating more reusable assets and expanding toward the concept. Five original selected pieces were generated with built-in `image_gen.imagegen` and delivered for implementation: temperate tree, ivy/stone planted corner, domestic linen awning, shielded wall lantern and worn angular street setts. One original planter alternate and an exact-byte road-name alias are retained, not counted as additional distinct selected pieces.

Canonical files, exact generation/edit prompts, source paths/hashes, dimensions, alpha notes and art anchors are recorded in [STREETSCAPE_ASSET_HANDOFF.md](../../../assets/world/city_block/STREETSCAPE_ASSET_HANDOFF.md), [the manifest](../../../assets/world/city_block/streetscape_assets_manifest.json) and [prompt set](../../../assets/world/city_block/STREETSCAPE_GENERATION_PROMPTS.json). All five canonical PNGs were verified byte-identical to their selected generated originals. This chat made new source-art/metadata additions only; runtime code/engine work remains owned by implementation.

The lead personally inspected the generated originals and the following actual Game views:

- `ground-review-08`: small transition, exterior and interior, with tree/planter and repaired service assembly.
- `ground-review-09`: [small transition](../reference/2026-10-18-city-block/ground-review-09/street-ground-transition-960x540.png), [small exterior](../reference/2026-10-18-city-block/ground-review-09/searchable-building-exterior-960x540.png) and [small interior](../reference/2026-10-18-city-block/ground-review-09/searchable-building-interior-960x540.png), containing all five selected pieces.

**The combined scene is materially closer to study 08.** Keep the substantial leafy/stone corner, single domestic awning, physical lantern and deeper entry planes. The native tree/planter has no broad green haze; the broad glow visible in RGB previews was in sampled alpha-zero pixels. The pipe now terminates at the wall over a compact flush drain, closing the rejected floor-L composition. The shown civic cutaway removes the civic fixture/cover while the external tree and neighboring house/awning remain appropriate to their shown states.

**Two ground follow-ups remain before the final visual checkpoint:**

1. A square step in the road edge persists near x428 in the small views, shifting vertically with the camera. It looks like a surface-piece join and should not be accepted as organic irregularity. Implementation is already investigating the real material/geometry boundary. Preserve the broader road profile while removing the abrupt axis-aligned step.
2. The new sett material currently reduces to dense granular noise at 960×540. Enlarge its apparent units modestly (roughly 1.4–1.8 times the current mapping) and compress fine mottling/joint contrast. It should read as worn stone courses while actor/effect contrast remains stronger. The source prompt's seamlessness request is not a substitute for judging its actual repeated mapping.

No further asset catalogue expansion is needed before these pieces are settled in one coherent scene and populated sample. These observations concern frozen native pixels; no clip playback, moving-combat comfort, all-seed art coverage or performance approval is added. The user's stronger visual target remains the standard beyond individual technical KEEP decisions.

## Integrated streetscape static stop — ground-review-11

19 October 2026. **KEEP for the shown integrated static streetscape. Both open ground findings from 09 are resolved in the current pixels; no further concrete visual correction is required before the final generated-layout/populated check.** This supersedes the 09 road-edge and material-scale reservations, not their historical record.

The lead personally opened these four native images:

- [Transition, 960×540](../reference/2026-10-18-city-block/ground-review-11/street-ground-transition-960x540.png)
- [Exterior, 960×540](../reference/2026-10-18-city-block/ground-review-11/searchable-building-exterior-960x540.png)
- [Interior, 960×540](../reference/2026-10-18-city-block/ground-review-11/searchable-building-interior-960x540.png)
- [Transition, 1280×720](../reference/2026-10-18-city-block/ground-review-11/street-ground-transition-1280x720.png)

The abrupt square road-edge step is gone at both sizes. The broad asymmetric profile now runs continuously across the shown region. Larger, quieter setts register as worn stone courses rather than granular noise, while the limestone frontage remains distinct. The current source diagnosis reported by implementation replaces the earlier visual speculation about a surface-piece join; this designer review judges the corrected native result and did not rerun that technical investigation.

The five-asset scene has a more coherent relationship between leafy corner, occupied domestic frontage, lit civic pier, recessed arcade and irregular street. Keep the tree/planter scale and restrained awning/lantern. The wall-mounted outlet and adjacent flush drain retain the physical correction to the rejected pavement L. In the shown cutaway, the civic cover/entry fixture are absent, outdoor planting and the neighboring house/awning remain, and the player/security bodies stay clear on the quiet floor.

This is a bounded static stop for this playable block, not a claim of full concept fidelity or completed city-wide/directional art coverage. The final L/T views and populated current capture are not included in these four inspected files. Proceed to those checks with the visual composition fixed. Continuous fades, player recovery in crowds, human motion comfort and performance remain outside this static judgment. No engine run, runtime-code edit, new asset generation or additional audit was performed for this stop.

### Additional current generated-layout check

The lead subsequently opened [ground-procedural-08, Seed 17 L layout](../reference/2026-10-18-city-block/ground-procedural-08/seed-17-layout-3-1280x960.png). **KEEP for this shown layout:** road arms join continuously through the broader splayed turn and remain open at the displayed exits; road/frontage values stay distinct. The leafy civic corner, planter and service hardware remain tied to the generated building, with the tree's root at the corner and no new decorative object crossing the road center. Shared shadow direction remains coherent.

This adds one actual generated-layout image at zoom 0.4 to the four Game stills above. It is not all-seed proof or a populated Game view; detailed painted fronts remain limited by the already recorded direction/footprint coverage. No additional concrete art blocker was found in the five inspected current images. Moving verification remains pending.

## Final current sampled-state stop — small-streetscape-verified

19 October 2026. **KEEP for environment readability in the sampled current-source moving states. No new streetscape visual blocker was found.** Together with the 11 static and current L-layout review, this closes the requested bounded designer check for this integrated block. It does not establish human continuous-motion comfort or eliminate the known player-in-crowd limitation.

The lead personally opened four actual 960×540 PNGs under [ground-moving/small-streetscape-verified](../reference/2026-10-18-city-block/ground-moving/small-streetscape-verified/):

| Image | Phase and checked metadata | Assessment |
| --- | --- | --- |
| `exterior.png` | Named outside state | Current tree/planter, awning, lantern, grounded drain, continuous road profile and quieter setts remain integrated. The shown player is clear on the road. The known narrative card covers upper architecture. |
| `frames/frame-0056.png` | Interior fight; wall 29.529 s; four enemies and one projectile recorded | Cutaway room and doorway stay visible. The quiet floor separates the shown player/security bodies and attack effect. External planting remains at its corner; no new foliage or fixture paints over the shown fight. |
| `frames/frame-0083.png` | Outside fight; wall 37.429 s; fight simulation 2.000 s; 21 enemies and six projectiles recorded | Orange tells and coloured projectiles remain salient across road/frontage and shaded ground. The player is difficult to isolate inside the tight body/effect pileup. This repeats the previously observed crowd-readability limit; no new terrain/fixture obstruction is apparent. |
| `fight-ending.png` | Named later outside state | Player is separated from the remaining crowd and the material hierarchy stays quiet. This sparse ending is not used as the sole populated-combat evidence. |

Exact phases/times were read from zero-based `capture-info.json` entries. Counts describe capture state and do not assert every entity is visible in the PNG. The metadata identifies scripted input, god mode, disabled ambient spawning and full combat flashes with Reduced Motion off. The 61 fire/hit and 28 death totals reported by implementation include indoor clearance; they are not outdoor-only outcomes or independently reproduced test results.

The known large HUD cards and pink interior pickup rendered above the restored roof remain visible. This environment pass does not claim to fix them or to solve actor recovery under overlapping bodies/effects. No additional streetscape correction is requested from these samples.

Neither MP4 was played back. This current review adds four sampled frames/states, not continuous fade/animation/input/comfort proof, a benchmark, all-seed/directional art coverage, or a fresh current-source moving normal/reduced-settings comparison. Earlier accessibility/technical records retain their own versioned scope. No engine, runtime-code edit, new asset or further audit was performed for this final check.
