# V4 advancement tree: first combat prototype, what is built

Companion to `2026-09-13-v4-tree-review.md`. This note records what the
prototype implements, where it lives, how to test it, and what is still
out. It follows the review's order of work (§9.7): A shared contract,
B the three engines on their own natives, C Gates, Witness, Fusions and
Reaction Q, D Ascendant.

## 1. Where things are

| Piece | Files |
|---|---|
| Tree data (verbatim V4 JSON, 350 nodes) | `data/ascension/tree_v4.json` |
| Review routes (three hybrids) | `data/ascension/routes_prototype.json` |
| Graph + requirement grammar | `core/systems/ascension/AscensionTreeDB.gd` |
| Purchase, refund, equipment rules on one saved Dictionary | `core/systems/ascension/AscensionLedger.gd` (state in `Global.attempt_ascension`, saved as `SaveData.attempt_ascension`) |
| Attack provenance tags | `core/systems/ascension/AscensionTags.gd` |
| Runner on the player (hits, kills, rolls, Q/V, Witness, Reaction, Ascendant) | `core/systems/ascension/AscensionRunner.gd`, `AscensionSlotHud.gd`, `AscensionEngine.gd` |
| Engines | `core/systems/ascension/engines/BarrageEngine.gd`, `ExecutionEngine.gd`, `DistortionEngine.gd` |
| Radial map | `core/systems/ascension/AscensionTreeLayout.gd`, `ui/screens/AscensionTreeView.gd`, `ui/screens/AscensionScreen.gd/.tscn` |
| Engine hooks | `RunEvents.enemy_damaged`, `RunEvents.player_paid_health`, `HitLedger.tags`, `ProjectileSimulationManager` (per-bullet tags, stable ids, enemy-projectile query), `player.pay_health`, `player.spawn_generated_*` |
| Dev tools | Performance overlay, Run tab: route loader, Clear tree, Open tree, Revelations on/off, Enemy HP x1/x3/x6; state strip shows TREE, R0, CHAIN, HEAT |

Inputs: Q = equipped Active, V = equipped Revelation, T = open the tree
(mid-run, pauses like the bag). The Hub has an Ascension button beside
Augments. Two ActiveAbilityHUD instances flank the R ability and show
only while a Q or V is equipped.

## 2. The shared contract

Every hit from the player resolves through `EnemyCombatService`, which
now emits `enemy_damaged(handle, applied, unclamped, health_before,
source, payload)` before the death path. The payload's tags name the
Core, the family (native or tree), the root node, the hit path, the
generation, Proc Power, free flags (`core_strike`, `execute_enabled`,
`execute`, `debt`, `v`, `witness`), and a `cast` root shared by a
whole chain. The runner parses that into one record with pre-hit and
post-hit health, HP fraction, overkill, lethality and normal / elite /
boss classification, pairs the lethal record with `enemy_defeated`,
keeps a per-enemy registry of tree statuses, and resolves named combat
rolls (modifier chain, Proc Power, 95% cap, guarantee, one reroll).

Health costs go through `player.pay_health(amount, reason)`: no
evasion, armour or i-frames, never below 1 HP, no on-damage rules
(Tithe Bones, Litany, HitFeel do not hear it); `player_paid_health`
fires instead.

## 3. What each engine implements

**Barrage** (Ranged native). Heat with tiers, Jam and cooling; Fifth
Shot; Heat Sink patches; Hot Rounds (first Core impact per volley);
seeking fragments simulated by the engine (lowest-HP target within L),
Pinball and Cluster Rounds; Crossfire from the camera edge; Coolant
quadrants; Loose Chamber; Ricochet; Bigger Magazine; Burst with all
seven mutations; Cool Head and Backfire; Overclock and Bottomless;
Overload; Hot Blood; SUPPRESSION with Six Guns, Sweep and Final Jam;
Bullet Hell's rotating points.

**Execution** (Melee native). Execution as the review defines it:
a normal killed by an execution-enabled hit, by damage or by the line;
a hit that leaves a normal in the band finishes it, seeded with 0.5D
of overkill. Finish, Mark (+ One at a Time), Spillover bolts with Meat
and Blood, Bloodletting, Corpse Bomb, Cleave, Reservoir, First Cut,
Elite Sentence, Chain Sentence, Last Word, Only the Weak, Gavel with
all seven mutations and both Evolutions, Red Mist, DECIMATION with its
three mutations; boss loop per review F13 (hits below half stack
Bloodletting, a Gavel cracks a boss).

**Distortion** (Magic native). Named rolls with the Roll Chance sink,
Denial's Misfire bonus, Weighted Heads, Snake Eyes, Second Chance,
Loaded Dice, Bad Luck (claims the Manifestation fortune noun; Lucky
Crit stays unregistered per F5). Twice, Residue's Fading and scars,
Scar Tissue, Misfire, Contradiction, Causal Debt (eight buckets, merge
rule, Interest, Late Payment), Back Pay, Pass It On, Compound
Interest, Payday over a 4 s deposit window (F11), Coin with Weighted /
Double or Nothing / House Edge / Two Coins / Counterfeit / Bad Penny
and its refunds, Loaded Coin, REWRITE with the collectable-Debt rule
(F3) and The Bill. Debt numbers with their due time draw over every
indebted enemy.

**Cross-Core.** Witness every second native input (F12); Reaction Q at
the first Gate at 60% damage and doubled recovery, cast on a
catastrophe or on losing 15% max HP within a second, automatic Coin on
a chosen face (F7); Kill Feed, Death Debt and Wildfire on both parent
engines with the Core tags the review asks for (F8); Ascendant strikes,
Echoes, Second Skin, Twenty Bodies, the second Revelation slot, both
Ascendant sinks.

## 4. Tests

```
G=~/Downloads/Godot_v4.7.2-stable_linux.x86_64
for t in AscensionLedgerTest AscensionRunnerTest AscensionBarrageTest \
         AscensionExecutionTest AscensionDistortionTest AscensionHybridTest \
         AscensionScreenTest; do
  $G --headless --path . res://tools/tests/$t.tscn --quit-after 3000 2>&1 | grep -E "FAIL|passed"
done
```

`AscensionLedgerTest` replays all sixteen authored routes at their
authored prices; `AscensionHybridTest` loads the review's three hybrids
(18,000 / 19,800 / 17,600) and the Three-Core avalanche (71,000).
Never run the engine while a playtest is in progress.

## 5. Playtest loop

1. Overlay, Run tab: pick a route, Load route (it funds itself and
   buys in order through the real rules), set Enemy HP x3.
2. Press T to inspect the map; buy or refund on the screen.
3. Play with Revelations off first (overlay switch), then on.
4. Read the state strip: R0 (chain kills per seed kill), CHAIN (longest
   chain from one root), HEAT / JAM, TREE spent. Flight-recorder events
   under `ascension` record purchases, catastrophes and Revelations.

## 6. Not implemented, or approximated

- Denial's projectile slow (only its Misfire bonus); Undo (DTF1);
  Replay (DTV2); REWRITE's "normals' melee swings miss"; Heat Sink and
  Coolant were kept separate (the review suggests merging).
- Gather pulls through the knockback API, roughly. Only the Weak and
  One at a Time's damage reductions are applied by healing back a share
  of the hit after it lands.
- Foreign strikes use the existing slash / impact scenes and managed
  bullets; fragments, bolts, scars and Debt labels are drawn by the
  runner as bare shapes and text. No sounds, no dedicated art.
- The Wardstone purchase point from the earlier spec is not wired; the
  tree opens at the Hub and on T.
- Prices, D, R, L and every coefficient are V4's; nothing has been
  tuned from play yet. The review's pass/fail lines (§9.6) are the
  next step.
