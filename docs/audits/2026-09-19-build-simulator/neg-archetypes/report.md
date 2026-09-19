# NEG archetype wardrobes versus the POS baseline: seg6 pure presets and authored builds, Gravemarch set, balance revision 2 (aura caps applied), 2026-09-19

56 authored builds (presets, authored builds and routes at their own tiers) fought once per configuration with the same seed and crowd streams; only the wardrobe and the slotted augment differ. Medians over builds; per-build changes are the same build under both wardrobes. One scripted scenario: see the simulator caveats (no positioning, ranged and magic set payloads are lower bounds).

- **cursed_set**: set gravemarch, cursed slots [0, 1, 2], relics [], augments `-`
- **doctrine**: set gravemarch, cursed slots [0, 1, 2, 3], relics [], augments `augment_doctrine_of_burden`
- **engine**: set gravemarch, cursed slots [], relics ['curse_ashen_ballast', 'curse_jinxed_coin'], augments `augment_corruption_engine`
- **lens**: set gravemarch, cursed slots [], relics ['curse_ashen_ballast'], augments `augment_inversion_lens`
- **litany**: set gravemarch, cursed slots [0, 1, 2, 3], relics [], augments `augment_litany_of_wounds`
- **sigil**: set gravemarch, cursed slots [0, 1, 2, 3], relics [], augments `augment_equilibrium_sigil`

## Per Core medians (baseline -> configuration)

| Configuration | Core | n | Enemy HP/s | HP lost | Deaths (mean) | Min HP | Power worn | Armour worn | Max HP worn |
|---|---|---:|---|---|---|---|---|---|---|
| cursed_set | melee | 22 | 3490 -> 4032 (+16%) | 103 -> 116 (+13%) | 0.09 -> 0.09 | 247 -> 179 (-28%) | 0.67 -> 0.67 | 41.2 -> 28.7 | 303 -> 227 |
| cursed_set | ranged | 22 | 2985 -> 2718 (-9%) | 169 -> 169 (+0%) | 0.14 -> 0.27 | 153 -> 68 (-55%) | 0.77 -> 0.77 | 31.2 -> 21.2 | 285 -> 214 |
| cursed_set | magic | 12 | 1877 -> 1811 (-3%) | 145 -> 141 (-2%) | 0.42 -> 0.50 | 113 -> 20 (-82%) | 0.66 -> 0.66 | 24.6 -> 16.4 | 229 -> 172 |
| doctrine | melee | 22 | 3490 -> 2884 (-17%) | 103 -> 101 (-2%) | 0.09 -> 0.05 | 247 -> 245 (-1%) | 0.67 -> 0.42 | 41.2 -> 60.7 | 303 -> 268 |
| doctrine | ranged | 22 | 2985 -> 2436 (-18%) | 169 -> 157 (-7%) | 0.14 -> 0.05 | 153 -> 137 (-10%) | 0.77 -> 0.52 | 31.2 -> 53.2 | 285 -> 252 |
| doctrine | magic | 12 | 1877 -> 1635 (-13%) | 145 -> 131 (-9%) | 0.42 -> 0.25 | 113 -> 100 (-12%) | 0.66 -> 0.41 | 24.6 -> 48.4 | 229 -> 203 |
| engine | melee | 22 | 3490 -> 2851 (-18%) | 103 -> 145 (+41%) | 0.09 -> 0.05 | 247 -> 238 (-4%) | 0.67 -> 0.90 | 41.2 -> 3.5 | 303 -> 303 |
| engine | ranged | 22 | 2985 -> 2050 (-31%) | 169 -> 208 (+23%) | 0.14 -> 0.23 | 153 -> 68 (-55%) | 0.77 -> 1.00 | 31.2 -> 3.0 | 285 -> 285 |
| engine | magic | 12 | 1877 -> 1682 (-10%) | 145 -> 142 (-2%) | 0.42 -> 0.50 | 113 -> 30 (-74%) | 0.66 -> 0.89 | 24.6 -> 2.7 | 229 -> 229 |
| lens | melee | 22 | 3490 -> 2259 (-35%) | 103 -> 68 (-34%) | 0.09 -> 0.00 | 247 -> 301 (+22%) | 0.67 -> 0.67 | 41.2 -> 105.1 | 303 -> 303 |
| lens | ranged | 22 | 2985 -> 1965 (-34%) | 169 -> 118 (-30%) | 0.14 -> 0.00 | 153 -> 178 (+16%) | 0.77 -> 0.77 | 31.2 -> 91.9 | 285 -> 285 |
| lens | magic | 12 | 1877 -> 1490 (-21%) | 145 -> 112 (-23%) | 0.42 -> 0.17 | 113 -> 137 (+21%) | 0.66 -> 0.66 | 24.6 -> 82.7 | 229 -> 229 |
| litany | melee | 22 | 3490 -> 3526 (+1%) | 103 -> 135 (+31%) | 0.09 -> 0.14 | 247 -> 186 (-25%) | 0.67 -> 0.42 | 41.2 -> 28.7 | 303 -> 227 |
| litany | ranged | 22 | 2985 -> 2522 (-16%) | 169 -> 179 (+6%) | 0.14 -> 0.23 | 153 -> 70 (-54%) | 0.77 -> 0.52 | 31.2 -> 21.2 | 285 -> 214 |
| litany | magic | 12 | 1877 -> 1555 (-17%) | 145 -> 121 (-16%) | 0.42 -> 0.50 | 113 -> 26 (-77%) | 0.66 -> 0.41 | 24.6 -> 16.4 | 229 -> 172 |
| sigil | melee | 22 | 3490 -> 3696 (+6%) | 103 -> 115 (+12%) | 0.09 -> 0.14 | 247 -> 197 (-20%) | 0.67 -> 0.54 | 41.2 -> 28.7 | 303 -> 227 |
| sigil | ranged | 22 | 2985 -> 2536 (-15%) | 169 -> 165 (-3%) | 0.14 -> 0.27 | 153 -> 77 (-50%) | 0.77 -> 0.64 | 31.2 -> 21.2 | 285 -> 214 |
| sigil | magic | 12 | 1877 -> 1765 (-6%) | 145 -> 140 (-4%) | 0.42 -> 0.42 | 113 -> 37 (-68%) | 0.66 -> 0.53 | 24.6 -> 16.4 | 229 -> 172 |

## Pure presets, same build under each wardrobe (Enemy HP/s, HP lost)

| Build | Core | pos | cursed_set | doctrine | engine | lens | litany | sigil |
|---|---|---|---|---|---|---|---|---|
| Distortion pure | magic | 4433 / 164 | 4454 (+0%) / 145 | 4657 (+5%) / 141 | 4676 (+5%) / 11 | 4515 (+2%) / 108 | 5030 (+13%) / 13 | 4814 (+9%) / 9 |
| Dominion pure | magic | 6970 / 8 | 6656 (-5%) / 102 | 5304 (-24%) / 108 | 5937 (-15%) / 116 | 4974 (-29%) / 104 | 6494 (-7%) / 119 | 4983 (-29%) / 137 |
| Invocation pure | magic | 1655 / 170 | 1651 (-0%) / 192 | 1490 (-10%) / 31 | 1006 (-39%) / 204 | 1024 (-38%) / 120 | 1461 (-12%) / 192 | 1530 (-8%) / 183 |
| Bastion pure | melee | 2587 / 111 | 3556 (+37%) / 104 | 2091 (-19%) / 113 | 755 (-71%) / 112 | 726 (-72%) / 67 | 3471 (+34%) / 153 | 3420 (+32%) / 148 |
| Execution pure | melee | 5158 / 114 | 5117 (-1%) / 129 | 4878 (-5%) / 110 | 4840 (-6%) / 151 | 4635 (-10%) / 105 | 5230 (+1%) / 167 | 4841 (-6%) / 8 |
| Momentum pure | melee | 2375 / 0 | 2570 (+8%) / 0 | 2363 (-0%) / 0 | 713 (-70%) / 0 | 689 (-71%) / 0 | 2362 (-1%) / 0 | 2398 (+1%) / 0 |
| Barrage pure | ranged | 1985 / 197 | 2108 (+6%) / 53 | 1830 (-8%) / 166 | 1583 (-20%) / 238 | 1462 (-26%) / 151 | 1738 (-12%) / 212 | 1973 (-1%) / 222 |
| Ordnance pure | ranged | 4532 / 253 | 3885 (-14%) / 203 | 3995 (-12%) / 156 | 4676 (+3%) / 256 | 4516 (-0%) / 158 | 4052 (-11%) / 206 | 4258 (-6%) / 241 |
| Precision pure | ranged | 2306 / 201 | 2113 (-8%) / 222 | 2118 (-8%) / 187 | 2012 (-13%) / 223 | 2114 (-8%) / 122 | 2131 (-8%) / 232 | 2092 (-9%) / 193 |

## Largest per-build swings (Enemy HP/s)

| Configuration | Build | Core | Tier | Baseline | Configuration | Change | HP lost |
|---|---|---|---|---:|---:|---:|---|
| lens | Authored: Endless Lunge | melee | seg6 | 2419 | 668 | -72% | 0 -> 0 |
| lens | Bastion pure | melee | seg6 | 2587 | 726 | -72% | 111 -> 67 |
| lens | Momentum pure | melee | seg6 | 2375 | 689 | -71% | 0 -> 0 |
| engine | Bastion pure | melee | seg6 | 2587 | 755 | -71% | 111 -> 112 |
| engine | Authored: Endless Lunge | melee | seg6 | 2419 | 715 | -70% | 0 -> 0 |
| engine | Momentum pure | melee | seg6 | 2375 | 713 | -70% | 0 -> 0 |
| lens | Authored: Bomb suit | melee | seg6 | 2558 | 793 | -69% | 169 -> 99 |
| lens | Hybrid: Running guns | melee | seg6 | 2826 | 883 | -69% | 0 -> 0 |
| lens | Authored: Running guns | melee | seg6 | 2798 | 876 | -69% | 0 -> 0 |
| lens | Bastion early | melee | seg2 | 1589 | 511 | -68% | 184 -> 113 |
| engine | Authored: Bomb suit | melee | seg6 | 2558 | 865 | -66% | 169 -> 193 |
| engine | Hybrid: Running guns | melee | seg6 | 2826 | 956 | -66% | 0 -> 0 |
| lens | Momentum developed | melee | seg4 | 1624 | 556 | -66% | 0 -> 0 |
| engine | Authored: Running guns | melee | seg6 | 2798 | 964 | -66% | 0 -> 0 |
| lens | Bastion developed | melee | seg4 | 1693 | 585 | -65% | 10 -> 72 |
| engine | Bastion early | melee | seg2 | 1589 | 564 | -65% | 184 -> 177 |
| lens | Momentum early | melee | seg2 | 1399 | 519 | -63% | 180 -> 156 |
| engine | Momentum developed | melee | seg4 | 1624 | 617 | -62% | 0 -> 0 |
| engine | Bastion developed | melee | seg4 | 1693 | 671 | -60% | 10 -> 124 |
| engine | Momentum early | melee | seg2 | 1399 | 558 | -60% | 180 -> 176 |
