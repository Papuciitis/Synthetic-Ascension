# Objective visual rework — 18 October 2026

The approved weathered-city direction replaces the first objective art pass.
Each form now uses its own ground footprint or upright base anchor. Muted,
broad stone and iron shapes replace the ornate props, and sparse exact-radius
boundaries leave actors and hazards ahead of objective decoration. Gameplay
distances, hold times, costs, damage, spawning and rewards were preserved.

Implementation, final native checks and scoped independent pixel reviews pass.
The original [design review](../art/reviews/2026-10-18-objective-visual-design-review.md)
records the rejected first pass; it is not evidence of approval of these replacements.

## Changes

- **Breach:** exactly three actionable ground ruptures, with no decorative fourth
  copy. Sealing moves practical restraints; losing progress uses a broken arc
  and “Losing seal.” Completion swaps to a physically filled cap. A visible inner
  fissure and broken hardware retain source identity at small size.
- **Relay:** three receivers, no fake central objective. Shutters physically
  close across the painted receiver lens; banked partial progress remains steady.
- **Vigil:** a low embedded ward plate, with braces and static held, grace,
  draining and completed cues rather than an upright shrine.
- **Wardstone:** a simplified obelisk anchored at its base, with restrained contact
  shade and engaging clamps. Activation emphasizes the real sanctuary field.
- **Exit Rite:** an overhead threshold and the full existing channel area. Durable
  thirds are square archive plaques; safeguards are separate shield shapes.
  Locked, ready, channeling, grace, draining and completed states differ in stills.
- **Wager:** a practical scales bench with the actual paid tier, odds, next price,
  dwell and reserve refusal. Settlement closes the real collection tray. The
  presentation observes transactions and never spends Followers itself.
- **Vault / Last Chance:** a compact secured hatch and a physically opened,
  spent variant. Commitment text names the guaranteed Manifestation and actual
  costs. Last Chance displays and sacrifices the real safeguard count without
  implying the ordinary vault's extra encounter.
- **Exploration:** cues mark actual building entrances, security, cleared rooms
  and genuine reward pickups. Cache rewards receive quiet contact brackets.
  No decorative chest or new click interaction was added.
- **Ritual Interference:** a broken, spiked hazard boundary and real pending-corpse
  countdowns distinguish this dangerous area from a sanctuary.

Low forms draw below actor feet and shadows. Upright forms use a bounded visual
depth update relative to the player's position. Contact anchors and lens/tray
features are explicit source coordinates; transparent canvas margins no longer
determine alignment. State writes are latched and never advance gameplay.

## Confirmed defects corrected

The tagged cache's initial pickup attempt ran in `_ready` before ChunkManager
registered the chunk, so its real walkability query rejected every placement.
Deferring only that first attempt fixes the exact seeded production reproduction:
two genuine walkable pickups appear, survive streaming reload and duplicate no
payout. The original failed reproduction and corrected result remain in isolated
task evidence.

Graphical captures also exposed three GPU texture leaks during shutdown. A
Game-free cursor baseline reproduced the exact three texture sizes; an explicit
cursor-clear control removed them. CursorManager now releases its three hardware
cursor shapes and cached textures on exit. The final full-Game world capture
also shuts down cleanly. Cursor appearance and settings were preserved.

## Sources and evidence

Nine transparent PNGs were generated through the built-in image tool. Original
pixels were preserved; Godot imports use a 512-pixel edge limit and mipmaps.
Exact prompts, source filenames, hashes and anchor measurements are recorded in
[Breach / Vault provenance](../../assets/world/objectives/painted/PROVENANCE_V2.md),
[Wardstone / Rite provenance](../../assets/world/objectives/painted/PROVENANCE_WARD_RITE_V2.md)
and [Relay / Vigil / Wager provenance](../../assets/world/objectives/painted/PROVENANCE_RELAY_VIGIL_WAGER_V2.md).

Native checks use the real Godot 4.7.1 executable, actual process exit codes,
explicit completion summaries and full captured stdout through shutdown. Each
launch isolates APPDATA/LOCALAPPDATA, saves and recorder outputs. No timeout or
incomplete `--quit-after` result is counted as a pass. Scratch evidence root:
`.superpowers/sdd/2026-10-18-objective-visual-rework/`.

| Completed native suite | Passed | Failed |
| --- | ---: | ---: |
| ObjectivePresentationTest, all v2 integration | 25 | 0 |
| BreachGroundingTest | 9 | 0 |
| RelayVigilWagerPresentationTest | 39 | 0 |
| PrimaryObjectiveTest | 236 | 0 |
| SecondaryObjectiveTest | 35 | 0 |
| WardstoneRitePresentationTest | 30 | 0 |
| ExitRiteTest | 58 | 0 |
| ExitEncounterTest | 21 | 0 |
| VaultExplorationPresentationTest | 32 | 0 |
| TaggedCacheStreamingTest | 6 | 0 |
| CursedVaultTest | 32 | 0 |
| RitualInterferenceTest | 35 | 0 |
| WorldFootprintTest | 11 | 0 |
| GroundLootCapTest | 6 | 0 |
| Final ScriptParseAuditTest | 539 | 0 |

These suites cover overlapping behavior and are not summed into a unique total.
The final all-v2 import exited 0 with clean full output. A final independent code
review found no substantive P1/P2 in the 15 production files against `c099436c`;
it did not claim engine execution or pixel approval.

After final integration, BreachGroundingTest (9), WardstoneRitePresentationTest
(30), RelayVigilWagerPresentationTest (39), VaultExplorationPresentationTest (32)
and all 539 gameplay scripts were rerun cleanly: actual exit 0, explicit complete
summaries, no timeout, warnings or errors in full output. The shared 25-check
suite had already passed against the same final integration. Initial expected
failures and intermediate capture-tool failures are preserved in scratch.

## Native visual review

The single-Breach prototype was inspected before generating the rest of the
family. Independent review required stronger small-size source identity,
different static decay cues and visible actual enemies. All three were corrected
and received a [scoped visual go](../art/reviews/2026-10-18-breach-prototype-review.md).

The final world capture completed 27 images with zero failures and zero save
writes, actual exit 0 and clean full stdout. Nine panels cover Wardstone, all Rite
states, actual 15-enemy pressure, Relay, Vigil and genuine Wager purchase,
settlement and refusal. Every panel has normal 1280×720, small 960×540 and
960×540 Reduced Motion / Combat Flashes Off views. Pressure uses actual spawned
S3 enemies but does not claim to reproduce a timed Rite wave.

The final risk/exploration session completed 24 images over eight panels in S2,
with actual vault payout/healing bill, Last Chance's 3-to-0 safeguard sacrifice,
building lethal clear/reward and a real enemy death queued by Ritual
Interference. No pending-corpse fallback was needed. The normal vault retains
its production conditional encounter-placement path; these stills do not prove
every resulting encounter member found a place. The final Breach rerender
completed 18 images. Both native processes exited 0, with zero capture failures,
zero save writes and clean full output through shutdown.

Independent reviewers reopened every final image individually: [world, 27 views](../art/reviews/2026-10-18-objective-world-final-review.md),
[risk/exploration, 24 views](../art/reviews/2026-10-18-objective-risk-final-review.md)
and [Breach, 18 views](../art/reviews/2026-10-18-objective-breach-final-review.md).
All three give a scoped visual go with no remaining blocking finding. Relay's
modest lens difference and Wager's subdued spent caption remain human-recognition
checks. In the reduced Breach spawn frame enemies overlap one another; the
production count is three but three isolated silhouettes are not established
by those pixels.

The first world-packet reviewer had authored Relay/Vigil/Wager earlier in the
task. A fourth reviewer, who authored no production code or art, independently
reopened all 27 final world images and confirmed the scoped visual go; that
cross-review and the authorship disclosure are appended to the world report.
The risk reviewer separately discloses prior contribution to the Rite component.
Neither review is presented as a blinded unfamiliar-player evaluation.

[31 representative unchanged screenshots](../art/reference/2026-10-18-objective-visual-rework/README.md)
cover every staged panel, with original manifests, all 69 image hashes, final
native logs and final focused/script results. Full 69-image sets remain in the
isolated scratch evidence. A capture-only fix expires cosmetic transaction
notices between unrelated panels; genuine current-panel payment/reward notices
remain. The first contaminated image sets and tool-formatting-error run are
preserved separately and are not claimed as passing final evidence.

## Limits

These are frozen, controlled samples in the actual generated Game, terrain,
player, camera and HUD, attempt seed 16102026: S3 for world/Breach views and S2
for the exact seeded exploration/risk route. They establish placement, visible states,
real payout/source samples and render cleanup; they are not human playtesting.
Discovery during movement, dense combat, subjective feel and full-run balance
remain human checks. Grayscale readability was judged from value/shape; separate
grayscale renders and full four-side traversal were not supplied. No broad
combat rebalance was attempted, and this pass does
not resolve the previously recorded occasional 440–500 ms loading stalls.

Original reports and live saves/settings are preserved. The separate designer
chat's newer whole-game concept exploration is separate work; this objective
pass follows the approved review and the current terrain.
