# S3 guard-loggia visual refinement v2

19 October 2026. **Complete: three visual actions closed,16 suites and ten fresh native runs passed.** Runtime `7f4c12e6`, following `bd8cd602` and `5a3b1068`. Full [implementation audit](../../../audits/2026-10-19-s3-visual-refinement-v2.md).

The coordinating designer closed quiet infill in the [first review](coordinating-visual-review.md), then closed watch mass and real cardinal thresholds in the [revision2 review](revision2/coordinating-visual-review.md). It personally inspected14 revision2 screenshots, including north exterior. The subsequent [code-review correction](code-review.md) changes mask coverage only: merge the actual front/side and subtract the final door-notched cap. Visible architecture and original material remain unchanged.

## Final current-source evidence

All paths below are under `final/`. Each run stores its actual seed/chunk/building/profile, captured53-file source manifest and engine result. [Checks](final/checks.json) verify530/530 current hashes,548 parsed gameplay scripts, strict warnings clean in14 targets, unchanged original material and12 preserved historical source records. Earlier candidate hashes are never substituted. [Motion summary](final/review-summary.json):329native frames,122fires/115hits/56deaths; outdoor population drops21/23 with actual projectiles. All four videos [decode cleanly](final/video-decode-checks.json). Every final run has0failures/diagnostics/save writes.

| Native evidence | Purpose |
| --- | --- |
| [Small guard](final/architecture/guard-small/exterior.png), [normal guard](final/architecture/guard-normal/exterior.png) | Whole building after temporary tutorial messages finish; native960×540/1280×720. Optional details hidden for architectural comparison. |
| [Small common](final/architecture/common-small/exterior.png), [normal common](final/architecture/common-normal/exterior.png) | Same production building/camera with the instance-local common-base override. |
| [West](final/native-entry-west/exterior.png), [east](final/native-entry-east/exterior.png), [irregular](final/native-entry-irregular/exterior.png) | Natural foliage/HUD; actual physical entry, cutaway, restoration and deterministic streamed reload. Each folder also contains entered/restored PNGs and `entry-info.json`. |
| [North entrance](final/north-whole/exterior.png) | Clear natural north threshold; the south grille frontage reaches the lower viewport edge. Whole-building architecture is shown in the separate south pair. |
| [Normal south walkthrough](final/native-south-normal/walkthrough.mp4), [fight](final/native-south-normal/fight.mp4) | Reward/security site, native traversal, roof cutaway/restoration, reload, perimeter and controlled moving combat. |
| [Reduced north walkthrough](final/native-north-reduced/walkthrough.mp4), [fight](final/native-north-reduced/fight.mp4) | Same production behavior at native960×540 with reduced effects. |

The original camera, zoom and world lighting are retained. Still captures wait for the real temporary-tip queue and then recenter; they do not hide the HUD or change game settings. Entry/full samples retain natural props. Videos use native captured timing and resolution without interpolation or speed changes; scripted controls/god mode are disclosed in each encoding record.

## Candidate history

- Root `architecture/` and `native-entry-*` folders are the **first v2 visual candidate**. Its seven completed manifests had371 matches at review time. Material action closed; watch and thresholds continued.
- `revision2/` contains the **second visual candidate**, eight successful runs and14 stills. Its designer review closes the remaining actions. After the later mask-only correction,416/424 old source hashes still matched; the eight differences were this one corrected source file. These captures retain their original manifests.
- `final/` is the fresh post-correction packet. Only its results establish final-current-source correctness. The final tests include the exact cap-notch regression and shared-budget/order checks.
- `first-guard-small/` and `first-entry-west/` are exploratory captures. The first small framing clipped the roof before capture recentering was corrected.
- Root `native-south-normal/` was interrupted during a client/tool reset and has no completed run manifest. Partial frames are retained locally and excluded from successful evidence. No human process was stopped; its fresh final counterpart is separately recorded.

## Scope and limits

Only selected S3 civic parcels receive this family. Noncivic/common houses, other district families, S1/Hub, DonJons and legacy roofless rooms retain their separate contracts. The finished material is one original1254-square opaque bitmap; [exact original prompt/hash/scale](../../../../assets/world/districts/checkpoint_lanes/infill-v2-provenance.json) and [asset notes](../../../../assets/world/districts/checkpoint_lanes/README.md) are preserved. The revised100×128px front and28px continuous side remain within the original128-square support,16px margin and256px maximum visible height.

This packet does not establish full concept fidelity, human continuous-play/balance acceptance, alternate cell scales or comparative performance. Natural foliage still covers parts of the west frontage/interior; inherited ground noise/daylight and sparse street-material coverage remain visible. The [street follow-up](../../../design/2026-10-19-district-generation/08-street-material-coverage-follow-up.md), [staged player/tree, enemy and pickup visibility packet](../../../design/2026-10-19-district-generation/09-foreground-and-entity-visibility-packet.md), and selected subsequent S4A ruin family remain separate. No new push, wider terrain rollout or visibility feature is included.

All ten final native samples have a fitted watch. No new natural no-watch or multi-door passage capture is claimed; no-fit and door-fitting checks remain authored geometry-suite evidence rather than invented native cases.

The owner personally inspected14 selected final stills and six first/mid/last outdoor frames, listed with hashes in [the inspection record](final/owner-native-inspection.json). The designer's14 revision2 stills and owner's final samples are separate inspection sets; complete video decoding does not imply continuous visual playback.

Representative native stills, six selected combat frames, videos, manifests and test logs are versioned. The remaining raw frames, capture profiles, imports and ignored scratch remain local; no cleanup retry is part of this work.
