# Painted opening implementation plan

> **For agentic workers:** Use superpowers:executing-plans to implement task by task, with one independent review before completion.

**Goal:** Implement the approved four-still opening in the selected unfinished painted style, preserving the playable opening and saved modes.

**Architecture:** OpeningSequenceData owns text and optional texture paths. OpeningPresentation owns a reusable illustration layer and a bounded scrolling card. OpeningSequenceController selects and clears illustrations around its current card groups without adding phases or save fields.

**Tech Stack:** Godot 4.7, GDScript, PNG textures, current UI theme and accessibility helpers.

**Spec:** docs/design/2026-10-16-first-city-story-proposal.md and docs/design/2026-10-16-first-city-representative-scene.md. The user approved implementation on 16 October 2026. Opening ships first; PeeP and optional documents follow separately. New permanent augment growth is a suggestion for the balance chat, not part of this change.

## Global constraints

- Preserve mortal researcher, Bren's role, deliberate synthesis and resistance, arrest before lethal response, original sequences and first Follower.
- Preserve full, short, skip, replay and current phase resume; no phase renumbering or new progression rewards.
- Use the unfinished painted concept as the style reference for every image.
- Maintain readable text and usable controls at 640 by 480, with current typewriter and reduced-motion settings.
- Missing art falls back to text. No static cache of all images and no processing images each frame.
- Preserve unrelated shared-worktree changes. Use isolated test saves. The user has confirmed no human playtest and permitted checks; never stop another chat's engine process.

## Review focus

1. Art must clear before player movement/combat; consecutive cards retain the same image.
2. Long text and four choices must remain readable and focusable at 640 by 480.
3. Shared PauseMenu must own input/focus when open; intentionally paused hub dialogue must still work.
4. Missing/unknown image and interrupted fade must not hide later cards or leave stale art.
5. Resuming at Calibration or Separation must not replay earlier illustrated phases; short/skip must keep equivalent progress.

## Task 1 Presentation and approved content

**Files:** assets/textures/story/opening/{city,admission,synthesis,records}.png; data/narrative/OpeningSequenceData.gd; ui/screens/opening/OpeningPresentation.gd; core/systems/world/opening/OpeningSequenceController.gd; tools/tests/OpeningIllustrationTest.{gd,tscn}.

**Interfaces:** `show_illustration(id: StringName, crop: Rect2 = Rect2()) -> bool` selects an optional image. `clear_illustration(duration: float = 0.2) -> void` releases it after a bounded fade. Existing present methods and phase state stay compatible.

- [x] Write regression tests for image show/retain/clear/missing fallback, small card bounds/focused choices, reveal input and shared pause ownership. Confirm failure because illustration support is missing.
- [x] Save the approved synthesis image and three style-matched new images under the listed paths. Keep prompts and provenance in the art record.
- [x] Add approved historical sentence, Bren preservation line and conduit line to OpeningSequenceData.
- [x] Implement the image layer and responsive scrolling card while retaining existing styles and public card methods.
- [x] Integrate city/admission/synthesis/records at current full phases, synthesis-only in short, none in skip. Clear before returning to world actions.
- [x] Run new regression plus TutorialTypewriterTest, TutorialGuidanceTest, Segment1ProgressionTest, OpeningSequencePhysicsSafetyTest, StoryDirectorTest, SaveMigrationMatrixTest and PauseMenuFlowTest. Script-based suites use --script; scene suites use their .tscn.

## Task 2 Render verify and ship opening

**Files:** tools/dev/OpeningIllustrationPreview.{gd,tscn}; docs/art/reference/2026-10-16-painted-opening/; OPENING_SEQUENCE.md; docs/audits/2026-10-16-painted-opening.md; latest roadmap status entry.

**Interfaces:** The capture fixture instantiates the real OpeningPresentation and selects images through Task 1's methods. It uses throwaway saves and an offscreen rendering window.

- [x] Capture four shots at 1280 by 720, plus 640 by 480 long text/choices/action views and reduced motion. Inspect actual pixels; fix clipping/contrast or art occlusion.
- [x] Independently review scoped changes against the approved writing, five review conditions and existing save/input contracts. Correct material findings with targeted regression coverage.
- [x] Run affected suites after material fixes, then ScriptParseAuditTest last. Record assertion counts, process exits, diagnostics and visual evidence.
- [x] Update documentation with actual behaviour and remaining human pacing checks.
- [x] Stage only this task's exact files, commit and push to the existing branch as previously requested.

## Progress ledger

- Planning: approved writing and unfinished style are the authority. Existing linked worktree verified; unrelated changes preserved.
- Preflight: presentation/controller share the two explicit illustration methods; no save interface changes. Hub story also uses this presentation and can intentionally pause the tree.

- Delivery: opening committed first, PeeP next, with the final lore/evidence/status commit and branch push completing the agreed sequence. Final shared import and530-script audit passed; narrative production sources unchanged.
