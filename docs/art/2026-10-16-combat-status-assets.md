# Combat status badges and coloured captions

This pass extends the approved elite presentation to 21 implemented combat
states. The user approved the visual review and requested a separate commit
and push. The five existing elite badges and their canonical colours are
retained.

All new badges were generated individually with the built-in ImageGen tool.
Original transparent RGBA PNGs are preserved intact in
`assets/textures/ui/combat_status/`; Godot imports limit runtime textures to
128 pixels. The floating renderer draws a 26-world-pixel badge, approximately
17 screen pixels at default emphasis in the native 1280-wide fight. The
catalogue uses 1.35× callout emphasis for inspection; its persistent Debt
sample keeps the default size. The clipped brass rim and
charcoal inset match the previous modifier set. Exact prompts are preserved in
`assets/textures/ui/combat_status/status-imagegen-prompts.json`.

| ID | Caption | Symbol and palette |
| --- | --- | --- |
| `burn` | BURNING | Orange flame with an ivory hot core |
| `bleed` | BLEEDING | Crimson drops beneath a cutting slash |
| `stun` | STUNNED | Amber broken halo and impact spark |
| `slow` | SLOWED | Icy blue boot and heavy shackle |
| `warded` | WARDED | Turquoise protective arch |
| `haste` | HASTE | Swept emerald wing |
| `fading` | FADING | Dissolving slate-lavender wisp |
| `execution_mark` | MARKED | Red targeting brackets and dagger |
| `wound` | WOUNDED | Crimson heart divided by a cutting gash |
| `cracked` | ARMOUR CRACKED | Broken bronze breastplate |
| `prime` | PRIMED | Pale gold blade and stored-force arc |
| `weak_point` | EXPOSED | Open ivory target and gold centre |
| `fracture` | FRACTURED | Three orange shattered stone chunks |
| `link` | LINKED | Interlocked violet chain links |
| `blood_rite` | BLOOD RITE | Dark rose ritual cup and blood drop |
| `healing_sealed` | HEALING SEALED | Purple heart held by a pale clasp |
| `jam` | JAMMED | Red-orange obstruction across a gun barrel |
| `debt` | DEBT | Violet hourglass holding a gold coin |
| `anchored` | ANCHORED | Pale blue anchor planted on a steel bar |
| `marked` | MARKED | Violet diamond held by crescent brackets |
| `scarred` | SCAR | Coral armour reinforced with ivory stitches |

The two Mark identities have different artwork and colours because their
mechanics come from different systems. Named Hot Rounds shares the Burn
identity. Existing Healing Sealed, Jam, Anchor, Mark and Scar wording is
retained at its authored call site. Red Line keeps its conditional Ward and
Momentum colours while adding the Haste badge.

`CombatStatusIcons` is the shared semantic label/colour/art registry. Single
status messages use their own colour; mixed rows colour each name separately
and keep neutral separators. Authored badge pixels are never tinted by the
caption. Explicit IDs carry this metadata through pooling and reuse.

New application captions use the shared `CombatStatusFeedback` gate:
1.5 seconds per target/effect, at most eight captions per process frame,
and at most 512 cached targets. Off-screen applications and disabled ability
callouts remain quiet. Refreshes and damage ticks do not create repeated
captions; consumed/reapplied effects pass through the same bounded gate.
Debt keeps its existing persistent amount/countdown treatment, with a badge
beside that text rather than a recurring floating message.

This is presentation work. Existing status magnitudes, consumption rules,
durations and expiry behaviour are preserved. Reaction messages and resource
counters keep their existing treatments.

Captured native pages, the live crowded fight, reproduction details and the
verification record are in
`docs/art/reference/2026-10-16-combat-status/`. Catalog pages show staged
production text and artwork; the live clip applies common statuses through
the real gameplay APIs. The user requested seeing the result before any
commit or push.
