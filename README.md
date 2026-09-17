# Synthetic Ascension

Synthetic Ascension is a "horde-survivor action roguelite where the real depth
comes from constructing strange, emergent builds during a run"
(`docs/SYNTHETIC_ASCENSION_VISION.md`). The player escapes a collapsing city
under horde pressure while assembling a build out of equipment polarity
(POS/NEG), rarity merging, sets, augments, Manifestations, Luck, Followers and
Resonance. Godot 4.7, GDScript. The version of record is `project.godot` →
`config/version` (`0.0.0.25.5` as of 2026-08-30).

## Running the game

Any Godot 4.7.x binary opens the project. The convention in this repo:

    ~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --path .

The user's Windows desktop runs Godot 4.7.1 (see `tools/perf/run_benchmarks.ps1`).
Never run the engine, even headless, while a human playtest is in progress.

## Running the headless test suites

Import once per fresh checkout (and again after adding scripts):

    ~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --import

Then run any suite under `tools/tests/` (about 99 `.tscn` suites):

    ~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path . res://tools/tests/<Suite>.tscn --quit-after 3000

`ScriptParseAuditTest.tscn` parses every gameplay script; run it last after any
change. Suites print either "N passed, M failed" or "passes=N failures=M".

## Where truth lives

1. `docs/SYNTHETIC_ASCENSION_VISION.md` — what the game is trying to be.
2. `docs/SYNTHETIC_ASCENSION_DIRECTION_AND_ROADMAP.md` — priorities and tiers;
   its §27 status log records what is actually built, appended per session.
3. `docs/audits/` — dated, evidence-based audits of the tree, each with its own
   status section.
4. `docs/current_game_data.md` — the numeric truth of the game as read from
   code and resources, with file citations.

Playtests follow `docs/2026-08-28-playtest-protocol.md`. Patch-era history
(0.21–0.25.x) lives in `docs/history/` and the frozen `DEVELOPMENT_LOG.md`;
the other root-level docs are era-labelled — trust their banners.

## Layout

- `autoload/` — persistent state (Global, SaveManager), schedulers, event buses
- `core/` — actors, combat (projectile simulation, hit ledger) and systems
  (enemy_world, spawner, world/proc, manifestations, encounters, augments,
  run_sheet, telemetry, …)
- `data/` — authored resources and catalogs (items, enemies, narrative)
- `effects/` — item/augment/manifestation gameplay effects
- `scenes/` — game/world composition, encounters and environment scenes
- `spells/` — spell data, logic and scenes
- `ui/` — screens, widgets (including the developer console
  `PerformanceOverlay`) and controllers
- `assets/` — media and visual-only VFX
- `tools/tests/` — headless suites; `tools/perf/` — benchmark runner
- `docs/` — vision, roadmap, audits, game data; `docs/history/` — patch-era records
