# Playtest protocol — does the authored run produce the three hits?

**For:** the human playtester (this is the one step in the roadmap an agent
cannot do). **Gate:** roadmap §19 — Phase 3 starts only when this says the run
is genuinely fun. **Build:** branch `enemy-world-work` at `77ff1fb` or later (§ *What is new since this protocol was written* below). The game shows no
version label yet (BuildInfo has no UI consumer — see the stale-docs audit); note
the commit with `git rev-parse --short HEAD` before playing. Flight-recorder
incidents carry it in their `metadata.build` block.

Play three runs, one per NEG archetype, ~20 minutes each, segment 2 onward.
Answer every question with a sentence, not a score; scores come last.

---

## Before you start

- Settings › Accessibility: Reduced Motion **off** (HitFeel needs it), Damage
  Numbers on, Combat Flashes Full.
- Leave every debug flag at its default (`Global.debug_encounter_beats = true`,
  `debug_cursed_vault = true`); benchmarks turn beats off, play does not.
- Turn the performance flight recorder on so beats, escalations, vault opens
  and power thresholds are in the capture (`encounter/*` events).
- Note the version (`project.godot` → `config/version`) and the commit hash.

Tuning knobs you may touch between runs (all exports, no code): `HitFeel`
(`stop_ms`, `punch_px`, `stop_scale`), `EncounterDirector` (`first_beat_delay`,
`interval_min/max`), `ThreatDirector` (`rite_spawn_factor`, `rite_elite_add`,
`power_contrast_lag_sec`), `CursedVault` (`open_time`, `reward_rarity_*`).
Write down every change and why.

---

## The timeline to watch (roadmap §7)

| Minute | What should happen | What to write down |
|---|---|---|
| 0–3 | Killing feels good before any build exists | Which weapon (melee/ranged/magic)? Does a crit or a kill *land*? Is the stop too long / the kick too strong? |
| 3–6 | First real build decision | Which item made you think "this run is becoming X"? POS or NEG? First Manifestation? |
| 6–9 | First encounter beat (charger wedge / shield wall / crossfire / nest / hunter) | Did you notice the callout? Did you change movement or targeting? Which beat? |
| 9–12 | Second/third Manifestation begins a loop | Copy the Run Sheet's "what am I" sentence exactly. Is it true? |
| 12–15 | The Cursed Vault | Did you find it? Open it? What did the reward and the hunter feel like? Was the cost legible *before* opening? |
| 15–18 | Power threshold (3rd / 5th Manifestation) | Did old enemies visibly stop being a problem for a while? Did something worse then arrive? |
| 18–20+ | Exit Rite | Did the world resist (spawn pace, elites, crossfire + wedge)? Did the clear feel like escaping as a god, or a bar filling? |

---

## Per-archetype questions (roadmap §12)

**Corruption Engine run:** Did you inspect severity on cursed items? Did you
take a conventionally worse item because its curse was big? Did the Power cap
(30%) ever matter?

**Doctrine of Burden run:** Did you ever prefer six mild curses over two
catastrophic ones? Did the Run Sheet's "N qualifying curses (≥10% of their
range)" line make sense? Did the cap show "(CAPPED)"?

**Inversion Lens run:** Did a horrific roll (−90%+) excite you instead of
disappointing you? Was it obvious *which* curse the Lens took?

---

## End-of-run (roadmap §14 / §25)

1. Describe the build in one sentence **without percentages**. Then compare it
   to the Run Sheet's sentence. Which is better?
2. Immediate hit — "killing things feels good": yes / partly / no, and why.
3. Build hit — "I know what my run is becoming" by minute 10: yes / partly / no.
4. Power threshold felt at ~15 min: yes / no.
5. Something worth telling someone about at ~20 min: what was it?
6. Was any encounter beat *illegible* (you did not understand what the problem
   was)? Which?
7. Anything that felt generic or like number inflation rather than identity?

---

## Hand back

- The three sentences (yours and the Run Sheet's), per run.
- The capture directory (`performance_results/<date>/`) — it contains the
  `encounter/beat_started`, `encounter/escalation`, `encounter/vault_opened`
  events and the BuildInfo block.
- Your knob changes.
- One line per §25 criterion: met / not met / unclear.

If all five §25 criteria are "met" on at least one archetype, Phase 3 opens.
If not, the answers say which mechanism to tune first — not which new system
to build (roadmap §23).


---

## What is new since this protocol was written (2026-08-30/31)

The timeline above still holds. These are the things it does not yet ask
about, and they are the reason a fresh playtest is worth more than the one
this document originally described.

### 1. Can you see what is happening? (the readability layer)

Wave 1 surfaced values the code already computed but never showed. If these
do not land, every other verdict below is unreliable — a tester who thinks a
mechanic is broken cannot tell you whether it is fun.

- The **Run Sheet's Profile now carries a per-stat ledger**: every step of the
  stat pass, in order, summing to the number above it. Open it mid-run and
  ask: can you answer "why is my Power this high?" without guessing?
- A slot the **Inversion Lens has suppressed shows what it pays** (`+44%`),
  not the stored `−80`. This was the single most bug-shaped moment in the
  game. Does it read correctly now, on the bar, the tooltip and the swap
  preview?
- A **Lens retarget is announced** when a deeper curse arrives. Did you ever
  see stats move and not know why?
- The **power-contrast window is announced** and the Threat tooltip shows
  "Enemy scaling held — Ns", the phase, the elite chance and the rite state.
- The **pair rule is taught** ("two lit nouns always light a pair — all ten
  exist") in the intro card and the pair notifier. Did you work out the noun
  system from the UI, or only by accident?

### 2. Mechanisms that have never been played

- **Elite modifiers** (§9): ARMOURED, VAMPIRIC, SHIELDED, SPLITTING, FAST —
  none at recon/disturbance, one at ascension, two at collapse. *Could you
  tell which modifier an elite had, from its body, before it hurt you?* That
  is the whole point of the row; if the answer is no, the tells are wrong.
- **Ritual interference**: a collapse-phase sigil where the dead rise once as
  weakened revenants. Legible, or just more enemies?
- **The Exit Rite climax**: at 50% hold the district visibly warps; at 85% a
  last-chance vault appears at the rite's edge and costs your whole safeguard
  buffer. Was that a decision you thought about, or a trap?
- **The healing lock**: the Cursed Vault now bills 45 s of no healing. Did the
  approach announcement make that price clear *before* you opened it?

### 3. Two gameplay fixes that change how builds feel

Both landed 2026-08-31 and neither has been played:

- The **Conduit set** used to deal damage with no source, so none of it fed
  lifesteal or any Manifestation `on_hit` rule. A Conduit build should now
  drive procs it never drove. If you can, play one.
- The **Slow Heart curse** re-intercepted its own payout and returned healing
  at ~15% of its advertised rate. It should now feel like the curse its
  numbers describe — which may mean it is now too weak. Say so if it is.

### 4. Two design questions the code cannot answer

Recorded in `docs/audits/2026-08-28-test-coverage-gaps.md`; both need a
ruling before anything moves.

- **An activated Breach Seal follows you.** Walk into one, walk away, and it
  keeps pulling waves to *your* position anywhere in the district until it is
  sealed — it is handed the breach's position and ignores it. Intended
  pressure, or should breaches pour at the breach?
- **DeathRattle overwrites a shared cadence clock** another rule may have just
  reset. First-writer-wins or last-writer-wins?

### Extra knobs since the list above

`EliteModifiers` (per-phase counts, the five modifiers' consts),
`RitualInterference` (radius, duration, revive delay, revenant HP fraction,
cap), `CursedVault.cost_heal_lock_sec`, the rite's distortion ramp
end-points and `last_chance_edge_offset`.
