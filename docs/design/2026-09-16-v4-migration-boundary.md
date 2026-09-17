# V4 tree: the scene/resource migration boundary and a one-discipline pilot

Companion to `2026-09-16-v4-full-implementation-plan.md` (stage 5). Nothing
here is migrated; this records where the line is so the JSON stays the only
authoritative content source while a later pass can move definitions into
editor resources without a rewrite.

## 1. What is separated today

| Layer | Where | Stable identity | Notes |
|---|---|---|---|
| Definitions (nodes, prices, requires, conflicts, kinds, rings, builds) | `data/ascension/tree_v4.json` (verbatim V4) | node id (`EX01`, `MOQ3`, `MM1`, `UMM`, `pick.M2`, `ASC`) | The only authoritative source. `tools/design/v4_status.json` is a status ledger, not content. |
| Topology (edges, rings, angular layout) | `tree_v4.json` edges + `AscensionTreeLayout.gd` | edge (a, b, type) | Layout is derived from ring and discipline; no hand-placed coordinates. |
| Runtime state (owned ranks, equipped slots, claims, segment milestones, spent) | `Global.attempt_ascension` Dictionary (saved as `SaveData.attempt_ascension`) via `AscensionLedger` | node id keys | Save-stable; a resource migration must not change these keys. |
| Behaviour (what a node does) | `core/systems/ascension/engines/<Discipline>Engine.gd`, one script per discipline plus `UnionEngine.gd`; Fusions live in the engine that owns their trigger | `EFFECTS` table per engine: node id -> effect identifier (`&"stride"`, `&"deadshot"`, `&"rune_bomb"`) | Every engine declares the table; the body is still `has("MO01")` checks. The table is the migration hook (see §3). |
| Presentation (map, HUD slots, drawn payloads, combat text) | `ui/screens/AscensionScreen.gd`, `AscensionTreeView.gd`, `AscensionSlotHud.gd`, runner `_draw` | node id, slot name | Runner-drawn arcs, rings, lines and text; no per-node art. |
| Presets (playable loadouts) | `data/ascension/presets_v4.json`, `routes_prototype.json`, `tree_v4.json` builds | preset name | Replayed through the real rules by `AscensionPresetTest`; loaded by the dev overlay. |

Attack identity is data too: every generated attack carries tags
(`core`, `family`, `root`, `path`, `gen`, `pp`, `flag:*`, `cast`) rather
than a scene type, so a payload's provenance survives any future change of
how it is drawn.

## 2. The boundary

Rules that must hold through any migration:

1. One authoritative definition source at a time. While `tree_v4.json` is
   it, no `.tres` may define a price, requirement, conflict or coefficient.
   A generated resource must be produced from the JSON by a script and
   marked generated, never hand-edited.
2. Node ids and the save keys under `attempt_ascension` never change.
   Renaming a node is a data migration with a mapping table, not an edit.
3. Behaviour attaches by effect identifier, not by display text. Engines
   already expose `EFFECTS`; a resource that names `&"deadshot"` must reach
   the same code path as `has("PRQ")` does today.
4. Numbers that the design states (D multiples, R/L distances, seconds,
   Proc Power) stay in one place per rule. Today that place is the engine
   constant or literal beside the rule; a migration that moves them to
   resources must move them all for a discipline, not some.
5. Presentation never reads the JSON directly for rules; it reads the
   ledger (`owns`, `rank`, `equipped`) and the runner (`hud_state`,
   `describe`, `collect_draw_points`).

What stays in code regardless: the shared contract (tags, hit records,
named rolls, the attack queue and its budget, statuses, the incoming and
outgoing damage hooks, the projectile manager's per-slot behaviours).

## 3. The pilot: one discipline as resources (design only)

Pilot discipline: **Momentum**. It touches every hook family (pool claim,
dash, native fire, hits, kills, Q with mutations and two Evolutions, V with
three mutations, sinks, keystones, forks, an axiom, a catastrophe) and its
numbers are all in one file, so it measures the migration honestly.

Shape:

- `AscensionNodeDef` (Resource): `id`, `kind`, `discipline`, `core`,
  `ring`, `price`, `requires` (the same grammar as JSON), `conflicts`,
  `effect: StringName`, `params: Dictionary` (the rule's numbers, e.g.
  `{"momentum_per_dash": 15, "prime_seconds": 3.0, "strip_damage_d": 0.6}`).
- `AscensionDisciplineDef` (Resource): `code`, `name`, `core`,
  `resource_text`, `nodes: Array[AscensionNodeDef]`, `engine_script`.
- A generator `tools/design/export_discipline_resources.py` (or a Godot
  tool script) that writes `data/ascension/resources/momentum/*.tres` from
  `tree_v4.json` plus a hand-kept `params` table for that discipline. The
  JSON remains authoritative; the generator is rerun after JSON edits and a
  test asserts the resources match the JSON (ids, prices, requires).
- `AscensionTreeDB` gains a second loader that builds the same in-memory
  graph from resources for the pilot discipline only, behind a flag
  (`Global.debug_ascension_resource_pilot`). Everything downstream (ledger,
  runner, screen) stays unchanged because they already consume the DB.
- `MomentumEngine` reads its numbers from `params` when a def is present,
  falling back to today's constants. The first step is mechanical: replace
  `0.6 * D()` in Passing Blade with `param("MO02", "strip_damage_d") * D()`.

Acceptance for the pilot: `AscensionLedgerTest` and `AscensionMomentumTest`
pass with the flag on and off with identical outcomes; the matrix's
Momentum rows point at the same tests; no other discipline changes.

What the pilot does not do: no editor UI, no generic effect framework, no
second definition of any node. If the pilot shows that resources buy
nothing the JSON does not already give (the likely outcome while balance
is untuned), the migration stops there and this note records why.
