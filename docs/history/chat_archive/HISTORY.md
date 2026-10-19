# Synthetic Ascension game history

This history connects recovered conversations with dated project records. It preserves original intentions, changes of direction and failed experiments without turning old requests into the current plan. The [coverage register](coverage.json) is the live account of recovered messages, captures, attachments and gaps; the [archive index](README.md) explains how to follow them.

Recovery remains partial. A reader's `hasMore: false` does not establish a complete export. Browser captures distinguish reaching the beginning from reaching the end; capture dates are not original message dates. The opening concept has combined beginning-to-ending evidence, but the archive does not claim a unified complete transcript. Other chats contain short windows or access-failure receipts.

## The original concept in the user's own words

The recovered beginning of **Game Development Tools** establishes more than the previously available assistant recap. The user asks about a Vampire Survivors-like 2D dungeon crawler with random items and spells, identifies as a beginner, targets PC with possible Steam release, and wants cutscenes between parts. Godot is the assistant's recommendation; explicit engine selection is not captured here. [Opening source and digest](conversations/6981b42f-a1ac-8388-9f6b-f4316054575c.md).

Direct user requirements are:

- **Two persistence layers:** six item slots whose contents disappear on death, alongside three spell-card slots that remain.
- **Items, sets and starting identity:** duplicate pickups stack; set bonuses belong primarily to items; roughly four races and melee/ranged/magic starting options provide variety.
- **The “super randomizer”:** extreme positive and negative item stats are the attraction, with −9999 to +9999 illustrating the intended extremes. Exact bounds, distribution and stacking mathematics are undecided.
- **Desirable negatives:** a spell that makes negative modifiers beneficial is explicitly a must-have.
- **Followers connect progression and survival:** deeds/runs attract Followers; Followers buy spell upgrades and pay for death; remaining Followers permit respawn, while zero means permadeath with spell slots still active.
- **A technology-spreading premise:** the player discovers synthetic technology through melee/ranged/magic and tries to make it available to others while opposing entities intervene.

The last three points come from [the recovered original user message](https://chatgpt.com/c/6981b42f-a1ac-8388-9f6b-f4316054575c?messageId=bbb21f0e-601c-4894-ae7f-008c0a98675e), rather than reconstruction from the blueprint. “Items disappear on death” alongside Follower-funded respawns needs later clarification; this source does not settle every death/run boundary.

The user closes feature expansion and declines competitor study at that stage to protect the independent concept. A roughly three-hour first stage and €5–10 price are tentative questions or aspirations. Heavy-tailed rolls, soft caps, 2/4/6 set thresholds, race names, escalating death costs, logarithmic spell scaling and “Inverse Engine” with 50% conversion are assistant proposals, not confirmed rules. Market and uniqueness claims are historical opinions. Another assistant recap names *The Ascension of Syn’Tek* and an artificer/proto-god premise; its underlying original lore messages remain missing. [Concept evidence](conversations/6981b42f-a1ac-8388-9f6b-f4316054575c.md), [Syn’Tek recap](conversations/69822a53-6a20-8385-9eb7-3f5393b473c2.md).

## From concept to prototype

**February 3–5: playable foundations.** User-pasted logs record menu → saves → base → game flow, damage, Follower gains, a ten-Follower death cost, respawn and Game Over. A later item test updates HP to 125 and speed to 235. These are historical execution evidence. The user prioritizes a modular player foundation, reports unwanted autofire/missing click attacks, and supplies the inventory sketch: two columns by three rows below HP and Followers. The layout receives confirmation; final autofire and SaveCard repairs remain unconfirmed. [Combat](conversations/69826fce-5958-838b-91b1-44e7dfb4437c.md), [inventory](conversations/69831bf7-b8ac-8385-8a8d-85f1d4c0603b.md), [modular player](conversations/69835f0b-34e4-8397-be22-199a4d7287c1.md), [save cards](conversations/69849acb-2570-8385-9d51-0f3beff761d2.md).

**February 11–12: sniper identity and an unresolved failure.** In **Roguelike Enemy Spawning System**, the user accepts A/B behavior: disciplined base sniper and tactical, cover-using elite. This accepts the split, not every suggested stat or cap. The final user test says the sniper approaches without attacking and has an unwanted red tint. Pasted resources/scripts and an inspector image establish historical configuration; enum routing, module calls, spec assignment and tint repairs remain assistant diagnoses/proposals. No successful final test is recovered. [Sniper decisions and failure](conversations/698c4e97-b728-8390-bc30-e6dd762fe5d0.md).

**Undated branched tail: navigation revisions repeatedly fail.** **Atzarojums · Atzarojums · Atzarojums · Roguelike Enemy Spawning System** reports enemies stuck at walls, vibrating, then failing to approach. The user wants them to find a room exit even when it lies away from the player, and suggests routing to restore line of sight around cover. They explicitly imported one revision: enemies move left/right but miss a bottom exit when the player is above. They also ask to split navigation into separate modules so `enemy.gd` stops growing. The final `EnemySenses`/`EnemyNavigator` proposal has no subsequent result. Confident assistant explanations do not erase the preceding failed tests. Original dates and earlier context are absent. [Navigation sequence](conversations/698f4308-37a8-838c-8b0f-8f053e3ad8bf.md).

**February 21–22: accepted tooltip and shop, then cover discussion.** **Project Snapshot Summary** contains “It works!” after the reported Threat-tooltip delivery. The user chooses a proper RPG sell screen before procedural Segment 2, reversing the suggested order, approves the design, then accepts the delivered shop without more polish. This is broad historical acceptance; the ZIP contents are not preserved here. The next discussion explicitly makes windows/three-quarter cover shoot-through terrain, while rubble/table half-cover mechanics remain undecided. Suggested projectile probabilities, Threat heat curves, encumbrance and route distances are not selected rules. [Tooltip, shop-first decision and cover intent](conversations/69999621-00d4-838d-89e6-fe16c8e18065.md).

**February 23: exploration, tension and readability.** In **Procedural Cover System**, the user specifies open, explorable Segment 2 followed by tense Segment 3, and supplies assets intended as one-tile pieces. After assistant-reported integration/comfort passes, they report visual discomfort and parse/filter errors. They clarify that visible collision debugging is useful; the problem is busy, contrasty, repetitive ground and indistinct walls. A grass backdrop, revised Level 1 composition and sigil/VFX waypoints are requests or suggestions. The final response supplies another plan without recovered acceptance; exact layouts, collider choices and filtering fixes remain assistant proposals. [Procedural cover digest](conversations/699b92a5-20b8-838e-aac5-943bb51dc741.md), [raw messages](sources/699b92a5-20b8-838e-aac5-943bb51dc741/page-001.json).

**July 23: performance work meets correctness defects.** **Enemy Performance Optimization** asks whether enemies can receive a conversion analogous to bullets. The first reported patch is intermediate enemy LOD, not a completed packed-array/MultiMesh conversion. The user experiences improvement but reports death completing an unfinished objective and excessive Splitter-family loot; only one eligible descendant should inherit the original item. After a reported fix, they observe reconstruction speed inconsistency and HP-display disagreement. Preserved screenshots support the HP mismatch, not measured speed or FPS. The final stat-sync patch has no recovered user verification; a lightweight Grunt/Runner prototype remains proposed. [Performance snapshot](conversations/6a61ce3a-8f3c-83ed-b8a2-bcb9c5107438.md).

## Later project records and supersessions

These developments come from repository records, not reconstruction of missing conversations. [Repository chronology](batches/repository_history.md) preserves sources and verification limits; [current documentation context](batches/current_context.md) explains dated supersessions.

| Period | Recorded development and change |
| --- | --- |
| July patch era | Institutional escape, laboratory opening, Bren, Segments 1–10, equipment sets, augments, Hub exchange, procedural districts and the exit loop. Some patch reports supply static checks only. |
| July–August | The city becomes an open district web with alternative routes, landmarks and rewarded endpoints. Procedural segments gain a relay before the exit. Rarity merging, POS/NEG and Manifestations deepen build construction; performance work supports larger pressure budgets. |
| Late August | Canonical direction emphasizes synthetic-occult engines that change player behavior, with the Run Sheet explaining their interactions. Proving one memorable run precedes procedural breadth. |
| September 6–19 | An Elf/ranged playtest exposes weak teaching, excessive Followers, shake perceived as lag, crowded Rite channels and performance drops. Follower/tree proposals, economy audits, V4, seven NEG archetypes, simulation and a vertical-slice contract are successive records. |
| September 25–27 | Ranged V5 adds explicit local ranks/refunds and ranged identities. Records also describe non-block city work, a companion and walkable inter-segment Hub. A later ruling replaces normal projectile-overflow queuing with a larger simulation budget. |
| October 2–14 | Presentation moves toward an ancient arcane workshop. Bindings, potency, Transcendences and Theses answer weak augment choices beside the tree; Duos, Facets and the Reliquary follow. October 14 records earlier payoff and art for 52 upgrade forms; human encounter playtesting remains due in that record. |

The original “no more systems” belongs to February's scope decision; later hubs and trees are dated expansion, with approval history incomplete. Early Followers fund spells and lives; later vision adds belief, attention and metaphysical meaning. September's Reach/peak economy proposal and later V4 are different designs, not formulas to combine.

Other consequential revisions: a blanket Manifestation merge refusal changes because it blocks progression; shared resources become interacting state; Vector Halo changes from automatic discharge to a dash trigger. Hit-stop/camera punch are introduced for impact, then left off by default after playtest diagnostics. September's generated-shipping-art restriction and October's approved painted/generated masters are different dated records, not timeless rules. [Revision evidence](batches/repository_history.md), [supersession details](batches/current_context.md).

## Topic guide

| Looking for | Start here |
| --- | --- |
| Original user pitch, randomizer, persistence, Followers, price/scope | [Game Development Tools](conversations/6981b42f-a1ac-8388-9f6b-f4316054575c.md) |
| Syn’Tek and early spell/player recap | [Godot Expertise Overview](conversations/69822a53-6a20-8385-9eb7-3f5393b473c2.md) |
| Death, respawn, manual input and first logs | [Godot Code Review](conversations/69826fce-5958-838b-91b1-44e7dfb4437c.md) |
| Inventory sketch, first item, modular player, save UI | [Inventory](conversations/69831bf7-b8ac-8385-8a8d-85f1d4c0603b.md), [player](conversations/69835f0b-34e4-8397-be22-199a4d7287c1.md), [saves](conversations/69849acb-2570-8385-9d51-0f3beff761d2.md) |
| Sniper/elite split and failed attacks | [Roguelike Enemy Spawning System](conversations/698c4e97-b728-8390-bc30-e6dd762fe5d0.md) |
| Room exits, LOS, wall-follow failures, module split | [Branched navigation](conversations/698f4308-37a8-838c-8b0f-8f053e3ad8bf.md) |
| Threat tooltip, RPG selling, shoot-through windows | [Project Snapshot Summary](conversations/69999621-00d4-838d-89e6-fe16c8e18065.md) |
| Open Segment 2/tense Segment 3, assets, visual discomfort | [Procedural Cover System](conversations/699b92a5-20b8-838e-aac5-943bb51dc741.md) |
| Enemy LOD, Splitter loot, reconstruction/HP mismatch | [Enemy Performance Optimization](conversations/6a61ce3a-8f3c-83ed-b8a2-bcb9c5107438.md) |
| Escape, city, POS/NEG, Manifestations, later builds | [Repository chronology](batches/repository_history.md), [current context](batches/current_context.md) |
| Missing chats, exact submitted targets, recovery limits | [Coverage register](coverage.json), [submitted links](submitted_links.json), [archive index](README.md) |

## What governs the game now

Use the [current vision](../../SYNTHETIC_ASCENSION_VISION.md) for intent and latest relevant [roadmap status entries](../../SYNTHETIC_ASCENSION_DIRECTION_AND_ROADMAP.md#27-status-log-appended-by-implementation-the-sections-above-are-the-intent) and dated audits for progress. The roadmap's August header predates appended October entries; much of [Current Game Data](../../current_game_data.md) remains an August snapshot despite selected October updates.

For an old decision, follow its digest to the exact saved message. For present behavior, inspect current code and later verification. Proposals, reported deliveries, user observations and preserved artifacts carry different evidence. Missing originals remain gaps; a recap cannot supply them, and a historical assurance cannot prove that a fix worked or still applies.
