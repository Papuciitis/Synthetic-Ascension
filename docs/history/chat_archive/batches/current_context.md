# Current documentation context for the recovered chat archive

Prepared 2026-10-16 from repository documentation in this checkout. This is a comparison aid for interpreting old conversations, not a code audit or a replacement for missing chat messages. Statements that work was implemented or tested below are attributed to the named records; no engine or gameplay checks were run for this archive task.

## Source precedence and freshness

[README: Where truth lives](../../../../README.md#where-truth-lives) gives this order: the [vision](../../../SYNTHETIC_ASCENSION_VISION.md) states intent; the [roadmap](../../../SYNTHETIC_ASCENSION_DIRECTION_AND_ROADMAP.md) states priorities and its section 27 appends implementation status; dated [audits](../../../audits/) supply evidence; [Current Game Data](../../../current_game_data.md) supplies numeric snapshots with source citations. Patch-era records are historical. The [history README](../../README.md) says they were moved on 2026-08-29 and points current direction to the roadmap.

Important date boundaries:

| Record | Date actually represented | How to use it |
|---|---|---|
| Vision | No explicit date in the document | Broad design intent; its examples do not establish current implementation. |
| Roadmap sections 1–26 | Header dated 2026-08-27 | Ordered intent and evidence categories; later status entries may supersede examples of what is missing. |
| Roadmap section 27 | Appended entries through 2026-10-14 | Read the relevant later entry before treating an early open thread as still open. |
| Current Game Data | Original code/resource extraction 2026-08-28; augment-specific Quick answers and sections 4–5 refreshed 2026-10-14 | Unrelated sections retain the older snapshot. Counts and numbers cannot all be assigned the October date. |
| Vertical slice definition | 2026-09-19 | Acceptance contract and then-current inventory; later implementations close some listed gaps. |
| Ranged V5 decision/checklist records | 2026-09-25 through 2026-09-27 | Distinguish explicit user direction, handoff requirements, implementation assumptions and measured verification. |
| Front-end register | 2026-10-02 | Recorded presentation direction and UI implementation map. |
| Bindings/Theses and Duos/Facets/Reliquary | 2026-10-03 | Newer augment and major-choice design and implementation records. |
| Augment balance/artwork audit | 2026-10-14 | Latest examined augment implementation and verification record; future combination proposals remain separate. |

## Stable intent that old chats should be compared against

The [vision](../../../SYNTHETIC_ASCENSION_VISION.md) describes a horde-survivor action roguelite whose depth comes from assembling emergent synthetic-occult build engines. The central criterion is that different builds change the player's behavior. Equipment, POS/NEG polarity, rarity/merging, sets, augments, Manifestations, Luck, Followers and Resonance should interact rather than merely raise damage totals.

The three desired experiences are satisfying baseline combat within seconds, a recognizable build direction around minutes 5–10, and a memorable run event around minute 20. The Run Sheet should explain how the build works. The world should respond to escalation, objectives should create different situations, and the Exit Rite should be a resisted climax. Manifestations should form generators, converters, spenders, bridges and feedback loops. NEG archetypes should change how loot is valued: concentrated severity, many meaningful curses, one inverted flaw, or deliberate polarity parity.

The [roadmap](../../../SYNTHETIC_ASCENSION_DIRECTION_AND_ROADMAP.md#4-priority-framework) separates OBSERVED findings, PLAYTEST judgments, DESIGN BETS and VISION. Its ordered development intent is trustworthy foundations, one compelling run, proceduralizing that proven rhythm, scaling it, then expanding buildcraft. Performance work serves playable escalation. These categories are useful archive tags: a proposal or stated fantasy is not evidence that a mechanic exists or feels good.

## Dated progression recorded in the current documents

All rows are documentary claims, not fresh verification performed during archiving. Sources: [roadmap status log](../../../SYNTHETIC_ASCENSION_DIRECTION_AND_ROADMAP.md#27-status-log-appended-by-implementation-the-sections-above-are-the-intent), supplemented by the linked design records.

| Date | What the record says | Boundary or outstanding evidence |
|---|---|---|
| 2026-09-06 | One Elf ranged playtest exposed Run Sheet overflow, unclear elite teaching, hit shake perceived as lag, excessive Follower income, sustained-combat drops and Exit Rite congestion. The stabilization pass records fixes and headless checks. | This was one easiest-combination run, not general slice acceptance. Follower economy remained an open design thread. |
| 2026-09-06, night | Ascension tree specification and interactive mock-up were designed; the entry explicitly says no game code changed. | Do not read this proposal's Reach/peak economy as a shipped system. |
| 2026-09-13 | Follower economy audit says the September 6 proposal was unimplemented, V4 used a different provisional economy, and the intended long-run scale was unresolved. | Prototype prices were not validated production economy. |
| 2026-09-19 | Records seven NEG archetypes, balance revision 2, build simulation, performance instrumentation, loot/run audits and a vertical-slice definition. | It explicitly calls these headless results and still owes the human baseline with both recorders. |
| 2026-09-19, later | Records loot-loop/refund/rarity changes, Segment 1 choices and rooms, enemy rebasing/new roster additions, Luck/shot-rate rules, assets and partial performance work. | Tree redesign stayed deferred; some Segment 1 decisions required measurement. The Weaver, part of Siphon behavior, specialist pools and rendered baseline remained open in that entry. |
| 2026-09-25/26 | Ranged V5, first Ranged VFX pass, L-footprint buildings, Beka companion and walkable between-segment hub were recorded as prototype cores with headless verification. | Gameplay-scale visual review, comparison runs, Beka balance and a hub walkthrough remained due. Later checklist blocks revise the initial handback. |
| 2026-09-26/27 continuation | The [phase checklist](../../../design/2026-09-25-v5-phase-checklist.md) records V5 default for new runs, separate V4 control, integration fixes, tree purchase/declutter work, projectile identity atlas, pixel VFX conversion and non-block city generation. | Remaining items include grenade arc/shadow presentation, Spin aperture presentation, hub furnishing, portions of Exit Rite budget/overtime/recovery review and rendered acceptance. These are dated gaps, not proof they remain absent after later work. |
| 2026-10-02 | The [front-end register](../../../design/2026-10-02-front-end-arcane-register.md) records an ancient arcane workshop aesthetic across menus and run screens: painterly dark surfaces, candle/ember warmth, restrained gold/orange and blue magic accents. | Reduced motion and non-color selection cues are explicit presentation rules. The document includes rendered screenshot probe entry points. |
| 2026-10-03 | [Bindings and Theses](../../../design/2026-10-03-bindings-and-theses.md) records per-segment augment picks, grades, rank/swap/transcend options, Recast/Abstain, D-based potency through level 20, 16 Transcendences, expanded Doctrine plates/families and later Apocrypha stages. | The status entry still owes rendered review and the first human run, including whether stronger augments flatten segments 6–9. |
| 2026-10-03, later | [Duos, Facets and the Reliquary](../../../design/2026-10-03-duos-facets-and-the-reliquary.md) records six Duo pairs, two Facets for combat augments, Burdened Binding and Hub Reliquary functions: Corruption, Transfusion, Vouchers and profile Grimoire. It records review fixes for resource loops and invulnerability chains. | It still owes a rendered look and human run. |
| 2026-10-14 | [Augment balance and artwork audit](../../../audits/2026-10-14-augment-pass.md) records buffs to eight base augments, reliable Slash/Blink/spider outcomes, missile/Choir targeting changes, better readouts and 52 distinct painted illustrations: 16 base, 16 Transcendence, 14 Facet and 6 Duo. It reports 21 focused suites, 3,488 passing checks, parse audit 507/507 and actual Godot card captures. | This was focused verification, not every repository suite. Human encounter playtesting is still due. New curse combinations were proposals, not included rules. |

## Decisions, assumptions and review advice must remain distinguishable

The [V5 decision log](../../../design/2026-09-25-v5-decision-log.md) explicitly labels authority. Examples that should survive later summaries:

- **Explicit user direction in those records:** Beka's text-described appearance; the September 26 exclusion of GPT-generated shipping art; the four approved item prototypes in D-19; V5 default for new runs in the checklist. These are historical, scoped decisions. Later messages may change them.
- **Implementation interpretations:** D-4's firing-rate composition, D-5's rank refund interpretation, D-6's Spin Up grace timing, D-7's generic rank gates and D-10's grenade behavior after target death. They must not be rewritten as verbatim user requirements.
- **Superseding implementation record:** D-14 rejects the initial projectile overflow queue as the normal capacity solution. Simulation grows to a larger bound while rendering has a smaller budget; excess projectiles remain mechanically real. The initial roadmap handback's queue description predates this correction.
- **Historical safety incident:** D-18 records a test that wrote into the real player save and the subsequent test-slot convention. It is a documented past incident and convention, not evidence of a new archive-task incident.
- **Advisory review:** [the September 26 GPT handoff consult](../../../handoffs/2026-09-26-gpt-handoff-consult.md) recommends integration and measurement, and lists alleged earlier decisions. It is an assistant review document; where original user messages are missing, its attribution is secondary evidence.
- **Planned migration:** [the September 16 V4 migration boundary](../../../design/2026-09-16-v4-migration-boundary.md) explicitly says no resource migration was performed. Its stable node-ID/save-key and single-authoritative-source rules are a design boundary; the Momentum resource pilot is design only.

The [September 25 full handoff](../../../handoffs/2026-09-25-ranged-v5-and-visuals-claude.md) says prototype values are not validated balance. Its original Ranged proposal is preserved as an appendix, with newer brief instructions resolving scope and gaps. Source precedence within that artifact must be retained when recovering chat context.

## Concrete supersession traps for historical reconstruction

1. **"Equilibrium is future work."** That is an example in the vision; September 19 and October 14 records describe an implemented Sigil. Preserve both the earlier aspiration and the later status with their dates.
2. **"The Ascension tree is only designed."** That is the September 6 night entry. The September 19 inventory lists the V4 tree and nine engines; later V5 records add a separate Ranged prototype and then a new-run default. Do not collapse these stages.
3. **"Only three augment picks, maximum level five."** That is the weakness described at the start of the October 3 change. Later records describe per-segment Binding and level-20 scaling.
4. **"Projectile overflow queue fixed lost damage."** The first handback said this; D-14 later records why a queued normal attack was inadequate and changes the design.
5. **"All current numbers were refreshed in October."** Current Game Data explicitly retains August data outside selected augment sections. The September slice inventory also has dated counts that differ from the older numeric snapshot.
6. **"No generated art was ever approved."** D-13 records a September policy; the October 14 audit separately records user-approved painted style references and generated masters. Record the temporal evidence and scope; do not infer a universal reversal or silently erase the earlier decision.
7. **"Headless green means the game achieved its vision."** The roadmap, handbacks and latest augment audit all keep implementation checks separate from human playtest acceptance.

## Open questions to carry forward without inventing answers

The [September 19 slice contract](../../../design/2026-09-19-vertical-slice-definition.md) asks for one approximately 25-minute attempt spanning authored Segment 1, Hub, procedural Segment 2, resisted Exit Rite and Hub. It calls for one run per starting style. Its acceptance criteria include satisfying combat, named build identity, deliberate risk, visible power threshold, climax, behavioral build description, distinct stories, explained rendered hitches, resolved exploit decisions and Follower spending tension. Later code-change records can close implementation gaps but do not by themselves answer those experience questions.

Most useful questions for recovered chats and future handoffs:

- Which original messages explicitly approve, reject or revise the economy, endless/long-run progression, starting-style/hybrid structure and Exit Rite flow?
- Which dated playtests actually ran, on which build/style, with what observed outcomes and recorder captures?
- Which world/hub and art references were supplied by the user, and which were assistant recommendations or provisional placeholders?
- Which current-looking design paragraphs were superseded by later decisions or implemented differently under a documented assumption?
- Which remaining augment combination concerns became work, rather than remaining [October 14 proposals](../../../audits/2026-10-14-augment-combinations.md)?

Missing history should be represented as missing. This comparison does not reconstruct inaccessible user decisions, does not establish today's runtime state, and does not turn a historical assistant's assurance into independent proof.

Search tags: synthetic-ascension, current-docs, source-precedence, vision, roadmap, status-log, v4, v5, follower-economy, ascension, neg, manifestations, exit-rite, hub, beka, ranged, bindings, theses, duos, facets, reliquary, augment-art, playtest, supersession, documentary-evidence.
