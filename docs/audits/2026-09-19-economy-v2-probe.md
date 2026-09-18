# Economy probe before and after balance revision 2's merge and price law (Task 5), 2026-09-19

`FollowerEconomyAuditProbe` (read-only; synthetic price and stock fixtures at Luck 0, 100 stock samples per segment, seed 20260913; not a timed income sample). Before = commit ae791bc (rank price 26 + 18r + 2.5r^2, next-rank base 10, stat weights HP 0.45 / armour 2.5 / Luck 45); after = rank price 26 + 14r + r^2 with the meter as the exact lerp, stat weights HP 0.30 / armour 0.80 / Luck 35, gap half-life 3.0.

| Hub before segment | Buy median before -> after | Sell median | p90 buy | Whole stock (10 items) median |
|---|---|---|---|---|
| 2 | 120 -> 91 | 66 -> 50 | 189 -> 131 | 1238 -> 923 |
| 3 | 161 -> 115 | 88 -> 63 | 235 -> 158 | 1630 -> 1156 |
| 5 | 208 -> 142 | 114 -> 78 | 302 -> 193 | 2124 -> 1441 |
| 10 | 322 -> 205 | 177 -> 112 | 438 -> 266 | 3224 -> 2069 |
| 20 | 496 -> 298 | 272 -> 163 | 628 -> 363 | 5071 -> 3007 |
| 40 | 488 -> 295 | 268 -> 162 | 620 -> 361 | 4999 -> 2980 |

Reward and reconstruction rows are unchanged (they do not read item prices). The raw outputs are `2026-09-19-economy-v2-probe-before.txt` and `-after.txt`.

What this does not say: whether a useful shop upgrade now costs 30-90 seconds of the stage's organic earnings (section 5.3) needs the recorder's income capture from a human playtest; the follower economy audit's 2026-09-13 income figures predate every revision-2 change.
