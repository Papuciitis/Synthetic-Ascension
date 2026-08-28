# Audit — save compatibility (2026-08-28)

Read-only; no project file was modified. Verification runs were headless Godot
4.7.1 with a throw-away probe script (kept in the agent scratchpad, not in the
repo) that used `user://saves/slot_96` briefly and deleted it. Existing tests
were also run: `SaveIntegrityTest` 45/0, `AutosaveDebounceTest` 11/0,
`SettingsPersistenceTest` 15/0.

## 1. Save system overview

| Store | Path | Format | Writer / reader | Version field |
|---|---|---|---|---|
| Profile slots 1–3 | `user://saves/slot_N.tres` (+ `.tmp.tres`, `.bak.tres`) | Godot text resource, `script_class="SaveData"` | `autoload/SaveManager.gd:24-28` loads with `ResourceLoader.load(path, "", CACHE_MODE_IGNORE)`; `save_slot` (66-133) writes tmp → optional read-back → rotate primary→bak → tmp→primary | **none** (only per-subsystem ints: `attempt_doctrine_version`, `attempt_opening_version`, `attempt_segment1_layout_version`) |
| Settings | `user://settings.cfg` (+`.tmp`, `.bak`) | ConfigFile | `core/settings/SettingsStore.gd` / `SettingsSchema.gd` | `[schema] version=1` written (`SettingsStore.gd:29`), presence checked but value never compared (`:78`) |
| Run sheet / archive | none | — | `RunSheetArchive` is HUD-only (`ui/widgets/RunSheetHUD.gd`); no `user://` writes | — |
| Perf captures | `user://performance_captures` | JSON/CSV | write-only telemetry | — |

Only `SaveManager`, `SettingsManager` and `PerformanceFlightRecorder` touch `user://` (grep confirmed).

Actual on-disk shape (probe output; the game's own leftover `slot_97.tres` matches):

```
[gd_resource type="Resource" script_class="SaveData" format=3]
[ext_resource type="Script" path="res://data/items/StashInventory.gd" id="1_k71je"]
[ext_resource type="Script" path="res://data/items/ItemInstance.gd" id="2_j2e4y"]
[ext_resource type="Resource" path="res://data/items/defs/accessories/acc_firestone.tres" id="3_7n7xd"]
[ext_resource type="Script" path="res://autoload/SaveData.gd" id="4_846ef"]
[sub_resource type="Resource" id="Resource_xi01n"]
script = ExtResource("2_j2e4y")
data = ExtResource("3_7n7xd")
...
```

Two properties of this format drive most findings: (1) properties equal to their script default are **omitted**, so "missing field" is the normal state, and (2) every referenced script and item definition is stored as a **`res://` path with no `uid=`**, so the reference key is the path alone.

## 2. Schema table (`autoload/SaveData.gd`)

Loader semantics (verified by probe): a field absent from the file takes the `@export` default; unknown fields are silently dropped; a value of the wrong type is silently rejected (default kept) except arrays, which are element-converted with per-element `ERROR: Unable to convert...` and dropped elements.

| Field | Type | Default | Read by (`autoload/global.gd` unless noted) | Missing-field behaviour |
|---|---|---|---|---|
| slot_index | int | 0 | SaveManager.save_slot:72 | default 0 → would write to `slot_0.tres` (never happens in practice: set on create) |
| profile_name | String | "New Profile" | SaveCard.gd:157 | default |
| mortal_name | String | "The Arcanist" | apply_save:1303-1305 | default; empty healed |
| unlocked_spell_ids / unlocked_race_ids | Array[String] | seeded lists | **nobody** (reserved) | default |
| last_race_id / last_style_id | String | "human"/"ranged" | apply_save:1299-1301, SaveCard:161-168 (db lookup null-safe) | default |
| last_spell_ids | Array (untyped, contains null) | `["spell_magic_missile", null, null]` | apply_save:1302; player.gd:458 resizes to 3 before indexing | default; short array safe |
| total_runs / best_followers / updated_unix | int | 0 | SaveCard:190-191; save_slot:71 | default |
| meta_permanent_augment_ids | Array[String] | `["","",""]` | apply_save:1308-1323 (size≠3 healed, dup-slot healed) | default |
| meta_owned_augment_ids | Array[String] | [] | apply_save:1327-1332 | default |
| meta_augment_slot_locks | Array[bool] | [f,f,f] | apply_save:1355-1360 (size≥3 guard) | default |
| meta_augment_levels | Dictionary | {} | **nobody** (reserved) | default |
| meta_stash | StashInventory (sub-resource) | null | apply_save:1363-1365 (null → new) | new empty stash |
| meta_discovered_enemy_ids | Array[String] | [] | apply_save:1336-1340 | default |
| meta_seen_manifestation_cards | Array[String] | [] | apply_save:1341-1345 | default (tested) |
| opening_* (4) | bool/String | false/"" | apply_save:1349-1352 + legacy migration 1393-1406 | default, migrated from milestones |
| attempt_active | bool | false | apply_save:1370 gates the whole attempt block | default → "between attempts" |
| attempt_segment / _followers / _deaths_this_segment | int | 1/0/0 | apply_save:1372-1373, 1504 | clamped |
| attempt_world_seed | int | 0 | apply_save:1375 | 0 |
| attempt_resume_scene | String | "" | goto_resume:316-318 (""→HubShop), SaveCard:200 | default → HubShop |
| attempt_pending_augment_pick / _big_choice / _big_choice_source_segment | bool/int | false/0 | apply_save:1428-1430 (+legacy clear 1466-1470) | default |
| attempt_claimed_loot_ids | PackedInt32Array | empty | apply_save:1426 | default |
| attempt_major_choice_id / _offer_ids / _taken_ids | String/Array[String] | "" / [] | apply_save:1433-1451, 1462-1464 | default |
| attempt_mod_wardstone_radius_mul / _slow_mul / _exit_hold_mul | float | 1.0 | apply_save:1434-1436 (clamped) | default |
| attempt_doctrine_version | int | 0 | apply_save:1465 (≤0 ⇒ legacy migration) | 0 → legacy path (tested) |
| attempt_pending_doctrine_stage / _stage_ids / _rules / _events / _witness_used_segment / _threat_debt | String/Dict/Dict/Array[String]/int/float | ""/{}/{}/[]/0/0.0 | apply_save:1454-1459 | default |
| attempt_augment_levels / attempt_mod_mutations | Dictionary | {} | apply_save:1474-1475 | default |
| attempt_mod_stat_delta | StatDelta (sub-resource) | null | apply_save:1476 | null (consumers null-check) |
| attempt_race_id / _style_id / _weapon_id | String | "human"/"ranged"/"ranged" | apply_save:1479-1484 ("" ignored) | default |
| attempt_checkpoint_pos | Vector2 | INF | apply_save:1374 (+layout-version reset 1416-1420) | INF = unset |
| attempt_segment1_layout_version / _resonance / _milestones | int/float/Array[String] | 0/0.0/[] | apply_save:1376-1381, 1416-1428 | 0 ≠ current ⇒ checkpoint/milestones rebuilt |
| attempt_opening_version / _mode / _phase / _completed / _officer_completed / _bren_committed | int/String/int/bool×3 | 0/""/0/false | apply_save:1382-1413 (v0→legacy, v1→v2 phase shift) | migrated |
| attempt_inventory / attempt_bag | Inventory / BagInventory (sub-resource) | null | apply_save:1487-1497 (null → new; `_ensure_size` resizes to current SLOT_COUNT) | new empty |
| attempt_vendor_segment / _refreshes / _seed / attempt_vendor_bag | int×3 / BagInventory | 0 / null | apply_save:1499-1504 | default |

Nested resources: `ItemInstance` (`data: ItemData` **by resource path**, `rolled_mods`, `rarity`, `polarity`, `progress`, `upgrade_meter`, `best_pct`, `manifestation_id: StringName`, `locked`); `Inventory.items: Array[ItemInstance]`; `BagInventory.slots/debug_bag/auto_consolidate/extra_slots`; `StashInventory.slot_count/slots`; `StatDelta` six floats. `Global.get_item_data` (global.gd:460) is **not** on the load path at all — items resolve through the engine's ext_resource path.

## 3. Scenario matrix (observed)

| Scenario | Observed behaviour | Evidence |
|---|---|---|
| Older save (field missing) | Loads; defaults applied; migrations in `apply_save` handle doctrine v0, opening v0/v1, layout version | probe `unknown_field.tres`: `seen_cards=[] doctrine_ver=0`; global.gd:1393-1470; SaveIntegrityTest `_test_legacy_major_choice_migration` |
| Newer save (unknown field) | Silently ignored, no error | probe: `get(bogus)=<null>`, no ERROR lines |
| Field type changed (scalar) | Silently rejected, default kept (`attempt_checkpoint_pos = 5` → INF); string→int coerces to 0 (`attempt_segment="three"` → 0 → `max(1,…)`) | probe2.log:271 |
| Field type changed (array) | Element-wise conversion; unconvertible elements dropped with logged ERROR; plain Array→PackedInt32Array converts; short typed arrays load short (`slot_locks=[true]`, guarded at global.gd:1357) | probe2.log:260-271 |
| Sub-resource class changed for a typed property | Property silently becomes **null** → `apply_save` substitutes an empty stash → contents lost and overwritten on next save | probe `wrong_subclass.tres`: `meta_stash=<null>` |
| Removed manifestation id | Loads; `get_def` → null; `display_name`→"", `tags_of`→[]; every consumer null-checks (global.gd:524, ManifestationRunner.gd:104, ItemTooltip.gd:181). Only wart: `has_manifestation()` stays true, so ManifestBadge shows a neutral-colour badge and CursedVault's `guarantee_manifestation` (CursedVault.gd:107) is satisfied by a dead id | probe: `def=<null> display=[] tags=[]` |
| Removed/renamed **item .tres** referenced by any ItemInstance | **Entire SaveData load fails** (`[ext_resource] referenced non-existent resource`, ERR_FILE_CORRUPT) → `load_slot` returns null. No `uid=` in the file so no rename fallback | probe `item_deleted.tres`/`item_renamed_uid_kept.tres` → null |
| Renamed/moved **script** (`SaveData.gd`, `StashInventory.gd`, `ItemInstance.gd`, …) | Same total failure | probe `stash_script_*`, `root_script_*` → null |
| Removed `attempt_resume_scene` target | `change_scene_to_file` error logged, player stuck on current scene | global.gd:271-276; all 5 targets currently exist |
| Corrupt/truncated primary | null → backup used | probe `truncated.tres`, `garbage.tres`; SaveManager.gd:49-55; SaveIntegrityTest `_test_load_recovers_from_corrupt_primary` |
| Corrupt/unloadable primary **and** backup (the normal case for a deleted item, since both generations reference it) | `has_save()` true but `load_slot()` null → SaveSelect shows "EMPTY SLOT / Click to create" (SaveCard.gd:136-137) → click calls `create_slot` (SaveSelect.gd:101-103) → `save_slot` **deletes the older backup** and rotates the broken primary into `.bak` (SaveManager.gd:103-113). MainMenu Continue silently picks the next loadable slot (MainMenu.gd:78-82) | probe: `load_slot=null`, then `after create_slot: primary_is_new=true older_backup_survives=false` |
| Settings: missing key / unknown key / bad value | `Schema.normalize` fills defaults, clamps, drops unknowns; corrupt primary → `.bak`; file without `[schema] version` treated as absent | SettingsStore.gd:17-21,72-87; SettingsPersistenceTest |

Loader restriction: `ResourceLoader.load(path, "", CACHE_MODE_IGNORE)` (SaveManager.gd:27) has no type hint and no sanitisation. A `.tres` may carry `[sub_resource type="GDScript"] script/source=…` or an `ext_resource type="Script"` pointing at any path; Godot instantiates those on load (Resource `_init` runs). No code-execution probe was run; this item is by engine semantics, not observation. A type hint would not help — sub-resources load before the root type is checked.

## 4. Ranked risks, each with a minimal non-design fix

1. **Deleting or renaming any item `.tres` / any script referenced by a save bricks every save that references it, and the UI then offers to overwrite it.** Fix (two lines): in `SaveSelect._on_slot_pressed`, if `_sm.has_save(slot)` and `_load_slot(slot) == null`, show "save could not be read" and do not call `_create_slot`. Separately, `SaveManager.save_slot` should skip the `.bak` rotation when the primary is unloadable (or copy it to `slot_N.broken.tres`) so the older good generation survives. Also verify an exported build writes `uid=` in ext_resources; if not, treat file paths under `data/items/defs` and the five save-related scripts as frozen. **This is the constraint the cleanup audit must respect: none of its REMOVE candidates is an item def or a save-referenced script, but any future item rename is a save-format change.**
2. **No save-level version or game version.** Add `@export var save_version: int = 1` and `@export var game_version: String = ""` to `SaveData`; write `BuildInfo.version()` in `write_save`; in `apply_save` branch on `save_version` (a single `match`/`if <` chain) and `push_warning` when `game_version` is newer than the running build. Nothing else changes.
3. **Changing an `@export` default silently rewrites every existing save** because defaults are omitted from the file (`attempt_followers` 1→0 in af1fc46 is a real instance). Fix: treat default changes as migrations gated by the new `save_version`, or never change a default in place — add a new field instead (the `meta_seen_manifestation_cards` comment already shows the intent).
4. **Typed sub-resource property changes silently null the data** (`meta_stash`, `attempt_inventory`, `attempt_bag`, `attempt_vendor_bag`, `attempt_mod_stat_delta`). Fix: keep those five property types frozen; if a class must change, add a new property and migrate under `save_version`.
5. **Unrestricted `ResourceLoader.load` of user-writable `.tres`.** Minimal fix without redesign: after load, reject if `resource.get_script() != SaveData` (already implied by `as SaveData`) — that does not prevent sub-resource instantiation. The real fix (data-only format via `var_to_str`/JSON with `ItemData` stored by id) is a design change; flag it for the roadmap.
6. Dangling `manifestation_id` keeps `has_manifestation()` true. Fix: `return ManifestationCatalog.get_def(manifestation_id) != null` in `ItemInstance.has_manifestation`.
7. `SettingsStore` writes `schema/version` but never compares it — harmless today; add a `>` check that falls back to defaults if the file is from a newer schema.

## 5. Fields added/changed in the last 30 days (since 2026-07-29)

`git log -p -- autoload/SaveData.gd` and the nested resources:

- **7c894f3 (2026-08-26)**: `attempt_doctrine_version`, `attempt_pending_doctrine_stage`, `attempt_doctrine_stage_ids`, `attempt_doctrine_rules`, `attempt_doctrine_events`, `attempt_witness_used_segment`, `attempt_doctrine_threat_debt` — migration exists (global.gd:1465-1470) and is tested.
- **d053a5b (2026-08-24)**: `meta_seen_manifestation_cards` — round-trip tested.
- **1e31351 (2026-08-24)**: `ItemInstance.manifestation_id` — round-trip tested (`ManifestationSystemTest._test_identity_survives_a_save_round_trip`).
- **2aedd05 (2026-08-23)**: `BagInventory.auto_consolidate` (default true) — untested.
- **af1fc46 (2026-07-30)**: `opening_full_intro_seen`, `opening_response_id`, `opening_follower_explanation_seen`, `opening_replay_full_next_run`, `attempt_opening_version/_mode/_phase/_completed/_officer_completed/_bren_committed`, `ItemInstance.locked`; **default changes** `attempt_followers` 1→0 and `BagInventory.debug_bag` true→false (both retroactively alter old saves that stored the old default). Opening migration exists (global.gd:1393-1413) but has **no test**.

Also relevant: 8 new curse item `.tres` files were added 2026-08-24 (`data/items/defs/curses/`); any of these being renamed or removed later will hit risk 1 for every save holding one.

## 6. Test coverage

- `tools/tests/SaveIntegrityTest.gd`: write/copy semantics, backup rotation, corrupt primary → backup, cache bypass, delete, stash/vendor/doctrine/cards round-trips, legacy major-choice migration. **Not covered**: unknown field, older save without opening fields, missing item/script reference, both-generations-unloadable → create_slot overwrite, sub-resource class mismatch, type mismatch.
- `tools/tests/AutosaveDebounceTest.gd`: debounce/flush/validation flags only.
- `tools/tests/SettingsPersistenceTest.gd`: round-trip, corrupt primary → backup, clamping, missing keys → defaults.
- `tools/tests/ManifestationSystemTest.gd:906`: inventory + manifestation id round-trip.
- `tools/tests/AuditClosureTest.gd:405`: `total_runs`/`best_followers` bookkeeping only.
- Untracked `tools/tests/CursedVaultTest.gd` / `ThreatDirectorPressureTest.gd` do not touch saves.

Note: `user://saves/` on the development machine holds `slot_97.tres`/`slot_97.bak.tres` — leftovers of `AutosaveDebounceTest`, which writes a real profile and never deletes it (see the stale-tests audit).
