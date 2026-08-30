# Audit + plan — save paths → stable content ids (2026-08-30)

Date 2026-08-30 · tree `enemy-world-work` @ b2b1604 (HEAD f14868a is the
docs-only status commit on top of it; no code differs — the second repair
pass below sits at 5b6bfc3, whose two intervening commits add three test
`.gd.uid` sidecars and one audit, still no code) · kind: **read-only
audit + design plan. NOTHING IMPLEMENTED.** No project file was modified. One
throw-away headless probe (Godot 4.7.2, files only in the agent scratchpad,
nothing written under `user://` or `res://`) verified the four loader
behaviours in §2.1; every other claim is by reading, with file:line.
Companion: `docs/audits/2026-08-28-save-compatibility.md` (risk #5 is the
subject of this plan). Repair pass, same day: weapon-id claim (§1.4, §2.2,
§3.1, §3.8, §6 Q6), StatDelta floats (§1.5), downgrade path (§3.0 row 2,
§3.9, §6 Q7), null-guard evidence (§3.4 step 4, §6 Q1), two off-by-one
citations (§1.1, §1.4/§2.2). Second repair pass, same day: the resolver of
§3.4 was placed in `apply_save`, which the slot-select screen never runs —
moved to the load path (§3.0 row 1, §3.4, §3.5, §3.7, §5 tests 1-3 and 8,
§6 Q1); one latent note on `Variant` effect values (§1.4).

Summary in five lines:

1. Saves are Godot text resources. Exactly **two fields carry `res://` paths**:
   `SaveData.attempt_resume_scene` (a plain String) and `ItemInstance.data`
   (an `ext_resource` with no `uid=`), the latter reaching disk through the
   four item containers. Six scripts are also referenced by path.
2. Every other reference is already a stable string id, and every
   `ItemData` already has a unique `id` equal to its filename — the key space
   for an id-keyed format exists today; nothing needs re-authoring.
3. One dead item path fails the **whole profile file**, both generations;
   one dead string id degrades **per item**. The plan moves items from the
   first class to the second and turns the resume scene into a token.
4. Format: `save_version 1 → 2`; `ItemInstance.data_id` replaces the
   serialized `data`; `SaveData.attempt_resume_id` replaces the path; a
   31-row legacy-alias table ships in `res://`, never in saves; v0/v1 files
   are read through a text pre-scan + alias step on the load path itself
   (`SaveManager._load_save_data`, upstream of the slot cards), never
   rewritten on load.
5. The six scripts stay path-frozen — this plan does not touch the format's
   own scripts; that is the data-only-format roadmap item, not this one.

## 1. Persistence-key inventory

Legend. **scalar** — value only. **id-keyed** — string/StringName resolved
through a catalog or used by membership. **path-keyed** — a `res://` path is
the reference key. **script-keyed** — a script path emitted by
`ResourceSaver` as `[ext_resource type="Script"]`. **typed sub-resource** —
an `@export` of a custom Resource class (frozen per `autoload/SaveData.gd:12-14`).
W = write site, L = load site; `global.gd` unless a file is named; `a/b` =
`write_save` active-branch / inactive-branch line.

Format facts everything below rests on: `ResourceSaver.save(save, tmp)`
(`autoload/SaveManager.gd:100`) writes `user://saves/slot_N.tres`;
`ResourceLoader.load(path, "", CACHE_MODE_IGNORE) as SaveData`
(`SaveManager.gd:32-36`) reads it; defaults are omitted from disk
(`SaveData.gd:10-11`); `CURRENT_SAVE_VERSION := 1`, `save_version` default 0
(`SaveData.gd:19-20`). Real on-disk header, from the probe (§2.1), identical in
shape to the 08-28 sample:

```
[gd_resource type="Resource" script_class="SaveData" format=3]
[ext_resource type="Script" path="res://data/items/StashInventory.gd" id="1_a3qmg"]
[ext_resource type="Script" path="res://data/items/ItemInstance.gd" id="2_qsjyu"]
[ext_resource type="Resource" path="res://data/items/defs/accessories/acc_firestone.tres" id="3_osyqe"]
[ext_resource type="Script" path="res://data/StatDelta.gd" id="4_xpy12"]
[ext_resource type="Script" path="res://autoload/SaveData.gd" id="5_bqyf8"]
[sub_resource type="Resource" id="Resource_6q88y"]
script = ExtResource("2_qsjyu")
data = ExtResource("3_osyqe")
rolled_mods = SubResource("Resource_kg1v3")
rarity = 2
manifestation_id = &"pilgrims_momentum"
```

No `uid=` on any `ext_resource` (the runtime saver has no uid source; only
the editor's does). The StatDelta sub-resource also carries
`metadata/_custom_type_script = "uid://gbut6h2xvcgp"`, a uid to
`StatDelta.gd` — metadata, not a reference key.

### 1.1 PATH-KEYED — the two rows this audit exists for

| # | Field | Where | Value on disk | W | L |
|---|---|---|---|---|---|
| **P1** | `attempt_resume_scene: String` | `SaveData.gd:81` | literal `res://scenes/game.tscn` (`PATH_GAME`, global.gd:30) or `res://ui/screens/HubShop.tscn` (`PATH_HUB_SHOP`, :31) | never in the `write_save` active branch; stamped directly on `SaveManager.current_save` by scene code: global.gd:1786 (`start_new_attempt`), :1823 (`on_segment_completed`), `scenes/game.gd:69,449`, `ui/screens/HubShop.gd:111,1666`, `ui/screens/MainMenu.gd:277`; cleared `""` at global.gd:1672 (inactive branch) | `goto_resume` global.gd:318-321 → `goto_scene` :272-277 → `change_scene_to_file(path)` verbatim, no existence check; `""` → `PATH_HUB_SHOP`. Cosmetic substring match `ui/components/SaveCard.gd:216-220` |
| **P2** | `ItemInstance.data: ItemData` | `data/items/ItemInstance.gd:6` — nested, not on SaveData | `[ext_resource type="Resource" path="res://data/items/defs/<set>/<id>.tres"]`, one per distinct def held anywhere in the file | `ResourceSaver.save` at `SaveManager.gd:100` emits it for every `ItemInstance` inside the four carriers below; instances are assigned by live reference (global.gd:1595, 1661, 1662, 1666) | the **engine** resolves it during `ResourceLoader.load` (`SaveManager.gd:35`) before any GDScript runs. `Global.get_item_data` (global.gd:461-462) is **not** on the load path |

P2's carriers (typed sub-resource fields; see 1.3): `meta_stash` →
`StashInventory.slots: Array[ItemInstance]` (`data/items/StashInventory.gd:5`);
`attempt_inventory` → `Inventory.items` (`data/items/Inventory.gd:43`);
`attempt_bag`, `attempt_vendor_bag` → `BagInventory.slots`
(`data/items/BagInventory.gd:11`). Item universe: 31 `.tres` under
`data/items/defs/` (accessories 4, conduit 6, curses 8, gravemarch 6, lattice
6, `item_test.tres`); all 31 set `ItemData.id` (`data/items/ItemData.gd:4`),
all 31 ids unique (`grep '^id = ' | sort | uniq -d` empty), all 31 ids equal
the file basename. `item_test.tres` has `runtime_enabled = false` (:14) so
`item_db` skips it (global.gd:703) — but a save holding it still path-loads it.

**Path-keyed field count: 2** (P1 on `SaveData`; P2 nested, reaching disk
through 4 container fields).

### 1.2 SCRIPT-KEYED — six scripts, every save

Emitted as `[ext_resource type="Script" path=...]` with no uid by
`ResourceSaver` (`SaveManager.gd:100`); resolved by the engine at
`SaveManager.gd:35`. Documented frozen at `SaveData.gd:15-18`.

| Script | Reached through |
|---|---|
| `res://autoload/SaveData.gd` | the root `[resource]` of every file |
| `res://data/items/StashInventory.gd` | `meta_stash` (`SaveData.gd:52`) |
| `res://data/items/Inventory.gd` | `attempt_inventory` (`SaveData.gd:133`) |
| `res://data/items/BagInventory.gd` | `attempt_bag`, `attempt_vendor_bag` (`SaveData.gd:134,140`) |
| `res://data/items/ItemInstance.gd` | every element of the three `Array[ItemInstance]` exports |
| `res://data/StatDelta.gd` | `attempt_mod_stat_delta` (`SaveData.gd:109`) and every `ItemInstance.rolled_mods` (`ItemInstance.gd:7`) |

No other script ever enters a save: manifestation logic is a catalog-held
preload keyed by StringName (`data/manifestations/ManifestationDef.gd:32`),
augment/item effect scenes live inside content `.tres` (with uid), and no
non-test code constructs `ItemData.new()`, so an embedded `ItemData` cannot
appear.

### 1.3 TYPED SUB-RESOURCE — the five frozen properties (+ nested)

| Field | Class | W | L (null → substitute) |
|---|---|---|---|
| `meta_stash` (`SaveData.gd:52`) | `StashInventory` | global.gd:1595 (live ref) | :1370-1372 → `StashInventory.new()` |
| `attempt_mod_stat_delta` (:109) | `StatDelta` | :1640 / :1693 `null` | :1485 (stays null; consumers null-check) |
| `attempt_inventory` (:133) | `Inventory` | :1661 / :1712 `null` | :1496 → `Inventory.new()` |
| `attempt_bag` (:134) | `BagInventory` | :1662 / :1713 `null` | :1497 → `BagInventory.new()` |
| `attempt_vendor_bag` (:140) | `BagInventory` | :1666 / :1717 `null` | :1511 (stays null) |
| nested `ItemInstance.rolled_mods` (`ItemInstance.gd:7`) | `StatDelta` | per instance | regenerated by `_recompute_flat_mods` (`ItemInstance.gd:215-232`) |

Sub-resources are saved and applied **by reference, not copy** (write
:1595/1640/1661/1662/1666, apply :1370/1485/1496/1497/1511) — `current_save`
and `Global` share the same objects between saves. Dictionaries by contrast
are deep-duplicated both ways (:1632-1639, :1461-1484).

### 1.4 ID-KEYED — already in the target shape

| Field (`SaveData.gd`) | Namespace / catalog | W | L |
|---|---|---|---|
| `last_race_id` (:33), `attempt_race_id` (:111) | `race_db` (RaceData.id, 4 files) | 1571; 1643/1696 | 1307; 1488 |
| `last_style_id` (:34), `attempt_style_id` (:112) | `style_db` (StyleData.id, 3) | 1572; 1644/1697 | 1308 (**also** `selected_weapon_id`, 1309); 1490 |
| `attempt_weapon_id` (:113) | nominally `weapon_db` — **id derived from filename** (`StarterMelee` → `melee`, global.gd:594-605; no weapon `.tres` sets `id`) — but the persisted value is **never resolved**: `weapon_db` has exactly one reader, global.gd:400 inside `sync_run_selection_from_tree_meta`, keyed on `selected_style_id` and called once from `_ready` (:256) before any save is applied; `selected_weapon_id` has no reader outside `write_save` and a debug print (`base.gd:176`) | 1645/1698 | 1492-1493 copies it verbatim into `selected_weapon_id` — a dead-letter string, no lookup, no fallback |
| `last_spell_ids` (:35), `unlocked_spell_ids` (:29, reserved) | `spell_db` (SpellData.id, 1) | 1573; — | 1310 → `player.gd:461-465` (null → empty slot) |
| `unlocked_race_ids` (:30) | reserved | — | — |
| `meta_permanent_augment_ids` (:47), `meta_owned_augment_ids` (:48), `meta_augment_levels` (:51, reserved), `attempt_augment_levels` (:107) | `augment_db` (AugmentData.id, 13) | 1578-1581; 1585-1587; —; 1638/1691 | 1316-1330 (size/dup healed); 1335-1338; —; 1483 |
| `meta_discovered_enemy_ids` (:53) | `EnemySpec.id` (17; Grunt rides the class default) | 1589-1590 | 1343-1346 (membership only) |
| `meta_seen_manifestation_cards` (:58) | prefixed ids `intro` / `noun:<n>` / `pair:<id>` | 1592-1594 | 1348 (membership only) |
| `opening_response_id` (:63) | code literals | 1597 | 1356 |
| `attempt_major_choice_id` (:92), `_offer_ids` (:98), `_taken_ids` (:99) | `MajorChoiceDB.defs_by_id` (MajorChoiceDef.id, 19 incl. doctrines) | 1617/1677; 1623-1625/1682; 1627-1629/1683 | 1441; 1448 (dead ids filtered, global.gd:1111-1115); 1454 |
| `attempt_pending_doctrine_stage` (:101), `attempt_doctrine_stage_ids` (:102), `attempt_doctrine_rules` (:103), `attempt_mod_mutations` (:108) | stage literals / choice ids / free-form rule + mutation keys. Latent, not counted: the **values** of the last two come from `@export var value: Variant` (`core/systems/major_choice/effects/MCE_AddDoctrineTag.gd:5`, `MCE_AddMutation.gd:5`) — scalars in every authored `data/major_choices/*.tres` today, but a content author could put a Resource or `res://` string into a save through them with no code change | 1631/1685; 1632/1686; 1633/1687; 1639/1692 | 1460; 1461; 1462; 1484 |
| `attempt_doctrine_events` (:104) | **display strings** (e.g. `"WITNESS EXPENDED"`), not ids | 1634/1688 | 1463 |
| `attempt_segment1_milestones` (:121), `attempt_opening_mode` (:126) | code literals, version-gated | 1651-1653/1704; 1655/1706 | 1386; 1391 |
| nested `ItemInstance.manifestation_id` (`ItemInstance.gd:19`) | `ManifestationCatalog` (18 StringNames, `ManifestationCatalog.gd:64-239`) | per instance | `has_manifestation` `ItemInstance.gd:86-90` (dead id → false, id kept) |

Uniqueness of every catalog above is convention only: all ten registries
insert last-wins with no assert or test (`item_db` global.gd:704, `augment_db`
:863, `MajorChoiceDB.gd:35`, `ManifestationCatalog.gd:242`, …).

### 1.5 SCALARS

`save_version` (W 1566, L 1300) · `game_version` (1567, 1303) · `slot_index`
(`SaveManager.gd:71`, :83) · `profile_name` (`SaveManager.gd:72`,
`SaveSelect.gd:187`) · `mortal_name` (1574, 1311) · `total_runs` (1730) ·
`best_followers` (1568, monotonic) · `updated_unix` (`SaveManager.gd:82`) ·
`meta_augment_slot_locks` (1602-1604, 1362-1367) · `opening_full_intro_seen`,
`opening_follower_explanation_seen`, `opening_replay_full_next_run`
(1596/1598/1599, 1355/1357/1358) · `attempt_active` (1607, 1377) ·
`attempt_segment` (1609/1669, 1379) · `attempt_followers` (1610/1670, 1516) ·
`attempt_world_seed` (1648/1701, 1382) · `attempt_deaths_this_segment`
(1611/1671, 1380) · `attempt_pending_augment_pick` (1612/1673, 1436) ·
`attempt_pending_big_choice` (1613/1674, 1437) · `attempt_big_choice_source_segment`
(1614 / **not reset**, 1438) · `attempt_claimed_loot_ids: PackedInt32Array`
(1660/1711, 1434; seed-scoped hashes) · `attempt_mod_wardstone_radius_mul`,
`_slow_mul`, `attempt_mod_exit_hold_mul` (1618-1620/1678-1680, 1442-1444) ·
`attempt_doctrine_version` (1630 & 1684 always current, 1471) ·
`attempt_witness_used_segment` (1635/1689, 1464) · `attempt_doctrine_threat_debt`
(1636/1690, 1465) · `attempt_checkpoint_pos` (1647/1700, 1381) ·
`attempt_segment1_layout_version` (1649 & 1702 always current, 1383) ·
`attempt_segment1_resonance` (1650/1703, 1384) · `attempt_opening_version`
(1654 & 1705 always current, 1390) · `attempt_opening_phase`, `_completed`,
`_officer_completed`, `_bren_committed` (1656-1659/1707-1710, 1392-1395) ·
`attempt_vendor_segment`, `_refreshes`, `_seed` (1663-1665/1714-1716,
1508-1510) · nested `ItemInstance.rarity/polarity/progress/upgrade_meter/best_pct/locked`
(`ItemInstance.gd:8-23`) · nested `StatDelta.max_hp/armor/move_speed/power/haste/luck`
(`data/StatDelta.gd:4-9`; six floats, reaching disk through `attempt_mod_stat_delta`
and every `ItemInstance.rolled_mods`, §1.3) · `BagInventory.debug_bag/auto_consolidate/extra_slots`
(`BagInventory.gd:12-18`) · `StashInventory.slot_count` (`StashInventory.gd:4`).

Not persisted at all (derived at runtime, listed so nobody looks for them):
set ids (`ItemData.set_id` → `set_db`, `data/sets/SetRunner.gd:23-24`),
item/augment effect scripts (inside content `.tres`, uid-referenced), and
`user://settings.cfg` (zero `res://` references).

## 2. What breaks on rename

### 2.1 Probe (verified, Godot 4.7.2 headless, scratchpad only)

A `SaveData` with one `ItemInstance(acc_firestone, R2, pilgrims_momentum)`
in `meta_stash` was saved with `ResourceSaver.save`, then the text was edited
and reloaded with `ResourceLoader.load(path, "", CACHE_MODE_IGNORE)`:

| File | Edit | Result |
|---|---|---|
| `good.tres` | none | loads; `data.id == "acc_firestone"` |
| `dead.tres` | item path → `acc_firestone_RENAMED.tres` | `Parse Error: [ext_resource] referenced non-existent resource` → **null** (whole file) |
| `dead.tres` | same, under `ResourceLoader.set_abort_on_missing_resources(false)` | **loads**; the instance survives with `data = <null>`, `rarity = 2`, `manifestation_id` and `rolled_mods` intact; `resource_path` is `dead.tres::Resource_6q88y`; two ERROR lines, no parse error |
| `fixed.tres` | dead path text-rewritten back to the live path | loads with full identity (`data.id == "acc_firestone"`) |
| `v2shape.tres` | item `ext_resource` and `data =` line removed; `data_id = "acc_firestone"` added | **loads on today's build**; unknown `data_id` silently dropped; `data = <null>` — the instance is kept, not an empty slot (§3.0 row 2) |
| `deadscript.tres` | `ItemInstance.gd` path → `ItemInstance_RENAMED.gd` | default: null (whole file). Under abort-off: file loads but `Array[ItemInstance]` rejects the script-less objects → `slots.size = 0` — **silent stash wipe** |

The last row is the reason abort-off can only ever be used behind a script
pre-check (§3.5).

### 2.2 Scenario table (today's behaviour)

| Scenario | What happens today | Evidence |
|---|---|---|
| Rename/move an item `.tres` under `data/items/defs/` (uid kept or not) | every profile whose stash, equipped inventory, bag **or vendor shelf** holds that item fails to load as a whole; primary and `.bak` normally reference the same item so both die; SaveSelect shows "UNREADABLE SAVE", Continue silently skips the slot | §2.1 rows 2, 6; `SaveManager.gd:57-66`; `SaveSelect.gd:100-105`; `MainMenu.gd:75-89`; 08-28 audit §3 |
| Delete an item `.tres` | identical to rename — the path is the only key | same |
| Change an `ItemData.id` without moving the file | nothing breaks in saves (path still resolves); `item_db` gets the new key; `can_merge` (`ItemInstance.gd:120-128`) still compares the live `data.id` so old and new stacks merge normally | global.gd:704 |
| Rename/move an item **effect** script or scene | nothing — effects are referenced from the item `.tres` with `uid=`, never from saves | `data/items/defs/curses/curse_jinxed_coin.tres:3-4` |
| Rename/move one of the six scripts (§1.2) | every save on every machine unreadable; no fallback | §2.1 row 6; `SaveData.gd:15-18` |
| Change the class of a frozen typed property | property loads null, silently; `apply_save` substitutes an empty container; next save makes the loss permanent | global.gd:1370-1372, 1496-1497; 08-28 probe `wrong_subclass.tres` |
| Delete a catalog rule (manifestation id) | loads; `has_manifestation()` false, id kept on the item, badge/tooltip/CursedVault follow | `ItemInstance.gd:86-90` (bc13160), `ManifestationSystemTest._test_dangling_manifestation_id_is_not_a_manifestation` |
| Delete an augment `.tres` | loads; id kept in save; effect silently absent | global.gd:822-824 |
| Delete a spell `.tres` | loads; spell slot silently empty | `player.gd:461-465` |
| Delete a major-choice / doctrine `.tres` | loads; dead offer ids filtered; if **all** offer ids are dead → empty offer, no regeneration | global.gd:1107-1115 |
| Rename `StarterMelee.tres` → anything | new attempts persist the new filename-derived id; an old `attempt_weapon_id` is copied verbatim into `selected_weapon_id` and **never looked up** — the only `weapon_db` lookup (global.gd:400-403) runs once in `_ready` (:256), keyed on the style id, before any save is applied, and nothing reads `selected_weapon_id` except the next `write_save`. The stale string round-trips harmlessly; no fallback, no error | global.gd:594-605, :400-403, :256, :1492-1493 |
| Rename/move `scenes/game.tscn` or `ui/screens/HubShop.tscn` | active-attempt saves load, but Continue → `change_scene_to_file` fails → `push_error`, player stuck on SaveSelect | global.gd:272-277, 318-321 |
| Reorganise a folder under `data/items/defs/` (e.g. `accessories/` → `rings/`) | same as renaming every item in it: all saves holding any of them unreadable | §2.1 |
| Reorganise `data/augments/`, `data/major_choices/`, `data/races/`, `data/styles/`, `spells/data/` | nothing — scanned recursively, keyed by `id` | global.gd:615-624, 863; `MajorChoiceDB.gd:28,33-35` |

The asymmetry in one line: **string ids degrade per item; `ext_resource`
paths are all-or-nothing for the file.** The plan moves P2 across that line
and turns P1 into a token.

## 3. Migration plan (design only)

### 3.0 Constraints and how the plan meets each

| # | Constraint (scout 4 §G) | Plan response |
|---|---|---|
| 1 | Old saves are `save_version 0`/`1`; new format bumps to 2 and branches in `apply_save` (`SaveData.gd:4-6,19-20`; global.gd:1300) | `CURRENT_SAVE_VERSION := 2`; the `< 2` work runs once, on the load path in `SaveManager._load_save_data` (§3.4, §3.5) — `apply_save` is too late for it: the slot-select screen shows a save through `load_slot` alone and reaches `apply_save` only when a slot is selected (`SaveSelect.gd:92-97,200-204`; `SaveManager.gd:182-183`). `apply_save` keeps an idempotent `if save.save_version < 2` guard for the resume token (§3.4), and the `SaveData.gd:6` sentence "branch on save_version in Global.apply_save" gains "or in `SaveManager._load_save_data` when the slot card must see the result" |
| 2 | Newer-than-build saves load best-effort with a warning (global.gd:1300-1304; `_test_save_version_round_trip`) | the warning is untouched, but "best-effort" is weaker than it sounds for items. An installed v1 build opening a v2 file keeps every item as a **data-less `ItemInstance`**, not an empty slot (§2.1 row 5): nothing in `apply_save` filters them (:1370, 1496-1497, 1511), the slot card counts them as gear (`SaveCard.gd:228-230, 238-240`), and its next `write_save` writes them back with no `data` and no `data_id` (dropped at load as an unknown property) — item identity is gone for good after one v1 save, `meta_stash` included (:1595); the v2 primary survives one cycle as `.bak` (`SaveManager.gd:131-148`). Nothing in this plan can reach an already-installed build; accepted, with the forward mitigation in §6 Q7 |
| 3 | Absent field ≠ detectable (defaults not written) | branch on `save_version`, never on "is `data_id` empty" alone; the legacy path is entered only for `< 2` |
| 4 | Never retype the five frozen properties | none retyped; the only field changes are two **new** exports (`ItemInstance.data_id`, `SaveData.attempt_resume_id`) and one export **removed** from serialization (`ItemInstance.data`, §3.3) |
| 5 | Never change an `@export` default | no default changes; new fields default `""` |
| 6 | Until every generation is rewritten, the six scripts and `data/items/defs/` stay rename-frozen | scripts stay frozen (non-goal, §3.8). Item defs become rename-safe for v2 files by construction and for v0/v1 files through the alias step (§3.5); `.bak` generations go through the same loader |
| 7 | Rewrites go through `save_slot` (tmp → validate → rotate → `.broken` set-aside) | **no load-time rewrite exists**; v2 is materialised only by the next ordinary `write_save` + `save_slot` |
| 8 | An old-format-but-parseable save must not surface as "UNREADABLE SAVE" | v0/v1 files still return a `SaveData` from `load_slot`; only a missing **script** still returns null (§3.5) |
| 9 | No extra cost on the autosave flush path | the only write-side addition is stamping `data_id` over ≤ ~50 in-memory instances; no read-back, no extra file |
| 10 | Id lookups degrade like manifestation ids | unknown item id → that slot loads empty with a warning; unknown resume id → hub with a warning; the rest of the file is intact |
| 11 | `_load_save_data` instantiates arbitrary sub-resources (risk #5) | not fixed here; item paths leave the file, which shrinks the surface; the script surface is unchanged (§3.8) |
| 12 | Prior art: per-subsystem version ints with tested legacy branches | followed: one `save_version` branch, one alias table, one test per direction (§5) |

### 3.1 Canonical key per content kind

| Content kind | Canonical key | Persisted as | Status |
|---|---|---|---|
| Item definition | `ItemData.id` (String; 31, unique, == basename) | `ItemInstance.data_id: String` (new) | **changes** (was `ext_resource` path) |
| Resume scene | token `"game"` / `"hub"` | `SaveData.attempt_resume_id: String` (new); resolved via `Global.RESUME_SCENES := {"game": PATH_GAME, "hub": PATH_HUB_SHOP}` | **changes** (was `res://` path) |
| Manifestation | catalog StringName | `ItemInstance.manifestation_id` | unchanged |
| Augment, major choice / doctrine, race, style, spell, enemy, card, milestone, opening mode | existing string ids | existing fields | unchanged |
| Weapon | filename-derived today; persisted but never resolved (§1.4) | `attempt_weapon_id` | unchanged in the save format; content follow-up (§6 Q6) |
| The six scripts | `res://` path | `ext_resource type="Script"` | unchanged — frozen (§3.8) |

### 3.2 Legacy-alias table — ships in `res://`, never in a save

New `data/items/ItemAliases.gd` (`class_name ItemAliases`, constants only):

- `LEGACY_PATHS: Dictionary` — the complete `res:// path → id` snapshot of
  `data/items/defs/` **as of the v2 release**, 31 rows today, e.g.
  `"res://data/items/defs/accessories/acc_firestone.tres": "acc_firestone"`.
  It is frozen at ship time: v0/v1 files can only contain paths that existed
  before v2, so the table never needs to grow afterwards; it is what lets a
  v1 file survive any later move or rename of those 31 files. Explicit rather
  than derived from the basename so a test can assert every row resolves and
  so a future id/basename divergence cannot silently widen it.
- `RENAMED_IDS: Dictionary` — `old id → new id`, empty today. Grows only
  when an `ItemData.id` is changed after v2 (ids, not paths, are then the
  thing that must stay stable or be aliased).
- `RESUME_LEGACY: Dictionary` (on `Global`, next to `RESUME_SCENES`) —
  `{"res://scenes/game.tscn": "game", "res://ui/screens/HubShop.tscn": "hub"}`.

Nothing in a save ever names an alias; saves carry ids only.

### 3.3 Format change (save_version 2)

`autoload/SaveData.gd`
- `CURRENT_SAVE_VERSION := 2`.
- `+ @export var attempt_resume_id: String = ""` next to `attempt_resume_scene`.
- `attempt_resume_scene` stays declared (frozen field) and is written `""`
  in **both** `write_save` branches, so it is absent from every v2 file.
- Header block updated: `data/items/defs/` leaves the frozen list; the six
  scripts stay.

`data/items/ItemInstance.gd`
- `+ @export var data_id: String = ""` (id of `data`; the only item
  reference that reaches disk from v2 on).
- `@export var data: ItemData` → `var data: ItemData` — runtime only, no
  longer serialized, so no `[ext_resource type="Resource"]` is ever emitted
  for an item again. Legacy files still assign it: the text loader calls
  `set("data", ExtResource(..))`, which sets script members whether exported
  or not (engine semantics; pinned by the v1 fixture test in §5, and with a
  fallback if it does not hold — §6 Q8).
- `data_id` is stamped wherever `data` is assigned (`from_roll`
  `ItemInstance.gd:49-65`, `from_data` :234-240, `snapshot_copy` :33-46,
  `merge_from` if it reassigns) **and** by a belt-and-braces walk in
  `write_save` (§3.6) so instances that came in from a legacy file are
  stamped even if no code path touched them.

Everything else on disk is byte-identical to v1.

### 3.4 Loader resolution order (in `SaveManager._load_save_data`, immediately after the engine load)

A new `Global._resolve_item_refs(save, dead_subresources := {})` is called by
`SaveManager._load_save_data` (`SaveManager.gd:32-36`; it already reaches
`Global` at :182) on the `SaveData` it is about to return — for every
version, step 1 being the v2 path — over every `ItemInstance` in the four
carriers (nulls skipped, as today). It runs **there and not in `apply_save`**
because `apply_save` is downstream of the only screen that displays a save:
`SaveSelect._refresh_ui` calls `_load_slot` → `SaveManager.load_slot` →
`_load_save_data` and hands the raw object to `SaveCard.set_slot_data`
(`SaveSelect.gd:92-97,200-204`); `apply_save` runs only from `set_current`
once a slot is selected (`SaveManager.gd:182-183`), from
`MainMenu._on_continue_pressed` after its own `load_slot` (`MainMenu.gd:79-81`),
and from `DevSetCollisionTools.gd:227`. Resolving on the load path means
every consumer of `load_slot` — the four cards, Continue, the rename flow
(`SaveSelect.gd:181-189`), `set_current → apply_save` — sees one resolved
object; `apply_save`'s container handling (global.gd:1370, 1496-1497, 1511)
is unchanged and never receives a data-less instance.

1. **id** — `data_id != ""` → `item_defs_by_id[data_id]` (a second dict
   filled by `_scan_items_dir_recursive` global.gd:682-708 for **every**
   `ItemData` with a non-empty id, `runtime_enabled` or not; `item_db` keeps
   its drop-pool meaning). Hit → `data = def`.
2. **alias** — miss → `ItemAliases.RENAMED_IDS.get(data_id)` → step 1
   again. Hit → `data = def`, `data_id = def.id` (the save heals on next write).
3. **path fallback, with a warning** — miss, but `data != null` (only
   possible for a v0/v1 file whose `ext_resource` still resolved, or one
   recovered by §3.5) → `data_id = data.id`; counted, and one
   `push_warning("slot %d: %d items resolved by legacy path; ids stamped,
   rewritten on next save")` per file, not per item — the resolver runs on
   every `load_slot`, and SaveSelect loads all four slots per refresh.
4. **degrade** — still nothing → the slot becomes `null` (today's universal
   "empty slot" convention, handled by every consumer: `SaveCard.gd:226-241`,
   `ManifestationRunner.gd:97-99`, global.gd:519-521, `InventorySlotView.gd:278`)
   and `push_warning("slot %d item id %s unknown; slot emptied")`. The
   instance is **not** kept data-less — not because consumers would crash
   (`inst == null or inst.data == null` is the project's empty test almost
   everywhere: `HubItemSlot.gd:88`, `HubShop.gd:476,841,1513,1571`,
   `InventoryStash.gd:294,540`, `ItemPickup.gd:167,186`, `Inventory.gd:104,171,229`,
   `BagInventory.gd:218,302`, `InventoryRouter.gd:91,165`, `ItemInstance.gd:114,124`,
   `InventorySlotView.gd:278`, `UiFlyVfx.gd:28`; of 93 `inst.data.*` reads in
   non-test code exactly one is reachable without it, `ItemTooltip.gd:312`,
   where `current` from `run_inventory.get_at` is checked for null but not for
   `data`) — but because every container operation already treats such an
   instance as empty, so keeping it buys a stale GEAR/BACKPACK count on the
   slot card (`SaveCard.gd:228-230`) and an id that nothing can act on (§6 Q1).

`attempt_resume_id`: in the same `_load_save_data` step, for
`save_version < 2` (the version the §3.5 pre-scan already read),
`attempt_resume_id = RESUME_LEGACY.get(save.attempt_resume_scene, "")`;
a non-empty path with no alias → `"hub"` + warning. `apply_save` repeats the
mapping idempotently under its own `if save.save_version < 2` guard (only
when `attempt_resume_id == "" and attempt_resume_scene != ""`) for a
`SaveData` that never went through `load_slot` — the in-memory fixture of
`_test_legacy_major_choice_migration` is that shape today. For all versions,
`goto_resume` becomes `goto_scene(RESUME_SCENES.get(attempt_resume_id,
PATH_HUB_SHOP))` — the save can no longer name a scene file.
`SaveCard._save_status` (`SaveCard.gd:213-221`) switches to the token; it
can only do so because the card receives the object after the mapping — on
the raw field it would show "ATTEMPT ACTIVE" for every v0/v1 slot that reads
RESPITE / IN SEGMENT today.

Warnings from steps 3-4 repeat on every `load_slot` (each SaveSelect refresh
loads all four slots) until the next ordinary save materialises v2;
`push_warning`, not error; accepted.

Repair note: the earlier text of step 4, and the review that leaned on it,
listed `HubItemSlot.gd:102`, `HubShop.gd:481-501,846,1522,1574`,
`ItemPickup.gd:169-188` and `InventoryStash.gd:306-542` as unguarded
`inst.data` reads; each sits behind an `inst.data == null` return (lines
above). The decision stands on the counting/identity argument, not on crashes.

Second repair note: this section first placed `_resolve_item_refs` and the
resume mapping inside `apply_save` while claiming the slot card would show
the token and never a stale count. Both claims were false in that placement:
the card never sees `apply_save`'s output (`SaveSelect.gd:92-97,200-204`), so
a v1 file rescued by §3.5 would have reached `_equipped_count`/`_bag_count`
(`SaveCard.gd:224-241`, `inst != null` only) holding data-less instances, and
`_save_status` an empty `attempt_resume_id`. Moved to the load path.

### 3.5 Reading v0/v1 files: text pre-scan + alias, no rewrite

The engine resolves `ext_resource` before `apply_save` can run, so §3.4
alone cannot rescue a v1 file whose item path has moved. `SaveManager._load_save_data`
(`SaveManager.gd:32-36`) gains a pre-scan that costs nothing for v2 files:

1. `FileAccess.get_file_as_string(path)`; if it contains `save_version = N`
   with `N >= 2` → plain `ResourceLoader.load` as today. (Absent line = 0.)
2. Otherwise scan the `[ext_resource …]` header lines only:
   - any `type="Script"` whose path fails `ResourceLoader.exists` → **return
     null** (unreadable, exactly as today — §2.1 row 6 shows abort-off must
     never see a missing script);
   - each `type="Resource"` path under `res://data/items/defs/` that fails
     `ResourceLoader.exists` → look up `ItemAliases.LEGACY_PATHS`; record
     `ext_id → alias id` (or `ext_id → ""` when the table has no row).
3. If step 2 recorded nothing → plain load. Else scan the `[sub_resource
   id="X"]` blocks for `data = ExtResource("ext_id")` lines → `X → alias id`,
   then load under `ResourceLoader.set_abort_on_missing_resources(false)`
   (restored in the same call). The dead items load with `data = null`
   (§2.1 row 3); their `resource_path` is `<file>::X` (observed).
4. `_load_save_data` then calls `Global._resolve_item_refs(save, {X → alias
   id})` (§3.4) before returning — the map never leaves this function, which
   is the second reason the resolver sits here rather than in `apply_save`.
   The resolver sets `data_id` from the map for a data-less instance whose
   `resource_path` tail matches, then runs steps 1-4. An alias hit recovers
   the item in full; no row → step 4, slot emptied — and the object
   `load_slot` hands to the slot card already holds the empty slot.

Properties: no file is written on load; `.bak` gets the identical treatment
when `load_slot` falls back to it (`SaveManager.gd:66` is the same
`_load_save_data`); the read-back validation at `SaveManager.gd:108` goes
through it too, where a v2 file costs the pre-scan's one string read plus
step 1 over the just-written instances (≤ ~50 dictionary hits; autosave
skips read-back, so constraint 9 holds); the abort-off window is one
synchronous `load` on the main thread (§6 Q3 for the alternative that avoids
the toggle entirely). Only the tail of the alias table is ever consulted, so
the common case for a v1 file (all paths still exist) is one extra string
read plus the resolver's step-3 stamping.

### 3.6 What `write_save` stamps after migration

`write_save` (global.gd:1564) in both branches: `save_version = 2`,
`game_version` (unchanged), `attempt_resume_scene = ""`,
`attempt_resume_id = <token>` (active) / `""` (inactive); then
`_stamp_item_ids(save)` sets `data_id = data.id` on every carried instance
with `data != null`. The file that results contains no
`res://data/items/defs/` substring and no `attempt_resume_scene` line.
`SaveManager.save_slot` is untouched. Migration is therefore materialised
by the **next ordinary save**, and the `.bak` becomes v2 one save later.
Recommended one-liner alongside: `create_slot` (`SaveManager.gd:68-75`)
stamps `save_version = CURRENT_SAVE_VERSION` so a fresh, item-less file
does not take the legacy pre-scan on its first read.

### 3.7 Interaction with backup / `.broken` machinery

- `load_slot` (`SaveManager.gd:57-66`) unchanged. A v1 file rescued by §3.5
  is "readable" → `_unreadable_primary` not set; a file with a missing script
  is still null → flagged → set aside as `.broken.tres` on the next save
  (`SaveManager.gd:116-130`) exactly as pinned by
  `_test_save_after_unreadable_primary_keeps_backup`.
- Rotation (`SaveManager.gd:131-148`) and rollback (:150-162) unchanged; the
  two generations may straddle v1/v2 for one save cycle and both load
  through the same code.
- Read-back validation (`SaveManager.gd:108`) parses the just-written v2
  file → pre-scan sees `save_version = 2` → no legacy work, only the
  resolver's step 1 over the instances it just wrote (§3.5); autosave
  (`validated=false`) still skips it. `AutosaveDebounceTest` expectations
  (`debug_save_writes`, `debug_last_save_validated`) hold.
- `delete_slot` (`SaveManager.gd:166-176`) unchanged: no new artifact.
- `.broken.tres` files set aside **before** v2 because of a dead item path
  would in fact be loadable after v2 (alias or empty-slot). No recovery UI is
  planned (§6 Q5).
- SaveSelect / MainMenu logic unchanged; `SaveCard` changes only the
  `_save_status` field read (§3.4). All three keep calling `load_slot` and
  never `apply_save` (`SaveSelect.gd:92-97,200-204`; `MainMenu.gd:79-81`),
  which is what forces the resolver onto the load path. The "UNREADABLE SAVE"
  state keeps its exact meaning (missing script, disk damage).

### 3.8 What stays frozen after this plan

- The six scripts of §1.2, by path. Lifting that needs a data-only format
  (`var_to_str`/JSON, no `ext_resource`, no sub-resource instantiation) —
  the real fix for risk #5, explicitly out of scope here.
- The three weapon filenames (id source) until Q6 is done — hygiene, not
  save compatibility: the persisted id is never resolved (§1.4).
- `ItemData.id` values become the stable contract; changing one requires a
  `RENAMED_IDS` row.

### 3.9 Alternatives considered and rejected

- **uid injection**: the runtime saver cannot emit `uid=` (no uid source
  outside the editor; probe output confirms none on 4.7.2), so it would be a
  text post-process of every written file, it does nothing for files already
  on disk, and it keeps the engine instantiating whatever path/uid the file
  names. Scripts do have `.gd.uid` files, which is the only thing that makes
  it tempting.
- **Migrate-and-rewrite on load**: a rewrite outside `save_slot` bypasses
  tmp/validate/rotate/set-aside (constraint 7) and adds a write to a read
  path (constraint 9).
- **Dual-write `data` and `data_id` for one release** (so an installed v1
  build keeps full item fidelity on v2 files): puts the paths back in the
  file, which is the thing being removed, and only buys one release — a v1
  build opening a file from the release after would still hold data-less
  instances and destroy item identity on its first save (§3.0 row 2, §6 Q7).
  The v1 build's newer-save warning (global.gd:1300-1304) is the only thing
  it has; the plan accepts that.
- **Keep everything frozen forever**: the status quo; 31 filenames and six
  scripts become permanent API for a project still reorganising its tree.

## 4. Non-goals — verbatim commitments

- **No resource is renamed now.** Nothing under `data/items/defs/`, no
  script, no scene moves as part of, or as a consequence of, this document.
- **The save format does not change now.** `CURRENT_SAVE_VERSION` stays 1;
  no field is added, removed, retyped or redefaulted; `ItemInstance.data`
  stays `@export`.
- **Nothing is implemented now.** No alias table, no resolver, no pre-scan,
  no test. The plan is the deliverable.
- The six-script freeze and the `data/items/defs/` freeze in
  `autoload/SaveData.gd:15-18` remain in force until the plan is executed
  and its tests pass.

## 5. Acceptance-test sketch (`tools/tests/SaveIntegrityTest.gd`, slot 97)

Fixtures are literal `.tres` strings written with `FileAccess` (as
`_test_load_recovers_from_corrupt_primary` does with garbage today), so the
tests do not depend on a real rename. The resolver and pre-scan take the
alias dictionaries as parameters (defaulting to `ItemAliases.*`) so a test
can inject rows without touching the shipped table.

1. `_test_legacy_v1_save_loads_items_by_path_and_stamps_id` — v1 fixture
   referencing a live path (`acc_firestone.tres`) → `load_slot` non-null
   and, **on the object `load_slot` returns, before any `apply_save`**,
   `meta_stash.get_at(0).data.id == "acc_firestone"` and
   `data_id == "acc_firestone"`; then `apply_save`, `write_save` + `save_slot`
   → file text contains no `res://data/items/defs/`, `save_version == 2`.
2. `_test_legacy_v1_renamed_item_loads_via_alias` — v1 fixture referencing
   `…/accessories/acc_firestone_legacy.tres` (non-existent) with an injected
   `LEGACY_PATHS` row → loads; slot 0 resolves to `acc_firestone` with
   `rarity`, `manifestation_id`, `locked` preserved; `_unreadable_primary`
   not set; a `SaveCard` fed the `load_slot` object (as `SaveSelect._refresh_ui`
   does) counts the item as gear; `SaveSelect._on_slot_pressed` selects it
   (no "UNREADABLE SAVE").
3. `_test_legacy_v1_deleted_item_degrades_to_empty_slot` — same fixture,
   no alias row, a second live item in slot 1 → `load_slot` returns slot 0
   `null` (not a data-less instance), slot 1 intact; exactly one step-4
   warning; a `SaveCard` fed that object counts one item, not two (the
   stale-count case of §3.4 step 4); a following save round-trips cleanly.
4. `_test_legacy_v1_missing_script_is_still_unreadable` — v1 fixture with
   `ItemInstance_RENAMED.gd` → `load_slot` null, `has_save` true, next
   `save_slot` sets aside `.broken.tres` (reuses the assertions of
   `_test_save_after_unreadable_primary_keeps_backup`). Pins the §2.1 row-6
   hazard: abort-off never runs with a missing script.
5. `_test_v2_item_round_trip_carries_ids_only` — stash + equipped + bag +
   vendor bag with items → `write_save`, `save_slot`, `load_slot`,
   `apply_save`: every instance `data != null`, `data.id == data_id`,
   manifestation/rarity/polarity/locked equal; file text has no
   `data = ExtResource(`.
6. `_test_v2_unknown_item_id_degrades` — v2 fixture with
   `data_id = "no_such_item"` in slot 0 and a live id in slot 1 → slot 0
   `null`, slot 1 resolved, file otherwise applied.
7. `_test_v2_renamed_id_resolves_via_alias` — v2 fixture with
   `data_id = "acc_firestone_old"` and injected `RENAMED_IDS` row → resolves;
   after a save the file carries `acc_firestone`.
8. `_test_resume_scene_migrates_to_token` — v1 fixture with
   `attempt_active = true`, `attempt_resume_scene = "res://ui/screens/HubShop.tscn"`
   → `attempt_resume_id == "hub"` on the `load_slot` object and
   `SaveCard._save_status` → `"RESPITE"` (the raw field would give
   "ATTEMPT ACTIVE"); an in-memory `SaveData.new()` with the same two fields
   handed straight to `apply_save` also ends with `"hub"` (the idempotent
   guard); unknown path → `"hub"` + warning; after
   `write_save` the file has no `attempt_resume_scene` line; a v2 file with
   `attempt_resume_id = "game"` resumes to `PATH_GAME` (check the value
   `goto_resume` would pass, not the scene change).
9. `_test_item_alias_table_is_live` — every `LEGACY_PATHS` value and every
   `RENAMED_IDS` value is a key of `item_defs_by_id`; every `LEGACY_PATHS`
   key that still exists loads to an `ItemData` whose `id` equals the value;
   all `ItemData.id` under `data/items/defs/` are unique (closes the
   "no assert anywhere" gap).
10. `_test_save_version_round_trip` — bump the fixture expectations: fresh
    `SaveData` reads 0, `write_save` stamps 2, `CURRENT + 1` still applies.
11. Unchanged and must still pass: `_test_save_after_unreadable_primary_keeps_backup`,
    `_test_load_recovers_from_corrupt_primary`, `_test_meta_stash_round_trip`,
    `_test_active_vendor_round_trip`, `_test_legacy_major_choice_migration`,
    `SaveSelectUnreadableSlotTest`, `AutosaveDebounceTest` (write count and
    validation flag unchanged), `ManifestationSystemTest`.

## 6. Open questions (undecidable from code) with recommendations

1. **Dead item at load: empty the slot, or keep a data-less instance?**
   Keeping preserves the id on disk for a future build that restores it, and
   consumers would mostly cope (`inst.data == null` is already the empty test
   nearly everywhere, §3.4 step 4; one reachable exception, `ItemTooltip.gd:312`),
   but every container operation already treats such an instance as empty,
   so keeping it buys a stale GEAR/BACKPACK count on the slot card and an id
   nothing can act on. The count argument holds only because the resolver
   runs on the load path, upstream of `SaveCard` (§3.4); in `apply_save` it
   would empty nothing the card ever sees. *Recommend:* empty the slot and
   warn with container, index and id; do not add a quarantine field now.
   Revisit if a real deletion ever ships.
2. **`item_test.tres` and other `runtime_enabled = false` defs**: resolve
   them for already-owned items or treat as unknown? *Recommend:* resolve
   (separate `item_defs_by_id`); "no longer drops" and "no longer exists"
   are different statements.
3. **Legacy rescue mechanism**: the correlation approach of §3.5 (abort-off
   + `resource_path::id` mapping, no file written) vs writing a path-rewritten
   copy to a fifth slot artifact and loading that (engine does the
   resolution, no abort toggle, but a write on the read path and a new file
   for `delete_slot`/`has_save` to know about). *Recommend:* §3.5; if the
   `resource_path` correlation proves unreliable in the test of §5.2, fall
   back to the rewrite variant.
4. **When to lift the `data/items/defs/` rename freeze**: at v2 ship (the
   alias table covers every pre-v2 path) or after a grace period.
   *Recommend:* at v2 ship, once §5 tests 1-4 and 9 pass; keep the script
   freeze indefinitely.
5. **Recover pre-v2 `.broken.tres` files?** They may become loadable after
   v2. *Recommend:* no UI; leave delete as the player's choice, as 9453f95
   decided.
6. **Weapon ids**: author `id` on `data/weapons/Starter{Magic,Melee,Ranged}.tres`
   with the current derived values (`magic`/`melee`/`ranged`) so the id
   stops depending on the filename. Content change, not save format; the
   persisted id is never resolved today (§1.4), so this is hygiene rather
   than compatibility. *Recommend:* yes, as its own commit, before any weapon
   file moves.
7. **Downgrade fidelity**: an installed v1 build reading a v2 file does not
   see empty slots — it keeps every item as a data-less `ItemInstance`
   (§2.1 row 5; `apply_save` filters nothing, :1370/1496-1497/1511). In play
   the containers treat those as empty, the slot card counts them as gear
   (`SaveCard.gd:228-230, 238-240`) and `ItemTooltip.gd:312` can error when
   an equipped slot holds one; on its first save the v1 build writes them
   back with no `data` and no `data_id`, so item identity is gone for good —
   `meta_stash` included, since it is written every save (:1595) — and the
   v2 file survives only one cycle as `.bak` (`SaveManager.gd:131-148`).
   *Recommend:* accept — nothing in this plan can reach an already-installed
   build, the newer-save warning (054f635) is the only tool it has, and
   dual-writing paths defeats the plan (§3.9). One cheap forward mitigation,
   its own commit before v2: in `SaveManager._load_save_data`, when the
   loaded `save_version > CURRENT_SAVE_VERSION`, null out every carried
   `ItemInstance` whose `data == null` and warn, so any build shipped from
   then on degrades a newer file to honest empty slots (right counts, no
   tooltip error). On the load path for the same reason as §3.4: the slot
   card never sees `apply_save`, so a mitigation there would fix the tooltip
   and leave the counts wrong. It does not save
   identity — only a refuse-to-save-over-newer rule would, a separate
   decision — and builds older than that commit cannot be helped.
8. **Does the text loader populate a non-exported `var data`?** Expected
   from engine semantics (`set()` on a script instance), unprobed because it
   needs a modified `ItemInstance.gd`. *Recommend:* pin it with §5.1; if it
   fails, keep `data` exported and have `_stamp_item_ids` null `data` around
   the `ResourceSaver.save` call inside `save_slot` (synchronous, restored
   before return) — uglier, same on-disk result.
