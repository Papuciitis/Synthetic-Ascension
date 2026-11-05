# Claude brief — The Ascension of Syn’Tek

Capture and edit a new trailer for **The Ascension of Syn’Tek**. Aim for
**65–85 seconds** with a **2:00 maximum** including the end card. Use the
[44-second draft](trailer-recut.mp4) to see what we have. Prioritize fresh moving
takes for the new edit. Every shot should show an action, reaction or reveal.

The viewer should leave thinking **my choices change how I fight**. Prove it
once in a clean, readable sequence. Record two takes with the same weapon,
camera, enemy type and location. Show the ordinary attack in the first take.
Change one actual rule. In the second take, show what the player does differently
and what the enemies visibly experience. For Sunder Wake, show travel building
Momentum, the attack, the tear opening at the aim point, and the enemy reaction
in one held shot. Use a real choice and a matching payoff. A short insert of the
choice name or the actual confirmation is enough. Let the world carry the rest.

## What to shoot

1. **The real opening menu.** Capture its weather and title drawing on with the
   original menu theme. Preserve the official **The Ascension of Syn’Tek**
   wordmark. Get a clean shot of the reveal and a separate take with a real menu
   action. Keep a fully revealed hold for the ending.
2. **Hub, Beka, and Ascension Tree.** Film the lit Hub alive with movement and
   one real station interaction. Get a short close shot of Beka moving and the
   actual pet response at the Quiet Alcove. Open the real Tree and capture its
   unfurl, camera glide, and one node confirmation. A Hub pet is a character
   beat. Show its gameplay effect only if you separately record the real
   companion Offhand.
3. **Augment and equipment choices.** Capture one real pending Binding as the
   cards animate in and a choice commits. Pick a rule with a visible result and
   record it in the same run. Keep the name or the commit on screen just long
   enough to read. If the proof sequence is Sunder Wake, show its actual equip
   once. Use the bag or item slots only where they explain that decision.
4. **Fights with a different shape.** Capture a second real build whose play
   pattern contrasts with Momentum. Try a verified Precision route that makes
   the player stop and aim, or a Bastion route that holds ground. Show what the
   player does under comparable pressure. Then capture a distinct wave or
   objective beyond the current Ward Vigil footage. Keep one clear enemy tell,
   player response and impact together. The S5 Tank and Mage labels describe
   enemy encounters. Verify player loadouts separately.

## How to cut it

Open on a short threat or action that is readable immediately, then let the
real menu reveal name the game. Give the Hub and Beka a small moment of warmth
before the Tree and the choice. Hold the proof shot through the payoff. Build
from that single action to contrasting builds, a larger wave, and one final
earned hit or clear. Cut back to the real logo on that beat. Give the sound a
little room before the payoff and carry the impact into the title.

Frame with real game cameras and a capture-only HUD treatment. Hide inventory
slots, peripheral counters, unrelated banners and button prompts during hero
shots. Keep telegraphs, player and enemy silhouettes, and the cues the audience
needs to follow the action. Capture a normal-HUD version of the proof take too.
Use the Ascension and Augment UI when it is the subject of the shot. Let movement
come from the game and use restrained reframing to direct attention.

Use `assets/audio/music/main_menu.mp3` for the reveal and
`assets/audio/music/in_game.mp3` for ordinary gameplay. Record game effects and
music separately if possible so the real attacks, clicks and encounter sounds
can lead the mix. Use a boss cue only for the boss beat it belongs to. Build the
energy with contrast and timing using the game’s own sound.

Look at the scale and sound arc of the [Battlefield 1 reveal](https://www.youtube.com/watch?v=c7nRTF2SowQ),
the legible cause and effect in the [Noita editor’s breakdown](https://www.derek-lieu.com/blog/2020/10/17/noita-10-launch-trailer),
and the selective HUD and in-engine camera work in the [Tunic editor’s breakdown](https://www.derek-lieu.com/blog/2022/3/21/tunic-release-trailer).
Apply those editing principles with Syn’Tek’s game assets and music.

## Capture and delivery

Use the project’s guarded workflow in
[tools/capture/trailer](../../../tools/capture/trailer/README.md). Its existing
take director covers the `find`, `vigil`, and `street` routines. The source
probes `MenuScreenshotProbe`, `AscensionShotProbe` and `HubScreenshotProbe`
show how to reach the real menu, Tree and Hub beats. Capture-only staging is
fine for repeatability. Log the actual build, seed, loadout and staging, and
keep both the raw takes and the existing drafts.

Record 1080p at a steady frame rate with at least three seconds of lead-in and
two seconds after each key action. Before polishing the whole trailer, assemble
the choice and consequence beat and check it with the audio muted. A viewer
should be able to point to what changed and what the player did to trigger it.
Then render the full 1080p H.264/AAC MP4, keep the editable cut list and raw
takes, and check title, runtime, small-screen readability and sound in the
export. Report any required moving take that remains unavailable.
