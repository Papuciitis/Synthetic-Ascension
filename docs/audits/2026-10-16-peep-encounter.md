# PeeP terminal encounter — 16 October 2026

Status: scoped implementation, independent review correction, 47-assertion GREEN and rendered inspection complete. Quit-submode, related hub/Library checks and the shared 530-script parse audit passed. Human pacing and final audio approval remain open.

## Source and approved direction

The first and repeat dialogue comes from the approved PeeP section of `docs/design/2026-10-16-first-city-story-proposal.md`. The selected unfinished painted style informs the restrained charcoal and rough gold mark. `docs/SYNTHETIC_ASCENSION_VISION.md` and the 16 October first-city entry in `docs/SYNTHETIC_ASCENSION_DIRECTION_AND_ROADMAP.md` govern the early city context and retained/reset boundary.

Later direct user clarification places the protagonist's emotional arc across initial death shock, gradual understanding of return and an eventual enduring burden. Later Syn'Tek ambition and hubris belong to that longer story. This city encounter uses the approved short script; it supplies no creator, mechanism, physical form or late cosmology for PeeP.

The parallel development work supplies the current lasting-development backend and shared preparation screen. Its confirmed interface is `Global.get_city_development_summary()` and `res://ui/screens/CityDevelopmentScreen.tscn`, a `CanvasLayer` with `closed`, `close()` and `refresh()`. The profile stores cumulative chosen improvements and unspent Research; preparation applies to a future attempt. The encounter therefore names “lasting development and unspent Research” among retained categories and distinguishes temporary augment growth from the prepared foundation. It grants no development or Research on death.

## Implementation

- `data/narrative/PeePEncounterData.gd` holds the first conversation, compact repeat, terminal explanation, retained/reset categories, milestone information and break hint. The approved first conversation is immediately present without a timed reveal or required spoken answer.
- `ui/screens/PeePContinuation.gd` renders the durable `Global.pending_peep_summary()` name and segment with ordinary labels. It records `seen:peep_first_conversation` through `StoryDirector` and immediately saves that first presentation, independently of accepting continuation. Reopening the same pending defeat uses the compact conversation; “Read first conversation” expands the original dialogue in place.
- `ui/screens/peep/PeePMargin.gd` draws one static, uneven gold page corner with a displaced charcoal shadow that closes its open edge. It uses native drawing, no portrait, animation or physical-location claim. The same still arrangement serves Reduced Motion. The existing dry UI click accompanies arrival.
- `PREPARE NEXT ATTEMPT` instantiates the shared `CityDevelopmentScreen` under PeeP. Its close signal returns focus to the invoking button. Parent cancel handling and terminal actions defer while this overlay exists; the shared overlay owns its input and spending rules. Preparation can be inspected with zero Research.
- Reading focus supports incremental Up/Down and Page Up/Page Down scrolling. Tab goes directly to the continuation action. The action focus cycle also includes preparation and, on repeats, the first-conversation disclosure. Labels retain readable font sizes at 640×480 and use scrolling for overflow.
- Existing acceptance, menu, quit and repeated-input guards remain in the encounter. Acceptance alone calls `Global.accept_peep_continuation()` and routes to the fresh attempt. Menu, quit and cancel preserve the unresolved decision. The seen flag uses existing story memory; this presentation adds no save-schema field.

The retained information covers Library/discoveries, story history, augment ownership and equipped preferences, Stash equipment, Method/Doctrine/Apotheosis commitments, lasting development and unspent Research. Reset information covers carried gear/bag, Followers/Congregation, purchased tree powers, temporary augment growth, mutations, Transcendence, Duos, Facets, corruptions and world/checkpoint/pressure state. Commitment effects return after completed Segments 3, 6 and 9.

## Verification evidence

Observed RED: `PeePContinuationUiTest` reported **19 passed, 15 failed**, exit **1**, before the production changes. These were ordinary assertion failures for missing first/repeat dialogue, durable seen memory, disclosure, full consequences, preparation and keyboard reading. Log: `docs/audits/evidence/2026-10-16-opening-peep-lore/PeePContinuationUiTest-red.log`.

The focused fixture is `tools/tests/PeePContinuationUiTest.gd` / `tools/tests/PeePContinuationUiTest.tscn`. It uses an isolated profile and real input for scrolling, disclosure, preparation close, menu and acceptance. It checks the entire pending snapshot, run count and navigation count across preparation/disclosure, plus single acceptance and retained pending state. The `--peep-quit-check` submode exercises the actual quit button with isolated durable-save assertions.

Corrected GREEN: **47 passed, 0 failed, exit 0**, with no script/runtime diagnostics. Quit submode passed **7/0**, exit **0**, including durable pending facts on isolated disk. Related hub/Library suites passed and the shared parse audit passed **530/0**, exit **0**; all eleven narrative production hashes match its source manifest. Independent scoped review found the replay reading issue described below; its correction passed the actual-input regression. Source diff whitespace check: clean when source was handed to the parent; this is not engine verification.

The initial read-only review identified one concrete issue: expanding the first-conversation disclosure kept focus on the toggle, so its action-only focus loop could skip the expanded words. The guarded 640×480 regression opens the disclosure through real Enter input and checks incremental Down, Page Down and controller D-pad reading, followed by Tab to the visible decision. Its observed review RED reported **43 passed, 4 failed**, exit **1**, with exactly those four reading/return-path assertions failing; the first/repeat, durable memory, preparation and continuation-lifecycle checks passed. Log: `docs/audits/evidence/2026-10-16-opening-peep-lore/PeePContinuationUiTest-review-red.log`. The scoped correction now transfers focus to the reading container and positions the expanded conversation's opening words at its top after layout. Tab uses the existing direct return to the continuation action. Corrected GREEN passed all **47 assertions**, exit **0**.

`tools/dev/PeePContinuationPreview.gd` / `tools/dev/PeePContinuationPreview.tscn` targets these actual-render fixtures in `docs/art/reference/2026-10-16-peep-encounter/`:

- `first-1280x720.png`
- `first-640x480.png`
- `repeat-1280x720.png`
- `repeat-reduced-960x540.png`
- `first-replay-960x540.png`

Each overflowing fixture also writes its matching `-actions.png` view and checks that Quit is within the captured viewport after scrolling. The driver constructs fresh `SaveData` fixtures in a unique `user://peep_preview_…/` directory and does not load a human profile. All **ten PNGs were generated and visually inspected**, exit **0**, with no errors. They show readable full/small/reduced pages, a replay beginning at its opening words and reachable actions.

## Remaining limits

Rendered QA established the page corner and shadow's visibility, text layout and action/disclosure bounds at the target sizes. Automated pending-state checks do not establish emotional pacing, a human's reading comfort or the final audible click mix. Shared development behavior remains owned and verified by the parallel development work; final verification must use its settled source. Ordinary reconstruction, successful escape, terminal-defeat creation and continuation persistence remain backend lifecycle responsibilities; this change consumes their existing pending boundary.
