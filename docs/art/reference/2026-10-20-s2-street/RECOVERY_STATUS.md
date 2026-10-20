# S2 street production checkpoint — 20 October 2026

The street milestone remains incomplete. Work resumed after the user's two
forced restarts. Guarded headless checks now pass; current-source native garden
fitting and full Game traversal/combat evidence remain outstanding. No aesthetic
or behavioral acceptance is inferred from the headless results. The production
run itself performed no commit, push, reset, stash, broad staging or unrelated
cleanup. The lead subsequently packaged this as an explicitly incomplete Git
checkpoint with [Linux handoff instructions](../../../../HANDOFF.md). Linux now
owns heavy implementation/checking; Windows retains art direction and review.

## Current production changes

- S2 visible wall height is 240 px for civic rectangles, 208 px for domestic
  rectangles and 176 px for irregular buildings. Other segments retain their
  existing proportions and S3 forms.
- Shared-ground S2 street parcels receive fitted entry aprons and local side
  landings. They connect to an actual nearby lane, subtract all parcel bounds
  and previous surfaces, and remain within the owning chunk. The rejected v1
  rear/side paving wrap is removed. The urban-fill court path is unchanged.
- A sparse S2 service lane may append one fitted 8×8 or 7×8 workshop after the
  original lot decisions. It respects route/access keepouts, a one-cell neighbor
  separation and chunk bounds. This is a physical addition. Original lot RNG,
  existing parcels, doors and rewards remain intact in the checked fixtures.
  The annex explicitly disables exploration loot and local encounters and has
  no secondary objective. A zero loot chance alone was insufficient because
  positive Luck can raise it; the review caught and fixed this.
- S2 domestic returns reuse quiet field/trim crops from the original house
  source. Irregular decorated bays stay 112 px tall, with a plain upper wall
  beneath the raised roof. The review caught a missing upper strip on civic
  irregular buildings; civic and domestic upper faces are now covered.
- Existing S2 civic pressure plants use a more legible 96 px source width.
- Actual parcel use is forwarded to the visual kit. Only S2 row_house parcels
  receive the new seeded domestic garden treatment; a noncivic flag alone does
  not identify a dwelling. Some variants remain untended.
- The selected fruit tree uses fruit_tree_overhead_v2.png at measured root
  anchor (660,1060) and uniform scale 135/1167. The flower/herb bed uses anchor
  (955,485) and its original aspect ratio, up to 115 px visible width. A separate
  irregular soil patch supplies plot depth. The first frontal tree source is
  not used. Outdoor gardens do not fade with the roof.

The garden source verdict is provisional. Correct source scale/identity and
passing structural tests do not establish native contact, fit or readability.
Lawn/moss integration, domestic furnishings and domestic masonry are queued
under their governing art records, not implemented by this checkpoint.

## Verification and review fixes

Portable copies of post-review results are in [review-checks](review-checks/).
The [copied original test logs](review-checks/logs/README.md) retain both the
initial red regressions and the final passing results without scratch access.
[Source hashes](review-checks/source-hashes.json) describe this headless
checkpoint, not the older native images.
The later [packaging normalization](review-checks/packaging-normalization.json)
records terminal-newline cleanup in asset metadata; pixels, JSON values and
tested implementation are unchanged. The original test hash record is retained.

| Check | Result | Applicability |
| --- | --- | --- |
| Service-frontage regression, initial red | 8 fixtures, 6 failures | Four loot-enabled annexes and two uncovered civic upper-face points. |
| Loot fix, upper wall still red | 8 fixtures, 2 failures | Loot failures disappear independently; upper-wall failures remain. |
| Service-frontage regression, final green | 8 fixtures, 0 failures | Both fixes; original reward/RNG/cells, protected roads and real entry reachability checked. |
| Natural service survey | 12 chunks, 4 seeds, 0 failures | Repeated after both fixes; four fitted annexes and one intentionally empty lane retained. Checks real entries, protected cells and household-only gardens. |
| Planned buildings | 20 chunks, 62 styled buildings, 4 entrance directions, 0 failures | After both fixes. |
| Script parse audit | 549 scripts, 8 roots, 0 failures | After both fixes. |
| Strict warning audit | 14 targets, 7 categories, 0 diagnostics/failures | Isolated snapshot; production dependencies refreshed and gameplay source/scene text matched. Project settings unchanged. All 14 target hashes match. |
| PowerShell parsing | 3 capture/guard scripts, 0 parse errors | Resource helper, standard city runner and strict warning runner. |

Earlier in the resumed work, before the two review fixes, the procedural suite
passed 5,430 checks across 76 parcels/22 sizes/four door directions; the kit suite
passed 1,298; player roof occlusion passed 11; footway geometry passed 19. These
are earlier supporting results, not a claim that every suite was repeated after
the final fixes. The final focused regression, natural survey, planned-building,
parse and strict checks cover the changed paths.

The latest survey is [natural-streets-review-fixed.json](natural-streets-review-fixed.json).
The earlier natural-streets-final.json is valid prior survey evidence. The older
natural-streets.json has a parse failure and natural-streets-fixed.json an
overstrict empty-lane assertion; neither is passing evidence.

## Native evidence and its limits

The v1-native folder contains 24 actual Game environment plates at the audit
locations, seed16102026. The isolated frozen run exited0 with zero diagnostics,
failures and save writes. Its original source hashes remain in that folder. The
lead retained the improved wall/roof balance provisionally, rejected the paving
halo and requested a real neighbor/service relationship and coherent returns.
V1 is historical evidence; later edits are not authenticated by it.

The environment-v2 folder contains 1280×720 and 960×540 native views of the actual
production ChunkManager at seed16102026, chunk(-1,3). The run exited0 with zero
diagnostics/save writes; peak private memory was1080MB and minimum available
RAM920MB. The lead provisionally retained its stronger mass and fitted annex
relationship. Its parcels are passage and workshop, so it is not home or garden
evidence. It has one frozen chunk, natural ground/props and the existing camera,
but no Game/HUD/player/objectives/entry/combat. It predates the garden integration
and review fixes.

The v2-native, v2-native-retry and v2-single-chunk folders contain source records
from stopped attempts, not completed native plates. The attempted home garden
run also stopped before producing an image. No current-source full Game or home
garden native result is claimed.

Useful genuine homes found by the survey are seed16102026/chunk(0,3), an
irregular south-entry row_house with bed variant0, and seed17/chunk(-3,5), a
north-entry row_house with fruit-tree variant1. Use these natural sites for the
next bounded fit review, not an authored replacement showcase.

## Crash observations and guarded continuation

Windows events at11:03:10 and11:11:58 Europe/Riga recorded Event41, BugcheckCode0,
nonzero PowerButtonTimestamp and LongPowerButtonPressDetected. The user confirmed
a frozen screen followed by a forced restart. These events record recovery, not
the root cause. Older error reports flushed after reboot must not be treated as
fresh diagnoses. Memory pressure is observed, but is not established as the
cause of either freeze.

Every engine start checks for another active Godot game. Headless preflight
requires1024MB available RAM and1536MB commit headroom; native preflight requires
1536MB RAM and3072MB commit headroom. The owned process is monitored every500ms
and stopped if private memory exceeds1200MB, RAM drops below384MB, commit headroom
below768MB, or its timeout expires. These are capture/test protections, not game
settings or a guarantee against a machine fault.

Resource monitoring is now wired into the standard automated city capture
runner and warning audit runner. Automated results retain measurements and exact
stop reason. Interactive -Playable runs have preflight only, because that path
returns control to the human.

Under the user's authorization, Task Manager and Windows Search were closed
earlier; the respawned Search helper, Dell Pair app and Windows Widgets helper
were subsequently closed. The current Codex session, OS and security services
were retained. No driver, power, pagefile, BIOS, security or Windows configuration
was changed. Resource headroom still limits native work; do not weaken the guard
or repeat renderer launches merely to recreate the freeze.

## Remaining acceptance work

When native preflight permits, judge current-source garden contact and whole
street composition at960 and1280, with natural foliage/actors and ordinary HUD
after temporary tips clear, plus the second natural fit/seed. Then use the guarded
standard runner for actual physical traversal, entry/cutaway/exit/restoration,
deterministic streamed reload and occupied moving combat. Qualify scripted input,
god mode and controlled spawns. Final visual acceptance remains with the lead
under the concept-fidelity audit.

The ground-care/S7 packet and real dwelling interior packet follow the exterior
checkpoint. Wider street coverage, staged entity visibility and S4A remain
separate pending work. This does not close the playable-street or whole-city
fidelity goal.
