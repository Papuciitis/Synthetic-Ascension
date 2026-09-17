I’d design a Balance Recorder that produces a timeline and report for each run. Its main job should be explaining why the player became stronger, richer, or easier to kill.
The game already has useful foundations: combat events, Follower transactions, a stat contribution ledger, and Ascension counters. We could build on those.
What it should measure
Area	Measurements	What we learn
Player scaling	Current/max HP, armor, Power, Haste, Luck, movement speed; each stat’s contributions from equipment, augments, tree nodes, and temporary effects. Snapshot every build change.	Where power comes from, which multipliers dominate, and when growth stalls or jumps.
Player damage	Damage by weapon, ability, item effect, summon, and damage over time; attack rate, criticals, targets hit, chain length, and damage per cast. Separate damage before defenses, damage after defenses, actual HP removed, and overkill.	Which effects carry the build, whether damage is wasted, and how single-target strength compares with crowd clearing.
Enemy scaling	Enemy type, elite modifiers, actual HP and attack damage, scaling factors, spawn source, healing/shields, and time from first engagement to death. Track enemies that escape or remain alive too.	Whether enemies become tougher through HP, defenses, healing, or simply greater numbers.
Player survival	Incoming damage by enemy and attack; damage prevented by armor, evasion, and invulnerability; actual healing, overhealing, healing denied by locks/caps, and intentional HP spending. Record low-health time, rescues, deaths, and the seconds leading up to each death.	Whether deaths come from burst damage, sustained pressure, insufficient recovery, or a particular enemy combination.
Follower economy	Every gain and loss with its reason; opening/closing balance per segment; recruitment, sales, purchases, refreshes, tree investment, drains, sacrifices, and reconstruction. Identify refunds, undo, and save restoration separately.	Income growth, meaningful spending decisions, expensive build upkeep, and whether wealth outpaces available purchases.
Loot and choices	Items generated, collected, left behind, removed by the ground-loot cap, equipped, merged, and sold; rarity and quality. Record shop offers and reward choices presented alongside what was chosen.	Whether progression is limited by prices, availability, inventory capacity, or unsuitable rewards.
Pacing and pressure	Segment/phase, resonance, Threat, overtime, nearby enemies, elite mix, spawn/kill rates, objective progress, Exit Rite attempts, and time spent fighting, travelling, or managing the build.	Where runs drag, difficulty spikes, or farming becomes more attractive than progressing.


The most useful report outputs
I’d prioritize these over a giant page of totals:
- Time to kill ordinary enemies, elites, and bosses, by segment and build.
- Damage taken as a percentage of max HP, including the worst one-second bursts.
- Damage versus recovery over time—showing whether a build can sustain incoming pressure.
- Followers earned and spent per active minute and per segment, broken down by source.
- Affordability: when important upgrades become available and affordable, when they are purchased, and how much of the wallet they consume.
- Build milestones: when the first working combination appears and how combat changes afterward.
- Before/after comparisons between game versions, with comparable builds, progression, and enemy pressure.
For your game, chain reactions deserve their own attribution: the initiating attack, effects it triggered, and their combined contribution. Otherwise a powerful interaction could look like unexplained “player damage.”
How to keep the measurements trustworthy
I recommend exact gameplay events plus periodic snapshots and segment summaries. Summaries alone lose causes; recording every frame adds substantial volume.
Every recording should include the build/version, world seed, starting progression, loadout, and debug modifiers. Separate active gameplay time from pauses and shop time. Keep unfinished and failed runs, and show sample counts and variation across runs.
One particular trap: higher damage after an upgrade does not prove the upgrade caused it—enemy density and Threat may also have changed. The report should preserve that context.