# Balance capture

Capture: `2026-10-18_14-29-09_19808_357870982_1`  
Outcome: **application_closed**  
Build: `0.0.0.25.5` / `c9d5a31772f3`  
World seed: `1794675549650`

This is one observed session. Resuming a save starts a separate capture with the same run key; earlier gameplay is not inferred.

## Recording health

Dropped history records: **0**. Wallet discontinuities: **0**. Writer failures: **0**.

## Economy

| Opening | Earned | Spent | Adjustments | Debug grants | Closing |
|---:|---:|---:|---:|---:|---:|
| 370 | 29880 | 0 | 0 | 0 | 30250 |

Opening + earned - spent + adjustments + debug grants = closing. Refunds, trade undo and system synchronization are adjustments; developer funding (route loaders, overlay grants) is a debug grant, never earned income. Sales count as earnings under their own reason. Amounts are actual wallet changes.

| Reason | Gained | Spent | Net | Count |
|---|---:|---:|---:|---:|
| combat_influence | 29847 | 0 | 29847 | 10611 |
| miniboss_victory | 8 | 0 | 8 | 1 |
| boss_victory | 25 | 0 | 25 | 1 |

## Combat

| Measurement | Value |
|---|---:|
| Gameplay seconds | 986.56 |
| Paused seconds | 76.28 |
| Hub seconds | 298.72 |
| Loading/other seconds | 0.10 |
| Enemy HP removed | 472725.64 |
| Enemy overkill | 231231.50 |
| Damage directly credited to player | 273420.29 |
| Player HP lost to hits | 845.15 |
| Player overkill | 0.00 |
| HP intentionally paid | 0.00 |
| Healing applied | 849.04 |
| Healing overflow | 13785.32 |
| Healing sealed | 0.00 |
| Weapon attacks | 6440.00 |
| Resolved hits/ticks | 24124.00 |
| Critical hits | 28.00 |
| Kills | 11053.00 |
| Deaths | 0.00 |
| Reconstructions | 0.00 |
| Rescues | 0.00 |
| Hits evaded | 21.00 |
| Hits during invulnerability | 1.00 |
| Hits missed by a rule | 0.00 |
| Lethal hits intercepted (left at 1 HP) | 0.00 |
| Hits under god mode | 0.00 |

Enemy HP removed / gameplay second: **479.17**. Kills / gameplay minute: **672.22**.

Gameplay time includes travel while the player is alive; it excludes pauses, hub time, loading and death screens. These rates are not combat-only or training-dummy DPS.

## Health reconciliation

Every HP change is recorded at its owner (hits, heals, costs, takebacks, adjustments, rescues, reconstruction) and each life's expected HP is compared with the sampled HP once per second. Lives observed: **1** (completed 0). Recorded changes: **1859**. Checks: **1053**, unexplained: **0** (net unexplained HP 0.00, largest residual 0.000). An unexplained check means some HP change reached no record; it is reported, never balanced away.

| Category | Changes | Net HP |
|---|---:|---:|
| hit | 163 | -845.15 |
| heal | 1652 | 849.04 |
| adjustment | 44 | 116.01 |

Sources per life, including Death Rattle payments, Scar Tissue and Slow Heart takebacks and stat-refresh clamps, are in summary.json under health.

## Damage attribution

Of enemy HP removed, 99.9% is attributed to an origin, 0.0% is unknown (a payload with no provenance) and 0.1% came from same-frame batches of unlike shots (mixed). Origin (what initiated the chain) and immediate source are alternate groupings of the same HP; never add the two tables. Casts count a cast id the first time it is seen, not its pellets or ticks.

| Origin | HP removed | Overkill | Hits | Kills | Casts |
|---|---:|---:|---:|---:|---:|
| native:ranged | 215698.95 | 85522.38 | 9049 | 4385 | 0 |
| ascension:BR05 | 100607.10 | 30223.29 | 8388 | 3430 | 771 |
| manifestation:predestination_sigil | 45040.07 | 68327.42 | 1197 | 859 | 0 |
| set:lattice:6 | 41948.53 | 25243.92 | 1488 | 922 | 0 |
| augment:magic_missile | 30399.02 | 10485.50 | 1464 | 668 | 0 |
| ascension:PRF2 | 14756.05 | 4328.67 | 693 | 294 | 0 |
| ascension:OR02 | 7010.94 | 2074.45 | 295 | 113 | 132 |
| ascension:BR06 | 5664.75 | 1029.97 | 313 | 118 | 0 |
| ascension:PRQ | 4288.24 | 1595.78 | 327 | 120 | 10 |
| ascension:BR02 | 2311.33 | 214.34 | 166 | 39 | 0 |
| manifestation:shard | 1310.33 | 417.74 | 55 | 21 | 0 |
| ascension:PR11 | 1150.55 | 351.56 | 64 | 25 | 0 |
| status:burn | 768.80 | 9.70 | 513 | 12 | 0 |
| ascension:PR09 | 767.14 | 357.75 | 57 | 16 | 0 |
| manifestation:retaliation_writ | 610.02 | 781.35 | 17 | 14 | 0 |
| mixed | 343.91 | 260.22 | 27 | 9 | 0 |
| … 1 more rows in summary.json | | | | | |

| Immediate source | HP removed | Overkill | Hits | Kills |
|---|---:|---:|---:|---:|
| native:ranged:bullet_node | 199305.35 | 80096.46 | 8293 | 4048 |
| ascension:BR05:fragment | 103269.38 | 31049.22 | 8639 | 3514 |
| set:lattice:6:afterstrike | 41948.53 | 25243.92 | 1488 | 922 |
| manifestation:predestination_sigil | 35774.72 | 64921.55 | 788 | 722 |
| augment:magic_missile:missile | 30399.02 | 10485.50 | 1464 | 668 |
| native:ranged:bullet | 16393.60 | 5425.92 | 756 | 337 |
| ascension:PRF2:edge_return | 14756.05 | 4328.67 | 693 | 294 |
| manifestation:predestination_sigil:mark_bonus | 9265.35 | 3405.87 | 409 | 137 |
| ascension:OR02:grenade | 7010.94 | 2074.45 | 295 | 113 |
| ascension:BR06:crossfire | 5664.75 | 1029.97 | 313 | 118 |
| ascension:BR02:bullet | 2311.33 | 214.34 | 166 | 39 |
| manifestation:shard:projectile | 1294.91 | 417.74 | 54 | 21 |
| ascension:PR11:crossing | 1150.55 | 351.56 | 64 | 25 |
| ascension:PRQ:beam | 1099.58 | 348.85 | 44 | 15 |
| status:burn | 768.80 | 9.70 | 513 | 12 |
| ascension:PR09:split | 767.14 | 357.75 | 57 | 16 |
| … 5 more rows in summary.json | | | | |

## Enemy scaling

| Archetype | Seen | Mean HP | Max HP | Kills | TTK samples | Mean TTK (s) | Removed alive |
|---|---:|---:|---:|---:|---:|---:|---:|
| grunt | 2963 | 16.91 | 21.27 | 2963 | 2963 | 0.046 | 0 |
| runner | 1053 | 15.14 | 19.14 | 1052 | 1052 | 0.040 | 1 |
| grunt [elite] | 436 | 55.45 | 74.88 | 435 | 435 | 0.866 | 1 |
| runner [elite] | 137 | 42.94 | 56.86 | 133 | 133 | 0.178 | 4 |
| spitter | 651 | 39.21 | 46.80 | 651 | 651 | 0.327 | 0 |
| brute | 182 | 125.64 | 148.90 | 180 | 180 | 2.295 | 2 |
| orbiter | 741 | 31.72 | 38.29 | 741 | 741 | 0.187 | 0 |
| charger [elite] | 101 | 165.47 | 224.63 | 101 | 101 | 1.722 | 0 |
| charger | 487 | 52.56 | 63.82 | 486 | 486 | 0.364 | 1 |
| orbiter [elite] | 144 | 92.17 | 126.36 | 144 | 144 | 1.191 | 0 |
| spitter [elite] | 109 | 127.62 | 164.73 | 106 | 106 | 1.089 | 3 |
| brute [elite] | 21 | 380.06 | 524.14 | 20 | 20 | 1.290 | 1 |
| bomber | 424 | 28.62 | 34.04 | 424 | 424 | 0.133 | 0 |
| lurker | 156 | 47.40 | 55.31 | 156 | 156 | 0.258 | 0 |
| bomber [elite] | 75 | 93.93 | 119.80 | 75 | 75 | 0.363 | 0 |
| warden | 153 | 75.52 | 85.09 | 153 | 153 | 0.566 | 0 |
| leech | 348 | 40.73 | 51.05 | 348 | 348 | 0.665 | 0 |
| chanter | 196 | 33.39 | 42.54 | 196 | 196 | 0.219 | 0 |
| chanter [elite] | 47 | 112.30 | 149.75 | 46 | 46 | 0.494 | 1 |
| leech [elite] | 70 | 138.10 | 179.71 | 70 | 70 | 0.894 | 0 |
| sniper | 84 | 51.18 | 72.32 | 78 | 78 | 2.826 | 6 |
| herald | 247 | 57.30 | 72.32 | 244 | 244 | 0.482 | 3 |
| splitter | 1246 | 39.90 | 127.63 | 1243 | 1243 | 0.459 | 3 |
| siphon | 112 | 40.62 | 46.80 | 112 | 112 | 0.180 | 0 |
| summoner | 267 | 48.17 | 59.56 | 260 | 260 | 0.377 | 7 |
| summoned_minion | 707 | 10.42 | 10.64 | 436 | 436 | 0.008 | 271 |
| lurker [elite] | 31 | 158.72 | 194.68 | 31 | 31 | 0.866 | 0 |
| herald [elite] | 57 | 198.65 | 270.49 | 56 | 56 | 1.734 | 1 |
| summoner [elite] | 48 | 158.42 | 209.66 | 45 | 45 | 0.776 | 3 |
| warden [elite] | 20 | 216.75 | 299.51 | 19 | 19 | 1.758 | 1 |
| sniper [elite] | 26 | 206.62 | 254.58 | 24 | 24 | 1.765 | 2 |
| siphon [elite] | 23 | 132.47 | 164.73 | 23 | 23 | 0.356 | 0 |
| boss_bulldozer | 1 | 6037.99 | 6037.99 | 1 | 1 | 23.812 | 0 |
| boss_arcanist | 1 | 21378.36 | 21378.36 | 1 | 1 | 74.552 | 0 |
| boss_pylon | 4 | 40.00 | 40.00 | 0 | 0 | — | 4 |

TTK runs from first observed damaging hit to death using gameplay seconds. Only defeated, engaged enemies contribute; surviving enemies are not assigned zero. HP reflects registration/entry and later elite or boss configuration.

## Upgrade effort and benefit

An offer is a vendor item shown, never an acquisition; an acquisition is a pickup, reward, purchase or debug grant that landed in a container or fed one, and a player move never is. An undone trade reverses its own counts. Merges are counted where the destination lives; meter gained is in ranks. Organic income excludes trades, undo, vendor refreshes, reconstruction, adjustments and debug grants; with no organic income the shop cost in minutes is unavailable (-), not zero. Debug grants are prepared fixtures, listed apart from earned progression.

| Segment | Dropped / offered | Compatible drops | Acquired (pickup / reward / trade / debug) | Purchases (value), net of undo | Sales (value) | Merges (equipped) | Meter gained (equipped) | Rank-ups (mean s between) | Organic income / min | Shop cost (min) |
|---|---|---:|---|---|---|---|---:|---|---:|---:|
| all | 1804 / 0 | 378 | 226 / 0 / 0 / 0 | 0 (0), net 0 | 0 (0) | 206 (73) | 34.08 | 30 (22.8) | 1817.23 | - |
| 5 | 611 / 0 | 125 | 109 / 0 / 0 / 0 | 0 (0), net 0 | 0 (0) | 93 (32) | 17.03 | 14 (18.6) | 1462.34 | - |
| 6 | 1193 / 0 | 253 | 113 / 0 / 0 / 0 | 0 (0), net 0 | 0 (0) | 113 (41) | 17.05 | 16 (20.1) | 2096.22 | - |
| 11 | 0 / 0 | 0 | 4 / 0 / 0 / 0 | 0 (0), net 0 | 0 (0) | 0 (0) | 0.00 | 0 (-) | - | - |

Compatible drops by item, polarity and rank gap (equipped rank minus dropped rank; whole capture):

| Item:polarity:gap | Count | Value |
|---|---:|---:|
| lattice_focusnode:pos:5 | 22 | 2433 |
| lattice_shellplate:pos:6 | 19 | 1681 |
| lattice_pulsecoil:pos:4 | 17 | 2390 |
| lattice_focusnode:pos:6 | 17 | 1968 |
| lattice_strideframe:pos:5 | 16 | 1706 |
| acc_firestone:pos:3 | 16 | 1940 |
| lattice_tickspurs:pos:6 | 14 | 1409 |
| lattice_pulsecoil:pos:5 | 14 | 1760 |
| lattice_shellplate:pos:5 | 13 | 1609 |
| acc_firestone:pos:4 | 13 | 1382 |
| lattice_fingerprint:pos:6 | 12 | 1209 |
| lattice_strideframe:pos:4 | 12 | 1553 |
| lattice_strideframe:pos:6 | 12 | 1101 |
| lattice_focusnode:pos:4 | 11 | 1695 |
| lattice_pulsecoil:pos:6 | 11 | 1149 |
| lattice_fingerprint:pos:5 | 11 | 1202 |

## Exit and pressure

An attempt is an actual channel entry (proximity is not one). Progress lost is in hold seconds by cause. A reconstruction death is one within 10 gameplay seconds of a respawn. Reconstruction spending is compared with all Followers earned in the segment.

| Segment | Status | Unlock to first channel (s) | Attempts | Channel (s) | Lost: lapse / death | Seals | Waves (enemies) | Deaths channeling / after reconstruction | Reconstruction spent / earned | Beats (members, specialists) | Overtime injected (s) / final |
|---|---|---:|---:|---:|---|---:|---|---|---|---|---|
| 5 | completed | 40.7 | 2 | 20.0 | 0.0 / 0.0 | 3 | 7 (38) | 0 / 0 | 0 / 10583 | 18 (70, 9) | 45 / 1.00 |
| 6 | completed | 5.0 | 1 | 20.0 | 0.0 / 0.0 | 3 | 7 (38) | 0 / 0 | 0 / 19297 | 19 (54, 8) | 40 / 0.48 |
| 11 | unfinished | - | 0 | 0.0 | 0.0 / 0.0 | 0 | 0 (0) | 0 / 0 | 0 / 0 | 0 (0, 0) | 0 / 0.00 |

Spawn requests by source and outcome (whole capture; a rejection names the gate that refused it, as the spawner reported it):

| Source:outcome | Requests | Enemies |
|---|---:|---:|
| ambient:spawned | 2120 | 7849 |
| ambient:rite_pressure | 411 | 0 |
| beat:spawned | 138 | 138 |
| ambient:paused | 54 | 0 |
| burst_at:spawned | 24 | 72 |
| ambient:refill_hold | 19 | 0 |
| burst:gated | 10 | 0 |
| burst:spawned | 4 | 27 |
| burst:rite_pressure | 4 | 0 |
| ambient:culled | 1 | 0 |

Overtime clock injections by contributor (seconds of unseal time; the director's final overtime already includes them once):

| Contributor | Seconds |
|---|---:|
| manifestation:overtime_gospel@slot5#-9223371566102868507 | 65.0 |
| manifestation:overtime_gospel@slot0#-9223371565733769824 | 20.0 |

## Incidents

Death contexts: **0**; manual captures: **0**. Each `death_context` / `incident_context` record in events.jsonl holds the exact terminal health change and its resolution, the last 5 gameplay seconds of events (at most 2048) and 5 Hz state samples (at most 32), the pure effect snapshot, the build index and the health residual at that moment. Incident payload bytes: **0** (ceiling 2097152 per incident); history trimmed to fit: 0 events, 0 samples (oldest first; the terminal event and latest state are never trimmed). Incidents whose ring had already overwritten context: 0. Live ring now: 232 events, 23 samples, 0 overwritten.

## Recorder coverage

Recorder revision 2, balance revision 2. Measured: pure_snapshots, health_reconciliation, source_attribution, incidents, exit_detail, progression. Not measured by this revision (absent means unavailable, never zero): none.

## Coverage

Player damage is grouped by immediate source in summary.json; self-inflicted rule damage uses the source `self_damage`. An intercepted lethal hit counts its actual HP removed under player HP lost and its excess under overkill. Contact pressure is a combined swarm source. Enemy HP loss comes from the authoritative EnemyWorld damage event; legacy actors that bypass it are outside this damage total. Critical counts require a HitLedger. Generic heals retain a generic source. Detailed ability ancestry, avoided-hit raw damage, loot decisions and automated balance judgments are outside this core recorder.

See events.jsonl for wallet operations, build snapshots, pressure samples and lifecycle events; segments.csv for progression comparisons.
