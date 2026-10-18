# Ability and objective presentation — 18 October 2026

Implemented and verified for human playtesting. Deadshot and Judgment now
have distinct preparation, accepted lanes, release and aftermath presentation.
Wardstones, Exit Rites, District Relay, Ward Vigil, Breach Seal and Wager Shrine
have original painted world forms and visible state identities. No damage,
cooldown, aim selection, capture/hold duration, collision radius, wave count,
Resonance, checkpoint, safeguard or reward rule was retuned.

## Presentation

- Deadshot uses a converging brass sight, the actual narrow beam lanes, a
  painted release confined to those lanes and a brief residue. Twin Shot,
  Fan and Wallbang previews include every accepted path and its real width.
- Judgment distinguishes placed wide lanes from the release and aftermath.
  The centre seal stays at the player; One Line, Back and Forth, Recalculate,
  Kill Line, Smart Grid and Firing Squad use the same Precision painter.
- One painter per Precision engine retains at most 18 release records.
  It has no damage, time-slow or cooldown authority. It pauses with the
  encounter, expires its last visual, clears on death even after the tree
  pauses, and is removed when its engine is replaced or its runner leaves.
  Texture dependencies are preloaded; drawing performs no image file load.
- Six distinct prop silhouettes use charcoal stone, worn brass and ivory.
  State treatment distinguishes dormant, working, draining, completed and
  spent forms. Sealed Breach fissures become teal even at gameplay
  minification. Persistent completion checks accompany the colour change.
- Ground boundaries retain the actual radii. The Relay now shows its real
  attunement radius rather than the smaller decorative circle. The
  Wardstone's sanctuary drawing follows the same modified radius as its
  field shape. Exit Rite progress, durable thirds and safeguard pips remain.
- Reduced Motion holds decorative motion still. Combat Flashes Off removes
  the bright release overlay while preserving essential lanes, progress and
  state marks. Wardstone idle/attune, gate unlock and Rite pulse effects now
  follow those preferences as well.

The seven PNGs were generated through the built-in image tool, inspected and
copied into `assets/world/objectives/painted/`. Their alpha is preserved;
Godot imports use a 512-pixel limit and mipmaps. Exact prompts and source
filenames are in [the asset provenance](../../assets/world/objectives/painted/PROVENANCE.md).

## Verification

All processes used the native Godot 4.7.1 executable. Both `APPDATA` and
`LOCALAPPDATA` pointed inside this task's isolated `userdata/` directories.
The native process objects' actual exit codes were checked; timeout-driven
or console-wrapper success was not accepted as a passing test.

| Suite | Passed | Failed |
| --- | ---: | ---: |
| ObjectivePresentationTest | 19 | 0 |
| PrecisionPresentationTest | 14 | 0 |
| AscensionPrecisionTest | 47 | 0 |
| AscensionPrecisionV5Test | 45 | 0 |
| PrimaryObjectiveTest | 236 | 0 |
| ExitRiteTest | 58 | 0 |
| RiteSafeguardPresentationTest | 7 | 0 |
| RiteClimaxTest | 65 | 0 |
| **Total** | **491** | **0** |

Every suite exited 0. The safeguard presentation fixture deliberately parks
ThreatDirector and produces its existing missing-director warning. No other
test error or unexpected warning was accepted. The objective identity checks
were first observed RED against the old presentation: two unchanged geometry
checks passed and seven missing-identity checks failed with exit 1.

The new integration checks cover identity selection, restored/completed state
changes, original collision geometry, all ten Twin/Fan paths, Wallbang and
Judgment widths, fixed capacity, expiry, pause, paused-death cleanup, engine
replacement and retained essential geometry under Reduced Motion/flashes off.
The existing gameplay suites separately verify the original hit amounts,
Deadshot mutations, Judgment delays, objective completion, spawns and Rite
rules. The shared final script audit remains part of the parent delivery's
integration checks.

## Native evidence and limits

`AbilityObjectiveGamePreview.tscn` produced **36 final captures**, native
exit 0, no rendering/script errors and **zero save writes**, on the Intel UHD
OpenGL compatibility driver. These use the actual generated Segment 3 Game
terrain, player, camera and HUD, seed 16102026, with frozen staged samples.
Each of twelve panels was captured at 1280×720, 960×540, and 960×540 with
Reduced Motion enabled plus Combat Flashes Off. Deadshot release is sampled
at 45 ms, Judgment release at 55 ms, and aftermath at 220 ms of the existing
340 ms cosmetic lifetime. Gameplay attack clocks are unchanged.

Twelve reviewed examples are published in
[`docs/art/reference/2026-10-18-abilities-objectives/`](../art/reference/2026-10-18-abilities-objectives/),
which has a `.gdignore` so documentation images do not become game assets:

- [Wardstone and Exit Rite states](../art/reference/2026-10-18-abilities-objectives/sanctuary-normal.png)
- [Relay, small window](../art/reference/2026-10-18-abilities-objectives/relay-small.png)
- [Vigil, Reduced Motion](../art/reference/2026-10-18-abilities-objectives/vigil-reduced.png)
- [Open, sealing and sealed Breaches](../art/reference/2026-10-18-abilities-objectives/breach-normal.png)
- [Raised and settled Wager Shrine](../art/reference/2026-10-18-abilities-objectives/wager-small.png)
- [Deadshot aim](../art/reference/2026-10-18-abilities-objectives/deadshot-aim-normal.png),
  [release peak](../art/reference/2026-10-18-abilities-objectives/deadshot-release-normal.png),
  [aftermath](../art/reference/2026-10-18-abilities-objectives/deadshot-aftermath-small.png),
  [Twin/Fan/Wallbang with Reduced Motion](../art/reference/2026-10-18-abilities-objectives/deadshot-twin-fan-reduced.png)
- [Judgment plots](../art/reference/2026-10-18-abilities-objectives/judgment-plots-normal.png),
  [release peak](../art/reference/2026-10-18-abilities-objectives/judgment-release-normal.png),
  [aftermath with Reduced Motion](../art/reference/2026-10-18-abilities-objectives/judgment-aftermath-reduced.png)

[Focused logs and the final native capture log](evidence/2026-10-18-abilities-objectives/) are committed. Full local captures, logs and run metadata are under
`.superpowers/sdd/2026-10-18-playtest-feedback/abilities-objectives/`.
[The verification JSON](2026-10-18-abilities-objectives-verification.json)
records suite results, source hashes and the published evidence subset.

These are staged visual integration controls with an immortal, frozen player,
not a played fight, collision-clearance certificate or human readability
approval. Busy-fight warning visibility, subjective impact and full-run pacing
still need human playtesting. The fixed painter capacity is verified; no
whole-game performance gain is claimed for this visual pass.
