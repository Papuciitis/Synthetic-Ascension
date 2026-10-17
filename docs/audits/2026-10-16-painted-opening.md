# Unfinished painted opening

16 October 2026. Implementation, focused verification and rendered inspection are complete. The user approved the opening writing and selected the unfinished painted concept as the base for all shots. PeeP and the eight documents follow as separate changes; cumulative permanent development belongs to the balance chat.

## What changed

Four optional stills accompany existing opening phases: service entrance, admissions desk, completed synthesis and records-conduit departure. The existing player actions and phase numbers remain authoritative. Full mode uses all four, short mode uses a synthesis crop, skip uses none, and phase resume bypasses earlier groups. The three approved text additions live in OpeningSequenceData.

OpeningPresentation loads a single image on demand, keeps it across successive cards and releases it before world play. Unknown images fall back to text. AtlasTexture supplies reused crops. A version guard prevents an old clear from removing a later image, including selecting the same image again.

Cards now constrain width and use vertical scrolling at small sizes. Reading focus supports incremental arrows and page keys before moving to choices. Shared PauseMenu owns input/focus while open; intentionally paused hub story cards remain usable. Blocking cards hide the world guidance prompt, and existing controller guidance restores it when walking resumes.

The illustrated layer uses static painted compositions. Its transitions are described under "Painted transitions" below. Existing sound cues remain stand-ins; this change does not claim that the proposed shift bell, contact recording or conduit knock are final audio assets.

## Art and scope

The four PNGs are in `assets/textures/story/opening/`. [Art source record](../../assets/textures/story/opening/README.md) preserves the built-in image tool prompts and selected style reference. The economical unfinished treatment and anonymous silhouettes do not establish definitive character portraits.

The player still aligns all three nodes in full mode, calibrates, confronts the construct and deliberately resists seizure. The officer's arrest order precedes lethal escalation. Bren preserves the original sequences and follows the work. No new save fields, phases, combat rewards or permanent-stat rules are introduced by the opening.

## Verification record

- Baseline TutorialTypewriterTest: 17 passed, 0 failed, exit 0.
- Initial illustration regression: RED 0/1, exit 1, specifically missing illustration support; GREEN 17/0, exit 0.
- Same-image clear race: RED 18/1, exit 1; GREEN 19/0, exit 0.
- Independent review identified keyboard reading that skipped text. Actual-input/prompt regressions reproduced three failures (19/3, exit 1). The correction passed all 22 assertions, exit 0.
- Refreshed production captures completed with exit 0 and no layout failures. All nine were visually inspected. The fixture calls public presentation methods, including the actual captions and action labels; the admission capture opens its notice over an existing guidance prompt and confirms the prompt is hidden.
- Related suite results are recorded in the verification table below as they complete. Engine jobs use isolated/no-profile fixtures and are coordinated through `.godot/engine-test-slot.json` while host memory is tight. The human editor is preserved.

| Suite | Passing / failed | Exit | Diagnostics |
|---|---:|---:|---|
| OpeningIllustrationTest, final review correction | 22 / 0 | 0 | None |
| TutorialTypewriterTest | 17 / 0 | 0 | None |
| TutorialGuidanceTest | 21 / 0 | 0 | None |
| Segment1ProgressionTest | 40 / 0 | 0 | None |
| OpeningSequencePhysicsSafetyTest | 5 / 0 | 0 | None |
| StoryDirectorTest | 166 / 0 | 0 | None |
| SaveMigrationMatrixTest | 34 / 0 | 0 | One intentional newer-save-version warning; best-effort loading assertion passed |
| PauseMenuFlowTest | 38 / 0 | 0 | None |

## Painted transitions (17 October 2026)

The stills were said to crossfade, but a new still replaced the texture at once and faded in from transparent, and a clear was a 0.2 s fade. The opening never shows two stills in a row: between any two, it clears the first and plays world beats. So what the player sees is each still painting in over the world and washing back out to it. The stills now move the way they were painted:

- **Paint-in.** A still arrives in broad slanted strokes washing in from the left, each with a warm wet rim while it lands (0.75 s). The stroke pattern is seamless smooth noise, made once per run the first time a still is shown. The rect's own pixels place it, so an AtlasTexture crop washes in the same way.
- **Wash-out.** Clearing runs the paint-in backwards (0.55 s) and awaits it as before.
- **Crossfade, for a direct change of still.** If a still is shown while another is up, the one showing stays beneath, exactly as it was, while the next paints over it (0.95 s), and is released once covered; a third still arriving mid-crossfade keeps the more painted one beneath. The current opening never takes this path; it is there for any sequence that shows stills back to back.
- **Drift.** While read, each still pushes in slowly (to 104% over 20 s, easing out) toward its painting's focal point: the worker's meal tin, the badge and stamp, the central node, the packet and bracing hand.
- **Reduced Motion.** Every transition is immediate and there is no push-in; turned on while a still is read, the push-in stops where it is.
- **Real time.** Transitions run on real time, so the cards' slowed `Engine.time_scale` cannot stretch them.

The existing contracts hold: a still kept across consecutive cards, the version guard against an old clear, release before world play, and quiet fallback for unknown art. `OpeningIllustrationTest` grew from 22 to 41 checks: paint-in, crossfade with both stills present and the lower one released, wash-out awaited by the caller, push-in, Reduced Motion (also turned on while a still is read), a third still mid-crossfade, and the stroke pattern made once per run (none after a presentation is built, the same texture in every presentation). `TutorialTypewriterTest` 19/0, `TutorialGuidanceTest` 21/0, `Segment1ProgressionTest` 42/0, `OpeningSequencePhysicsSafetyTest`, `StoryDirectorTest`, `PauseMenuFlowTest` and `SaveMigrationMatrixTest` all pass.

`tools/dev/OpeningTransitionPreview.tscn` renders real UI pixels at 1280×720 with each transition frozen at set points: paint-in, the wash-out state, and the direct crossfades from city to admission and from synthesis to records (a path the current opening does not take). The frames are in [2026-10-17-opening-transitions](../art/reference/2026-10-17-opening-transitions/). The first pattern used many small dashes and read as rain; the stroke scale was broadened until the transitions read as the paintings' own broad brushwork. These are still frames: the motion's timing and feel need a human look in the running opening.

## Review decisions

Runtime keyboard reading is checked by real input events and refreshed production captures; the read-only reviewer did not launch an engine. If wrong, a keyboard reader could miss the middle of a long card.

The existing admission prompt is hidden during blocking story cards and restored by the controller's walking guidance. If wrong, walking could resume without its hint; the final fixture includes the live prompt before opening the notice.

## Remaining checks

The shared final gameplay parse sweep passed 530/0, exit 0, with no diagnostics. All eleven narrative production source hashes match both the focused GREEN snapshot and the shared audit manifest. The shared runtime-safety suite passed 21/0, exit 0. Exact shared evidence is in `docs/audits/evidence/2026-10-16-city-development/shared-script-parse.json`, `shared-runtime-safety.json` and their logs; this avoids repeating the broad checks. Human playtesting remains necessary for pacing, reading comfort and the handoff back to combat. Those checks do not require a change to the agreed story direction.
