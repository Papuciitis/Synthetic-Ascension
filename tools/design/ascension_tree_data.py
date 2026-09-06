"""Authored data for the Follower-funded Ascension tree (design-time only).

One source of truth for the node graph. `build_ascension_tree.py` validates it,
writes `ascension_tree.json`, embeds it into `ascension_tree_mockup.html`, and
regenerates the node tables inside `docs/design/ASCENSION_TREE_SPEC.md`.

Node fields
  id, style, subtree, ring, type, name, effect
  ranks      Small nodes: number of purchasable ranks (each rank repeats `effect`)
  req        any-of prerequisites (ids); the node opens when ONE is owned
  req_all    all-of prerequisites (ids)
  req_min    for `req`: how many of the list must be owned (default 1)
  gate_nodes minimum purchased nodes in the same subtree before this opens
  excl       ids this node can never coexist with (sealed on purchase)
  side       fork sides "A"/"B" (a fork pair shares one layout slot)
  parent     mutations / capstone hang off this active
  price      the explicit price line of keystones, revelations, axioms
  op_cost    operating cost text (revelations, ascendant)
  bounds     duration / cooldown / caps / cannot-hit text (revelations, actives)
  needs      implementation budget: subsystems or APIs the node requires
  gutter     edge placement between two subtrees ("a|b") for bridges/witness/ascendant
  ratio      sinks: geometric cost ratio per rank
  cap        sinks: hard cap text
  opens      bridges: the bridge-open node ids the generated attack may count for
Layout is computed from (style, subtree, ring, order within the list); nothing is
hand-placed.
"""

RINGS = [
    {"index": 0, "name": "CORE", "radius": 0, "role": "style core and Doctrine sockets"},
    {"index": 1, "name": "MORTAL", "radius": 150, "role": "Fundamentals"},
    {"index": 2, "name": "BELIEVER", "radius": 290, "role": "Mechanics"},
    {"index": 3, "name": "PROPHET", "radius": 440, "role": "Specialization: forks, keystones, actives, mutations, axioms"},
    {"index": 4, "name": "ICON", "radius": 600, "role": "Revelations and capstones"},
    {"index": 5, "name": "ASCENDANT", "radius": 760, "role": "Witness, bridges, sinks, Ascendant"},
]

# Capital costs: fixed bases (by ring where it matters), escalated per class owned.
CLASSES = {
    "core":       {"base": [0], "escalation": "none", "rate": 0, "refundable": False, "hub_only": False, "permanent": True},
    "doctrine":   {"base": [0], "escalation": "none", "rate": 0, "refundable": False, "hub_only": True, "permanent": True},
    "small":      {"base": [150, 300, 600], "escalation": "linear", "rate": 0.10, "refundable": True, "hub_only": False, "permanent": False},
    "mechanic":   {"base": [2500, 4000, 12000], "escalation": "geometric", "rate": 1.15, "refundable": True, "hub_only": False, "permanent": False},
    "mutation":   {"base": [25000], "escalation": "geometric", "rate": 1.25, "refundable": True, "hub_only": False, "permanent": False},
    "capstone":   {"base": [80000], "escalation": "geometric", "rate": 1.25, "refundable": False, "hub_only": True, "permanent": True},
    "keystone":   {"base": [35000], "escalation": "geometric", "rate": 1.5, "refundable": False, "hub_only": True, "permanent": True},
    "fork":       {"base": [50000], "escalation": "geometric", "rate": 1.5, "refundable": False, "hub_only": True, "permanent": True},
    "active":     {"base": [60000], "escalation": "geometric", "rate": 1.5, "refundable": False, "hub_only": True, "permanent": True},
    "axiom":      {"base": [40000], "escalation": "geometric", "rate": 1.5, "refundable": False, "hub_only": True, "permanent": True},
    "revelation": {"base": [300000], "escalation": "geometric", "rate": 2.0, "refundable": False, "hub_only": True, "permanent": True},
    "witness":    {"base": [300000], "escalation": "geometric", "rate": 2.0, "refundable": False, "hub_only": True, "permanent": True},
    "bridge":     {"base": [2500000], "escalation": "geometric", "rate": 2.0, "refundable": False, "hub_only": True, "permanent": True},
    "ascendant":  {"base": [25000000], "escalation": "none", "rate": 0, "refundable": False, "hub_only": True, "permanent": True},
    "sink":       {"base": [60000], "escalation": "sink", "rate": 1.35, "refundable": False, "hub_only": False, "permanent": True},
}

# Peak-congregation gates: the run's peak Followers must once have reached this.
PEAK_GATES = {"ring3": 30000, "revelation": 500000, "witness": 5000000, "bridge": 5000000, "ascendant": 50000000}

ECONOMY = {
    "reach_ratio": 1.35,
    "reach_from_segment": 3,
    "gross_segment_1": 1500,
    "gross_segment_2plus": 6000,
    "on_hand_table": {1: 1400, 2: 5700, 3: 8900, 5: 16000, 10: 73000, 20: 1500000, 40: 590000000},
    "refund": {"start": 0.50, "decay": 0.90, "floor": 0.10},
    "floor_base": 10, "floor_per_segment": 2, "floor_death_growth": 1.7, "floor_tax": 0.20,
    "wipe_per_normal": 2, "wipe_per_elite": 10,
    "sink_base": 60000,
}

STYLES = [
    {"id": "melee", "name": "Melee", "hue": "#b8452e", "core": "mel_core",
     "subtrees": [
         {"id": "execution", "name": "Execution", "prefix": "mel_exe",
          "fantasy": "I touch something and it dies.",
          "input": "Hunt HP fractions, not bodies: ignore healthy targets, sweep through weakened ones, time Gavel and Decimation for the moment the crowd dips under the Verdict line.",
          "hud": "VERDICT 16% readout; enemies under the threshold get a red tick (reuses the Mark overlay path)."},
         {"id": "momentum", "name": "Momentum", "prefix": "mel_mom",
          "fantasy": "Movement is violence.",
          "input": "Never stop: dash through enemies to prime them, chain dashes on kills, attack mid-stride.",
          "hud": "The existing MOMENTUM row (the tree claims the manifestation noun) plus dash-charge pips."},
         {"id": "bastion", "name": "Bastion", "prefix": "mel_bas",
          "fantasy": "Their violence is mine.",
          "input": "Walk into crowds, hold Guard to bank Force, release it through slashes or the rupture; standing still is rewarded (fights Momentum, pairs with Anchor Rite).",
          "hud": "FORCE 64/100 meter (new noun, hue at least 12 degrees from ward)."},
     ]},
    {"id": "ranged", "name": "Ranged", "hue": "#c9a24a", "core": "rng_core",
     "subtrees": [
         {"id": "precision", "name": "Precision", "prefix": "rng_pre",
          "fantasy": "One shot, perfect consequence.",
          "input": "Keep hitting the same target to Read it, line enemies up for pierce, stay far.",
          "hud": "READ n counter; Read enemies show a reticle."},
         {"id": "barrage", "name": "Barrage", "prefix": "rng_bar",
          "fantasy": "Random bullshit, engineered.",
          "input": "Manage Heat: hold fire to climb tiers, kill to vent, back off before the Jam (or take Overclock and live hot).",
          "hud": "HEAT bar with tier ticks at 25/50/75 and a red Jam zone."},
         {"id": "ordnance", "name": "Ordnance", "prefix": "rng_ord",
          "fantasy": "Prepare the field, then cause a disaster.",
          "input": "Place things before enemies arrive: mines via dashes, Coordinates via cursor, then herd enemies into the timers.",
          "hud": "COORD 2/3 plus mine count; telegraph circles are the language."},
     ]},
    {"id": "magic", "name": "Magic", "hue": "#7c5cff", "core": "mag_core",
     "subtrees": [
         {"id": "invocation", "name": "Invocation", "prefix": "mag_inv",
          "fantasy": "Bring impossible things into existence.",
          "input": "Choose where to fight: near Sigils. Feed them kills, cast through them, Consecrate to reposition the arena.",
          "hud": "SIGILS 3/5 plus Echo pips per Sigil."},
         {"id": "distortion", "name": "Distortion", "prefix": "mag_dis",
          "fantasy": "Reality behaves incorrectly around you.",
          "input": "Gamble on purpose: flip the Coin before committing, cash Debt timing, let enemy projectiles fail.",
          "hud": "DEBT 412 pending damage plus coin state."},
         {"id": "dominion", "name": "Dominion", "prefix": "mag_dom",
          "fantasy": "The battlefield obeys.",
          "input": "The cursor becomes a second body: decide where enemies go, compress them into impact radius, link them so one hit is many, hold ground.",
          "hud": "LINKS 8 plus Sovereign zone timers."},
     ]},
]


def N(id, ring, type, name, effect, **kw):
    node = {"id": id, "ring": ring, "type": type, "name": name, "effect": effect}
    node.update(kw)
    return node


NODES = []

# ---------------------------------------------------------------------------
# Cores and Doctrine sockets (free; the sockets are filled by the existing
# Ascension Doctrine picks after segments 3 / 6 / 9, never bought).
# ---------------------------------------------------------------------------
for style, core in (("melee", "mel_core"), ("ranged", "rng_core"), ("magic", "mag_core")):
    NODES.append(N(core, 0, "core", style.upper(), "Your starting style. Owned from minute one.", style=style, subtree=None))
    for stage, seg in (("method", 3), ("doctrine", 6), ("apotheosis", 9)):
        NODES.append(N(f"{core[:3]}_doc_{stage}", 0, "doctrine", stage.capitalize(),
                       f"Doctrine socket: filled by the free 1-of-3 pick after segment {seg}.",
                       style=style, subtree=None, segment=seg))

# ---------------------------------------------------------------------------
# MELEE - EXECUTION
# ---------------------------------------------------------------------------
S = dict(style="melee", subtree="execution")
NODES += [
    N("mel_exe_01", 1, "small", "Heavy Hand", "+6% melee damage per rank.", ranks=3, req=["mel_core"], **S),
    N("mel_exe_02", 1, "mechanic", "First Verdict", "Grants an execute threshold of 10%: a melee hit that leaves a normal enemy at or below 10% HP kills it, ignoring armor; overkill is captured.", req=["mel_exe_01"], needs=["execute_threshold channel", "overkill on EnemyDeathContext"], **S),
    N("mel_exe_03", 1, "small", "Lower Bar", "+3% execute threshold per rank.", ranks=3, req=["mel_exe_02"], **S),
    N("mel_exe_04", 2, "mechanic", "Spillover", "Overkill from a melee kill hits the nearest enemy within 90 px.", req=["mel_exe_02"], needs=["nearest_enemy"], **S),
    N("mel_exe_05", 2, "small", "Clean Cut", "Executions refund 25% of slash cooldown per rank.", ranks=2, req=["mel_exe_03", "mel_exe_04"], needs=["refund_attack_cooldown API"], **S),
    N("mel_exe_06", 2, "mechanic", "Elite Sentence", "The execute threshold applies to elites at half value.", req=["mel_exe_04"], **S),
    N("mel_exe_07", 2, "mechanic", "Bloodletting", "Each execution grants +2% threshold for 4 s (5 stacks, refreshing).", req=["mel_exe_05", "mel_exe_06"], **S),
    N("mel_exe_08", 2, "small", "Reservoir", "Spillover carries +25% of the overkill per rank (base 100%).", ranks=2, req=["mel_exe_04"], **S),
    N("mel_exe_fork_a", 3, "fork", "Quiet Sentence", "Your first hit on any enemy Sentences it for 3 s; a second melee hit on a Sentenced enemy executes at 2x threshold.", side="A", req=["mel_exe_07"], excl=["mel_exe_fork_b"], needs=["per-handle Sentenced status"], **S),
    N("mel_exe_fork_b", 3, "fork", "Collective Sentence", "Executions cleave: 60% of the victim's max HP to enemies in a 70 px arc.", side="B", req=["mel_exe_07"], excl=["mel_exe_fork_a"], **S),
    N("mel_exe_key", 3, "keystone", "Only the Weak Die", "+12% execute threshold.", price="-25% damage against enemies above 50% HP.", req=["mel_exe_07"], gate_nodes=5, **S),
    N("mel_exe_act", 3, "active", "Gavel", "Q: 0.25 s windup, then a 90 px radius strike at 3.0x slash damage that executes at 2x threshold inside the radius.", bounds="6 s cooldown.", req=["mel_exe_06"], gate_nodes=4, **S),
    N("mel_exe_mut1", 3, "mutation", "Public Execution", "Gavel overkill spills to every enemy within 120 px.", parent="mel_exe_act", req=["mel_exe_act"], **S),
    N("mel_exe_mut2", 3, "mutation", "Swift Justice", "Gavel cooldown 6 -> 3.5 s, radius 90 -> 62 px.", parent="mel_exe_act", req=["mel_exe_act"], **S),
    N("mel_exe_mut3", 3, "mutation", "Tithe of the Condemned", "+1 Follower per 10 Gavel executions (cap 20 per segment).", parent="mel_exe_act", req=["mel_exe_act"], **S),
    N("mel_exe_cap", 4, "capstone", "The Verdict Stands", "A Gavel that kills 5 or more grants +10% threshold for 6 s.", parent="mel_exe_act", req=["mel_exe_mut1", "mel_exe_mut2", "mel_exe_mut3"], req_min=2, **S),
    N("mel_exe_axiom", 3, "axiom", "Violence Propagates", "Spillover applies to kills of any style you can produce.", price="Spill range 90 -> 60 px for non-melee kills.", req=["mel_exe_08"], gate_nodes=6, **S),
    N("mel_exe_rev", 4, "revelation", "DECIMATION", "V: 0.6 s stationary cast. Every normal enemy in the camera rect (+64 px) at or below the threshold dies; elites at or below half the threshold lose 50% max HP.", bounds="Max 150 targets (lowest HP fraction first); cannot touch bosses; 45 s cooldown.", op_cost="1 Follower per 4 executed (min 5), previewed on the HUD before commit; refuses if unaffordable.", req=["mel_exe_act"], gate_nodes=8, needs=["camera-rect gather"], **S),
]

# ---------------------------------------------------------------------------
# MELEE - MOMENTUM
# ---------------------------------------------------------------------------
S = dict(style="melee", subtree="momentum")
NODES += [
    N("mel_mom_01", 1, "small", "Light Feet", "+4% move speed per rank.", ranks=3, req=["mel_core"], **S),
    N("mel_mom_02", 1, "mechanic", "Stride", "Claims the Momentum meter: a dash adds +25% Momentum; slashes deal +10% damage per 25% Momentum (cap +40%).", req=["mel_mom_01"], needs=["claim ManifestationState.momentum"], **S),
    N("mel_mom_03", 1, "small", "Second Wind", "Dash cooldown -10% per rank.", ranks=3, req=["mel_mom_02"], needs=["dash_cooldown_multiplier poll"], **S),
    N("mel_mom_04", 2, "mechanic", "Passing Blade", "The dash path (40 px wide) deals 0.6x slash damage and Primes enemies hit: their next melee hit taken is +50% (3 s).", req=["mel_mom_02"], needs=["gather_in_sector along dash", "per-handle Primed status"], **S),
    N("mel_mom_05", 2, "small", "Reach", "Slash arc radius +6 px per rank while Momentum is at or above 50%.", ranks=3, req=["mel_mom_04"], **S),
    N("mel_mom_06", 2, "mechanic", "Kill Reset", "A melee kill cuts the remaining dash cooldown by 0.5 s (0.3 s ICD).", req=["mel_mom_03", "mel_mom_04"], **S),
    N("mel_mom_07", 2, "small", "Running Cut", "Slash cooldown -5% per rank while moving.", ranks=2, req=["mel_mom_05"], **S),
    N("mel_mom_08", 3, "mechanic", "Afterimage", "At Momentum >= 75% every slash repeats 0.25 s later at its origin for 50% (generation 1, NO_AFTERIMAGE).", req=["mel_mom_06", "mel_mom_07"], **S),
    N("mel_mom_fork_a", 3, "fork", "Unbroken Motion", "Momentum does not decay for 2 s after a kill.", price="Stability can never fill.", side="A", req=["mel_mom_08"], excl=["mel_mom_fork_b"], **S),
    N("mel_mom_fork_b", 3, "fork", "Thousand Cuts", "At Momentum >= 90% slashes echo once at 35% (generation 1).", price="Momentum drains 10%/s while attacking.", side="B", req=["mel_mom_08"], excl=["mel_mom_fork_a"], **S),
    N("mel_mom_key", 3, "keystone", "Never Stop", "The dash gains a second charge (each 1.6 s, i-frames kept).", price="Slashes deal -30% while Momentum is below 25%.", req=["mel_mom_06"], gate_nodes=5, excl=["mel_bas_key", "mag_dom_key"], needs=["dash charges"], **S),
    N("mel_mom_act", 3, "active", "Lunge", "Q: 240 px dash toward the aim point ending in a 1.5x 180-degree slash; counts as a dash (emits player_dashed).", bounds="5 s cooldown.", req=["mel_mom_04"], gate_nodes=4, **S),
    N("mel_mom_mut1", 3, "mutation", "Rebound", "A Lunge kill resets Lunge's cooldown (1.0 s ICD).", parent="mel_mom_act", req=["mel_mom_act"], **S),
    N("mel_mom_mut2", 3, "mutation", "Wake", "The Lunge path deals Passing Blade at 1.0x, 60 px wide.", parent="mel_mom_act", req=["mel_mom_act"], **S),
    N("mel_mom_mut3", 3, "mutation", "Shadow Step", "Lunge leaves an Afterimage that slashes twice over 0.5 s.", parent="mel_mom_act", req=["mel_mom_act"], **S),
    N("mel_mom_cap", 4, "capstone", "Blur", "After a Lunge: 0.6 s of 100% evasion and +25% move speed for 2 s.", parent="mel_mom_act", req=["mel_mom_mut1", "mel_mom_mut2", "mel_mom_mut3"], req_min=2, **S),
    N("mel_mom_rev", 4, "revelation", "NO DISTANCE BETWEEN US", "V: for 4 s each slash first teleports you to the nearest not-yet-hit normal or elite within 400 px (one hop per 0.12 s, 0.1 s i-frames per landing); ends early after 0.5 s without a target.", bounds="Cannot hop to bosses; 60 s cooldown; Momentum set to 0 on end.", op_cost="3% of current Followers (min 10).", req=["mel_mom_act"], gate_nodes=8, needs=["teleport with i-frames API"], **S),
]

# ---------------------------------------------------------------------------
# MELEE - BASTION
# ---------------------------------------------------------------------------
S = dict(style="melee", subtree="bastion")
NODES += [
    N("mel_bas_01", 1, "small", "Plate", "+3 armor per rank.", ranks=3, req=["mel_core"], **S),
    N("mel_bas_02", 1, "mechanic", "Stored Force", "Claims Force (cap 100): 40% of post-armor damage taken becomes Force (1 per 2 HP); a slash consumes up to 30 Force for +1% damage each.", req=["mel_bas_01"], needs=["Force resource on AscensionState"], **S),
    N("mel_bas_03", 1, "small", "Thick Skin", "Damage taken -4% per rank.", ranks=3, req=["mel_bas_02"], **S),
    N("mel_bas_04", 2, "small", "Vessel", "Force cap +20 per rank.", ranks=3, req=["mel_bas_02"], **S),
    N("mel_bas_05", 2, "mechanic", "Surrounded", "+5% melee damage per enemy within 90 px at swing time (max +40%).", req=["mel_bas_03"], **S),
    N("mel_bas_06", 2, "mechanic", "Immovable", "Displacement of the player is negated; each resisted knockback grants +8 Force and a 70 px 0.4x shockwave.", req=["mel_bas_04", "mel_bas_05"], needs=["player displacement hook"], **S),
    N("mel_bas_07", 2, "small", "Slow Leak", "Force decay -3%/s per rank (base 6%/s after 3 s idle).", ranks=2, req=["mel_bas_04"], **S),
    N("mel_bas_08", 3, "mechanic", "Return to Sender", "Enemy projectiles within 48 px during a slash are consumed: +5 Force and +10% slash damage each (max 5).", req=["mel_bas_06"], needs=["consume_enemy_projectiles_in_radius"], **S),
    N("mel_bas_fork_a", 3, "fork", "Pressure Vessel", "Force at cap auto-detonates: 160 px burst dealing Force x2.5, Force -> 0.", side="A", req=["mel_bas_08"], excl=["mel_bas_fork_b"], **S),
    N("mel_bas_fork_b", 3, "fork", "Overpressure", "Force may exceed its cap by 50%; slashes consume up to 60 Force; no auto-detonate.", side="B", req=["mel_bas_08"], excl=["mel_bas_fork_a"], **S),
    N("mel_bas_key", 3, "keystone", "Anvil", "Standing still for 0.5 s: damage taken -35% and Force gain x2.", price="Move speed -15%, dash cooldown +0.6 s.", req=["mel_bas_07"], gate_nodes=5, excl=["mel_mom_key"], **S),
    N("mel_bas_act", 3, "active", "Guard", "Hold Q: move -50%, damage taken -60%, damage taken becomes Force at 100%, projectiles touching a 72 px ring are consumed (+3 Force).", bounds="Drains 4 Force/s and ends at 0; no cooldown.", req=["mel_bas_05"], gate_nodes=4, needs=["hold-input semantics for Q"], **S),
    N("mel_bas_mut1", 3, "mutation", "Bulwark", "Melee attackers striking the Guard ring are stunned 0.4 s (2 s ICD per enemy).", parent="mel_bas_act", req=["mel_bas_act"], **S),
    N("mel_bas_mut2", 3, "mutation", "Counterweight", "Releasing Guard after 1 s fires a 2.0x 145-degree shockwave spending 50% Force.", parent="mel_bas_act", req=["mel_bas_act"], **S),
    N("mel_bas_mut3", 3, "mutation", "Martyr's Ledger", "Guard also converts 2% max HP/s into +6 Force/s (never below 30% HP).", parent="mel_bas_act", req=["mel_bas_act"], **S),
    N("mel_bas_cap", 4, "capstone", "Living Rampart", "Guard's drain is removed; Force gain while guarding +50%.", parent="mel_bas_act", req=["mel_bas_mut1", "mel_bas_mut2", "mel_bas_mut3"], req_min=2, **S),
    N("mel_bas_axiom", 3, "axiom", "Pressure Is Power", "Damage taken fills Force under any style; ranged and magic attacks may consume Force at half rate.", price="Force cap -20.", req=["mel_bas_07"], gate_nodes=6, **S),
    N("mel_bas_rev", 4, "revelation", "THE WORLD BREAKS FIRST", "V: needs 40+ Force. A rupture of radius 160 + 2.4 x Force (cap 400) deals Force x4 plus 30% of the damage you took in the last 10 s, knockback 600, stun 0.8 s; Force -> 0.", bounds="Bosses capped at 15% max HP; 30 s cooldown.", op_cost="2% of current Followers, 4% if Force was at cap.", req=["mel_bas_act"], gate_nodes=8, needs=["10 s damage-taken ledger"], **S),
]

# ---------------------------------------------------------------------------
# RANGED - PRECISION
# ---------------------------------------------------------------------------
S = dict(style="ranged", subtree="precision")
NODES += [
    N("rng_pre_01", 1, "small", "Rifling", "Projectile speed +10% per rank.", ranks=3, req=["rng_core"], **S),
    N("rng_pre_02", 1, "mechanic", "Read the Target", "The third consecutive hit on one enemy exposes a Weak Point for 4 s: hits deal x1.4 and report as critical (Lucky Crit rolls untouched).", req=["rng_pre_01"], needs=["per-handle hit streak + Read record"], **S),
    N("rng_pre_03", 1, "small", "Sharp Eye", "Weak Point multiplier +0.1 per rank.", ranks=3, req=["rng_pre_02"], **S),
    N("rng_pre_04", 2, "small", "Long Arm", "Range +60 px per rank.", ranks=2, req=["rng_pre_01"], **S),
    N("rng_pre_05", 2, "small", "Distance Is Contempt", "+8% damage per rank against targets 300+ px away.", ranks=3, req=["rng_pre_04"], **S),
    N("rng_pre_06", 2, "mechanic", "Penetrator", "Pierce +1; +15% damage per enemy already pierced (max +60%).", req=["rng_pre_03"], **S),
    N("rng_pre_07", 2, "mechanic", "Second Read", "Hits on a Weak Point gain +1 pierce; the enemy behind becomes Read after one hit.", req=["rng_pre_06"], **S),
    N("rng_pre_08", 2, "small", "Held Breath", "Weak Point duration +1 s per rank.", ranks=2, req=["rng_pre_03"], **S),
    N("rng_pre_fork_a", 3, "fork", "Impossible Shot", "A projectile expiring without a hit retargets once to the nearest enemy within 240 px (generation 1, NO_RETARGET).", side="A", req=["rng_pre_07"], excl=["rng_pre_fork_b"], needs=["projectile expire callback + retarget API"], **S),
    N("rng_pre_fork_b", 3, "fork", "Terminal Geometry", "After piercing a Read enemy the projectile bends up to 45 degrees toward the nearest other Read enemy within 200 px (once).", side="B", req=["rng_pre_07"], excl=["rng_pre_fork_a"], needs=["projectile bend API"], **S),
    N("rng_pre_key", 3, "keystone", "One Bullet", "Ranged cooldown 0.22 -> 0.44 s, damage x2.4, pierce +2.", price="Every extra-projectile source is disabled (the shotgun mutation included).", req=["rng_pre_06"], gate_nodes=5, excl=["rng_bar_key"], **S),
    N("rng_pre_act", 3, "active", "Ballistic Solution", "Q: 0.5 s stop, then one 5x infinite-pierce shot (speed 1400) along the line through the most enemies in a 60-degree aim cone.", bounds="8 s cooldown.", req=["rng_pre_06"], gate_nodes=4, **S),
    N("rng_pre_mut1", 3, "mutation", "Twin Solution", "Two lines (best and second best, at least 20 degrees apart).", parent="rng_pre_act", req=["rng_pre_act"], **S),
    N("rng_pre_mut2", 3, "mutation", "Executioner's Solution", "Normals at or below 25% HP on the line die outright.", parent="rng_pre_act", req=["rng_pre_act"], **S),
    N("rng_pre_mut3", 3, "mutation", "Quick Solution", "No stop; cooldown 8 -> 5 s; damage 5x -> 3.5x.", parent="rng_pre_act", req=["rng_pre_act"], **S),
    N("rng_pre_cap", 4, "capstone", "Perfect Solution", "Every enemy hit by the Solution becomes Read; kills refund 2 s of its cooldown.", parent="rng_pre_act", req=["rng_pre_mut1", "rng_pre_mut2", "rng_pre_mut3"], req_min=2, **S),
    N("rng_pre_axiom", 3, "axiom", "Nothing Is Wasted", "Any projectile or magic impact that hits nothing retargets once to the nearest enemy within 200 px (generation +1, NO_RETARGET).", price="Base range -10%.", req=["rng_pre_08"], gate_nodes=6, **S),
    N("rng_pre_rev", 4, "revelation", "LINE OF JUDGEMENT", "V: 1.0 s designation (enemies at 15% time scale while you aim) computes up to three lines maximizing on-screen intersections; on release each fires as an 8x hitscan beam (24 px wide) 0.2 s apart.", bounds="Max 60 targets per line; bosses capped at 10% max HP per line; 50 s cooldown.", op_cost="5% of current Followers (min 15).", req=["rng_pre_act"], gate_nodes=8, needs=["hitscan helper", "local time scale during designation"], **S),
]

# ---------------------------------------------------------------------------
# RANGED - BARRAGE
# ---------------------------------------------------------------------------
S = dict(style="ranged", subtree="barrage")
NODES += [
    N("rng_bar_01", 1, "small", "Trigger Discipline", "Ranged cooldown -4% per rank.", ranks=3, req=["rng_core"], **S),
    N("rng_bar_02", 1, "mechanic", "Heat", "Claims Heat: +6 per shot, decays 15/s after 0.6 s idle. At 25: +10% rate; 50: +20% and +1 pellet; 75: +30% and +2; 100: Jam for 1.2 s and Heat -> 0.", req=["rng_bar_01"], needs=["Heat resource", "extra_projectiles on the hit profile"], **S),
    N("rng_bar_03", 1, "small", "Heat Sink", "Jam duration -0.2 s per rank.", ranks=3, req=["rng_bar_02"], **S),
    N("rng_bar_04", 2, "mechanic", "Fragmentation", "Ranged kills release 2 fragments (generation 1, 30%, seeking the nearest enemy within 140 px, NO_FRAGMENT).", req=["rng_bar_02"], needs=["spawn-from-point API"], **S),
    N("rng_bar_05", 2, "small", "Coolant", "Heat decay +3/s per rank.", ranks=3, req=["rng_bar_03"], **S),
    N("rng_bar_06", 2, "small", "Kill Reload", "Kills vent 8 Heat per rank.", ranks=2, req=["rng_bar_04"], **S),
    N("rng_bar_07", 2, "mechanic", "Ricochet", "Projectiles bounce once toward the nearest enemy within 160 px at 60% (generation 1, NO_RICOCHET).", req=["rng_bar_04"], needs=["on-hit retarget API"], **S),
    N("rng_bar_08", 3, "mechanic", "Ricochets Ricochet", "+1 bounce (generation 2, budget 2), -20% per bounce.", req=["rng_bar_07"], **S),
    N("rng_bar_fork_a", 3, "fork", "ONE WEAPON, INFINITE BULLETS", "The 75 tier becomes +60% rate and +3 pellets.", price="Jam lasts 2.0 s.", side="A", req=["rng_bar_08"], excl=["rng_bar_fork_b"], **S),
    N("rng_bar_fork_b", 3, "fork", "INFINITE WEAPONS, ONE TARGET", "At Heat >= 50 every third shot also fires from a Crossfire point on a 380 px ring, aimed at your target (generation 1, CROSSFIRE, 70%).", side="B", req=["rng_bar_08"], excl=["rng_bar_fork_a"], **S),
    N("rng_bar_key", 3, "keystone", "Overclock", "The Jam is removed; Heat cap 150 with a fourth tier at 100 (+40% rate, +3 pellets).", price="Damage taken +35% and decay only 5/s while Heat is 100 or more.", req=["rng_bar_05"], gate_nodes=5, excl=["rng_pre_key"], **S),
    N("rng_bar_act", 3, "active", "Suppressive Burst", "Q: 1.5 s at +150% fire rate with no Heat gain; ends by setting Heat to 75.", bounds="10 s cooldown.", req=["rng_bar_04"], gate_nodes=4, **S),
    N("rng_bar_mut1", 3, "mutation", "Sustained", "Burst lasts 2.5 s instead of 1.5 s.", parent="rng_bar_act", req=["rng_bar_act"], **S),
    N("rng_bar_mut2", 3, "mutation", "Vented", "Burst ends at Heat 25 instead of 75, venting a 120 px 1.0x burn nova.", parent="rng_bar_act", req=["rng_bar_act"], **S),
    N("rng_bar_mut3", 3, "mutation", "Enfilade", "Every Burst shot ricochets (+1, generation budget respected).", parent="rng_bar_act", req=["rng_bar_act"], **S),
    N("rng_bar_cap", 4, "capstone", "Belt-Fed", "Burst kills extend it by 0.15 s each (max +2 s).", parent="rng_bar_act", req=["rng_bar_mut1", "rng_bar_mut2", "rng_bar_mut3"], req_min=2, **S),
    N("rng_bar_axiom", 3, "axiom", "Heat Is Universal", "Slashes and casts add +4 Heat; Heat rate tiers apply to every style's attack cooldown.", price="The Jam applies to every style.", req=["rng_bar_06"], gate_nodes=6, **S),
    N("rng_bar_rev", 4, "revelation", "ABSOLUTE SUPPRESSION", "V: for 5 s every shot you fire spawns 3 more from three rotating Crossfire points on a 420 px ring (generation 1, CROSSFIRE, 60%, no fragments or ricochets); Heat is frozen.", bounds="Cap 300 secondary shots; Crossfire never targets bosses; 60 s cooldown.", op_cost="1 Follower per 20 shots spawned (min 8), charged on end.", req=["rng_bar_act"], gate_nodes=8, **S),
]

# ---------------------------------------------------------------------------
# RANGED - ORDNANCE
# ---------------------------------------------------------------------------
S = dict(style="ranged", subtree="ordnance")
NODES += [
    N("rng_ord_01", 1, "small", "Blast Radius", "Ordnance blast radius +8% per rank.", ranks=3, req=["rng_core"], **S),
    N("rng_ord_02", 1, "mechanic", "Impact Fuse", "Every fifth ranged hit drops a Shell at the impact point (0.6 s delay, radius 80, 1.8x, generation 1, ORDNANCE, NO_ORDNANCE_TRIGGER).", req=["rng_ord_01"], needs=["pooled Shell scene: telegraph + delayed blast"], **S),
    N("rng_ord_03", 1, "small", "Shorter Fuse", "Shell delay -0.1 s per rank.", ranks=2, req=["rng_ord_02"], **S),
    N("rng_ord_04", 2, "mechanic", "Caltrops", "Dashing drops a Mine at the start point (arms in 0.5 s, radius 70, 1.5x, 12 s life, max 6).", req=["rng_ord_02"], needs=["pooled Mine scene"], **S),
    N("rng_ord_05", 2, "small", "Magazine", "Max mines +2 per rank.", ranks=2, req=["rng_ord_04"], **S),
    N("rng_ord_06", 2, "mechanic", "Fracture", "Blast hits apply Fractured: +6% damage taken per stack (max 5, 5 s).", req=["rng_ord_03"], needs=["per-handle Fractured status"], **S),
    N("rng_ord_07", 2, "mechanic", "Secondary Detonation", "A killing blast spawns one follow-up Shell at the victim (generation +1, budget 2).", req=["rng_ord_06"], **S),
    N("rng_ord_08", 3, "small", "Heavier Shells", "Blast damage +10% per rank.", ranks=3, req=["rng_ord_07"], **S),
    N("rng_ord_fork_a", 3, "fork", "Saturation Coordinates", "Every 3 s the densest cluster (6+ enemies within 100 px, scanned at 10 Hz) is auto-designated: 3 Shells over 1 s.", side="A", req=["rng_ord_08"], excl=["rng_ord_fork_b"], needs=["cluster density scan"], **S),
    N("rng_ord_fork_b", 3, "fork", "Walking Barrage", "While moving, a Shell lands 120 px behind you every 0.8 s.", side="B", req=["rng_ord_08"], excl=["rng_ord_fork_a"], **S),
    N("rng_ord_key", 3, "keystone", "Beacon Doctrine", "Elites hit by three blasts become Beacons: a Shell strikes them every 1.5 s until death (max 3 Beacons).", price="Mines and Impact Fuse deal -50% to normals.", req=["rng_ord_06"], gate_nodes=5, needs=["per-handle Beacon status"], **S),
    N("rng_ord_act", 3, "active", "Designate", "Q: place a Coordinate at the cursor (max 3, 15 s). Press on an existing one: it receives 4 Shells over 1.6 s at 2.0x.", bounds="12 s cooldown from firing.", req=["rng_ord_04"], gate_nodes=4, needs=["Coordinates list"], **S),
    N("rng_ord_mut1", 3, "mutation", "Saturation", "4 -> 7 Shells, scattered over 160 px.", parent="rng_ord_act", req=["rng_ord_act"], **S),
    N("rng_ord_mut2", 3, "mutation", "Guidance", "Coordinates track the nearest elite; 4 -> 3 Shells at 3.0x.", parent="rng_ord_act", req=["rng_ord_act"], **S),
    N("rng_ord_mut3", 3, "mutation", "Cascade", "Each Designate kill adds a Shell to the sequence (max +6).", parent="rng_ord_act", req=["rng_ord_act"], **S),
    N("rng_ord_cap", 4, "capstone", "Fire for Effect", "Coordinates persist after firing; cooldown 12 -> 8 s.", parent="rng_ord_act", req=["rng_ord_mut1", "rng_ord_mut2", "rng_ord_mut3"], req_min=2, **S),
    N("rng_ord_rev", 4, "revelation", "TOTAL FIRE MISSION", "V: 1.2 s grid telegraph over the screen, then 24 Shells over 4 s on a density-biased stratified grid (3.0x, radius 110, 0.16 s stagger).", bounds="90 px player-safe radius per Shell; bosses capped at 12% max HP total; 75 s cooldown.", op_cost="6% of current Followers (min 20) plus 1 per Cascade Shell.", req=["rng_ord_act"], gate_nodes=8, **S),
]

# ---------------------------------------------------------------------------
# MAGIC - INVOCATION
# ---------------------------------------------------------------------------
S = dict(style="magic", subtree="invocation")
NODES += [
    N("mag_inv_01", 1, "small", "Wider Sigil", "Magic impact radius +6 px per rank.", ranks=3, req=["mag_core"], **S),
    N("mag_inv_02", 1, "mechanic", "Leave a Sigil", "Every fourth impact leaves a Sigil (8 s, max 3) that pulses a 0.35x 48 px impact every 1.0 s (generation 1, SIGIL, NO_SIGIL_SPAWN).", req=["mag_inv_01"], needs=["pooled Sigil scene"], **S),
    N("mag_inv_03", 1, "small", "Endure", "Sigil life +3 s per rank.", ranks=3, req=["mag_inv_02"], **S),
    N("mag_inv_04", 2, "small", "Congregation", "Max Sigils +1 per rank.", ranks=2, req=["mag_inv_03"], **S),
    N("mag_inv_05", 2, "mechanic", "Fed by Death", "Kills within 90 px of a Sigil grow it: +5% pulse damage and +2 px radius (max +100% / +40 px).", req=["mag_inv_02"], needs=["Sigil growth record"], **S),
    N("mag_inv_06", 2, "mechanic", "Echo Shrine", "Casting within 70 px of a Sigil stores an Echo (max 3), released as full impacts when it expires or is triggered.", req=["mag_inv_05"], needs=["Echo store"], **S),
    N("mag_inv_07", 2, "small", "Warm Circle", "+6% magic damage per rank per Sigil within 150 px (max 3 counted).", ranks=2, req=["mag_inv_04"], **S),
    N("mag_inv_08", 3, "small", "Pulse Rate", "Sigil pulse interval -0.1 s per rank.", ranks=2, req=["mag_inv_06"], **S),
    N("mag_inv_fork_a", 3, "fork", "Autonomous Invocation", "Sigils aim: pulses become 0.5x impacts thrown at the nearest enemy within 220 px.", side="A", req=["mag_inv_08"], excl=["mag_inv_fork_b"], **S),
    N("mag_inv_fork_b", 3, "fork", "Recursive Ritual", "A fully grown Sigil splits once: a child at 60% (generation 2, budget 1, cannot split) at the nearest cluster within 200 px.", side="B", req=["mag_inv_08"], excl=["mag_inv_fork_a"], **S),
    N("mag_inv_key", 3, "keystone", "Inherit the Word", "Sigil pulses run apply_to_magic_impact and fire player_hit_landed as yours, so item on-hit rules trigger (0.5 s ICD per Sigil).", price="Your direct casts deal -25%.", req=["mag_inv_07"], gate_nodes=5, needs=["as-player hook proxy with SIGIL origin"], **S),
    N("mag_inv_act", 3, "active", "Consecrate", "Q: place a Sigil at the cursor (within 260 px) now and pulse every Sigil immediately.", bounds="7 s cooldown.", req=["mag_inv_05"], gate_nodes=4, **S),
    N("mag_inv_mut1", 3, "mutation", "Great Sigil", "The Consecrated Sigil has 1.5x radius and damage and counts as 2 toward the cap.", parent="mag_inv_act", req=["mag_inv_act"], **S),
    N("mag_inv_mut2", 3, "mutation", "Beacon of Ruin", "Consecrate also releases every stored Echo.", parent="mag_inv_act", req=["mag_inv_act"], **S),
    N("mag_inv_mut3", 3, "mutation", "Wandering Sigil", "The Consecrated Sigil follows you at 120 px/s (one at a time).", parent="mag_inv_act", req=["mag_inv_act"], **S),
    N("mag_inv_cap", 4, "capstone", "Liturgy", "Cooldown 7 -> 4 s; Consecrated Sigils never expire while you are within 200 px.", parent="mag_inv_act", req=["mag_inv_mut1", "mag_inv_mut2", "mag_inv_mut3"], req_min=2, **S),
    N("mag_inv_rev", 4, "revelation", "THE HOST", "V: for 6 s every Sigil duplicates once (60 px offset, generation 2, cannot grow or split, dies with the Host) and all Sigils pulse at 3x rate; Host copies release their Echoes on end.", bounds="Cap 12 Sigils on the field; bosses capped at 10% max HP total; 70 s cooldown.", op_cost="4% of current Followers (min 15) plus 1 per Sigil duplicated.", req=["mag_inv_act"], gate_nodes=8, **S),
]

# ---------------------------------------------------------------------------
# MAGIC - DISTORTION
# ---------------------------------------------------------------------------
S = dict(style="magic", subtree="distortion")
NODES += [
    N("mag_dis_01", 1, "small", "Improbable", "Luck +6% per rank.", ranks=3, req=["mag_core"], **S),
    N("mag_dis_02", 1, "mechanic", "Twice", "12% chance (Luck-scaled, cap 20%) that an impact bursts again 0.15 s later at 50% (generation 1, NO_TWICE).", req=["mag_dis_01"], **S),
    N("mag_dis_03", 1, "small", "Lingering Wrong", "Durations of statuses you apply +10% per rank.", ranks=2, req=["mag_dis_02"], **S),
    N("mag_dis_04", 2, "mechanic", "Misfire", "Enemy projectiles within 90 px have a 15%/s chance each to be consumed (10 Hz poll, random subset).", req=["mag_dis_02"], **S),
    N("mag_dis_05", 2, "small", "Denial", "Misfire chance +5% per rank.", ranks=2, req=["mag_dis_04"], **S),
    N("mag_dis_06", 2, "mechanic", "Causal Debt", "Each hit re-applies 20% of its damage after 2.0 s (deferred ledger, max 3 pending per enemy; voided on death).", req=["mag_dis_03"], needs=["deferred damage ledger"], **S),
    N("mag_dis_07", 2, "small", "Interest", "Debt +5% per rank.", ranks=3, req=["mag_dis_06"], **S),
    N("mag_dis_08", 3, "mechanic", "Contradiction", "An enemy holding two or more of burn, stun, slow, Fractured, Primed, Read or Debt takes +15% from you.", req=["mag_dis_05", "mag_dis_07"], needs=["per-handle status registry"], **S),
    N("mag_dis_fork_a", 3, "fork", "Revision", "Once per 12 s a hit of 25%+ max HP is undone (healed back, 0.5 s i-frames).", price="1 Follower per Revision.", side="A", req=["mag_dis_08"], excl=["mag_dis_fork_b"], **S),
    N("mag_dis_fork_b", 3, "fork", "Inheritance", "Pending Debt on a dying enemy transfers to the nearest enemy within 120 px (generation +1, budget 2).", side="B", req=["mag_dis_08"], excl=["mag_dis_fork_a"], **S),
    N("mag_dis_key", 3, "keystone", "Loaded Dice", "Lucky Crit cap 8% -> 16%, multiplier 1.5x -> 2.0x.", price="Every failed Luck roll costs 1% max HP (0.2 s ICD).", req=["mag_dis_07"], gate_nodes=5, needs=["Lucky Crit cap and multiplier as parameters"], **S),
    N("mag_dis_act", 3, "active", "Coin", "Q: a 50/50 flip (Luck-biased up to 65/35). HEADS: 3 s of guaranteed Lucky Crits and Debt timers at 0.3 s. TAILS: -10% current HP and +40% magic damage for 3 s.", bounds="9 s cooldown.", req=["mag_dis_04"], gate_nodes=4, needs=["LuckResolver force-success window"], **S),
    N("mag_dis_mut1", 3, "mutation", "Weighted", "HEADS bias +10%.", parent="mag_dis_act", req=["mag_dis_act"], **S),
    N("mag_dis_mut2", 3, "mutation", "Double or Nothing", "TAILS may be re-flipped within 1 s; a second TAILS costs 20% HP.", parent="mag_dis_act", req=["mag_dis_act"], **S),
    N("mag_dis_mut3", 3, "mutation", "House Edge", "Either result consumes all enemy projectiles within 160 px.", parent="mag_dis_act", req=["mag_dis_act"], **S),
    N("mag_dis_cap", 4, "capstone", "Rigged", "Cooldown 9 -> 6 s; HEADS refunds 25% of the Revelation cooldown (once per 30 s).", parent="mag_dis_act", req=["mag_dis_mut1", "mag_dis_mut2", "mag_dis_mut3"], req_min=2, **S),
    N("mag_dis_axiom", 3, "axiom", "Effects Have Memory", "Statuses you apply under any style have a 20% chance to reapply once at 50% duration when they expire.", price="Base status durations -15%.", req=["mag_dis_03"], gate_nodes=6, **S),
    N("mag_dis_rev", 4, "revelation", "CONSENSUS FAILURE", "V: for 4 s every Luck check you make succeeds, Twice always fires, Debt applies instantly, enemy projectiles within 220 px are consumed, and enemy melee against you misses.", bounds="Explicitly excluded: cooldown resets, item internal cooldowns, boss arena mechanics; generation budgets enforced. 90 s cooldown, then 6 s of forced Luck failure (banks Misfortune for Broken Providence on purpose).", op_cost="8% of current Followers (min 25).", req=["mag_dis_act"], gate_nodes=8, needs=["evasion override"], **S),
]

# ---------------------------------------------------------------------------
# MAGIC - DOMINION
# ---------------------------------------------------------------------------
S = dict(style="magic", subtree="dominion")
NODES += [
    N("mag_dom_01", 1, "mechanic", "Gravity Well", "Impacts pull enemies in a 120 px ring inward by 40 px and slow them 30% for 1.5 s.", req=["mag_core"], needs=["apply_knockback inward"], **S),
    N("mag_dom_02", 1, "small", "Heavier", "Pull +10 px per rank.", ranks=3, req=["mag_dom_01"], **S),
    N("mag_dom_03", 1, "small", "Lingering Weight", "Slow +0.5 s per rank.", ranks=2, req=["mag_dom_01"], **S),
    N("mag_dom_04", 2, "mechanic", "Collision", "Pulled enemies ending within 14 px of each other take 0.4x impact damage each (once per pull, max 20 pairs).", req=["mag_dom_02"], needs=["pairwise collision check"], **S),
    N("mag_dom_05", 2, "mechanic", "Bind", "Enemies hit by one impact become Linked (up to 6, 6 s): Linked enemies share slows and stuns.", req=["mag_dom_03"], needs=["Link registry"], **S),
    N("mag_dom_06", 2, "small", "Longer Chain", "Link +2 s per rank; rank 2 also raises members 6 -> 8.", ranks=2, req=["mag_dom_05"], **S),
    N("mag_dom_07", 2, "mechanic", "Collective Burden", "25% of damage dealt to a Linked enemy is copied to each partner (generation 1, NO_LINK_SHARE, max 5).", req=["mag_dom_05"], **S),
    N("mag_dom_08", 3, "small", "Crushing", "+5% magic damage per rank per enemy within 60 px of the impact centre (max +40%).", ranks=2, req=["mag_dom_04", "mag_dom_07"], **S),
    N("mag_dom_fork_a", 3, "fork", "Singularity", "An impact on 6+ enemies collapses them to its centre with a 0.3 s stun.", side="A", req=["mag_dom_08"], excl=["mag_dom_fork_b"], **S),
    N("mag_dom_fork_b", 3, "fork", "Forced Orbit", "Pulled enemies orbit you at 110 px for 2 s, unable to attack (velocity override).", side="B", req=["mag_dom_08"], excl=["mag_dom_fork_a"], needs=["enemy velocity override"], **S),
    N("mag_dom_key", 3, "keystone", "Sovereign Ground", "Standing still for 1 s leaves a 90 px zone (max 2, 6 s): enemies inside are slowed 50% and take +20% damage.", price="Move speed -10%, dash cooldown +0.4 s.", req=["mag_dom_06"], gate_nodes=5, excl=["mel_mom_key"], needs=["Sovereign zones"], **S),
    N("mag_dom_act", 3, "active", "Compel", "Q (aimed): a 200 px cone; every enemy in it is dragged 140 px toward the cursor point and stunned 0.4 s.", bounds="8 s cooldown.", req=["mag_dom_04"], gate_nodes=4, needs=["pull-to-point velocity override"], **S),
    N("mag_dom_mut1", 3, "mutation", "Compel: Ring", "Compel becomes a 220 px circle around the cursor.", parent="mag_dom_act", req=["mag_dom_act"], **S),
    N("mag_dom_mut2", 3, "mutation", "Compel: Chain", "Every pulled enemy is Linked together (cap 12 for that batch).", parent="mag_dom_act", req=["mag_dom_act"], **S),
    N("mag_dom_mut3", 3, "mutation", "Compel: Repulse", "Hold to invert: shove 260 px; 0.6x on collision.", parent="mag_dom_act", req=["mag_dom_act"], **S),
    N("mag_dom_cap", 4, "capstone", "Absolute Compel", "Cooldown 8 -> 5 s; pulled enemies are Subjugated (+10% damage taken, 3 s).", parent="mag_dom_act", req=["mag_dom_mut1", "mag_dom_mut2", "mag_dom_mut3"], req_min=2, **S),
    N("mag_dom_rev", 4, "revelation", "KNEEL", "V: every normal on screen is pulled to the cursor point at 900 px/s for 0.8 s and held 2.0 s; elites are slowed 70% and held 1.0 s.", bounds="Bosses unaffected; max 300 targets; released with a 0.5 s no-attack stumble; 60 s cooldown.", op_cost="5% of current Followers (min 15) plus 1 per 25 pulled.", req=["mag_dom_act"], gate_nodes=8, **S),
]

# ---------------------------------------------------------------------------
# EDGE: sinks (per subtree), witnesses, bridges, ascendant
# ---------------------------------------------------------------------------
SINKS = [
    ("snk_mel_sharpen", "melee", "execution", "Sharpen", "+3% melee damage per rank.", 1.35, "none"),
    ("snk_mel_verdict", "melee", "execution", "Verdict", "+0.5% execute threshold per rank.", 1.5, "threshold total 40%"),
    ("snk_mel_ledger", "melee", "bastion", "Ledger", "Force cap +5 per rank.", 1.3, "Force cap 300"),
    ("snk_rng_rifling", "ranged", "precision", "Rifling", "+2% projectile speed and range per rank.", 1.3, "+60% total"),
    ("snk_rng_judgement", "ranged", "precision", "Judgement", "+4% Active and Revelation damage per rank.", 1.35, "none"),
    ("snk_rng_barrel", "ranged", "barrage", "Barrel", "Heat per shot -1% per rank.", 1.4, "-40% total"),
    ("snk_mag_dominion", "magic", "dominion", "Dominion", "+2% impact radius per rank.", 1.35, "+50% total"),
    ("snk_mag_invocation", "magic", "invocation", "Invocation", "Sigil life +0.5 s and pulse damage +2% per rank.", 1.35, "none"),
    ("snk_mag_consensus", "magic", "distortion", "Consensus", "Luck +1% and Revelation Follower cost -1% per rank.", 1.5, "cost floor 50% of base"),
]
REV_OF = {"execution": "mel_exe_rev", "momentum": "mel_mom_rev", "bastion": "mel_bas_rev",
          "precision": "rng_pre_rev", "barrage": "rng_bar_rev", "ordnance": "rng_ord_rev",
          "invocation": "mag_inv_rev", "distortion": "mag_dis_rev", "dominion": "mag_dom_rev"}
STYLE_REVS = {"melee": ["mel_exe_rev", "mel_mom_rev", "mel_bas_rev"],
              "ranged": ["rng_pre_rev", "rng_bar_rev", "rng_ord_rev"],
              "magic": ["mag_inv_rev", "mag_dis_rev", "mag_dom_rev"]}
for sid, style, sub, name, effect, ratio, cap in SINKS:
    NODES.append(N(sid, 5, "sink", name, effect, style=style, subtree=sub, req=STYLE_REVS[style], ratio=ratio, cap=cap))

# Witness nodes live on the OTHER two styles' trees: a Melee player buys the
# Witness of Ranged or Magic. Bridges sit on gutters; each style tree shows the
# two bridges that involve it plus the Ascendant on its third gutter.
WITNESS = {
    "melee": ("wit_melee", "Witness of the Blade", "Grants the melee core slash as a tree-triggerable secondary attack (never input-triggered)."),
    "ranged": ("wit_ranged", "Witness of the Shot", "Grants the ranged core projectile as a tree-triggerable secondary attack (never input-triggered)."),
    "magic": ("wit_magic", "Witness of the Sign", "Grants the magic core impact as a tree-triggerable secondary attack (never input-triggered)."),
}
BRIDGES = [
    ("brg_mel_mag", "INCARNATE", ("melee", "magic"),
     "Every third slash spawns a MagicImpact at the arc's far edge (0.7x); every impact that hits 3+ enemies fires a 0.5x slash arc from you toward its centre.",
     ["mel_exe_02", "mel_mom_04", "mag_inv_02", "mag_dom_01", "mag_dis_02"]),
    ("brg_mel_rng", "TOTAL OFFENSIVE", ("melee", "ranged"),
     "A slash hitting 2+ enemies fires one projectile per extra enemy (max 3) at the farthest; a ranged kill within 100 px of you triggers a 0.5x slash arc.",
     ["mel_exe_02", "mel_mom_04", "rng_pre_02", "rng_bar_07", "rng_ord_02"]),
    ("brg_rng_mag", "ARCANE BALLISTICS", ("ranged", "magic"),
     "A projectile that expires or exhausts its pierce bursts as a 0.6x MagicImpact; an impact fires one projectile outward per 3 enemies hit (max 3).",
     ["rng_pre_02", "rng_bar_07", "rng_ord_02", "mag_inv_02", "mag_dom_01", "mag_dis_02"]),
]
SUBTREE_ORDER = {"melee": ["execution", "momentum", "bastion"], "ranged": ["precision", "barrage", "ordnance"], "magic": ["invocation", "distortion", "dominion"]}
# gutter pairing per style: gutter 0 = A|B, 1 = B|C, 2 = C|A
for style, subs in SUBTREE_ORDER.items():
    gutters = [f"{subs[0]}|{subs[1]}", f"{subs[1]}|{subs[2]}", f"{subs[2]}|{subs[0]}"]
    others = [s for s in ("melee", "ranged", "magic") if s != style]
    my_bridges = [b for b in BRIDGES if style in b[2]]
    for gi, bridge in enumerate(my_bridges):
        bid, bname, pair, effect, opens = bridge
        other = pair[0] if pair[1] == style else pair[1]
        wid, wname, weffect = WITNESS[other]
        NODES.append(N(f"{wid}@{style}", 5, "witness", wname, weffect, style=style, subtree=None, gutter=gutters[gi],
                       req=STYLE_REVS[style], canonical=wid, target_style=other,
                       bounds="Needs any Revelation of your style and a peak congregation of 5,000,000."))
        NODES.append(N(f"{bid}@{style}", 5, "bridge", bname, effect, style=style, subtree=None, gutter=gutters[gi],
                       req=STYLE_REVS[style], req_all=[f"{wid}@{style}"], canonical=bid, target_style=other, opens=opens,
                       bounds="Bridge attacks carry origin BRIDGE, generation 1, budget 1, never emit weapon_fired, and count as the other style only for the bridge-open nodes listed."))
    NODES.append(N(f"brg_asc@{style}", 5, "ascendant", "ASCENDANT",
                   "Every primary attack carries all three style tags for the bridge-open nodes; each bridge-open list fires at most once per source attack; chains get budget 2 total. Prize: a second Revelation from a different subtree may be slotted on V (both share the longer cooldown).",
                   style=style, subtree=None, gutter=gutters[2], req_all=[f"{b[0]}@{style}" for b in my_bridges],
                   canonical="brg_asc", op_cost="1 Follower per 50 bridge-generated attacks, charged per segment.",
                   bounds="Needs both bridges of your style and a peak congregation of 50,000,000."))

AXIOMS = ["mel_exe_axiom", "rng_pre_axiom", "mag_dis_axiom", "mel_bas_axiom", "rng_bar_axiom"]

# Bridge-open node lists per style, for the whitelist rule.
BRIDGE_OPEN = {
    "melee": ["mel_exe_02", "mel_mom_04"],
    "ranged": ["rng_pre_02", "rng_bar_07", "rng_ord_02"],
    "magic": ["mag_inv_02", "mag_dom_01", "mag_dis_02"],
}

PROC_TAGS = {
    "origins": ["PRIMARY", "ACTIVE", "REVELATION", "SIGIL", "BRIDGE"],
    "rules": [
        "PRIMARY chains stop at generation 2; BRIDGE chains at generation 1.",
        "Generation >= 1 never emits weapon_fired (a beat is not an attack) but does emit player_hit_landed.",
        "no_self tags: AFTERIMAGE, RETARGET, RICOCHET, FRAGMENT, ORDNANCE_TRIGGER, SIGIL_SPAWN, TWICE, LINK_SHARE, CROSSFIRE.",
        "Every generator checks allowed_children and the remaining budget before spawning.",
    ],
}
