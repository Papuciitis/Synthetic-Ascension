#!/usr/bin/env python3
"""Build data/ascension/tree_v5_ranged.json from the immutable V4 tree.

The V4 file is never modified. Every V5 change is authored here as data so the
diff against V4 is reproducible and reviewable (handoff 2026-09-25, Phase 1
Checkpoint 1). Graph shape (links, edges) is intentionally untouched; only
requires/conflicts/names/tooltips/rules/rank fields and the builds change.

Rank representation (decision D-3): a ranked local carries "max_rank" and
"rank_costs" (index 0 = rank 1, equal to cost_followers). The generic gates
(rank 2: none; rank 3: 2 other owned unique locals of the discipline;
rank 4: 4) live in AscensionLedger, not per-node JSON.

Run:  python3 tools/design/build_tree_v5.py [--check]
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
V4_PATH = ROOT / "data/ascension/tree_v4.json"
V5_PATH = ROOT / "data/ascension/tree_v5_ranged.json"

# ---------------------------------------------------------------- rank tables

RANK_COST_ROWS = {
    200: [200, 350, 750, 1500],
    400: [400, 700, 1300, 2300],
    800: [800, 1300, 2300, 3900],
}

MAX_RANKS = {
    "PR01": 3, "PR02": 3, "PR03": 4, "PR05": 3, "PR06": 2, "PR07": 3,
    "PR09": 3, "PR11": 2, "PR12": 3,
    "BR01": 3, "BR02": 4, "BR04": 3, "BR05": 4, "BR06": 3, "BR07": 2,
    "BR08": 2, "BR09": 2, "BR11": 3, "BR12": 2,
    "OR01": 3, "OR02": 4, "OR08": 3, "OR09": 3, "OR10": 3, "OR11": 3,
    "OR12": 3,
}

# ---------------------------------------------------------------- requires

BR_LOCALS = ["BR01", "BR02", "BR03", "BR04", "BR05", "BR06", "BR07", "BR08",
             "BR09", "BR10", "BR11", "BR12"]


def count_req(ids, n):
    return {"count": {"ids": ids, "at_least": n}}


REQUIRES = {
    "BR03": {"owned": "BR01"},
    "BR07": {"owned": "BR01"},
    "BRF1": {"all": [count_req(BR_LOCALS, 4), {"owned": "BR01"}]},
    "BRF2": {"all": [count_req(BR_LOCALS, 4), {"owned": "BR03"}]},
    "BRK1": {"all": [count_req(BR_LOCALS, 4), {"owned": "BR03"}]},
    "BRS1": {"all": [count_req(BR_LOCALS, 4), {"owned": "BR03"}]},
    "BRA": {"all": [count_req(BR_LOCALS, 5), {"owned": "BR03"}]},
    # Big One correction (handoff finding B): OR09 now produces Grenades, so
    # it may no longer satisfy a Shell-only upgrade. Genuine Shell producers:
    # OR01 Impact Fuse, OR04 Secondary Blast, OR11 Saturation Scan, ORQ.
    "OR12": {"any": [{"owned": "OR01"}, {"owned": "OR04"},
                     {"owned": "OR11"}, {"owned": "ORQ"}]},
    # Bandolier needs a live grenade producer.
    "OR10": {"any": [{"owned": "OR02"}, {"owned": "OR09"}]},
}

# BRE1 keeps its V4 recipe plus owned BR03 (its beam generates Heat each tick).
BRE1_EXTRA_REQ = {"owned": "BR03"}

# ---------------------------------------------------------------- texts
# name (or None to keep), tooltip, rules. Tooltips must match the V5 runtime.

TEXTS = {
    "BR01": ("Spin Up",
        "Sustained native Ranged fire climbs three stages of firing rate: +15/35/60% (higher ranks up to +20/45/80%).",
        "Sustained native Ranged fire climbs three attack-speed stages; stage times and bonuses improve with rank "
        "(R1 0.40/1.20/2.40s for +15/35/60%; R3 0.30/0.80/1.60s for +20/45/80%). Pauses under 0.35s hold the stage; "
        "after 0.75s idle one stage is lost every 0.5s. No Heat, no Jam, no cooling chore. Free starter choice."),
    "BR02": (None,
        "Every 5th eligible Ranged Core strike arms 2 extra 0.6D rounds for the next attack (ranks: 3 rounds, then every 4th, then 4 rounds every 3rd).",
        "Every 5th weighted eligible Ranged Core strike arms 2 extra 0.6D rounds, Proc Power 0.5, for the next eligible "
        "attack. Ranks: R2 3 rounds; R3 every 4th; R4 4 rounds every 3rd. One armed package at a time; a second merges "
        "up to twice the package size. Extra rounds never advance this counter."),
    "BR03": ("Hot Core",
        "Creates the optional 0-100 Heat pool: side rounds and a radiant burn aura at 50/75/100 Heat, with a 2s Meltdown at 100.",
        "Requires Spin Up. Creates the 0-100 Heat pool: +8 Heat per native input (+4 more during Burst, +4 per Witness "
        "shot). At 50/75 Heat each input adds one/two 0.35D side rounds and a radiant burn aura of 0.5R/R at "
        "0.12/0.22 D/s; at 100 a 2s Meltdown grants three side rounds and a 2R aura at 0.35D/s, then Heat rests at 40 "
        "with a 3s lockout. Firing never stops and nothing Jams. Without this node no Heat exists anywhere."),
    "BR04": (None,
        "Every 3rd eligible strike's first projectile impact applies a named Hot Rounds burn (0.15/0.20/0.30 D/s by rank). Works without Heat.",
        "The first Core projectile impact from every 3rd eligible strike applies Hot Rounds burn: R1 0.15D/s for 2.0s, "
        "R2 0.20D/s for 2.5s, R3 0.30D/s for 3.0s (burn Proc Power 0). Works with no Hot Core. With Hot Core at 50+ "
        "Heat the first impact of every volley instead blasts 0.5D in R/2 (Proc Power 0.30) and applies the ranked "
        "burn; at 75+ every projectile of the volley applies the burn, strongest rate refreshed, never stacked."),
    "BR05": (None,
        "Every real Ranged kill releases seeking fragments: 2/3/4/5 by rank, each 0.6D.",
        "Every real Ranged kill releases rank-count seeking fragments (2/3/4/5), each 0.6D, lifetime 2s, Proc Power "
        "0.4, seeking targets within 3R of the corpse. Fragments are generated payloads, never Core strikes; each "
        "victim spawns one group at most."),
    "BR06": (None,
        "Every 3rd eligible strike fires from the screen edge: R2 two points at 0.7D, R3 every 2nd strike at 0.65D.",
        "R1: every 3rd weighted eligible Core strike spawns one screen-edge firing point shooting 0.8D at the cursor, "
        "Proc Power 0.5. R2: two separate edge points at 0.7D each. R3: every 2nd strike, two points at 0.65D. Edge "
        "shots never advance Crossfire's own counter."),
    "BR07": ("Kill Throttle",
        "At Spin Up stage 2+, every 3 real Ranged kills grant 2s Overdrive: one extra 0.4D side round per native input (rank 2: every 2 kills, 2.5s).",
        "Requires Spin Up. While firing at Spin Up stage 2 or higher, every 3 distinct real Ranged kills grant 2s of "
        "Overdrive: each native input adds one 0.4D side round, Proc Power 0.25. R2: every 2 kills, 2.5s. Reactivation "
        "refreshes, never stacks. Works without Heat; Overdrive rounds generate no Heat and refill nothing."),
    "BR08": ("Vent Volley",
        "Every 12 native inputs automatically fire 8 outward 0.6D rounds (rank 2: every 10 inputs, 12 rounds). Burst completion adds one volley.",
        "Every 12 real native Ranged inputs automatically fire 8 radial 0.6D rounds, Proc Power 0.3 (R2: every 10 "
        "inputs, 12 rounds). A normal Burst completion fires one extra volley. With Hot Core, the Q-completion volley "
        "also vents Heat to 40 and adds one 0.4D round per 10 Heat spent, up to 6. No Jam exists."),
    "BR09": (None,
        "Core projectiles bounce to one different enemy within 2R at 70% damage; rank 2 allows a second bounce.",
        "Core projectile impacts bounce once to a different enemy within 2R at 70% current damage, Proc Power 0.6. "
        "R2: one additional different-enemy bounce at 70% of the previous hit, Proc Power 0.4. A projectile never "
        "ricochets into the same victim twice."),
    "BR11": ("Reserve Feed",
        "Every 6 native inputs store 2 spare 0.7D rounds (up to 12); every 12th input launches up to 6 at your aim. Ranks store faster and hold more.",
        "Every 6 real native inputs store 2 spare 0.7D rounds, Proc Power 0.3, up to 12 (R2: 3 up to 18; R3: every 5 "
        "inputs, 4 up to 24). Every 12th native input automatically fans up to 6 stored rounds toward aim; a Vent "
        "Volley on the same input absorbs them instead. Burst completion consumes all stored rounds, capped at 24. "
        "With Hot Core, first crossings of 50 and 75 Heat each bank +1. Works without Heat."),
    "BR12": (None,
        "Each Core ricochet impact emits 2 non-bouncing 0.5D fragments (rank 2: 3 at 0.45D).",
        "Each physical Core Ricochet impact emits 2 non-bouncing 0.5D fragments, Proc Power 0.3, even without a kill "
        "(R2: 3 fragments at 0.45D). Impact fragments cannot bounce or recurse; their real kills may still trigger "
        "Fragmentation once per victim. Conflicts with Pinball."),
    "BRQ": (None,
        "Q: for 2s fire at twice your current legal rate with one bonus 0.45D round per shot; completion fires a 12-round 0.6D fan.",
        "Q: for 2.0s the native gun fires at x2 its current legal rate while you aim and move; each native input adds "
        "one forward 0.45D round (Proc Power 0.35). Normal completion fires a 12-round 0.6D fan of Q-generated Core "
        "strikes (Proc Power 0.7) counting as one activation. Never needs Heat and never Jams; with Hot Core each "
        "Burst input adds +4 extra Heat. Press Q again to cancel."),
    "BRQ1": ("Sustained",
        "Burst lasts 3s; movement is only slowed 10% during it.",
        "Burst lasts 3.0s instead of 2.0 and the movement penalty during Burst is 10%. Completion effects unchanged."),
    "BRQ2": ("Vented",
        "Completion releases a burn nova: 1D in R, or 2D in 2R with Hot Core (which also vents Heat to 40).",
        "On normal completion: a 1D burn nova in R without Hot Core, or a 2D nova in 2R with it (direct hit Proc Power "
        "0.3; burn 0.2D/s for 2s, Proc Power 0). With Hot Core the completion also vents Heat to 40 after end bonuses "
        "are counted."),
    "BRQ5": ("Ammo Dump",
        "Every 4 native inputs during Burst earn one bonus 0.5D end-volley round, up to 12; Hot Core adds Heat/20 more, up to 5.",
        "Every 4 native inputs during this Burst earn 1 bonus 0.5D end-volley round, Proc Power 0.3, maximum 12. With "
        "Hot Core, add floor(Heat/20) extra rounds at completion, maximum 5, snapshotted before any vent. Cancelling "
        "skips the dump."),
    "BRQ6": ("Emergency Stop",
        "Cancelling Burst in its first half refunds 50% of the unused cooldown; with Hot Core it also removes 30 Heat.",
        "Cancel Burst during its first half to refund 50% of the unused Q cooldown; with Hot Core, additionally remove "
        "30 Heat. A cancelled Burst produces no completion fan, Ammo Dump, Vented nova or Vent Volley."),
    "BRQ7": ("Belt-Fed",
        "Each distinct real kill during Burst extends it 0.10s, up to +2s.",
        "Every distinct real kill during an active Burst extends it by 0.10s, capped at +2s total. V-rooted kills do "
        "not count."),
    "BRF1": ("Controlled Fire",
        "Spin Up stage 3 persists 1.5s longer; at stage 3 projectiles fly 25% faster and Reserve Feed stores one extra round per event.",
        "Requires Spin Up. Stage 3 persists an extra 1.5s before decay; while stage 3 is active, native projectiles "
        "gain +25% travel speed and Reserve Feed, if owned, stores one additional round per completed event. With Hot "
        "Core: ceasing fire for 0.35s at 70-90 Heat vents to 40 and arms the next attack with +0.5D, once per 3s. "
        "Works fully without Heat."),
    "BRF2": ("Thermal Fury",
        "During Meltdown the radiant aura deals double damage and Vent Volley fires twice; each Meltdown ends by paying 5% of current HP.",
        "Requires Hot Core. During Meltdown the radiant aura DPS doubles and Vent Volley, if owned, fires twice its "
        "radial count once per Meltdown (without Vent Volley, the Meltdown itself releases 8 radial 0.6D shots). Each "
        "Meltdown's end costs 5% of current HP. A deliberately dangerous branch, never mandatory for projectile "
        "count."),
    "BRK1": ("Overclock",
        "Heat capacity 200 with sustained Meltdown above 100; stronger side rounds and aura, +25% damage taken, emergency vent at 180.",
        "Requires Hot Core. Heat capacity becomes 200: at 100 the weapon enters sustained Meltdown until cooling below "
        "100. 100-149: 3 side rounds per input, 2R aura at 0.35D/s. 150-179: 4 rounds, 2.5R aura at 0.50D/s. Above "
        "100 you take 25% more enemy damage. At 180: one 16-round 0.6D radial emergency vent, 0.60s of no native "
        "fire, Heat resets to 40 with a 3s lockout. Cooling still applies after 0.35s idle even in Meltdown."),
    "BRK2": ("Bottomless",
        "The weapon fires itself at your normal rate toward aim; holding the attack input suppresses it.",
        "Auto-fires at the current normal native Ranged interval toward aim; holding the primary attack input "
        "suppresses firing. Movement -10% at Spin Up stage 3, or -20% during 100+ Heat with Hot Core. Auto-fire "
        "inputs are real native inputs; never fires while stunned or paused. No Heat requirement."),
    "BRC": (None,
        "Catastrophe: 20 stage-3 native inputs in 8s, a Meltdown end, or three Controlled Fire vents in 10s release four 12-round radial volleys.",
        "Ready when owned with 6 unique BR locals, Spin Up and Vent Volley or Reserve Feed. Triggers on any of: 20 "
        "real native inputs at Spin Up stage 3 within a rolling 8s (no Heat needed); an ordinary Meltdown end, "
        "Thermal Fury release or Overclock emergency vent; or three Controlled Fire vents within 10s. Payoff: 4 "
        "radial volleys 0.15s apart, 12 x 0.8D each, Proc Power 0.4, 8s recovery. Its own kills never recharge it."),
    "BRV3": ("Final Salvo",
        "SUPPRESSION's end fires one 1D radial round per 4 gun shots (max 60) with a 0.60s recovery.",
        "On ending, SUPPRESSION fires one 1D radial round per four gun shots emitted, maximum sixty, then 0.60s of "
        "firing recovery. There is no baseline Jam."),
    "BRA": (None,
        "Axiom: with Hot Core, Melee and Magic Core strikes add 5 Heat and convert thermal side rounds into 0.4D strikes of their own kind.",
        "Requires Hot Core. When equipped, Melee and Magic Core strikes add 5 Heat, share the owned Hot Core threshold "
        "effects, and each bonus thermal round becomes one 0.4D slash/impact after the native strike. Ordinary "
        "Meltdown/Overclock rules apply; no style is ever disabled."),
    "BRS1": (None,
        "Repeatable: Heat generation is reduced by 30% x rank/(rank+75). Buying more can delay Meltdown payoffs.",
        "Requires Hot Core. Repeatable: Heat generation reduced by 30% x rank/(rank+75); price 200 x (rank+1)^1.25. "
        "Warning: more control can delay Thermal Fury and Meltdown - a tradeoff, never an automatic upgrade."),
    # -------- Precision (rank text only where behaviour changes) --------
    "PR01": (None,
        "Ranged Core hits build Read; a Weak Point opens at 3.0 weighted points (ranks: 2.5, then 2.0).",
        "Ranged Core hits build Read using their Proc Power; at 3.0 weighted points (R2 2.5, R3 2.0) the target is "
        "exposed for 3s and the next Core hit consumes the Weak Point for +1D. One hit never both exposes and "
        "consumes."),
    "PR02": (None,
        "First Core hit from beyond 2R exposes immediately; ranked, Far Shot Weak Points consume for +1.2D/+1.4D.",
        "The first Ranged Core hit on an enemy farther than 2R exposes a Weak Point immediately. R2: a Weak Point "
        "created by Far Shot grants +0.2D extra when consumed (total +1.2D); R3 +0.4D (total +1.4D). Other Weak "
        "Points stay +1D."),
    "PR03": (None,
        "Ranged Core projectiles pierce 2/3/4/5 additional targets by rank.",
        "Ranged Core projectiles pierce additional targets: 2/3/4/5 by rank. Each target already crossed adds 0.2D "
        "to later hits on that trajectory, up to +1D. Native attacks with no projectile gain no geometric pierce."),
    "PR05": (None,
        "Aim stores after 0.80/0.65/0.50s (by rank) without a native attack.",
        "Not attacking for 0.80s (R2 0.65s, R3 0.50s) stores Aim: the next shot gains +1D and Proc Power 1.25. "
        "Movement is allowed; taking damage clears it."),
    "PR06": (None,
        "Core projectiles bounce off terrain once (rank 2: twice) at 75% per bounce.",
        "Core projectiles may bounce off terrain once at 75% current damage, Proc Power 0.7 (R2: two bounces, each "
        "successive bounce x0.75). No indefinite wall ping-pong."),
    "PR07": (None,
        "Returning shots deal 60/75/90% (by rank) of their damage as the return begins.",
        "A Core projectile reaching maximum range or exhausting pierce returns along its path for 60% (R2 75%, R3 "
        "90%) of its damage as the return begins, Proc Power 0.5, one hit per victim, no second return."),
    "PR09": (None,
        "The split emits 2/3/4 rounds by rank at widening angles, each 0.7D.",
        "Killing an exposed enemy after the projectile crossed another target emits R1 2 rounds at +/-20 degrees, "
        "R2 3 at -24/0/+24, R3 4 at -30/-10/+10/+30; each 0.7D, one pierce, Proc Power 0.4. Count changes rounds, "
        "not per-round damage."),
    "PR11": (None,
        "Trajectory-intersection window 0.50s (rank 2: 0.65s) for the extra 1D.",
        "An enemy crossed by two different projectile trajectories within 0.50s (R2 0.65s) takes an extra 1D, once "
        "per target per second, Proc Power 0.4."),
    "PR12": (None,
        "Store 3/4/6 spare rounds (by rank) from returning kills; the next shot fires them all at 0.8D.",
        "A returning shot that kills stores one spare round, up to 3 (R2 4, R3 6); the next native input fires all "
        "stored rounds at 0.8D each, Proc Power 0.5. Spare rounds cannot generate spare rounds."),
    "PRF2": (None,
        "Core projectiles curve up to 30 degrees toward exposed targets at -15% Core shot damage.",
        "Core projectiles curve up to 30 degrees toward exposed targets; Core shot damage -15% (returning and split "
        "damage unchanged). Conflicts with Deadeye."),
    "PRC": (None,
        "Twelve distinct enemies or six Weak Points from one root - or 12D across 3+ physical hits on one boss - summon six edge guns.",
        "One projectile root crossing twelve distinct enemies or consuming six Weak Points creates six edge guns "
        "(2D lines, 8s recovery). Boss fallback: one physical Ranged projectile root dealing at least 12D to a "
        "single elite/boss across at least three separate physical hits triggers the same payoff once per recovery. "
        "Burn ticks and Q beams do not qualify."),
    # -------- Ordnance --------
    "OR01": (None,
        "Every 4th weighted Ranged Core hit calls a Shell (ranks: every 3rd, every 2nd).",
        "Every 4th weighted Ranged Core hit (R2 3rd, R3 2nd) calls one Shell at the victim: 1.5D in R after a 0.6s "
        "tell, Proc Power 0.5. At most one Shell per initiating strike activation; excess credit banks."),
    "OR02": ("Grenadier",
        "Real Ranged attack activations automatically throw grenades at nearby enemies: 1.3D blasts that attach or land and explode.",
        "Every 4 activation credits (R2 3, R3 3 with two grenades, R4 2 with two) automatically launch a grenade "
        "toward the enemy nearest your aim (native input = 1 credit, Witness shot = 0.6, generated rounds = 0). A "
        "grenade flies 0.35s, attaches to a living enemy and detonates after 0.40s, or lands and detonates after "
        "0.80s: 1.3D in R, Proc Power 0.5, one detonation each. No Mines and no dashing required. Free starter "
        "choice."),
    "OR03": (None,
        "Hitting a victim under a falling Shell or carrying an attached grenade advances the fuse 0.15s per strike.",
        "Hitting a victim under a falling Shell advances its impact by 0.15s per eligible Core strike; if the target "
        "dies the Shell redirects once within 3R. The same benefit advances an attached grenade's fuse by 0.15s per "
        "strike, minimum 0.10s remaining; an immediate Sticky Follow-Up detonation resolves once."),
    "OR05": ("Sticky Follow-Up",
        "Shooting an enemy carrying an attached grenade detonates it immediately for +0.8D.",
        "Requires Grenadier. A Ranged Core hit on a victim carrying an attached grenade immediately detonates the "
        "oldest one, adding +0.8D to that single blast (same Proc Power 0.5). At most one boosted detonation per "
        "initiating strike; other attached grenades keep their timers."),
    "OR06": (None,
        "Any Mine, attached or grounded grenade, or trap blast detonates other armed explosives whose radii touch.",
        "Requires Grenadier. An eligible real Mine, attached grenade, grounded grenade or Q trap blast immediately "
        "detonates other armed explosive objects whose blast radii touch. Falling Shells never chain mid-air; their "
        "impact blast may start a chain. Every explosive detonates once and leaves the armed graph first."),
    "OR08": (None,
        "3 distinct blasts arm Fracture (ranks: 2 blasts; then 5 shrapnel).",
        "R1: 3 distinct real blasts on one victim arm Fracture; the next blast consumes it for 3 x 0.6D shrapnel, "
        "Proc Power 0.35. R2: arms after 2 blasts. R3: 5 shrapnel. One stack armed or consumed per physical blast."),
    "OR09": ("Running Barrage",
        "After real travel, automatically lob grenades toward the enemy nearest your aim (1.0L/0.75L per trigger; rank 3 throws two).",
        "After 1.0L of real travel (R2 0.75L; R3 1.0L for two grenades), automatically lob a grenade toward the "
        "enemy nearest the current aim region, at most once per 0.50s, banking up to 2L of credit. Walking and "
        "dashing count; forced displacement does not. Produces ordinary Grenades that chain, sticky and feed "
        "Secondary Blast."),
    "OR10": ("Bandolier",
        "Every 6/5/4 activation credits (by rank) store a spare grenade (cap 3/5/7); producers add one stored spare per launch.",
        "Requires Grenadier or Running Barrage. Every 6 (R2 5, R3 4) eligible activation credits store one spare "
        "grenade, reserve cap 3/5/7. When a producer next launches, at most one spare joins that launch. No reserve "
        "fires without a producer. The ordinary Mine cap is unchanged."),
    "OR11": (None,
        "The scan fires 3/4/5 Shells by rank.",
        "The first qualifying real blast kill after moving R scans the densest occupied cell within 3R once and "
        "fires 3 Shells 0.2s apart (R2 4, R3 5). Targets chosen at trigger time; movers can escape."),
    "OR12": (None,
        "Every 7th/6th/5th Shell (by rank) becomes the 4D-in-2R Big One. Only true Shells count.",
        "Every 7th (R2 6th, R3 5th) ordinary Shell becomes the 4D in 2R Big One with a 0.9s tell, Proc Power 1. "
        "Shell sources: Impact Fuse, Secondary Blast, Designate, Saturation Scan. Grenades, stickies and Mines "
        "never advance the counter. A Big One counts once and cannot be duplicated."),
    "ORQ": (None,
        "Q tap: immediately bombard the cursor with 4 Shells. Hold 0.35s: place a Coordinate (up to 3) to fire later.",
        "Tap Q (release before 0.35s): immediately start a normal 4-Shell Designate sequence at the cursor, if the "
        "7s fire cooldown allows. Hold Q 0.35s or longer: place one Coordinate on release, up to 3, 0.25s placement "
        "recovery, without consuming the fire cooldown. Tap while hovering a Coordinate to fire it. Nothing fires "
        "before a hold is classified."),
    "ORQ4": (None,
        "Designate Shells land as armed 3s traps (Mine-compatible for conversions), separate cap 24.",
        "Designate Shells land as armed 3s traps exploding on contact or expiry, separate cap 24. Traps carry the "
        "Mine-compatible tag for Rune Bomb and Chain Reaction, without sharing the ordinary Mine cap. The optional "
        "stationary-trap route."),
    "ORQ5": (None,
        "Placed Coordinates follow at an aim-set offset; a tapped sequence tracks your aim for its first 0.6s.",
        "A placed Coordinate follows at an aim-set offset within L. For instant-tap Q, the impact region tracks the "
        "current aim for the first 0.6s of the sequence, then fixes. Landed trap payloads never move."),
    "ORQ7": (None,
        "Fired placed Coordinates go dormant and reactivate when the Q cooldown completes. Instant taps gain nothing.",
        "Fired placed Coordinates become dormant and reactivate when the 7s Q cooldown completes; replaced dormant "
        "Coordinates are removed. An instant tap places no Coordinate and gains nothing from this mutation."),
    "ORF1": (None,
        "Automatic Shells cover distinct groups before repeating; grouped grenades also spread. Shell damage -15%.",
        "Automatic Shells select distinct occupied cells before reusing one; three distinct real blast kills within "
        "1s call an extra Shell at a less-covered group; ordinary Shell direct damage -15%. Grenades launched "
        "together also prefer different groups but keep full damage."),
    "ORF2": (None,
        "Your latest Core hit tags an elite/boss for 4s: Shells +50% (half suppressed), grenades +30% and prioritized.",
        "The most recent actual Core hit on an elite/boss selects it for 4s. Automatic Shells target it at +50% "
        "with every second one suppressed. Automatic grenades prioritize it at +30% with none suppressed. The two "
        "bonuses never stack on one payload. Manual Designate is unaffected."),
    "ORK2": (None,
        "Blasts (Shells, grenades, Mines) gain +40% radius and +25% damage; your own blasts hurt you.",
        "All actual blast payloads, including grenades, gain +40% radius and +25% damage. Standing in your own "
        "blast pays 3% max HP, at most once per 0.25s. The enlarged self-damage zone is previewed for grenades, "
        "Shells and traps."),
    "ORC": (None,
        "Twelve blasts in one root, or 24 owned blasts in 8s, draw six lanes of four 2D Shells each.",
        "Twelve distinct blast activations within one attack root, or 24 distinct owned Grenade/Shell/Mine blast "
        "activations across a rolling 8s window, draw six lanes across the field: four 2D Shells per lane over 1s, "
        "Proc Power 0.3, 8s recovery; Mines touched by lanes detonate. Each explosive counts once; its own blasts "
        "never rebuild the trigger."),
    "ORA": (None,
        "Axiom: a Q that makes no Shells leaves one at its endpoint; Shell-producing Qs advance Big One once.",
        "Any Q that does not already create Shells leaves one Shell at its endpoint; a Shell-producing Q (including "
        "instant-tap Designate) advances Big One by one if owned. One grant per real Q activation."),
}

# Short per-rank effect strings for the tree UI: index 0 describes rank 1,
# index N the effect after buying rank N+1. Shown as "next: ...".
RANK_EFFECTS = {
    "PR01": ["expose at 3.0 weighted points", "expose at 2.5 points", "expose at 2.0 points"],
    "PR02": ["far hits expose; consume +1D", "Far Shot Weak Points consume for +1.2D", "Far Shot Weak Points consume for +1.4D"],
    "PR03": ["pierce 2 extra targets", "pierce 3", "pierce 4", "pierce 5"],
    "PR05": ["Aim after 0.80s", "Aim after 0.65s", "Aim after 0.50s"],
    "PR06": ["1 terrain bounce at 75%", "2 terrain bounces, x0.75 each"],
    "PR07": ["return at 60%", "return at 75%", "return at 90%"],
    "PR09": ["2 split rounds", "3 split rounds", "4 split rounds"],
    "PR11": ["0.50s crossing window", "0.65s crossing window"],
    "PR12": ["store up to 3 spares", "store up to 4", "store up to 6"],
    "BR01": ["stages +15/35/60% (0.40/1.20/2.40s)", "stages +15/40/70% (0.35/1.00/2.00s)", "stages +20/45/80% (0.30/0.80/1.60s)"],
    "BR02": ["every 5th arms 2 rounds", "every 5th arms 3", "every 4th arms 3", "every 3rd arms 4"],
    "BR04": ["burn 0.15D/s for 2.0s", "burn 0.20D/s for 2.5s", "burn 0.30D/s for 3.0s"],
    "BR05": ["2 fragments per kill", "3 fragments", "4 fragments", "5 fragments"],
    "BR06": ["every 3rd: 1 edge shot 0.8D", "every 3rd: 2 edge shots 0.7D", "every 2nd: 2 edge shots 0.65D"],
    "BR07": ["3 kills grant 2.0s Overdrive", "2 kills grant 2.5s Overdrive"],
    "BR08": ["every 12 inputs: 8 rounds", "every 10 inputs: 12 rounds"],
    "BR09": ["1 bounce at 70%", "2 bounces at 70% each"],
    "BR11": ["store 2 per 6 inputs, cap 12", "store 3 per 6, cap 18", "store 4 per 5, cap 24"],
    "BR12": ["2 fragments 0.5D per ricochet", "3 fragments 0.45D"],
    "OR01": ["Shell every 4th weighted hit", "every 3rd hit", "every 2nd hit"],
    "OR02": ["1 grenade per 4 credits", "1 per 3 credits", "2 per 3 credits", "2 per 2 credits"],
    "OR08": ["arm at 3 blasts, 3 shrapnel", "arm at 2 blasts", "5 shrapnel"],
    "OR09": ["1 grenade per 1.0L", "1 per 0.75L", "2 per 1.0L"],
    "OR10": ["store per 6 credits, cap 3", "per 5 credits, cap 5", "per 4 credits, cap 7"],
    "OR11": ["scan fires 3 Shells", "4 Shells", "5 Shells"],
    "OR12": ["every 7th Shell is Big One", "every 6th", "every 5th"],
}

# Builds replaced: Ranged-heavy V4 routes describe removed Heat/Jam/Caltrops
# mechanics. Non-Ranged builds are kept verbatim.
V5_BUILDS = [
    {
        "name": "P1 Precision control",
        "native_core": "ranged",
        "nodes": ["core.ranged", "PR01", "PR02", "PR03", "PR07", "PRQ"],
        "ranks": {"PR03": 2},
        "equip": "Deadshot; no Keystone required",
        "play": "The unchanged long-range control build: distance, Weak Points, pierce and returns. Free PR01, then PR02, PR03, PR07, PR03 rank 2, Deadshot.",
        "adapt": "Add PR05 for aimed fire or PR09 once its prerequisite holds.",
        "risk": "No horde tools early; walls without bounce value make PR06 ranks poor.",
        "paid_subtotal": 2500,
    },
    {
        "name": "B1 No-Heat Barrage",
        "native_core": "ranged",
        "nodes": ["core.ranged", "BR01", "BR02", "BR05", "BR06", "BRQ"],
        "ranks": {"BR05": 2, "BR01": 2},
        "equip": "Burst; no Hot Core anywhere",
        "play": "Spin the gun up, keep firing: Fifth Shot packages, fragments on kills, edge fire every third strike, Burst on demand. No Heat bar, no Jam.",
        "adapt": "BR11 Reserve Feed and BR09 Ricochet extend the storm.",
        "risk": "Idle time drops Spin Up stages; single targets favour Precision.",
        "paid_subtotal": 2850,
    },
    {
        "name": "B2 Thermal machine gun",
        "native_core": "ranged",
        "nodes": ["core.ranged", "BR01", "BR02", "BR03", "BR04", "BR08", "BR05", "BRQ", "BRF2"],
        "ranks": {},
        "equip": "Burst; Thermal Fury fork",
        "play": "Buy Hot Core deliberately: side rounds and a radiant aura at 50/75, a 2s Meltdown at 100, Thermal Fury doubling the aura and paying 5% HP per Meltdown.",
        "adapt": "Overclock for sustained Meltdown; Reserve Feed banks rounds off Heat crossings.",
        "risk": "Health payments and +25% damage taken above 100 with Overclock.",
        "paid_subtotal": 3400,
    },
    {
        "name": "O1 Automatic Grenadier",
        "native_core": "ranged",
        "nodes": ["core.ranged", "OR02", "OR01", "OR04", "OR08", "ORQ"],
        "ranks": {"OR02": 2},
        "equip": "Designate (tap for instant bombardment)",
        "play": "Grenades throw themselves as you attack; Impact Fuse calls Shells, Secondary Blast chains corpses, tap-Q bombards. No Mine or Coordinate chores.",
        "adapt": "OR05/OR06 for deliberate chain play; OR11/OR12 for artillery.",
        "risk": "Grenade fuses give enemies a moment; pure single-target is slower.",
        "paid_subtotal": 2150,
    },
    {
        "name": "O2 Explosive chain specialist",
        "native_core": "ranged",
        "nodes": ["core.ranged", "OR02", "OR01", "OR04", "OR08", "ORQ", "OR05", "OR06", "OR09", "OR11"],
        "ranks": {"OR02": 2},
        "equip": "Designate; chain everything",
        "play": "O1 plus deliberately chosen interactions: shoot stickies for boosted blasts, chain grounded explosives, lob while running, scan after blast kills.",
        "adapt": "OR12 Big One through the true Shell producers; ORC for the rolling-window catastrophe.",
        "risk": "Overlapping detonations must be read; friendly Danger Close is a real hazard.",
        "paid_subtotal": 4550,
    },
]


def build() -> dict:
    data = json.loads(V4_PATH.read_text())
    data["title"] = "Synthetic Ascension — Ranged V5 prototype tree"
    data["version"] = "5.0-ranged-prototype"
    data["date"] = "2026-09-25"
    data["status"] = ("Ranged V5 prototype (handoff 2026-09-25): Spin Up replaces baseline Heat, "
                      "Hot Core makes Heat optional, Grenadier replaces Caltrops, ordinary local "
                      "ranks on selected PR/BR/OR nodes. V4 (tree_v4.json) is the untouched control.")
    data["rank_rules"] = {
        "gate": "Rank 2 needs the owned node only; rank 3 needs 2 other owned unique local "
                "nodes of the same discipline; rank 4 needs 4. Ranks never traverse edges, "
                "never count as extra locals, and refund their exact recorded payments in "
                "reverse order.",
        "cost_rows": {str(k): v for k, v in RANK_COST_ROWS.items()},
    }

    nodes = {n["id"]: n for n in data["nodes"]}
    changed = []

    for nid, max_rank in MAX_RANKS.items():
        node = nodes[nid]
        base = node["cost_followers"]
        row = RANK_COST_ROWS[base]
        node["max_rank"] = max_rank
        node["rank_costs"] = row[:max_rank]
        node["rank_effects"] = RANK_EFFECTS[nid]
        changed.append(nid)

    for nid, req in REQUIRES.items():
        nodes[nid]["requires"] = req
        changed.append(nid)

    # BRE1 Heat Beam: its effect generates Heat, so it now needs Hot Core.
    bre1 = nodes["BRE1"]
    old_req = bre1["requires"]
    if "all" in old_req:
        old_req["all"].append(BRE1_EXTRA_REQ)
    else:
        bre1["requires"] = {"all": [old_req, BRE1_EXTRA_REQ]}
    changed.append("BRE1")

    for nid, (name, tooltip, rules) in TEXTS.items():
        node = nodes[nid]
        if name:
            node["name"] = name
        node["tooltip"] = tooltip
        node["rules"] = rules
        changed.append(nid)

    # Builds: keep non-Ranged routes; replace Ranged ones with the V5 tests.
    ranged_ids = ("PR", "BR", "OR", "RM", "MR")
    kept = []
    for b in data["builds"]:
        node_ids = b.get("nodes", [])
        stale = any(i[:2] in ("BR", "OR") and i not in ("ORE1", "ORE2") for i in node_ids)
        if b.get("native_core") == "ranged" or stale:
            continue
        kept.append(b)
    data["builds"] = kept + V5_BUILDS

    data["_v5_changed_ids"] = sorted(set(changed))
    return data


def validate(data: dict) -> list:
    problems = []
    nodes = {n["id"]: n for n in data["nodes"]}

    def ids_in(rule):
        out = []
        if isinstance(rule, dict):
            if "owned" in rule:
                out.append(rule["owned"])
            if "count" in rule:
                out.extend(rule["count"].get("ids", []))
            for key in ("all", "any"):
                for child in rule.get(key, []):
                    out.extend(ids_in(child))
        return out

    # Every requires/conflicts/links id exists; links symmetric; edges synced.
    edge_set = set()
    for e in data["edges"]:
        a, b = e["a"], e["b"]
        edge_set.add((a, b))
        edge_set.add((b, a))
    for n in data["nodes"]:
        nid = n["id"]
        for rid in ids_in(n.get("requires", {})):
            if rid not in nodes:
                problems.append(f"{nid}: requires unknown {rid}")
        for cid in n.get("conflicts", []):
            if cid not in nodes:
                problems.append(f"{nid}: conflicts unknown {cid}")
            elif nid not in nodes[cid].get("conflicts", []):
                problems.append(f"{nid}: conflict with {cid} not reciprocal")
        for lid in n.get("links", []):
            if lid not in nodes:
                problems.append(f"{nid}: links unknown {lid}")
            elif nid not in nodes[lid].get("links", []):
                problems.append(f"{nid}: link to {lid} not reciprocal")
            elif (nid, lid) not in edge_set:
                problems.append(f"{nid}-{lid}: link missing from edges[]")
        if "max_rank" in n:
            if len(n["rank_costs"]) != n["max_rank"]:
                problems.append(f"{nid}: rank_costs length != max_rank")
            if n["rank_costs"][0] != n["cost_followers"]:
                problems.append(f"{nid}: rank_costs[0] != cost_followers")
            if len(n.get("rank_effects", [])) != n["max_rank"]:
                problems.append(f"{nid}: rank_effects length != max_rank")

    # The Big One correction: the grenade-only route no longer qualifies.
    or12 = nodes["OR12"]["requires"]
    if "OR09" in ids_in(or12):
        problems.append("OR12 still accepts OR09 (grenade producer)")
    for needed in ("OR01", "OR04", "OR11", "ORQ"):
        if needed not in ids_in(or12):
            problems.append(f"OR12 missing Shell source {needed}")

    # Heat ownership: only BR03 may claim Heat; its dependents must require it.
    for nid in ("BRF2", "BRK1", "BRS1", "BRA"):
        if "BR03" not in ids_in(nodes[nid]["requires"]):
            problems.append(f"{nid} does not require BR03")
    for nid in ("BR03", "BR07", "BRF1"):
        if "BR01" not in ids_in(nodes[nid]["requires"]):
            problems.append(f"{nid} does not require BR01")
    if "BR03" not in ids_in(nodes["BRE1"]["requires"]):
        problems.append("BRE1 does not require BR03")

    # Free starters per core: ring-1 locals reachable from the core anchor.
    for core in ("melee", "ranged", "magic"):
        anchor = f"core.{core}"
        starters = [n["id"] for n in data["nodes"]
                    if n["kind"] == "local" and n.get("ring") == 1
                    and n.get("core") == core and anchor in n.get("links", [])]
        if not starters:
            problems.append(f"no free starters adjacent to {anchor}")

    # V5 build subtotals recomputed from data.
    for b in data["builds"]:
        if "paid_subtotal" not in b:
            continue
        total = 0
        starter_used = False
        for nid in b["nodes"]:
            n = nodes[nid]
            if n["kind"] == "core":
                continue
            cost = n["cost_followers"]
            if (not starter_used and n["kind"] == "local" and n.get("ring") == 1
                    and n.get("core") == b["native_core"]):
                cost = 0
                starter_used = True
            total += cost
        for nid, target in b.get("ranks", {}).items():
            costs = nodes[nid].get("rank_costs", [])
            total += sum(costs[1:target])
        if total != b["paid_subtotal"]:
            problems.append(f"build {b['name']}: computed {total} != stated {b['paid_subtotal']}")

    return problems


def main() -> int:
    data = build()
    problems = validate(data)
    for p in problems:
        print("PROBLEM:", p)
    if problems:
        return 1
    if "--check" in sys.argv:
        print("validation clean (no file written)")
        return 0
    V5_PATH.write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n")
    print(f"wrote {V5_PATH} ({len(data['nodes'])} nodes, {len(data['edges'])} edges, "
          f"{len(data['_v5_changed_ids'])} changed ids)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
