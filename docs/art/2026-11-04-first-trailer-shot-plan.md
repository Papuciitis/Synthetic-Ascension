# First gameplay trailer — provisional shot plan, 4 November 2026

Target: 36 seconds. These editorial choices are a proposal under delegated
autonomous work, not a newly approved human vision or a claim that footage exists.
Promise: an inhabited city under horde pressure, with equipment choices changing
how the player fights. Follow [the game vision](../SYNTHETIC_ASCENSION_VISION.md).

## Six shots to collect in the first practical session

| Edit time | Capture and framing | What the cut communicates |
| --- | --- | --- |
| 00–04 | Start on a landed hit in an ordinary street fight; player near centre, attached frontage and an open escape lane visible. Keep several seconds either side. | Immediate combat impact; a place worth exploring, without an empty city sweep. |
| 04–08 | Move through a real passage, enter one home, show the roof cut away, then approach a genuine available pickup. | The city has usable spaces; preserve the actual entrance and visibility rules. |
| 08–14 | Hold a legible item/Manifestation rule in Bag/Run Sheet UI, then make one real equip/merge decision. Keep one causal change, with its name readable. | A decision builds the machine. Do not cut several unrelated cards into a fictitious combination. |
| 14–23 | Return to the same street and enemy family with the same weapon. Show the newly equipped rule's trigger, HUD resource change and resulting attack, twice if readable. | The choice changes the player's movement/attack loop, beyond a larger damage number. |
| 23–32 | Move into one real active objective beat: Ward Vigil, District Relay or Breach Seal, whichever is visually strongest in the captured run. Hold an actual tell, evasive response and impact. | Pressure escalates and the build meets a concrete problem. Completion is optional; never imply it from unrelated cuts. |
| 32–36 | Finish on the clearest earned payoff from that run; cut on impact to the existing game title or plain “Synthetic Ascension” text. | Leave the game's name and the changed build in memory. No invented release date, store status or CTA. |

Candidate for shots 08–23: movement banking Momentum followed by a Manifestation
spending it. Existing rules include [Pilgrim's Momentum](../../effects/manifestations/logic/PilgrimsMomentum.gd)
and [Sunder Wake](../../data/manifestations/ManifestationCatalog.gd); the
[HUD resource owner](../../ui/controllers/HudManifestationController.gd) can expose the change.
This is a source-backed candidate, not verified trailer-ready build footage.
Choose the actual earned item after a short rehearsal; no full multi-rule engine
is assumed ready. If the rule cannot be shown clearly, capture another genuine
rule rather than labelling ordinary weapon damage as its result.

## Capture conditions and editorial controls

- Capture actual 1920×1080 output at the normal overhead player-follow camera,
  normal zoom, 60 Hz physics and `time_scale = 1`; target stable real-time 60 FPS.
  If only stable 30 FPS is possible, record and edit at 30 and disclose it in the take log.
- Record six useful takes, roughly 8–15 seconds each, with live game audio and
  several seconds of handles. Review native frames and a 960×540 downscale for
  player, tells, item text, doorway and resource readability before extending the session.
- Keep ordinary health/damage and ordinary elite rolls. Existing scripted probes
  use god mode/staged rewards; their demonstrations are not normal-run footage.
  Retain source/engine, seed, segment, take times, actual settings and any staging in a take log.
- Record baseline combat before the decision and changed combat after it in the
  same run/location; log the item, rule and other intervening changes. Keep the
  HUD visible for correlation and avoid suggesting that a jump in enemy tier proves build power.
- Use existing [settings](../../core/settings/SettingsSchema.gd): retain ability
  callouts; trial damage numbers off if they obscure bodies. Compare combat flash
  `full`/`reduced` and screen shake on/off once; keep the clearer choice consistent.
  Hit Feel has its own toggle; record its value. UI scale 1.0 is the first pass.
- Capture SFX and UI sounds with Music initially at its existing 0.32 default;
  listen for impacts, pickup and card confirmation, clipped peaks and missing audio.
  Keep music below those cues; do not invent an unverified soundtrack asset.
- Cut on movement, trigger or impact. Hold the decision long enough to read one
  rule; optional editorial text may repeat its actual name. Use straight cuts,
  preserve threat direction, and let one impact sound bridge the build-to-combat cut.

## Existing evidence and gates

The [combined-city originals](reference/2026-10-23-linux-city-combined/README.md)
provide scoped street/interior/collection composition references, not approved
1080p motion footage. The [export-fix originals](reference/2026-10-25-exported-run-fix/README.md)
support readable ancestry/path and three-card UI; use a card insert only if that
actual choice belongs to the filmed build. Do not spend this first trailer explaining every menu.

Ground helper 82/0, map 69/0 and renderer-subset 60/0 checks are data evidence;
the helper/map remain unwired at this plan's authoring and no new Game pixels are accepted.
Fresh normal/small Game review of the target yard, memory headroom, real-time
capture pacing, audio and a genuinely readable before/after build remain gates.
Use [capture readiness](../audits/2026-11-04-trailer-capture-readiness.md) for probe
staging, retained-frame memory and offline clock traps; do not turn guarded 20-FPS
stills into smooth-footage claims. Stop at these six shots; fourteen-district
coverage and a full late-run climax are outside this first capture session.

- HUD framing: keep UI Scale **1.0**. Its [application](../../core/settings/SettingsRuntimeApplier.gd) changes the whole root viewport's content scale; it is not a HUD-only compact setting.
- With [default bindings](../../core/settings/InputActionCatalog.gd), **H** temporarily expands the [Exit Rite checklist](../../ui/controllers/HudGateChecklistController.gd); release it and let its three-second expansion settle. **Tab/I** toggles [inventory/Run Sheet management](../../ui/controllers/HudBagController.gd), which pauses gameplay through [HUD](../../ui/screens/hud.gd). Neither collapses the left equipment/augment dashboard.
- Rehearse genuine equipped, mid-run combat so the dashboard carries the build rather than a blank opening loadout. Log actual gear, preserve the causal before/after rule, and never stage impossible equipment. The newer export-fix capture still shows the dashboard behind its cards; it does not establish a smaller combat HUD.
