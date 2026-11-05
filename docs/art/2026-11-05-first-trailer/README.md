# First gameplay trailer, cut 1 (5 November 2026)

**File:** `~/Videos/Synthetic-Ascension-first-trailer.mp4` (not in Git, 99 MB).

| Property | Value |
| --- | --- |
| Duration | **0:40.87** (2452 frames) |
| Video | 1920×1080 H.264 High, 60 fps, BT.709 |
| Audio | AAC-LC 48 kHz stereo |
| Loudness | −14.4 LUFS integrated, −0.8 dBTP |

Every gameplay shot is real game footage at recorded speed, with the real HUD,
from `codex/trailer-build` `a2720c2d` in Canal Services (segment 7, seed
16102028).

## Story

| Time | Shot |
| --- | --- |
| 0:00 | A swarm closes on the Ward Vigil. A full Momentum bank tears the ground at the aim point. |
| 0:02.5 | Street fight, then along the frontages to a real door. The roof cuts away and an item is picked up inside. |
| 0:09 | The bag opens on the find: **Lattice Strideframe, Manifestation Sunder Wake**. The card is held about 4.4 s (3.9 s at a 1.5× punch-in), then equipped. |
| 0:17 | Walking out fills Momentum; the next attacks spend it, and two tears open at the aim point. |
| 0:21 | The Ward Vigil wakes and the horde converges. The player dodges the charger wedge's wind-ups, the ring tightens, and one Sunder clears it. "VIGIL HELD", the district shifts, and a final Sunder lands. |
| 0:34.9 | Cut on that impact to **SYNTHETIC ASCENSION**, held 6 s, with the impact's sound running under it. |

Frame ranges are in the [cut list](cutlist.md). [`cutlist.json`](cutlist.json) is
the editable project; rebuild steps are in
[`tools/capture/trailer/README.md`](../../../tools/capture/trailer/README.md).

## How the footage was made

The takes were recorded offline from the actual Game by Godot's Movie Maker,
with a preload that keeps the game's clocks on the recorded frames. They are not
a live performance capture. Two takes were used: `find`
([log](take-find.json)) and `vigil` ([log](take-vigil.json)).

What was staged:

- God mode.
- A segment-7 start with the onboarding tips marked as seen.
- An equipped loadout of ordinary items without Manifestations.
- Warps to the start points, and an unrecorded 4× pre-roll so the street is already populated when the take starts.
- The found item: a placed R4 Lattice Strideframe whose rule was set to Sunder Wake.
- In the Vigil take, the same item worn from the start.
- The charger-wedge beat, called at 7 s instead of waiting for its cadence.

Played live, with production input through the director:

- Movement, mouse aim, attacks, dashes, and the bag open, hover and click.
- Spawning, the encounter director, the Vigil and its waves.
- Roofs, pickups, merges and the HUD.

During the Vigil fight, picked-up duplicates merged into worn items through the
normal merge rule and brought two more rules (Ward, Cadence). Its last shots
therefore carry three rules. The find take shows Sunder Wake alone.

The game's music was muted during capture. The bed is the project-owned S10
score (phases 1–3 and the release chord; see its PROVENANCE), mixed and ducked
under the game sounds.

## Checks

- **Watched in full:** at 1920×1080 and as 320/480-px frames.
- **First 5 s:** the opening frame reads as the player in the Vigil ring under a swarm. The first Sunder impact sound lands at 2.0 s.
- **Card:** the name and the orange Sunder Wake heading read at 480 px. The full rule reads at 1080p.
- **Title:** readable at 480 px.
- **Impacts:** 4–14 dB above the bed beneath them, which includes the game's own gunfire. Audio was checked by measurement, not by ear.
- **File:** 0 decode errors.

## Known limits

- **Runtime:** 41 s, short of the 75–90 s target. That is all the strong footage these two takes give.
- **Choice is silent:** the bag pauses the game, and no UI sound was recorded for the open, hover or equip, so the music carries it.
- **Door hidden:** the door used faces north, so the doorway is hidden by the roof until it cuts away.
- **Hard to read:** charger wind-up fans are hard to see in a crowd at normal zoom. Narrative HUD notices sometimes sit over the action.

## Pickups for a longer cut

Record in normal play at 1920×1080, 60 fps, with game audio, UI scale 1.0 and
the same build. Keep 3 s before and 2 s after each action.

1. **A door that faces the camera** (city). In Canal Services:
   1. Stand on the street about 6–8 m below a house whose door is on its bottom (south) wall.
   2. Walk straight up into the doorway.
   3. Keep walking for 2 s inside, then pick up an item.

   The door arch must be visible on the facade before the roof fades.
2. **A narrow passage** (city):
   1. Find a 2–3-tile alley between two buildings. This seed has none near the trailer street.
   2. Fight at its mouth for 2 s.
   3. Walk through it to the far end.
3. **One readable Charger tell** (escalation):
   1. After reaching the Ward Vigil (Chargers spawn from then on), stand on open stone with a single Charger approaching.
   2. Wait for its yellow three-ray fan.
   3. Dash sideways (Shift) as it flashes white, then kill it.
4. **An equip with sound** (choice):
   1. Open the bag (Tab), hover a found item for 4 s, then click to equip.
   2. Confirm whether the game plays a UI sound. If it doesn't, that is a game audio gap rather than a recording problem.
5. **Another objective beat for 75–90 s:** a Breach Seal or Cursed Vault fight with the same build, from tell to completion.
