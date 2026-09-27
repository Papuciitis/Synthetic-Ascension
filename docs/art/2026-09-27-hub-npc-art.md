# Hub NPCs — art request (2026-09-27)

People for the market square: four service NPCs at the stations, a smith at
the forge, a crowd of the movement's supporters (how many depends on the
player's Followers), and more poses for Beka, who now lives in the hub.

Until a piece lands the game shows a stand-in, so any subset can arrive in
any order. Drop the PNGs in the repo root as before; Claude files them under
`incoming/hub/`, bakes them to size and wires them in.

## Style block (paste at the top of every prompt)

Same as the square's art, so the people match the stalls and houses:

> Detailed pixel-art game sprite for a top-down 2D action RPG, matching an
> existing set of market-square props. Camera is top-down three-quarter
> view: looking down at about 45 degrees. Clean pixel art with a near-black
> outline (#140E0C) around every solid shape, 4 to 5 flat shading tones per
> material, light from the top left. Warm, muted medieval palette: undyed
> wool, oak and leather browns, soot greys, faded indigo and moss green,
> small brass and gold accents. Paint in NEUTRAL evening colours, not
> night: the game adds its own dusk tint and lights. Fully transparent
> background (real alpha, not white, not a checkerboard), the figure
> centred, feet at the bottom, nothing else in the frame: no ground, no
> cast shadow, no text, no watermark, no border.

**Who these people are.** Ordinary people of an old institutional city who
chose to follow the Pattern, a new kind of magic, over the institution that
banned it: labourers, clerks, carriers, scribes. They are not soldiers, not
cultists in masks, not sci-fi. Grounded and restrained. The movement's only
shared sign is a small gold pin or stitched badge shaped like a branching
tree (the rune on the obelisk); give every person one somewhere small.

**Scale.** The player is about 77 px tall on screen. Adults should read
about the same, 72 to 84 px. Generate large (1024 px or more tall); the bake
scales them down.

## 1. Service NPCs (one standing pose each)

One image per NPC, a single full-body standing pose facing the viewer
(front three-quarter), arms relaxed or holding their thing. The game adds a
slow breathing bob. The Exchanger, Quartermaster and Chronicler stand
behind their stall counters, so their lower legs will be hidden; still draw
the full figure.

| # | File | Who |
|---|---|---|
| N1 | `hub_npc_exchanger.png` | the merchant |
| N2 | `hub_npc_quartermaster.png` | at Gear & Stash |
| N3 | `hub_npc_chronicler.png` | at the Quiet Alcove |
| N4 | `hub_npc_acolyte.png` | at the Ascension obelisk |
| N5 | `hub_npc_smith.png` | at the forge (ambient) |

**N1 — the Exchanger.** A lean middle-aged trader in a long faded-indigo
coat over a wool waistcoat, a leather satchel of ledgers at the hip, fingerless
gloves, a pencil behind one ear, holding a small open ledger. Watchful,
unsmiling, tidy.

**N2 — the Quartermaster.** A broad, older former porter in a heavy canvas
apron over a moss-green tunic, rolled sleeves, a coil of leather straps over
one shoulder and a tally board in hand. Grey stubble, steady.

**N3 — the Chronicler.** A young scribe in an undyed wool robe with
ink-stained cuffs, a scarf, round spectacles, holding a thick book against
the chest, a quill tucked in the book. Quiet, attentive.

**N4 — the Acolyte.** A figure in a deep hooded robe of dark indigo with a
gold branching-tree rune stitched on the chest, face half-shadowed under the
hood but kind, holding a small brass lantern low in both hands.

**N5 — the smith.** A stocky smith in a scorched leather apron, bare
forearms, a hammer resting on one shoulder, soot on the face, a thick wrap
around one wrist. Tired but warm.

## 2. The crowd (three views each)

The supporters walk around the square, so each one needs to face every way.
One image per person with THREE poses side by side in equal cells, same
person, same size, feet on the same line:

1. front (walking toward the viewer),
2. back (walking away),
3. side, facing RIGHT (the game mirrors it for left).

Each pose mid-stride is ideal but a standing pose is fine; the game adds a
walking bob. The three cells must be evenly spaced (the bake re-aligns them
if they are not, as with the brazier).

| # | File | Who |
|---|---|---|
| C1 | `hub_crowd_pilgrim.png` | hooded traveller with a walking staff and bedroll |
| C2 | `hub_crowd_labourer.png` | dock labourer carrying a sack on one shoulder |
| C3 | `hub_crowd_washer.png` | woman in a shawl and apron with a laundry basket on the hip |
| C4 | `hub_crowd_elder.png` | old man in a patched coat with a cane |
| C5 | `hub_crowd_courier.png` | young courier with a satchel and a cap |
| C6 | `hub_crowd_clerk.png` | ex-institution clerk in a plain grey uniform coat, badge torn off, the tree pin in its place |
| C7 | `hub_crowd_baker.png` | baker with flour on the apron, a tray of bread |
| C8 | `hub_crowd_mender.png` | woman in a headscarf with a toolbag and a lamp |

Vary skin tones, ages and builds across the eight. No children.

## 3. Beka (more poses)

Beka is the same small black-and-white cat as the existing Beka art
(`beka_stand`, `beka_sit`, `beka_sleep`): black back, ears and tail, white
chest, face blaze, paws and belly, pale green eyes, pink nose. Match those
exact markings in every pose. On screen she is about 34 px tall sitting, so
generate at the same scale as each other and keep the markings bold.

| # | File | Pose |
|---|---|---|
| K1 | `hub_beka_walk.png` | walk cycle, 6 frames side by side in equal cells, side view facing RIGHT, feet on one line |
| K2 | `hub_beka_content.png` | sitting upright, eyes closed, head tilted up slightly, being petted (purring) |
| K3 | `hub_beka_groom.png` | sitting, licking one raised front paw |
| K4 | `hub_beka_stretch.png` | the long front stretch after a nap, rear up, front paws forward, facing right |

K1 matters most (she walks everywhere); the others add life. She is
affectionate and calm; nothing sad, nothing silly.

## Notes

- One figure per image (K1: exactly six frames; section 2: exactly three).
- Re-roll anything with ground, a shadow or a second figure painted in.
- Priority: K1, then N1–N4, then the crowd, then the rest.
