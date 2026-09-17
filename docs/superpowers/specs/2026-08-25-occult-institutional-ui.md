# Occult-Institutional UI Consistency Specification

## Intent

Synthetic Ascension presents reverse-engineered magic and divinity as dangerous institutional engineering. Its interface should feel like a research instrument, ritual ledger, or containment protocol: physical, angular, warm, and deliberate. It must not resemble neon cyberpunk, holographic hacker tooling, or rounded consumer software.

## Visual language

- IBM Plex Sans Condensed remains the readable body face.
- Alegreya SC is the institutional register for menus, ordinary objectives, dossiers, and section headings.
- Marcellus SC is reserved for sacred/systemic events: Exit Rites, manifestations, bosses, and ascension language.
- Surfaces use warm charcoal rather than pure black, 1-2 px desaturated brass/copper rules, 2-4 px corners, small shadows, and restrained orange focus accents.
- Rounded 10-18 px cards and buttons in the pictured menus are replaced with the same angular construction used by the HUD.
- Orange indicates focus, selection, or an active rite. It is not the default border on every surface.

## Objective ownership

Before the primary objective is complete, the ordinary objective panel owns the current task and the Exit Rite checklist remains absent or empty. After completion, the ordinary objective channel is cleared and the Exit Rite checklist becomes the sole owner of gate requirements and readiness. The evacuation banner remains the sole owner of the live evacuation timer.

This prevents `EXIT RITE - READY` and `EXIT RITE / READY / 2/2` from appearing simultaneously.

## First encounters

Enemy discoveries use a non-modal in-world recognition beat rather than the blocking tutorial card.

1. When a previously undiscovered archetype is eligible to be introduced, gameplay freezes for 0.8 seconds without a blackout or Continue button.
2. A compact `FIRST ENCOUNTER` card appears near the target and a copper ritual tether identifies the actual enemy.
3. The card contains the enemy name, role/threat classification, one actionable counter, and an archive notice. It does not repeat the full lore paragraph.
4. Gameplay resumes automatically. The card and tether remain readable for approximately five more seconds, then retract.
5. If the enemy dies or leaves the viewport, the tether retains or clamps its last readable endpoint and the card completes normally.
6. Multiple discoveries queue and never overlap. Encounters wait during management pause, bosses, and Exit Rite channeling.
7. The complete quote, behaviour, expectation, and counter remain available from the Run Sheet as archived observations.

Blocking narrative/tutorial records continue to use the existing modal path, but inherit the shared typography and angular surface language.

## Management-mode clarity

Opening the bag establishes a deliberate analysis layer:

- the world receives a stronger dim treatment;
- Top Left telemetry, Run Sheet, and Bag are raised above that dim layer;
- combat objectives remain hidden while management is open;
- panel backgrounds become more opaque and small labels gain stronger contrast;
- the three management surfaces align to the existing left/right grid and retain their current interaction behavior.

## Pictured menu scope

This pass updates Main Menu, Save Select, Save Cards, the blocking tutorial modal, Top Left HUD, Bag, Run Sheet, and objective/gate surfaces. It does not replace the title illustration, world art, enemy placeholder sprites, or other unfinished game assets.

## Accessibility and safety

- The recognition beat restores the exact previous pause state and never unpauses a game it did not pause.
- No encounter requires reading during the 0.8 second freeze; the compact card persists after play resumes.
- Text remains legible at 1080p and card placement is clamped inside viewport margins.
- Existing remappable HUD detail controls remain unchanged.
