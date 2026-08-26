# Exit Rite Safeguards Design

## Problem

The Exit Rite is correctly allowed to become the densest fight in a segment, but its current progress loss and wave rewind turn a difficult late-segment hold into a repetition trap. Segment 2 is especially punishing because leaving or dying can re-arm pressure the player already survived. Segment 3 can feel easier because its live spawn composition differs, but spawn caps or segment-specific population clamps would hide rather than solve the Rite's fairness problem.

## Design Goal

Keep the full horde and the 20-second siege, while making earned progress durable and exploration produce concrete emergency tools. The result should reward preparation, preserve pressure, and make defeat feel attributable to tactical choices rather than repeated scripted waves.

## Core Rules

- The Rite seals progress at 33%, 66%, and 100% of `hold_time`.
- Progress may drain only to the latest sealed threshold. A death applies the existing `death_progress_kept` loss, then clamps to the same floor.
- Each scripted `BURST_STAGES` wave fires at most once per Rite instance. Progress loss and death never decrement `_burst_stage`.
- Crossing a seal triggers one automatic pulse:
  - First seal: 420 px radius, 650 force, 0.15 s stun, heal 15% of missing HP.
  - Second seal: 500 px radius, 850 force, 0.35 s stun, heal 25% of missing HP.
  - Final seal: 620 px radius, 1,100 force, 0.60 s stun, heal 35% of missing HP and grant 5.0 s invulnerability.
- The existing per-second channel healing remains unchanged.
- The final seal completes the Rite only after its pulse and admission protection have been applied.

## Exploration Safeguards

- Attuning one Wardstone grants one segment-local safeguard charge.
- Completing one unique secondary objective grants one segment-local safeguard charge.
- Duplicate source IDs do not grant twice. The carried charge cap is three.
- Sources completed before the Rite is instantiated are replayed into it when it becomes available.
- Charges reset on segment transition. The game currently saves at safe inter-segment points rather than reconstructing a procedural segment mid-combat, so no profile schema change is required.
- While the player is inside an unlocked, incomplete Rite, pressing `interact` consumes one charge and triggers a manual pulse: 420 px radius, 700 force, 0.20 s stun, and healing equal to 10% of missing HP.
- Manual pulses do not advance channel progress, spend scripted waves, or create an invulnerability window.
- A failed consume—locked Rite, player outside, zero charges, completed Rite—does nothing and does not eat input.

## Presentation

- Three physical glyphs orbit the Rite. Filled glyphs show sealed thirds; a brighter inner pip count shows carried safeguards.
- A short contextual prompt appears only while the player is inside an unlocked Rite and has at least one charge: `[Interact] Invoke safeguard · N`.
- Pulse feedback is an expanding ochre/ivory ritual ring with weight and dust, not a blue electronic shockwave.
- No new persistent HUD panel is added.

## Architecture

- `ExitRite` owns channel state, sealed progress, charge state, input eligibility, and presentation state.
- `RitePulseResolver` owns proxy-safe enemy gathering, knockback, stun, and player healing/protection. It uses the existing `EnemyCombat` autoload.
- `SegmentProcBuilder` translates unique Wardstone/secondary completions into stable source keys and grants them to the Rite.
- `HudEvacOverlayController` displays only the contextual safeguard prompt using state exposed by the Rite.

## Non-Goals

- Do not lower spawn rate, burst counts, Threat, or population by segment.
- Do not clear all enemies, freeze combat, or make the Rite safe after the first seal.
- Do not add secondary-type specializations in this pass.
- Do not persist mid-Rite progress across application restarts.

## Acceptance Criteria

- Draining from 80% stops at 66%; dying from 80% also stops at 66% when the configured percentage would fall below it.
- A scripted wave cannot fire twice after any drain/death sequence.
- Each automatic seal fires exactly one pulse with the specified force, stun, heal, and final protection values.
- Wardstone and secondary source keys are deduplicated; charges never exceed three.
- Manual safeguard input works only inside an unlocked Rite, consumes exactly one charge, and uses `EnemyCombat` for both materialized and data-only enemies.
- The Rite remains a 20-second siege with all current burst counts and spawn pressure intact.
