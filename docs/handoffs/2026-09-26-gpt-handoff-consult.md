Yeah — Claude implemented a lot, but the handoff is biased toward **“new systems exist and tests pass”** rather than **“the actual game loop still behaves like Synthetic Ascension.”** The next work should be integration/tuning, not another feature wave.

## (a) Things Nauris had already decided that this handoff may have dropped

### P0 — verify these before adding anything else

1. **The objective → Resonance → Exit Rite loop is almost absent from the handoff.**  
   The world work talks about L-shaped buildings and 2.5D depth, but the actual level-design contract was much larger:
   - meaningful primary objective;
   - 0–3 optional objectives/events;
   - Resonance earned through progression, not standing around farming mobs;
   - Exit Rite states **LOCKED → LOCATED → READY**;
   - checklist explaining what is blocking the gate;
   - directional guidance appearing around ~75% progress;
   - safer vs riskier routes;
   - alleys/buildings rewarding exploration;
   - landmarks/readability without permanent GPS.

   This is probably the single biggest omission. A better building generator does not automatically produce the intended game.

2. **Segment 1's redesign needs checking against the new parcels.**  
   Segment 1 was meant to become a **substantially larger escape**, moving through institution/lab/research/containment/service areas and then into a city block/gate area. Violence starts fairly early; it isn't supposed to feel like a tiny tutorial arena.

   There was also already a pacing complaint that **objective → gate was too short**. The new geometry could accidentally make the map larger while leaving the actual progression path just as short.

3. **Ranged V5 must still obey the wider Ascension-tree rules.**  
   Nauris had already decided:
   - the player deliberately starts **Melee / Ranged / Magic**;
   - that starting choice matters;
   - hybrids come later;
   - the radial tree grows outward into increasing specialization;
   - Followers remain the progression currency for major Ascension purchases/screen-wipe abilities;
   - Followers do **not** get arbitrary per-segment hard caps.

   Local ranks/refund receipts are good, but I'd specifically test that V5 hasn't accidentally become its own little progression system detached from the shared ledger, hybrids, Witness, Ascendant progression, etc.

4. **Save compatibility needs more than “V4 has separate saves.”**  
   Previous work established some fairly important rules:
   - don't casually rename/move save-addressed resources;
   - explicit `save_version` / `game_version`;
   - preserve unreadable slots instead of destroying them;
   - handle a save from a newer build sensibly;
   - stable-ID migration was still an open problem.

   V4 being byte-identical is excellent as an A/B control, but I'd now demand an actual migration matrix:
   **old V4 save → V4**, **old save → V5**, **V5 save → newer V5**, corrupt save, partially missing resources, refunded ranked nodes, changed node IDs.

5. **Old combat correctness bugs need to be checked rather than assumed fixed.**  
   Earlier Ascension prototype review still had issues such as:
   - damage reductions that could effectively heal afterward;
   - some Undo / Replay / REWRITE interactions not covering normal attacks correctly;
   - Gather being approximate;
   - Denial projectile slow still unresolved.

   None of those are inherently fixed by reworking Ranged. They could still contaminate V5 testing and make balance conclusions meaningless.

6. **Performance work is not finished just because projectile loss is fixed.**  
   The previous bottleneck was already known to move toward **100–130 active enemy simulation**, with FULL/MID/FAR LOD still needing proper hysteresis and true physics shedding. Segment transitions had also shown a noticeable hitch.

   And the new projectile overflow queue creates a new danger: **you solved deletion by potentially creating backlog**.

   “Never lose player damage” is correct. “Queue projectile spawning until capacity exists” may not be. If shots fire now but only physically materialize 300 ms later under load, DPS and hit timing become frame-load-dependent.

   I'd make the rule:

   **Gameplay events may never be deleted *or delayed* by renderer capacity.**

   Simulation should remain authoritative; visuals are what degrade.

### P1 — existing design contracts that should come along for the ride

7. **The walkable hub must retain all the vendor QoL already designed.**  
   “Reuse shop economy unchanged” isn't enough. There were already decisions around:
   - persistent stock for the visit;
   - refreshes with escalating costs;
   - Affordable filtering;
   - relevant-slot comparison;
   - Ctrl-lock;
   - locked items protected from sell/discard/negative replacement;
   - one-step Undo Last Trade while in the hub;
   - remembered filters/search/sort/scroll;
   - right-click/Shift/double-click interactions;
   - BG3-ish warmer RPG presentation rather than gray rectangular developer UI;
   - set previews where applicable.

   Making the hub spatial should not regress the mature parts of the old trade screen.

8. **The item ecosystem is much larger than the eight curse icons.**  
   Existing rules still include:
   - POS and NEG as separate items;
   - Luck affecting POS/NEG rolls, drop chance, extra crits, evasion, Followers, exploration events, vendors/prices and augment-related rolls;
   - duplicate items remaining useful through rarity combining;
   - same-rarity feeds being strongest while lower rarity still contributes;
   - style-specific lifesteal.

   If the curse relics now have icons but none of their downstream economy/build interactions have been retested, that is presentation progress rather than item-system completion.

9. **The visual identity needs to apply outside Ranged too.**  
   The new Ranged work sounds aligned: constructed, engineered synthetic magic.

   But the larger project direction was also:
   - top-down/near-orthographic;
   - chunky, readable shapes;
   - limited unnecessary detail;
   - occult/fantasy/industrial rather than cyberpunk;
   - no return to “purple whimsical AI magic”;
   - readability at actual gameplay zoom beats pretty isolated assets.

   The new 2.5D buildings could easily drift into “generic indie isometric city” if their south faces, roof caps and entrances are more visually elaborate than the characters/enemies.

10. **The newer progression direction superseded the old “10 segments and done” assumption.**  
    There is older design material describing a 10-segment campaign/capstone, but the later decision was that runs can continue **beyond 10 segments** and Followers scale much further.

    I'd check for hardcoded assumptions such as `segment <= 10`, ten-element arrays, fixed boss progression, vendor scaling ending at 10, or save schemas sized around exactly ten segments.

---

# (b) New things I'd add next

### P0 — integration pass, not another content pass

1. **Build one brutal end-to-end vertical slice test.**

   Start a fresh run → choose Ranged → complete objective → do a secondary → enter building → gain Resonance → Exit Rite → hub → buy/sell/merge/Ascend → next segment → load/save → die/reload if relevant.

   That single route should exercise **the game**, not each system independently.

   Your current headless suites tell you the pieces don't immediately explode. They don't tell you the run is coherent.

2. **Add a “run truth” telemetry dump.**

   For every segment, log at minimum:
   - time to primary objective;
   - Resonance completion time;
   - time from READY to Exit Rite;
   - secondary objectives attempted/completed;
   - kills;
   - damage by source/node;
   - overkill;
   - proc counts;
   - grenade frequency;
   - Big One trigger count;
   - average/max projectile population;
   - overflow queue size and oldest queued age;
   - enemy FULL/MID/FAR populations;
   - frame spikes;
   - Followers earned/spent;
   - hub dwell time;
   - vendor refresh count;
   - healing received;
   - Beka shield absorbed;
   - Beka pulse activations and pickups moved.

   Without this, Nauris will be tuning by vibes on systems whose interactions are already becoming too complicated to reason about manually.

3. **Make projectile capacity a rendering-budget problem rather than a combat-budget problem.**

   This deserves special emphasis.

   For example, Barrage at absurd attack speed should still mathematically fire every shot at the correct simulation time. If there are too many to draw, combine/truncate visual representations, but keep hit timing and provenance exact.

   Otherwise a low-end PC gets a mechanically different Barrage build than a high-end PC.

4. **Introduce automated invariants rather than only scenario tests.**

   Things I'd assert continuously:
   - refund(purchase(x)) restores the exact previous ledger state;
   - damage contribution is conserved through overflow;
   - no proc recursively triggers itself unless explicitly permitted;
   - Witness cannot manufacture an invalid foreign-core source;
   - Big One cannot be fed by something merely tagged visually as a Shell;
   - Hot Core/Meltdown cannot reintroduce Jam through some older code path;
   - no item can exist simultaneously in inventory + equipped + vendor;
   - Followers cannot go negative;
   - Exit Rite cannot become READY with an unmet required blocker;
   - V4 data remains hash-identical.

### P1 — feel/readability work

5. **Give each Ranged subtree a measurable screen-language budget.**

   Precision should remain extremely clean. Barrage can accumulate activity. Ordnance can own big anticipation/impact shapes.

   I would explicitly prevent them from converging as power scales.

   At endgame:
   - Precision = *one horrifyingly exact line*;
   - Barrage = *controlled saturation*;
   - Ordnance = *space is about to become unsafe*.

   If all three eventually become “screen covered in gold-white VFX,” you've lost the subtree identities even though every individual texture follows the bible.

6. **Test tap-Q vs hold-Q under panic, not in a debug room.**

   That's a classic prototype trap.

   It can be mechanically correct and still feel wrong because:
   - the hold threshold is slightly too long;
   - quick taps occasionally become placement mode;
   - movement/aiming changes during hold;
   - release timing becomes ambiguous during frame drops;
   - the player cannot instantly tell which Q mode is armed.

   Coordinate placement especially needs a very obvious state transition without turning into sci-fi targeting UI.

7. **Treat Beka as a build-neutral utility companion until proven otherwise.**

   Shield + wounded-health-pull + equipment highlight is a nice memorial implementation because it isn't just “cat does DPS.”

   The risk is that Beka quietly becomes mandatory:
   - passive shield reduces attrition;
   - healing collection removes positional risk;
   - equipment highlighting increases loot efficiency.

   Those three effects all attack the same broader resource: **run friction**.

   Measure how much effective HP, travel distance and missed loot Beka removes. Don't balance by nerfing the agreed prototype numbers immediately; first find out whether the aggregate effect is actually large.

8. **Make the walkable hub compact enough that walking is atmosphere, not tax.**

   A physical courtyard is much better for identity than another menu.

   But after Segment 14, walking 20 seconds Merchant → Ascension → stash → gate every time will become miserable.

   You can preserve the physical hub while designing sightlines and distances so that all major functions are obvious and close. The quiet alcove can be the intentionally optional distant spot.

### P2 — world-specific hardening

9. **Stress every new building with hostile pathing, projectiles and pickups.**

   L-shapes + recessed entrances + south wall depth + two indoor volumes sounds exactly like the kind of system that passes geometry tests and then creates:
   - enemies hitting through façade depth;
   - projectiles visually crossing walls;
   - enemies pathing to the wrong side of recessed doors;
   - health pickups pulled by Beka through sealed walls;
   - loot spawning under roof caps;
   - camera occlusion hiding attacks;
   - indoor/outdoor spawn rules flickering at the threshold.

10. **Give procedural generation a gameplay validator, not just a geometry validator.**

   A generated block should fail generation if, for example:
   - critical route length is too short;
   - objective and gate spawn adjacent;
   - all optional content lies on the mandatory path;
   - no meaningful alternate route exists;
   - the safe route is accidentally shorter *and* more rewarding;
   - recessed entrances face unreachable space;
   - a landmark is not visible from any useful approach;
   - indoor loot can be collected without actually entering the building.

---

# (c) Things I would need to see the build to judge

These aren't answerable from headless tests or the handoff.

1. **Whether Spin Up actually feels better than baseline Heat.**  
   Mechanically I like the distinction — normal Barrage ramps attack speed, while Heat becomes a deliberate Hot Core identity — but the important question is whether the player *feels* the escalating instability without a Heat meter doing all the communication.

2. **Whether Barrage is visually readable at 2× or 3× the expected late-game fire rate.**  
   The current VFX can look excellent at prototype rates and become white-gold noise later.

3. **Whether Ordnance has satisfying weight.**  
   Shell arc, delay, explosion radius, camera response, enemy reaction and sound timing matter more here than another dozen mechanical rules.

4. **Whether the 2.5D geometry still reads as your 2D game.**  
   I'd need actual gameplay footage. The line between “nice depth” and “we accidentally made a fake isometric game with confusing collision” is thin.

5. **Whether recessed entrances are discoverable during a horde.**  
   They can look architectural in screenshots and disappear completely when 80 enemies are chasing you.

6. **Whether indoor spaces are worth entering.**  
   Higher risk + interruption + doorway bottleneck needs an actual reward difference. Otherwise players will learn to ignore buildings despite all the generation work.

7. **Whether the hub feels like a place or a checklist.**  
   The courtyard layout, NPC presence, audio and travel distance will decide that.

8. **Whether Beka reads clearly without becoming HUD noise.**  
   Particularly equipment highlighting during a large loot spill.

9. **Whether V5 Ranged competes with Melee/Magic rather than simply being more developed.**  
   This is an easy trap: after weeks spent rebuilding one style, it gains more interactions, feedback and interesting choices and therefore *feels* stronger even if DPS numbers are equal.

10. **Whether save compatibility actually survives real historical saves.**  
    I would not trust synthetic fixtures alone here. Load copies from several actual old versions/branches and abuse them.

---

## What I would tell Claude to do next

**Do not start Phase 6 content.**

The next milestone should essentially be:

> **“Synthetic Ascension Integration & Abuse Pass.”**

Take the new V5 Ranged, world buildings, Beka, relics and walkable hub and force them through a real multi-segment run while instrumenting the hell out of it.

My priority order would be:

**save/invariants → projectile timing/performance → complete run-loop integration → world navigation/readability → hub friction → Ranged feel/balance → Beka/item balance → additional content.**

The architecture is reaching the point where another cool system has less value than proving the existing systems can coexist without silently corrupting pacing, saves, performance or build logic.
