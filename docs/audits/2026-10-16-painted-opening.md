# Unfinished painted opening

16 October 2026. Implementation, focused verification and rendered inspection are complete. The user approved the opening writing and selected the unfinished painted concept as the base for all shots. PeeP and the eight documents follow as separate changes; cumulative permanent development belongs to the balance chat.

## What changed

Four optional stills accompany existing opening phases: service entrance, admissions desk, completed synthesis and records-conduit departure. The existing player actions and phase numbers remain authoritative. Full mode uses all four, short mode uses a synthesis crop, skip uses none, and phase resume bypasses earlier groups. The three approved text additions live in OpeningSequenceData.

OpeningPresentation loads a single image on demand, keeps it across successive cards and releases it before world play. Unknown images fall back to text. AtlasTexture supplies reused crops. A version guard prevents an old clear from removing a later image, including selecting the same image again.

Cards now constrain width and use vertical scrolling at small sizes. Reading focus supports incremental arrows and page keys before moving to choices. Shared PauseMenu owns input/focus while open; intentionally paused hub story cards remain usable. Blocking cards hide the world guidance prompt, and existing controller guidance restores it when walking resumes.

The illustrated layer uses crossfades and static painted compositions. Existing sound cues remain stand-ins; this change does not claim that the proposed shift bell, contact recording or conduit knock are final audio assets.

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

## Review decisions

Runtime keyboard reading is checked by real input events and refreshed production captures; the read-only reviewer did not launch an engine. If wrong, a keyboard reader could miss the middle of a long card.

The existing admission prompt is hidden during blocking story cards and restored by the controller's walking guidance. If wrong, walking could resume without its hint; the final fixture includes the live prompt before opening the notice.

## Remaining checks

The shared final gameplay parse sweep passed 530/0, exit 0, with no diagnostics. All eleven narrative production source hashes match both the focused GREEN snapshot and the shared audit manifest. The shared runtime-safety suite passed 21/0, exit 0. Exact shared evidence is in `docs/audits/evidence/2026-10-16-city-development/shared-script-parse.json`, `shared-runtime-safety.json` and their logs; this avoids repeating the broad checks. Human playtesting remains necessary for pacing, reading comfort and the handoff back to combat. Those checks do not require a change to the agreed story direction.
