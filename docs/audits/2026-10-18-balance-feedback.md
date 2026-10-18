# Playtest balance feedback — 2026-10-18

The capture supports a strong, sustainable Ranged build and two measured boss
kills. It also exposes a segment-attribution defect. It does **not** establish
that boss HP, regeneration or Fragmentation should be retuned across builds;
no such tuning change is inferred from this session.

## Original capture and coverage

Source: `balance_captures/2026-10-18/2026-10-18_14-29-09_19808_357870982_1/`.
The retained [original report](evidence/2026-10-18-balance-feedback/report.md),
[summary](evidence/2026-10-18-balance-feedback/summary.json) and
[segment CSV](evidence/2026-10-18-balance-feedback/segments.csv) are byte-identical
copies, including their original labels.

Recorded build: game `0.0.0.25.5`, commit `c9d5a31772f3`, Godot 4.7.1, world
seed `1794675549650`; recorder revision **2**, balance revision **2**, live
item/set/economy stages. The starting flags show developer mode enabled,
god mode disabled, enemy HP scale 1.0 and time scale 1.0. Coverage begins at S5
with an established Elf/Ranged setup, six Lattice pieces, Regeneration Ring
and substantial Ascension ownership; BR05 is already rank 2. Earlier
acquisition and build preparation are outside this capture.

The exact gameplay total is **986.557637677374 seconds** (986.56 rounded),
with 76.28 paused and 298.72 hub seconds. This is one evolving build in one
observed session, not a build comparison. Its 334 build records are successive
snapshots, not independent trials. Outcome is `application_closed`, not a
recorded run failure or proof of completing the full game.

Recording reports zero dropped records, wallet discontinuities and writer
failures. These checks support accounting integrity; they do not validate
every source label or segment identity.

## Boss fights and segment-label defect

| Observed fight | Boss HP | Engaged kill time | Samples |
| --- | ---: | ---: | ---: |
| S5 Bulldozer miniboss | 6,037.99 | 23.812 s | 1 |
| S10 Arcanist main boss | 21,378.36 | 74.552 s | 1 |

TTK is gameplay time from the first damaging hit to death. It excludes the
approach and pauses, and includes the fight's intervening movement and
commitments. Different tiers, roles, equipment states and one kill each do
not provide a controlled HP comparison. Both bosses died and the capture
records zero player deaths/reconstructions; this does not establish their
general difficulty or explain artistic feedback about their feel.

The original rows are **5, 6, 11**. After S5 completion, the recorder opened
the expected next row, S6. The developer route entered S10 without an ordinary
S6 completion, but revision 2 never realigned its active row on Game re-entry.
S10 combat and the Arcanist victory consequently remained under S6; the later
completion opened S11. Do not read that row as an ordinary S6 playthrough or
invent clears for S7–S9.

Bounded [route/boss records](evidence/2026-10-18-balance-feedback/route-boss-events.json)
preserve the original event sequence and labels. Matching-seed flight-recorder
incidents 62 and 106 explicitly identify S10 and the main-boss entrance;
their metadata/events and source hashes are in
[pfr-segment-evidence.json](evidence/2026-10-18-balance-feedback/pfr-segment-evidence.json).
The correction is tracked as recorder revision **3**, separately from the
unchanged item-balance revision. The recorder now aligns on the scene request, before the outgoing player is freed or incoming actors register, with a fallback at gameplay entry. It preserves the old row as `route_changed`, snapshots its final counters and counts incoming enemies once. Game readiness ends loading explicitly; Hub readiness is guarded, and the loader's temporary pause remains loading time. Failed scene or supplemental-atlas requests restore the prior clock. Historical artifacts remain unchanged.

[Native verification](evidence/2026-10-18-balance-feedback/verification.json) passes **115 checks**: recorder 36, health accounting 34, revision 10 and ledger 35, all native exit 0. The retained expected-failing regressions reproduce the initial segment defect, the earlier boundary/loading gaps and the supplemental-resource failure mismatch identified in independent review. All runs used isolated profiles.

## Health, damage and economy observations

The player lost **845.15 HP** to hits and received **849.04 applied healing**.
There were **13,785.32 HP of healing overflow**, about **94.2%** of applied
plus overflow. Regeneration Ring supplied 446.83 applied HP, generic healing
206.10 and lifesteal 182.98. Overflow is an aggregate: this report cannot
assign all of it to the ring. Travel at full health, multiple healing sources
and the existing build all affect it.

Health reconciliation records 1,859 changes, 1,053 checks and **zero
unexplained checks**, with zero maximum residual. The 44 stat adjustments
add 116.01 HP; they are recorded separately from healing and enemy damage.
The actual-health totals reconcile, but incoming damage still includes
262.19 HP under `unknown`, and generic healing lacks specific ancestry.
Source attribution is therefore less complete than HP accounting.

**472,725.64 enemy HP** was removed over **11,053 kills**. BR05 Fragmentation
accounts for **100,607.10 HP / 21.28%** as an origin and **103,269.38 HP /
21.85%** as the immediate fragment emitter. These are alternate groupings of
the same damage, not additive contributions. Native Ranged, Lattice,
Predestination Sigil and Magic Missile also contribute. This demonstrates a
working damage network in this build; it does not isolate Fragmentation's
marginal power against another build or establish a general nerf target.

The wallet reconciles exactly: **370 + 29,880 earned = 30,250 closing**,
with zero recorded spending, adjustments or developer grants *during this
capture*. Combat influence contributes 29,847, miniboss victory 8 and main
boss victory 25. The pre-owned Ascension setup precedes recording; zero
spending does not prove those purchases were free or represent normal
early-run progression. Shop affordability cannot be evaluated from a session
with no recorded purchases or offers.

## Follow-up targets and limits

If later cross-build evidence supports tuning, the relevant sources are
[S5 arena rules](../../scenes/world/events/MiniBossArena.gd),
[S10 arena rules](../../scenes/world/events/BossArena.gd), their
[Bulldozer](../../core/actors/enemy/EnemySpec_BossBulldozer.tres) and
[Arcanist](../../core/actors/enemy/EnemySpec_BossArcanist.tres) specifications,
[RegenerationRingEffect](../../effects/items/logic/RegenerationRingEffect.gd)
and [item curves](../../data/items/item_scaling_v2.json), plus
[BR05's authored rule](../../data/ascension/tree_v4.json) and
[BarrageEngine](../../core/systems/ascension/engines/BarrageEngine.gd).
Listing them is not a recommendation to change their numbers.

The source/context and original-artifact hashes are retained in
[provenance.json](evidence/2026-10-18-balance-feedback/provenance.json).
Only 14 lifecycle/boss-reward records were extracted from 19,083 event
records; the full 11 MB event stream is hashed rather than duplicated.
[Derived observations](evidence/2026-10-18-balance-feedback/derived-observations.json)
retain arithmetic and first/last build identities. The report analysis introduces no new balance experiments; the recorder correction is covered by the native checks above. Fresh non-developer
progression, other builds, repeated fights and human assessment remain
necessary before broad difficulty or economy conclusions.

## Incoming projectile ancestry follow-up

The original `unknown` incoming damage consists of **71 health changes in
62 metrics windows**, totaling **262.18514150329 HP**. A concrete production
loss path was identified: `EnemyShooter` supplies its enemy ID to
`ProjectileSimulationManager.spawn_enemy`, but the manager previously used
the ID only for visuals. When the firing actor was freed before impact,
the managed hit delivered a null source and the recorder fell back to
`unknown`. The aggregate historical windows cannot prove that every unknown
hit came from this path, so their original labels remain unchanged.

The manager now retains the spawn-time ID in its bounded reusable projectile
slots. During a recorded impact it passes a separate context to the actual
player; the recorder uses it for resolved-damage and canonical health source
labels. An unmixed batch has one source ID; a mixed batch is explicitly
`mixed` with up to 16 member IDs and an overflow flag. Unknown members remain
visible even after the cap. No mitigated HP shares are invented for members.

The source Node, attack kind, hit merging, caps, armour, Trauma rules and
health changes are preserved. The original **107-line damage resolver body
is byte-equivalent after newline normalization**, verified by its retained
body hash. Nested ordinary damage sees an empty context and restores the
outer context afterward. Legacy two-argument targets retain their API.
Per-impact context construction is gated by a canonical health observer;
the small slot identity is retained for projectiles already in flight when
recording begins.

The corrected pre-fix regression had 40 passing / 9 expected failing checks.
The expanded final regression passes **74/74**, including actual freed-owner
impacts, mixed/unknown batches, slot reuse, the 16-ID cap, reentrant callbacks,
real recorder source labels and reconciled health. An original 100-raw batch
still loses exactly 21 HP after its single cap, 100 armour and learned Trauma
resistance; a living boss retains its 31.5 HP result and original Node/kind.
Compatibility passes: BigHitProtection **16/16**, BalanceHealthAccounting
**34/34**, ProjectileHandleCombat **25/25**, ProjectileSlotReuse **17/17** and
ItemBatch3 **19/19** — **185 checks total**, six native exit-0 executions with
empty stderr, isolated APPDATA/LOCALAPPDATA, Godot 4.7.1 headless/Dummy audio.

The [follow-up evidence](evidence/2026-10-18-balance-feedback/incoming-projectile-attribution/)
contains representative original unknown windows, expected-red and clean-green
logs, native results, the resolver equivalence proof and source/evidence
hashes. Production paths are
[ProjectileSimulationManager](../../core/combat/projectile/ProjectileSimulationManager.gd),
[player](../../core/actors/player/player.gd) and the
[BalanceRecorder adapter](../../autoload/BalanceRecorder.gd); the focused
[regression](../../tools/tests/EnemyProjectileAttributionTest.gd) exercises the
actual delivery path. This is an instrumentation correction, not damage
tuning or retrospective recovery of unavailable firing identities.
