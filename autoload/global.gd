extends Node

# ============================================================
# Paths (centralized)
# ============================================================
const DEBUG_GLOBAL := false

# -- Data roots (must be plain constants; no function calls inside const)
# -- Root folders
const DATA_DIR := "res://data"
const UI_DIR := "res://ui"
const SCENES_DIR := "res://scenes"
const SPELLS_DIR := "res://spells/data"

# -- Data folders
const RACES_DIR := DATA_DIR + "/races"
const STYLES_DIR := DATA_DIR + "/styles"
const ITEMS_DIR := DATA_DIR + "/items/defs"
const SETS_DIR := DATA_DIR + "/sets"
const AUGMENTS_DIR := DATA_DIR + "/augments"
const MAJOR_CHOICES_DIR := DATA_DIR + "/major_choices"
const WEAPONS_DIR := DATA_DIR + "/weapons"
const DOCTRINE_REWARD_SERVICE := preload("res://core/systems/major_choice/DoctrineRewardService.gd")

# -- Scenes
const PATH_MAIN_MENU := UI_DIR + "/screens/MainMenu.tscn"
const PATH_SAVE_SELECT := UI_DIR + "/screens/SaveSelect.tscn"
const PATH_BASE := UI_DIR + "/screens/base.tscn"
const PATH_GAME := SCENES_DIR + "/game.tscn"
const PATH_HUB_SHOP := UI_DIR + "/screens/HubShop.tscn"
# v3: story-pass layout - admissions wing added, full-opening start moved to
# the street entrance. Stale checkpoints and spatial milestones reset.
const SEGMENT1_LAYOUT_VERSION: int = 3
# v2: ADMISSION phase inserted after HISTORICAL; saved phase ints >= 2 shift.
const OPENING_SEQUENCE_VERSION: int = 2

const VFX_DIR := "res://assets/vfx/world/augments"
const PATH_VFX_STAMINA_AURA := VFX_DIR + "/VFX_StaminaCoreAura.tscn"

# ============================================================
# Signals
# ============================================================

signal followers_changed(value: int)
signal followers_transaction(old_value: int, change: int, new_value: int, reason: StringName, context: Dictionary, show_feedback: bool, allow_aggregate: bool)
signal permanent_augments_changed(ids: Array[StringName])


# ============================================================
# Run selections (chosen at start of run)
# ============================================================

# Level / segment helpers
var exit_gate_pos: Vector2 = Vector2.INF
var objective_target_pos: Vector2 = Vector2.INF

# Level/tutorial one-shots (reset each run)
var tip_shown_wardstone_attune: bool = false
var tip_shown_resonance: bool = false
var tip_shown_gate_hold: bool = false

# More tutorial beats (Level 1)
var tip_shown_intro_move: bool = false
var tip_shown_resonance_goal: bool = false
var tip_shown_wardstone_anchor: bool = false
var tip_shown_gate_unsealed: bool = false


var selected_race_id: String = "human"
var selected_style_id: String = "ranged"
var selected_weapon_id: String = "ranged"
var mortal_name: String = "The Arcanist"

# 3 spell slots (string IDs)
var equipped_spell_ids: Array = ["spell_magic_missile", null, null]


# ============================================================
# Databases (loaded on startup)
# ============================================================

var race_db: Dictionary = {}   # String -> RaceData
var style_db: Dictionary = {}  # String -> StyleData
var weapon_db: Dictionary = {} # String -> WeaponData (or Resource)
var spell_db: Dictionary = {}  # String -> SpellData (or Resource)
var item_db: Dictionary = {}   # String -> ItemData
var set_db: Dictionary = {}    # StringName -> SetData

var augment_db: Dictionary = {}                   # StringName -> AugmentData
var permanent_augment_ids: Array[StringName] = [] # exactly 3 slots
var owned_augment_ids: Array[StringName] = []       # owned augment library (meta, persists forever)
var augment_slot_locks: Array[bool] = [false, false, false]       # lock equipped slots in hub
var meta_stash: StashInventory = null
var discovered_enemy_ids: Array[StringName] = []
## Manifestation explainer cards already shown, as prefixed ids ("intro",
## "noun:momentum", "pair:..."). Profile knowledge, exactly like the enemy
## dossiers above.
var seen_manifestation_cards: Array[StringName] = []
var debug_dev_mode: bool = false
var debug_dev_segment: bool = false
# Rollout flag for the authoritative Enemy World proxy slice: distant ordinary
# enemies become data-only records with batched rendering.
var enemy_proxy_rollout: bool = true

# WorldArt is deliberately not a global class; consumers preload it.
const _WORLD_ART_SCRIPT := preload("res://core/systems/world/WorldArt.gd")
var debug_force_enemy_introductions: bool = false
var debug_projectile_stress_test: bool = false
var debug_player_god_mode: bool = false
# Materialized enemies render through shared MultiMesh batches instead of
# per-node sprites. Applies to enemies spawned after the flag changes.
var debug_enemy_visual_batching: bool = true
var debug_set_collision_tools: bool = false
var debug_performance_lab: bool = false
var debug_combat_transactions: bool = false
var debug_opening_mode_override: String = "" # "", full, short, skip
var debug_opening_force_phase: int = -1
var debug_opening_response_override: String = ""

# Hub-only sale marks (not persisted; just for Hub UX)
var hub_sell_marks_bag: Dictionary = {}   # int -> bool
var hub_sell_marks_stash: Dictionary = {} # int -> bool



# Major Choices (Segment 5 big node)
var major_choice_db: MajorChoiceDB = MajorChoiceDB.new()


# ============================================================
# Run systems (reset each run)
# ============================================================

var run_inventory: Inventory = null      # 6-slot equipped
var run_bag: BagInventory = null         

# ============================================================
# Campaign attempt state (Continue snapshot)
# ============================================================

var attempt_active: bool = false
var attempt_segment: int = 1
var attempt_deaths_this_segment: int = 0
var attempt_checkpoint_pos: Vector2 = Vector2.INF
var attempt_world_seed: int = 0
var attempt_segment1_layout_version: int = SEGMENT1_LAYOUT_VERSION
var attempt_segment1_resonance: float = 0.0
var attempt_segment1_milestones: Array[StringName] = []
var opening_full_intro_seen: bool = false
var opening_response_id: StringName = &""
var opening_follower_explanation_seen: bool = false
var opening_replay_full_next_run: bool = false
var attempt_opening_version: int = OPENING_SEQUENCE_VERSION
var attempt_opening_mode: StringName = &""
var attempt_opening_phase: int = 0
var attempt_opening_completed: bool = false
var attempt_opening_officer_completed: bool = false
var attempt_opening_bren_committed: bool = false


var attempt_vendor_segment: int = 0
var attempt_vendor_refreshes: int = 0
var attempt_vendor_seed: int = 0
var attempt_vendor_bag: BagInventory = null

var attempt_claimed_loot_ids: PackedInt32Array = PackedInt32Array()
var _claimed_loot_set: Dictionary = {} # int -> true

# Buildings the player has walked into this attempt, keyed by the same stable
# seeded building_id the loot claim uses. Chunks are streamed, so the volume
# NODE is not an identity - walking three chunks away and back rebuilds it.
var _visited_building_set: Dictionary = {} # int -> true

var pending_augment_pick: bool = false
var pending_big_choice: bool = false
var attempt_big_choice_source_segment: int = 0 # Segment index that granted the pending big choice (usually 5)


# Attempt modifiers (reset on die-die)
var attempt_major_choice_id: StringName = &""
var attempt_wardstone_radius_mul: float = 1.0
var attempt_wardstone_slow_mul: float = 1.0
var attempt_exit_hold_mul: float = 1.0

# Stored offer so you cannot reroll by reopening HubShop
var attempt_major_choice_offer_ids: Array[StringName] = []
var attempt_major_choice_taken_ids: Array[StringName] = []

const ASCENSION_DOCTRINE_VERSION: int = 1
var attempt_doctrine_version: int = ASCENSION_DOCTRINE_VERSION
var attempt_pending_doctrine_stage: StringName = &""
var attempt_doctrine_stage_ids: Dictionary = {}
var attempt_doctrine_rules: Dictionary = {}
var attempt_doctrine_events: Array[String] = []
var attempt_witness_used_segment: int = 0
var attempt_doctrine_threat_debt: float = 0.0

# Attempt-scoped augmentation levels (StringName -> int); defaults to 1
var attempt_augment_levels: Dictionary = {}

# Run rules/mutations (StringName -> Variant)
var attempt_mutations: Dictionary = {}

# Additive attempt stats
var attempt_stat_delta: StatDelta = null


# Internal autosave throttle
var _autosave_timer: SceneTreeTimer = null
var _suppress_autosave: bool = false
var _autosave_dirty: bool = false
var autosave_fallback_seconds: float = 30.0
var _doctrine_active_slot: int = -1
var _doctrine_active_lock_until_ms: int = 0
# stacking bag
var run_luck: float = 0.0

## Pushes newly rolled items toward NEG polarity. Raised by curses that tax the
## LOOT TABLE rather than the player - a shape that is a poison to an ordinary
## run and a supply line to a curse build. Reset per attempt with everything else.
var curse_drop_bias: float = 0.0

var _followers: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var vfx_stamina_aura_scene: PackedScene

# ============================================================
# Lifecycle
# ============================================================

func _ready() -> void:
	_rng.randomize()

	_load_spells()
	_load_races()
	if DEBUG_GLOBAL:
		print("Race DB keys:", race_db.keys())

	_load_styles()
	if DEBUG_GLOBAL:
		print("Style DB keys:", style_db.keys())

	_load_weapons()

	load_items_from_dir(ITEMS_DIR)
	if DEBUG_GLOBAL:
		print("Item DB keys:", item_db.keys())

	load_sets_from_dir(SETS_DIR)
	if DEBUG_GLOBAL:
		print("Loaded set ids:", set_db.keys())
		print("Conduit-like ids:", set_db.keys().filter(func(k): return String(k).to_lower().find("conduit") != -1))

	# Pull selections if a selection screen stored them in meta
	sync_run_selection_from_tree_meta(get_tree())

	load_augments_from_dir(AUGMENTS_DIR)
	init_permanent_augments()

	# Major choices authored as resources
	major_choice_db.load_from_dir(MAJOR_CHOICES_DIR)
	if DEBUG_GLOBAL:
		print("MajorChoice defs:", major_choice_db.defs_by_id.keys())

	vfx_stamina_aura_scene = load(PATH_VFX_STAMINA_AURA) as PackedScene

# ============================================================
# Scene navigation API
# ============================================================

func goto_scene(path: String) -> void:
	# Scene changes are the natural safe point for any deferred combat autosave.
	flush_pending_save()
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Scene change failed: %s err=%s" % [path, err])

func goto_main_menu() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("to_menu")
	goto_scene(PATH_MAIN_MENU)

func goto_save_select() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("to_menu")
	goto_scene(PATH_SAVE_SELECT)

func goto_base() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("to_game")
	goto_scene(PATH_BASE)

func goto_game() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("to_game")
	goto_scene(PATH_GAME)

func goto_hub_shop() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("to_game")
	goto_scene(PATH_HUB_SHOP)

func goto_resume() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("to_game")
	# Resume current attempt if one exists; otherwise go to Base.
	if SaveManager == null or SaveManager.current_save == null:
		goto_save_select()
		return
	if SaveManager.current_save.attempt_active:
		var path: String = SaveManager.current_save.attempt_resume_scene
		if path == "":
			path = PATH_HUB_SHOP
		goto_scene(path)
	else:
		goto_base()


# ============================================================
# Followers
# ============================================================

var followers: int:
	get:
		return _followers
	set(value):
		_followers = maxi(0, value)
		followers_changed.emit(_followers)

func set_followers(value: int) -> void:
	transaction_followers(value - followers, &"system_sync", {}, false, false)

func add_followers(delta: int) -> void:
	transaction_followers(delta, &"legacy", {}, true, true)

func transaction_followers(amount: int, reason: StringName, context: Dictionary = {}, show_feedback: bool = true, allow_aggregate: bool = true) -> Dictionary:
	# The assistant is the first real follower. Early kills still grant drops and
	# Resonance, but cannot turn slain containment staff into believers.
	if amount > 0 and reason == &"combat_influence" and attempt_segment == 1 and not has_segment1_milestone(&"assistant_commitment"):
		return {"old": followers, "change": 0, "new": followers, "suppressed": true}
	var old_value := followers
	var new_value := maxi(0, old_value + amount)
	var actual_change := new_value - old_value
	if actual_change == 0:
		return {"old": old_value, "change": 0, "new": new_value, "suppressed": false}
	_followers = new_value
	followers_changed.emit(_followers)
	followers_transaction.emit(old_value, actual_change, new_value, reason, context, show_feedback, allow_aggregate)
	if DEBUG_GLOBAL and debug_combat_transactions:
		print("FOLLOWERS TRANSACTION:", actual_change, " reason=", reason, " total=", new_value)
	request_autosave()
	return {"old": old_value, "change": actual_change, "new": new_value, "suppressed": false}

func is_enemy_discovered(enemy_id: StringName) -> bool:
	return discovered_enemy_ids.has(enemy_id)

func mark_enemy_discovered(enemy_id: StringName) -> void:
	if enemy_id == &"" or discovered_enemy_ids.has(enemy_id):
		return
	discovered_enemy_ids.append(enemy_id)
	request_autosave()

func reset_enemy_discoveries() -> void:
	discovered_enemy_ids.clear()
	save_current_profile()

func is_manifestation_card_seen(card_id: StringName) -> bool:
	return seen_manifestation_cards.has(card_id)

func mark_manifestation_card_seen(card_id: StringName) -> void:
	if card_id == &"" or seen_manifestation_cards.has(card_id):
		return
	seen_manifestation_cards.append(card_id)
	request_autosave()


# ============================================================
# Run selection sync
# ============================================================

func sync_run_selection_from_tree_meta(tree: SceneTree) -> void:
	if tree.has_meta("run_race_id"):
		var race_meta: String = String(tree.get_meta("run_race_id"))
		if race_meta != "":
			selected_race_id = race_meta

	if tree.has_meta("run_style_id"):
		var style_meta: String = String(tree.get_meta("run_style_id"))
		if style_meta != "":
			selected_style_id = style_meta

	# weapon follows style (only if it matches known weapon keys)
	if weapon_db.has(selected_style_id):
		selected_weapon_id = selected_style_id
	else:
		selected_weapon_id = "ranged"

func set_run_selection(race_id: String, style_id: String) -> void:
	selected_race_id = race_id
	selected_style_id = style_id
	selected_weapon_id = style_id


# ============================================================
# Run resets
# ============================================================

func reset_run_systems() -> void:
	# tutorial one-shots
	tip_shown_wardstone_attune = false
	tip_shown_resonance = false
	tip_shown_gate_hold = false
	tip_shown_intro_move = false
	tip_shown_resonance_goal = false
	tip_shown_wardstone_anchor = false
	tip_shown_gate_unsealed = false

	reset_run_inventory()
	reset_run_bag_inventory()
	run_luck = 0.0
	curse_drop_bias = 0.0

	# exploration loot claim state (per-segment)
	attempt_claimed_loot_ids = PackedInt32Array()
	_claimed_loot_set.clear()
	_visited_building_set.clear()
	attempt_vendor_segment = 0
	attempt_vendor_refreshes = 0
	attempt_vendor_seed = 0
	attempt_vendor_bag = null

	# A fresh attempt in the same segment never trips ThreatDirector's
	# segment-change poll, so tell it explicitly or overtime/elite pressure
	# from the previous run bleeds into the new one.
	var threat_director := get_node_or_null("/root/ThreatDirector")
	if threat_director != null and threat_director.has_method("reset_run_state"):
		threat_director.call("reset_run_state")

func reset_run_inventory() -> void:
	run_inventory = Inventory.new()

func reset_run_bag_inventory() -> void:
	run_bag = BagInventory.new()

func reset_run_augments() -> void:
	# 3 slots, empty
	permanent_augment_ids = [StringName(), StringName(), StringName()]


# ============================================================
# Item access
# ============================================================

func get_item_data(item_id: String) -> ItemData:
	return item_db.get(item_id, null) as ItemData


## Pick a random item id, honouring each item's drop_weight.
##
## Every random-item path funnels through here so authored rarity means the same
## thing whether the item came from an enemy, a building, exploration or a
## vendor shelf. Passing no keys means "anything in the database".
func pick_weighted_item_id(rng: RandomNumberGenerator, keys: Array = []) -> String:
	var pool: Array = keys if not keys.is_empty() else item_db.keys()
	if pool.is_empty():
		return ""
	var total := 0.0
	for key in pool:
		var data: ItemData = item_db.get(str(key), null) as ItemData
		total += maxf(0.0, data.drop_weight) if data != null else 1.0
	if total <= 0.0:
		return str(pool[rng.randi_range(0, pool.size() - 1)])
	var target := rng.randf() * total
	for key in pool:
		var data: ItemData = item_db.get(str(key), null) as ItemData
		target -= maxf(0.0, data.drop_weight) if data != null else 1.0
		if target <= 0.0:
			return str(key)
	return str(pool[pool.size() - 1])


func get_equipped_rarity_average() -> float:
	if run_inventory == null:
		return 0.0
	var total: float = 0.0
	var count: int = 0
	for slot_index in range(Inventory.SLOT_COUNT):
		var instance: ItemInstance = run_inventory.get_at(slot_index)
		if instance == null:
			continue
		total += float(instance.rarity)
		count += 1
	return total / float(count) if count > 0 else 0.0


## Which Manifestation nouns the player currently wears, and how many rules of
## each. Feeds the drop roll's prerequisite weighting - a rule that talks about
## a noun you already carry is likelier to be the one that appears.
## Nouns the player holds, counted the way the PAIR system counts them.
##
## This used to count instances while ManifestationRunner counts DISTINCT rules,
## so two copies of one two-noun rule told the roller "momentum x2, cadence x2"
## - and the prerequisite weighting then steered every later drop toward those
## nouns - while the pair system read "x1, x1" and lit nothing. The player was
## being aimed at an engine they could not reach. One counting convention.
func equipped_manifestation_tags() -> Dictionary:
	var held: Dictionary = {}
	if run_inventory == null:
		return held
	var seen: Dictionary = {}
	for slot_index in range(Inventory.SLOT_COUNT):
		var instance: ItemInstance = run_inventory.get_at(slot_index)
		if instance == null or instance.manifestation_id == &"":
			continue
		if seen.has(instance.manifestation_id):
			continue
		seen[instance.manifestation_id] = true
		var def := ManifestationCatalog.get_def(instance.manifestation_id)
		if def == null:
			continue
		for tag in def.tags:
			held[tag] = int(held.get(tag, 0)) + 1
	return held


func build_item_drop_context(
	rarity_min: int,
	rarity_max: int,
	source_type: StringName,
	source_rank: int = 0,
	is_elite: bool = false
) -> ItemDropContext:
	var context := ItemDropContext.new()
	context.segment_index = maxi(1, attempt_segment)
	var threat := get_node_or_null("/root/ThreatDirector")
	context.threat_level = (
		clampf(float(threat.get("resonance")), 0.0, 1.0)
		if threat != null
		else 0.0
	)
	context.source_rank = source_rank
	context.is_elite = is_elite
	context.rarity_min = rarity_min
	context.rarity_max = rarity_max
	context.rarity_soft_cap = maxi(rarity_max + 1, floori(float(context.segment_index) / 3.0) + source_rank)
	context.player_luck = run_luck
	context.equipped_rarity_average = get_equipped_rarity_average()
	context.source_type = source_type
	return context


# ============================================================
# Loaders (startup)
# ============================================================

func _load_spells() -> void:
	spell_db.clear()

	_scan_dir_recursive(SPELLS_DIR, func(res: Resource) -> void:
		if res == null:
			return

		var id := _get_string_prop(res, "id")

		# Normalize if resource uses id without prefix
		if id != "" and not id.begins_with("spell_"):
			id = "spell_" + id

		# Fallback: derive from filename (MagicMissile -> spell_magic_missile)
		if id == "":
			var base := res.resource_path.get_file().get_basename()
			id = "spell_" + _camel_to_snake(base)

		spell_db[id] = res
	)

	if DEBUG_GLOBAL:
		print("Spell DB keys:", spell_db.keys())

func _load_weapons() -> void:
	weapon_db.clear()

	_scan_dir_recursive(WEAPONS_DIR, func(res: Resource) -> void:
		if res == null:
			return

		var id := _get_string_prop(res, "id")

		# Fallback: derive from filename (StarterMelee -> melee)
		if id == "":
			var base := res.resource_path.get_file().get_basename()
			id = _camel_to_snake(base)

		# Normalize common prefix
		if id.begins_with("starter_"):
			id = id.trim_prefix("starter_")

		weapon_db[id] = res
	)

	if DEBUG_GLOBAL:
		print("Weapon DB keys:", weapon_db.keys())

func _load_races() -> void:
	race_db.clear()
	_scan_dir_recursive(RACES_DIR, func(res: Resource) -> void:
		var r := res as RaceData
		if r != null and r.id != "":
			race_db[r.id] = r
	)

func _load_styles() -> void:
	style_db.clear()
	_scan_dir_recursive(STYLES_DIR, func(res: Resource) -> void:
		var st := res as StyleData
		if st != null and st.id != "":
			style_db[st.id] = st
	)

func has_variable(var_name: StringName) -> bool:
	for p in get_property_list():
		if p.name == var_name:
			return true
	return false


# ============================================================
# Sets
# ============================================================

func load_sets_from_dir(path: String) -> void:
	set_db.clear()
	_scan_sets_dir_recursive(path)
	if DEBUG_GLOBAL:
		print("Set DB keys:", set_db.keys())

func _scan_sets_dir_recursive(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		push_warning("Set dir not found: " + path)
		return

	dir.list_dir_begin()
	var fn: String = dir.get_next()
	while fn != "":
		if fn.begins_with("."):
			fn = dir.get_next()
			continue

		var full: String = path.path_join(fn)

		if dir.current_is_dir():
			_scan_sets_dir_recursive(full)
		elif fn.ends_with(".tres") or fn.ends_with(".res"):
			var res: Resource = ResourceLoader.load(full)
			var sd: SetData = res as SetData
			if sd != null and sd.id != StringName():
				set_db[sd.id] = sd
				if DEBUG_GLOBAL:
					print("Loaded set:", sd.id, "from", full)

		fn = dir.get_next()

	dir.list_dir_end()


# ============================================================
# Items
# ============================================================

func load_items_from_dir(path: String) -> void:
	item_db.clear()
	_scan_items_dir_recursive(path)

func _scan_items_dir_recursive(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		push_warning("Item dir not found: " + path)
		return

	dir.list_dir_begin()
	var fn: String = dir.get_next()
	while fn != "":
		if fn.begins_with("."):
			fn = dir.get_next()
			continue

		var full: String = path.path_join(fn)

		if dir.current_is_dir():
			_scan_items_dir_recursive(full)
		elif fn.ends_with(".tres") or fn.ends_with(".res"):
			var res: Resource = ResourceLoader.load(full)
			if res != null:
				var item: ItemData = res as ItemData
				if item != null and item.id != "" and item.runtime_enabled:
					item_db[item.id] = item

		fn = dir.get_next()

	dir.list_dir_end()


# ============================================================
# Augments + permanent augments
# ============================================================

func init_permanent_augments() -> void:
	if permanent_augment_ids.size() != 3:
		permanent_augment_ids.resize(3)
	for i in range(3):
		if permanent_augment_ids[i] == null:
			permanent_augment_ids[i] = StringName()

func init_owned_augments() -> void:
	# Ensure owned list exists and always contains equipped augments.
	if owned_augment_ids == null:
		owned_augment_ids = []
	# Backfill from equipped
	init_permanent_augments()
	for id in permanent_augment_ids:
		var sid: StringName = id
		if sid != StringName() and not owned_augment_ids.has(sid):
			owned_augment_ids.append(sid)

func add_owned_augment(id: StringName) -> void:
	if id == StringName():
		return
	if owned_augment_ids == null:
		owned_augment_ids = []
	if not owned_augment_ids.has(id):
		owned_augment_ids.append(id)
		request_autosave()


func move_owned_augment(from_index: int, to_index: int) -> void:
	init_owned_augments()
	if from_index < 0 or to_index < 0:
		return
	if from_index >= owned_augment_ids.size() or to_index >= owned_augment_ids.size():
		return
	if from_index == to_index:
		return
	var id: StringName = owned_augment_ids[from_index]
	owned_augment_ids.remove_at(from_index)
	owned_augment_ids.insert(to_index, id)
	request_autosave()

func is_augment_slot_locked(slot: int) -> bool:
	if augment_slot_locks == null or augment_slot_locks.size() < 3:
		augment_slot_locks = [false, false, false]
	if slot < 0 or slot >= 3:
		return false
	return bool(augment_slot_locks[slot])

func set_augment_slot_locked(slot: int, locked: bool) -> void:
	if augment_slot_locks == null or augment_slot_locks.size() < 3:
		augment_slot_locks = [false, false, false]
	if slot < 0 or slot >= 3:
		return
	augment_slot_locks[slot] = locked
	request_autosave()
func get_owned_augment_ids() -> Array:
	init_owned_augments()
	return owned_augment_ids.duplicate()

func set_permanent_augment(slot: int, id: StringName) -> void:
	init_permanent_augments()
	if slot < 0 or slot >= 3:
		return
	# Invariant: an augment id occupies at most one slot. Callers that mean
	# "move" (the library drag path) resolve the old slot themselves before
	# reaching here; anything else clearing the stale copy is the bug fix.
	if id != StringName():
		for other in range(3):
			if other != slot and permanent_augment_ids[other] == id:
				permanent_augment_ids[other] = StringName()
	permanent_augment_ids[slot] = id
	add_owned_augment(id)
	if DEBUG_GLOBAL:
		print("[AUG] set_permanent_augment slot=", slot, " id=", id, " -> ", permanent_augment_ids)
	permanent_augments_changed.emit(permanent_augment_ids)

# In-game UI surfaces (bag, overlays) that swallow number keys must also
# suppress active-augment hotkeys: the effects poll raw Input state, which
# is blind to GUI focus — pressing "2" while sorting the bag used to blink
# the player across the screen.
var _active_augment_input_locks: int = 0

func set_active_augment_input_locked(locked: bool) -> void:
	_active_augment_input_locks = maxi(0, _active_augment_input_locks + (1 if locked else -1))

func active_augment_input_blocked(slot: int = -1) -> bool:
	return _active_augment_input_locks > 0 or (slot >= 0 and active_augment_slot_blocked(slot))

func follower_belief_power() -> float:
	# Belief literally fuels Syn'Tek: a small, diminishing Power bonus from
	# the current congregation. sqrt keeps early followers meaningful and
	# hoarding from snowballing: 25 -> +5%, 100 -> +10%, cap +15%.
	return minf(0.15, 0.01 * sqrt(float(maxi(0, followers))))

func level_up_permanent_augment(id: StringName) -> void:
	if id == StringName():
		return
	set_augment_level(id, get_augment_level(id) + 1)
	if DEBUG_GLOBAL:
		print("[AUG] level_up_permanent_augment id=", id, " -> L", get_augment_level(id))
	permanent_augments_changed.emit(permanent_augment_ids)

func apply_permanent_augments_to_stats(s: Stats) -> void:
	init_permanent_augments()
	for id in permanent_augment_ids:
		if id == StringName():
			continue
		var a := augment_db.get(id, null) as AugmentData
		if a == null:
			continue

		var lvl: int = 1
		if has_method("get_augment_level"):
			lvl = get_augment_level(id)

		# Prefer level-aware stat application (keeps 'Augment Overclock' meaningful even for stat-only augments).
		if a.has_method("apply_to_stats_at_level"):
			a.apply_to_stats_at_level(s, lvl)
		else:
			a.apply_to_stats(s)

func load_augments_from_dir(path: String) -> void:
	augment_db.clear()
	_scan_augments_dir_recursive(path)
	if DEBUG_GLOBAL:
		print("Augment DB keys:", augment_db.keys())

func _scan_augments_dir_recursive(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		push_warning("Augment dir not found: " + path)
		return

	dir.list_dir_begin()
	var fn: String = dir.get_next()
	while fn != "":
		if fn.begins_with("."):
			fn = dir.get_next()
			continue

		var full := path.path_join(fn)

		if dir.current_is_dir():
			_scan_augments_dir_recursive(full)
		elif fn.ends_with(".tres") or fn.ends_with(".res"):
			var res := ResourceLoader.load(full)
			var ad := res as AugmentData
			if ad != null and ad.id != StringName():
				augment_db[ad.id] = ad
				if DEBUG_GLOBAL:
					print("[AUG] ", String(ad.id), " name=", ad.display_name,
						" desc_len=", ad.description.length(),
						" blurb_len=", ad.card_blurb.length(),
						" details_len=", ad.details.length(),
						" mods=", (ad.mods != null))

		fn = dir.get_next()

	dir.list_dir_end()


# ============================================================
# Shared directory scan helper
# ============================================================

func _scan_dir_recursive(dir_path: String, on_loaded: Callable) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_warning("Dir not found: " + dir_path)
		return

	dir.list_dir_begin()
	var fn: String = dir.get_next()
	while fn != "":
		if fn.begins_with("."):
			fn = dir.get_next()
			continue

		var full: String = dir_path.path_join(fn)

		if dir.current_is_dir():
			_scan_dir_recursive(full, on_loaded)
		else:
			if fn.ends_with(".tres") or fn.ends_with(".res"):
				var res: Resource = ResourceLoader.load(full)
				if res != null:
					on_loaded.call(res)

		fn = dir.get_next()

	dir.list_dir_end()


# ============================================================
# Luck roll shaping
# ============================================================

func roll_percent(luck: float, min_pct: float, max_pct: float) -> float:
	return clampf(
		ItemGenerator.roll_signed_range(min_pct, max_pct, luck, _rng),
		-0.9999,
		0.9999
	)

# ============================================================
# Helpers
# ============================================================


func _has_prop(obj: Object, prop: StringName) -> bool:
	for p in obj.get_property_list():
		if p.name == prop:
			return true
	return false

func _get_string_prop(res: Resource, prop: StringName) -> String:
	if res == null:
		return ""
	if not _has_prop(res, prop):
		return ""
	var v = res.get(prop)
	if typeof(v) == TYPE_STRING and String(v) != "":
		return String(v)
	return ""

func _camel_to_snake(s: String) -> String:
	# "MagicMissile" -> "magic_missile"
	# "StarterMelee" -> "starter_melee"
	var out := ""
	for i in range(s.length()):
		var ch := s.substr(i, 1)

		var is_upper := (ch >= "A" and ch <= "Z")
		var is_lower := (ch >= "a" and ch <= "z")
		var is_digit := (ch >= "0" and ch <= "9")

		if i > 0 and is_upper:
			var prev := s.substr(i - 1, 1)
			var prev_is_lower := (prev >= "a" and prev <= "z")
			var prev_is_digit := (prev >= "0" and prev <= "9")
			if prev_is_lower or prev_is_digit:
				out += "_"

		if is_upper:
			out += ch.to_lower()
		elif is_lower or is_digit:
			out += ch
		else:
			out += "_"

	# collapse double underscores (cheap cleanup)
	while out.find("__") != -1:
		out = out.replace("__", "_")

	out = out.strip_edges()
	out = out.trim_prefix("_")
	out = out.trim_suffix("_")
	return out

# ============================================================
# Campaign attempt & meta persistence
# ============================================================


# ============================================================
# Major Choices (Segment 5 big node)
# ============================================================

func has_mutation(id: StringName) -> bool:
	return attempt_mutations.has(id) or attempt_mutations.has(String(id))

func get_mutation(id: StringName, default: Variant = null) -> Variant:
	if attempt_mutations.has(id):
		return attempt_mutations[id]
	var k := String(id)
	return attempt_mutations.get(k, default)

func add_mutation(id: StringName, value: Variant = true) -> void:
	if id == StringName():
		return
	attempt_mutations[String(id)] = value
	request_autosave()


func pending_doctrine_stage() -> StringName:
	return attempt_pending_doctrine_stage


func get_doctrine_rule(key: StringName, fallback: Variant = null) -> Variant:
	if attempt_doctrine_rules.has(key):
		return attempt_doctrine_rules[key]
	return attempt_doctrine_rules.get(String(key), fallback)


func set_doctrine_rule(key: StringName, value: Variant) -> void:
	if key == StringName():
		return
	attempt_doctrine_rules[String(key)] = value
	request_autosave()


func add_doctrine_rule(key: StringName, amount: float) -> void:
	set_doctrine_rule(key, float(get_doctrine_rule(key, 0.0)) + amount)


func doctrine_active_cooldown(base_seconds: float) -> float:
	return maxf(0.0, base_seconds) * maxf(0.0, float(get_doctrine_rule(&"active_augment_cooldown_mul", 1.0)))


func notify_active_augment_used(slot: int) -> void:
	var seconds := maxf(0.0, float(get_doctrine_rule(&"active_augment_cross_lock_seconds", 0.0)))
	_doctrine_active_slot = slot
	_doctrine_active_lock_until_ms = Time.get_ticks_msec() + int(round(seconds * 1000.0))


func active_augment_slot_blocked(slot: int) -> bool:
	return slot != _doctrine_active_slot and Time.get_ticks_msec() < _doctrine_active_lock_until_ms


func doctrine_healing_multiplier(source: StringName) -> float:
	if source in [&"exit_rite", &"wardstone"]:
		return maxf(0.0, float(get_doctrine_rule(&"ritual_healing_mul", 1.0)))
	return maxf(0.0, float(get_doctrine_rule(&"other_healing_mul", 1.0)))

func get_augment_level(aug_id: StringName) -> int:
	if aug_id == StringName():
		return 1
	# store as String key for SaveData compatibility
	var k := String(aug_id)
	if attempt_augment_levels.has(k):
		return maxi(1, int(attempt_augment_levels[k]))
	return 1

func set_augment_level(aug_id: StringName, level: int) -> void:
	if aug_id == StringName():
		return
	attempt_augment_levels[String(aug_id)] = maxi(1, level)
	request_autosave()

func apply_attempt_modifiers_to_stats(s: Stats) -> void:
	if attempt_stat_delta != null:
		attempt_stat_delta.apply_to(s)

func apply_doctrine_final_stat_multipliers(s: Stats) -> void:
	if s == null:
		return
	s.max_hp = maxf(1.0, s.max_hp * float(get_doctrine_rule(&"max_hp_mul", 1.0)))

func try_consume_manufactured_witness() -> bool:
	if not bool(get_doctrine_rule(&"manufactured_witness", false)):
		return false
	if attempt_witness_used_segment == attempt_segment or followers < 100:
		return false
	var transaction := transaction_followers(
		-100,
		&"manufactured_witness",
		{"segment": attempt_segment},
		false,
		false
	)
	if int(transaction.get("change", 0)) != -100:
		return false
	attempt_witness_used_segment = attempt_segment
	attempt_doctrine_threat_debt += 25.0
	if not attempt_doctrine_events.has("WITNESS EXPENDED"):
		attempt_doctrine_events.append("WITNESS EXPENDED")
	if RunEvents != null and RunEvents.doctrine_event_recorded.has_connections():
		RunEvents.doctrine_event_recorded.emit(
			&"witness_expended",
			"WITNESS EXPENDED"
		)
	request_autosave()
	return true

func grant_doctrine_secondary_rewards(source_key: StringName) -> int:
	var rolls := maxi(0, int(get_doctrine_rule(&"secondary_reward_rolls", 0)))
	if rolls <= 0 or item_db.is_empty():
		return 0
	var delivered := 0
	for roll_index in range(rolls):
		if DOCTRINE_REWARD_SERVICE.grant_secondary_roll(self, source_key, roll_index):
			delivered += 1
	return delivered

func get_major_choice_offer(count: int = 3) -> Array:
	if not pending_big_choice:
		return []

	if attempt_big_choice_source_segment <= 0:
		attempt_big_choice_source_segment = 5

	# Persisted offer: reconstruct from ids
	if attempt_major_choice_offer_ids.is_empty():
		_generate_major_choice_offer(count)

	var out: Array = []
	for id in attempt_major_choice_offer_ids:
		var def: MajorChoiceDef = major_choice_db.get_def(StringName(str(id)))
		if def != null:
			out.append(def)
	return out

func _generate_major_choice_offer(count: int) -> void:
	# Continue-safe offer, based on attempt seed + context segment.
	var rng := RandomNumberGenerator.new()
	var seed_val: int = attempt_world_seed
	if seed_val == 0:
		seed_val = randi()

	var ctx_seg: int = get_major_choice_context_segment()
	rng.seed = int(seed_val) ^ (ctx_seg * 2654435761) ^ 0x5EED5

	var offer: Array[MajorChoiceDef] = []
	if attempt_pending_doctrine_stage != StringName():
		var context_script := load("res://core/systems/major_choice/MajorChoiceContext.gd") as Script
		var context: RefCounted = context_script.call("from_global", self, attempt_pending_doctrine_stage)
		offer = major_choice_db.build_stage_offer(context, attempt_major_choice_taken_ids, rng)
	else:
		offer = major_choice_db.build_offer(self, count, rng)
	attempt_major_choice_offer_ids.clear()
	for d in offer:
		attempt_major_choice_offer_ids.append(d.id)

	request_autosave()

func apply_major_choice(choice_id: StringName) -> bool:
	# Resolve the pending reward and apply a run-shaping modifier.
	if not pending_big_choice:
		return false

	var def: MajorChoiceDef = major_choice_db.get_def(choice_id)
	if def == null or not attempt_major_choice_offer_ids.has(choice_id) or attempt_major_choice_taken_ids.has(choice_id):
		return false
	if attempt_pending_doctrine_stage != StringName() and def.stage != attempt_pending_doctrine_stage:
		return false
	for e in def.effects:
		if e == null:
			continue
		e.apply(self)

	attempt_major_choice_id = choice_id
	if not attempt_major_choice_taken_ids.has(choice_id):
		attempt_major_choice_taken_ids.append(choice_id)
	if attempt_pending_doctrine_stage != StringName():
		attempt_doctrine_stage_ids[attempt_pending_doctrine_stage] = choice_id

	# clear offer + flag so you can't get stuck
	attempt_major_choice_offer_ids.clear()
	pending_big_choice = false
	attempt_big_choice_source_segment = 0
	attempt_pending_doctrine_stage = &""
	request_autosave()
	return true

func request_autosave(delay: float = 0.6) -> void:
	# Combat calls this once per kill; writing and re-validating the profile on
	# a sub-second debounce meant synchronous disk work mid-fight. Mark the
	# profile dirty and defer the write to a safe point (scene change, quit) or
	# the long fallback timer below.
	if _suppress_autosave:
		return
	if SaveManager == null or SaveManager.current_save == null:
		return
	_autosave_dirty = true
	if _autosave_timer != null and is_instance_valid(_autosave_timer):
		return
	_autosave_timer = get_tree().create_timer(maxf(delay, autosave_fallback_seconds))
	_autosave_timer.timeout.connect(_on_autosave_timeout)


func _on_autosave_timeout() -> void:
	_autosave_timer = null
	flush_pending_save()


func _cancel_autosave_timer() -> void:
	if _autosave_timer != null and is_instance_valid(_autosave_timer):
		var callback := Callable(self, "_on_autosave_timeout")
		if _autosave_timer.timeout.is_connected(callback):
			_autosave_timer.timeout.disconnect(callback)
	_autosave_timer = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush_pending_save()


func _exit_tree() -> void:
	_cancel_autosave_timer()
	# Application shutdown: release script-static caches that hold RID-backed
	# resources (textures/materials). Script statics destruct during script
	# server teardown — after rendering cleanup has begun — which is the window
	# the intermittent exit segfault lives in.
	_WORLD_ART_SCRIPT.release_static_caches()
	EnemyProjectile.release_static_caches()
	AugmentActiveBadge.release_static_caches()


func flush_pending_save() -> void:
	_cancel_autosave_timer()
	if not _autosave_dirty:
		return
	if SaveManager == null or SaveManager.current_save == null:
		_autosave_dirty = false
		return
	save_current_profile(false)


# ------------------------------------------------------------
# Exploration loot claim (prevents chunk-stream farming)
# ------------------------------------------------------------
func _rebuild_claimed_loot_set() -> void:
	_claimed_loot_set.clear()
	for v in attempt_claimed_loot_ids:
		_claimed_loot_set[int(v)] = true

func has_claimed_loot(id: int) -> bool:
	return _claimed_loot_set.has(id)

## True the first time this attempt sees `id`, false ever after. Identity is
## the seeded building id, never the streamed node, so exploration rewards
## cannot be farmed by walking out of and back into load radius.
func note_building_visit(id: int) -> bool:
	if id == 0:
		return false
	if _visited_building_set.has(id):
		return false
	_visited_building_set[id] = true
	return true


func has_visited_building(id: int) -> bool:
	return _visited_building_set.has(id)


func claim_loot(id: int) -> void:
	if id == 0:
		return
	if _claimed_loot_set.has(id):
		return
	_claimed_loot_set[id] = true
	attempt_claimed_loot_ids.append(id)
	request_autosave()

func apply_save(save: SaveData) -> void:
	_suppress_autosave = true

	# Last chosen setup (for Base screen defaults)
	selected_race_id = save.last_race_id
	selected_style_id = save.last_style_id
	selected_weapon_id = save.last_style_id
	equipped_spell_ids = save.last_spell_ids.duplicate()
	mortal_name = save.mortal_name.strip_edges()
	if mortal_name == "":
		mortal_name = "The Arcanist"

	# Meta augments (persist forever)
	if save.meta_permanent_augment_ids.size() != 3:
		save.meta_permanent_augment_ids = ["", "", ""]
	permanent_augment_ids = [StringName(), StringName(), StringName()]
	for i in range(3):
		var s: String = save.meta_permanent_augment_ids[i]
		permanent_augment_ids[i] = (StringName(s) if s != "" else StringName())
	# Heal saves corrupted by the old duplicate-slotting bug: an id may occupy
	# only one slot; keep the first occurrence (preserves slot order/locks).
	for i in range(3):
		if permanent_augment_ids[i] == StringName():
			continue
		for j in range(i + 1, 3):
			if permanent_augment_ids[j] == permanent_augment_ids[i]:
				permanent_augment_ids[j] = StringName()
	init_permanent_augments()
	permanent_augments_changed.emit(permanent_augment_ids)

	# Owned augments library (persist forever)
	owned_augment_ids = []
	for s2 in save.meta_owned_augment_ids:
		var ss: String = String(s2)
		if ss != "":
			owned_augment_ids.append(StringName(ss))
	init_owned_augments()

	# Enemy dossiers are profile knowledge, not attempt state.
	discovered_enemy_ids.clear()
	for enemy_id in save.meta_discovered_enemy_ids:
		var clean_enemy_id := String(enemy_id).strip_edges()
		if clean_enemy_id != "" and not discovered_enemy_ids.has(StringName(clean_enemy_id)):
			discovered_enemy_ids.append(StringName(clean_enemy_id))
	seen_manifestation_cards.clear()
	for card_id in save.meta_seen_manifestation_cards:
		var clean_card_id := String(card_id).strip_edges()
		if clean_card_id != "" and not seen_manifestation_cards.has(StringName(clean_card_id)):
			seen_manifestation_cards.append(StringName(clean_card_id))

	# Opening Chronicle profile state. Exported defaults make this safe for old
	# saves that predate the playable cinematic.
	opening_full_intro_seen = bool(save.opening_full_intro_seen)
	opening_response_id = StringName(save.opening_response_id.strip_edges())
	opening_follower_explanation_seen = bool(save.opening_follower_explanation_seen)
	opening_replay_full_next_run = bool(save.opening_replay_full_next_run)

	# Slot locks (persist)
	augment_slot_locks = [false, false, false]
	if save != null and save.has_method("get"):
		var arr_locks: Array = save.get("meta_augment_slot_locks") as Array
		if arr_locks != null and arr_locks.size() >= 3:
			augment_slot_locks[0] = bool(arr_locks[0])
			augment_slot_locks[1] = bool(arr_locks[1])
			augment_slot_locks[2] = bool(arr_locks[2])

	# Meta stash (persist forever)
	meta_stash = save.meta_stash
	if meta_stash == null:
		meta_stash = StashInventory.new()



	# Attempt snapshot (Continue)
	attempt_active = save.attempt_active
	if attempt_active:
		attempt_segment = max(1, save.attempt_segment)
		attempt_deaths_this_segment = max(0, save.attempt_deaths_this_segment)
		attempt_checkpoint_pos = save.attempt_checkpoint_pos
		attempt_world_seed = save.attempt_world_seed
		attempt_segment1_layout_version = int(save.attempt_segment1_layout_version)
		attempt_segment1_resonance = clampf(float(save.attempt_segment1_resonance), 0.0, 1.0)
		attempt_segment1_milestones.clear()
		for milestone_id in save.attempt_segment1_milestones:
			var clean_id := String(milestone_id).strip_edges()
			if clean_id != "":
				attempt_segment1_milestones.append(StringName(clean_id))
		attempt_opening_version = maxi(0, int(save.attempt_opening_version))
		attempt_opening_mode = StringName(save.attempt_opening_mode.strip_edges())
		attempt_opening_phase = maxi(0, int(save.attempt_opening_phase))
		attempt_opening_completed = bool(save.attempt_opening_completed)
		attempt_opening_officer_completed = bool(save.attempt_opening_officer_completed)
		attempt_opening_bren_committed = bool(save.attempt_opening_bren_committed)

		# Migration: an older save already beyond synthesis/Segment 1 must never be
		# dragged back into the cinematic merely because the new fields were absent.
		if attempt_opening_version <= 0:
			var passed_synthesis := attempt_segment1_milestones.has(&"synthesis")
			if attempt_segment > 1 or passed_synthesis:
				attempt_opening_completed = true
				attempt_opening_phase = 10
				attempt_opening_mode = &"legacy"
				attempt_opening_officer_completed = attempt_segment1_milestones.has(&"first_confrontation")
				attempt_opening_bren_committed = attempt_segment1_milestones.has(&"assistant_commitment")
				opening_full_intro_seen = true
				if attempt_opening_bren_committed:
					opening_follower_explanation_seen = true
			attempt_opening_version = OPENING_SEQUENCE_VERSION

		# v1 -> v2: the ADMISSION phase was inserted after HISTORICAL, so every
		# saved phase from the old BREN (2) up shifts one slot later. Completed
		# openings only care about the flag; mid-opening saves resume correctly.
		if attempt_opening_version == 1:
			if attempt_opening_phase >= 2:
				attempt_opening_phase += 1
			attempt_opening_version = OPENING_SEQUENCE_VERSION

		# Checkpoints from the compact recovery layout are unsafe in the rebuilt map.
		if attempt_segment == 1 and attempt_segment1_layout_version != SEGMENT1_LAYOUT_VERSION:
			attempt_checkpoint_pos = Vector2.INF
			attempt_segment1_resonance = 0.0
			attempt_segment1_milestones.clear()
			attempt_segment1_layout_version = SEGMENT1_LAYOUT_VERSION
			# Preserve narrative facts even though obsolete map coordinates and
			# spatial milestones must be rebuilt for the current layout.
			if attempt_opening_completed:
				attempt_segment1_milestones.append(&"synthesis")
				if attempt_opening_officer_completed:
					attempt_segment1_milestones.append(&"first_confrontation")
				if attempt_opening_bren_committed:
					attempt_segment1_milestones.append(&"assistant_commitment")
		attempt_claimed_loot_ids = save.attempt_claimed_loot_ids
		_rebuild_claimed_loot_set()
		pending_augment_pick = save.attempt_pending_augment_pick
		pending_big_choice = save.attempt_pending_big_choice
		attempt_big_choice_source_segment = int(save.attempt_big_choice_source_segment)

		# Attempt modifiers (reset on die-die)
		attempt_major_choice_id = (StringName(save.attempt_major_choice_id) if save.attempt_major_choice_id != "" else &"")
		attempt_wardstone_radius_mul = maxf(0.25, float(save.attempt_mod_wardstone_radius_mul))
		attempt_wardstone_slow_mul = clampf(float(save.attempt_mod_wardstone_slow_mul), 0.25, 2.0)
		attempt_exit_hold_mul = clampf(float(save.attempt_mod_exit_hold_mul), 0.25, 2.0)

		# Major choice offer + state (Continue-safe)
		attempt_major_choice_offer_ids.clear()
		for s_id in save.attempt_major_choice_offer_ids:
			var sid: String = String(s_id)
			if sid != "":
				attempt_major_choice_offer_ids.append(StringName(sid))

		attempt_major_choice_taken_ids.clear()
		for t_id in save.attempt_major_choice_taken_ids:
			var tid: String = String(t_id)
			if tid != "":
				attempt_major_choice_taken_ids.append(StringName(tid))

		attempt_doctrine_version = ASCENSION_DOCTRINE_VERSION
		attempt_pending_doctrine_stage = StringName(save.attempt_pending_doctrine_stage)
		attempt_doctrine_stage_ids = save.attempt_doctrine_stage_ids.duplicate(true)
		attempt_doctrine_rules = save.attempt_doctrine_rules.duplicate(true)
		attempt_doctrine_events = save.attempt_doctrine_events.duplicate()
		attempt_witness_used_segment = int(save.attempt_witness_used_segment)
		attempt_doctrine_threat_debt = maxf(0.0, float(save.attempt_doctrine_threat_debt))
		# Legacy major choices already wrote their effects into the old modifier
		# fields. Preserve their identity without replaying those effects or
		# manufacturing missed Doctrine screens.
		if attempt_major_choice_id != StringName() and not attempt_major_choice_taken_ids.has(attempt_major_choice_id):
			attempt_major_choice_taken_ids.append(attempt_major_choice_id)
		if int(save.attempt_doctrine_version) <= 0:
			# Legacy offer resources are intentionally disabled. Keeping a pending
			# pre-Doctrine offer would open an empty modal and permanently disable
			# Hub Continue, so retire that obsolete reward during migration.
			pending_big_choice = false
			attempt_big_choice_source_segment = 0
			attempt_major_choice_offer_ids.clear()
			attempt_pending_doctrine_stage = &""
			attempt_doctrine_stage_ids.clear()
			attempt_doctrine_rules.clear()
			attempt_doctrine_events.clear()

		attempt_augment_levels = save.attempt_augment_levels.duplicate(true)
		attempt_mutations = save.attempt_mod_mutations.duplicate(true)
		attempt_stat_delta = save.attempt_mod_stat_delta

		# Attempt identity (so Continue keeps your run identity)
		if save.attempt_race_id != "":
			selected_race_id = save.attempt_race_id
		if save.attempt_style_id != "":
			selected_style_id = save.attempt_style_id
		if save.attempt_weapon_id != "":
			selected_weapon_id = save.attempt_weapon_id

		# Load attempt inventories (or create)
		run_inventory = save.attempt_inventory if save.attempt_inventory != null else Inventory.new()
		run_bag = save.attempt_bag if save.attempt_bag != null else BagInventory.new()

		# Ensure sizes
		if run_inventory != null and run_inventory.has_method("_ensure_size"):
			run_inventory._ensure_size()
		if run_bag != null and run_bag.has_method("_ensure_size"):
			run_bag._ensure_size()
		if run_bag != null and run_bag.has_method("_rebuild_index"):
			run_bag._rebuild_index()

		# Vendor snapshot (HubShop anti-reroll)
		attempt_vendor_segment = int(save.attempt_vendor_segment) if save.has_method("get") else int(save.attempt_vendor_segment)
		attempt_vendor_refreshes = int(save.attempt_vendor_refreshes)
		attempt_vendor_seed = int(save.attempt_vendor_seed)
		attempt_vendor_bag = save.attempt_vendor_bag

		if attempt_vendor_bag != null and attempt_vendor_bag.has_method("_ensure_size"):
			attempt_vendor_bag._ensure_size()

		set_followers(save.attempt_followers)
	else:
		attempt_segment = 1
		attempt_deaths_this_segment = 0
		attempt_checkpoint_pos = Vector2.INF
		attempt_world_seed = 0
		attempt_segment1_layout_version = SEGMENT1_LAYOUT_VERSION
		attempt_segment1_resonance = 0.0
		attempt_segment1_milestones.clear()
		attempt_opening_version = OPENING_SEQUENCE_VERSION
		attempt_opening_mode = &""
		attempt_opening_phase = 0
		attempt_opening_completed = false
		attempt_opening_officer_completed = false
		attempt_opening_bren_committed = false
		attempt_claimed_loot_ids = PackedInt32Array()
		_claimed_loot_set.clear()
		attempt_vendor_segment = 0
		attempt_vendor_refreshes = 0
		attempt_vendor_seed = 0
		attempt_vendor_bag = null
		pending_augment_pick = false
		pending_big_choice = false

		# Attempt modifiers reset
		attempt_major_choice_id = &""
		attempt_wardstone_radius_mul = 1.0
		attempt_wardstone_slow_mul = 1.0
		attempt_exit_hold_mul = 1.0

		attempt_major_choice_offer_ids.clear()
		attempt_major_choice_taken_ids.clear()
		attempt_doctrine_version = ASCENSION_DOCTRINE_VERSION
		attempt_pending_doctrine_stage = &""
		attempt_doctrine_stage_ids.clear()
		attempt_doctrine_rules.clear()
		attempt_doctrine_events.clear()
		attempt_witness_used_segment = 0
		attempt_doctrine_threat_debt = 0.0
		attempt_augment_levels = {}
		attempt_mutations = {}
		attempt_stat_delta = null

		run_inventory = null
		run_bag = null
		set_followers(0)

	_suppress_autosave = false
func write_save(save: SaveData) -> void:
	_suppress_autosave = true
	save.best_followers = maxi(save.best_followers, followers)

	# Last chosen setup
	save.last_race_id = selected_race_id
	save.last_style_id = selected_style_id
	save.last_spell_ids = equipped_spell_ids.duplicate()
	save.mortal_name = mortal_name.strip_edges() if mortal_name.strip_edges() != "" else "The Arcanist"

	# Meta augments
	init_permanent_augments()
	save.meta_permanent_augment_ids.resize(3)
	for i in range(3):
		var id: StringName = permanent_augment_ids[i]
		save.meta_permanent_augment_ids[i] = (String(id) if id != StringName() else "")

	# Owned augments library (persist forever)
	init_owned_augments()
	save.meta_owned_augment_ids = []
	for sid in owned_augment_ids:
		save.meta_owned_augment_ids.append(String(sid))

	save.meta_discovered_enemy_ids = []
	for enemy_id in discovered_enemy_ids:
		save.meta_discovered_enemy_ids.append(String(enemy_id))
	save.meta_seen_manifestation_cards = []
	for card_id in seen_manifestation_cards:
		save.meta_seen_manifestation_cards.append(String(card_id))
	save.meta_stash = meta_stash
	save.opening_full_intro_seen = opening_full_intro_seen
	save.opening_response_id = String(opening_response_id)
	save.opening_follower_explanation_seen = opening_follower_explanation_seen
	save.opening_replay_full_next_run = opening_replay_full_next_run

	# Slot locks
	if augment_slot_locks == null or augment_slot_locks.size() < 3:
		augment_slot_locks = [false, false, false]
	save.meta_augment_slot_locks = [augment_slot_locks[0], augment_slot_locks[1], augment_slot_locks[2]]

	# Attempt snapshot
	save.attempt_active = attempt_active
	if attempt_active:
		save.attempt_segment = attempt_segment
		save.attempt_followers = followers
		save.attempt_deaths_this_segment = attempt_deaths_this_segment
		save.attempt_pending_augment_pick = pending_augment_pick
		save.attempt_pending_big_choice = pending_big_choice
		save.attempt_big_choice_source_segment = attempt_big_choice_source_segment

		# Attempt modifiers
		save.attempt_major_choice_id = String(attempt_major_choice_id)
		save.attempt_mod_wardstone_radius_mul = attempt_wardstone_radius_mul
		save.attempt_mod_wardstone_slow_mul = attempt_wardstone_slow_mul
		save.attempt_mod_exit_hold_mul = attempt_exit_hold_mul

		# Offer + taken ids
		save.attempt_major_choice_offer_ids = []
		for id in attempt_major_choice_offer_ids:
			save.attempt_major_choice_offer_ids.append(String(id))

		save.attempt_major_choice_taken_ids = []
		for id in attempt_major_choice_taken_ids:
			save.attempt_major_choice_taken_ids.append(String(id))
		save.attempt_doctrine_version = ASCENSION_DOCTRINE_VERSION
		save.attempt_pending_doctrine_stage = String(attempt_pending_doctrine_stage)
		save.attempt_doctrine_stage_ids = attempt_doctrine_stage_ids.duplicate(true)
		save.attempt_doctrine_rules = attempt_doctrine_rules.duplicate(true)
		save.attempt_doctrine_events = attempt_doctrine_events.duplicate()
		save.attempt_witness_used_segment = attempt_witness_used_segment
		save.attempt_doctrine_threat_debt = attempt_doctrine_threat_debt

		save.attempt_augment_levels = attempt_augment_levels.duplicate(true)
		save.attempt_mod_mutations = attempt_mutations.duplicate(true)
		save.attempt_mod_stat_delta = attempt_stat_delta

		# Attempt identity
		save.attempt_race_id = selected_race_id
		save.attempt_style_id = selected_style_id
		save.attempt_weapon_id = selected_weapon_id

		save.attempt_checkpoint_pos = attempt_checkpoint_pos
		save.attempt_world_seed = attempt_world_seed
		save.attempt_segment1_layout_version = attempt_segment1_layout_version
		save.attempt_segment1_resonance = attempt_segment1_resonance
		save.attempt_segment1_milestones = []
		for milestone_id in attempt_segment1_milestones:
			save.attempt_segment1_milestones.append(String(milestone_id))
		save.attempt_opening_version = attempt_opening_version
		save.attempt_opening_mode = String(attempt_opening_mode)
		save.attempt_opening_phase = attempt_opening_phase
		save.attempt_opening_completed = attempt_opening_completed
		save.attempt_opening_officer_completed = attempt_opening_officer_completed
		save.attempt_opening_bren_committed = attempt_opening_bren_committed
		save.attempt_claimed_loot_ids = attempt_claimed_loot_ids
		save.attempt_inventory = run_inventory
		save.attempt_bag = run_bag
		save.attempt_vendor_segment = attempt_vendor_segment
		save.attempt_vendor_refreshes = attempt_vendor_refreshes
		save.attempt_vendor_seed = attempt_vendor_seed
		save.attempt_vendor_bag = attempt_vendor_bag
	else:
		# Clear heavy attempt resources from disk
		save.attempt_segment = 1
		save.attempt_followers = 0
		save.attempt_deaths_this_segment = 0
		save.attempt_resume_scene = ""
		save.attempt_pending_augment_pick = false
		save.attempt_pending_big_choice = false

		# Attempt modifiers reset
		save.attempt_major_choice_id = ""
		save.attempt_mod_wardstone_radius_mul = 1.0
		save.attempt_mod_wardstone_slow_mul = 1.0
		save.attempt_mod_exit_hold_mul = 1.0

		save.attempt_major_choice_offer_ids = []
		save.attempt_major_choice_taken_ids = []
		save.attempt_doctrine_version = ASCENSION_DOCTRINE_VERSION
		save.attempt_pending_doctrine_stage = ""
		save.attempt_doctrine_stage_ids = {}
		save.attempt_doctrine_rules = {}
		save.attempt_doctrine_events = []
		save.attempt_witness_used_segment = 0
		save.attempt_doctrine_threat_debt = 0.0
		save.attempt_augment_levels = {}
		save.attempt_mod_mutations = {}
		save.attempt_mod_stat_delta = null

		# Attempt identity reset
		save.attempt_race_id = selected_race_id
		save.attempt_style_id = selected_style_id
		save.attempt_weapon_id = selected_weapon_id

		save.attempt_checkpoint_pos = Vector2.INF
		save.attempt_world_seed = 0
		save.attempt_segment1_layout_version = SEGMENT1_LAYOUT_VERSION
		save.attempt_segment1_resonance = 0.0
		save.attempt_segment1_milestones = []
		save.attempt_opening_version = OPENING_SEQUENCE_VERSION
		save.attempt_opening_mode = ""
		save.attempt_opening_phase = 0
		save.attempt_opening_completed = false
		save.attempt_opening_officer_completed = false
		save.attempt_opening_bren_committed = false
		save.attempt_claimed_loot_ids = PackedInt32Array()
		save.attempt_inventory = null
		save.attempt_bag = null
		save.attempt_vendor_segment = 0
		save.attempt_vendor_refreshes = 0
		save.attempt_vendor_seed = 0
		save.attempt_vendor_bag = null

	_suppress_autosave = false
func save_current_profile(validated: bool = true) -> void:
	if SaveManager == null or SaveManager.current_save == null:
		return
	_cancel_autosave_timer()
	_autosave_dirty = false
	write_save(SaveManager.current_save)
	SaveManager.save_current(validated)

func record_new_attempt(save: SaveData) -> void:
	if save != null:
		save.total_runs = maxi(0, save.total_runs) + 1

func start_new_attempt() -> void:
	# Attempt resets (die-die behavior)
	attempt_active = true
	attempt_segment = 1
	attempt_deaths_this_segment = 0
	attempt_checkpoint_pos = Vector2.INF
	attempt_segment1_layout_version = SEGMENT1_LAYOUT_VERSION
	attempt_segment1_resonance = 0.0
	attempt_segment1_milestones.clear()
	attempt_opening_version = OPENING_SEQUENCE_VERSION
	attempt_opening_phase = 0
	attempt_opening_completed = false
	attempt_opening_officer_completed = false
	attempt_opening_bren_committed = false

	# Every attempt needs fresh run-scoped containers before the game scene binds
	# HUD, player stats and world pickups. These two lines were present before the
	# opening rewrite and must remain part of the authoritative attempt reset.
	attempt_world_seed = int(Time.get_unix_time_from_system() * 1000.0) ^ _rng.randi()
	reset_run_systems()

	if debug_opening_mode_override in ["full", "short", "skip"]:
		attempt_opening_mode = StringName(debug_opening_mode_override)
	elif not opening_full_intro_seen or opening_replay_full_next_run:
		attempt_opening_mode = &"full"
	else:
		attempt_opening_mode = &"short"
	opening_replay_full_next_run = false
	# Bren is the first follower. The HUD remains at zero until commitment.
	set_followers(0)

	# Start-of-attempt augment event if you have empty slots
	init_permanent_augments()
	# Only show the intro augment pick on a truly fresh profile (0 augments owned).
	var owned: int = 0
	for id in permanent_augment_ids:
		if id != StringName():
			owned += 1
	pending_augment_pick = (owned == 0)
	pending_big_choice = false
	attempt_major_choice_id = &""
	attempt_pending_doctrine_stage = &""
	attempt_doctrine_stage_ids.clear()
	attempt_doctrine_rules.clear()
	attempt_doctrine_events.clear()
	attempt_witness_used_segment = 0
	attempt_doctrine_threat_debt = 0.0
	attempt_wardstone_radius_mul = 1.0
	attempt_wardstone_slow_mul = 1.0
	attempt_exit_hold_mul = 1.0

	# Default resume is the game
	if SaveManager != null and SaveManager.current_save != null:
		record_new_attempt(SaveManager.current_save)
		SaveManager.current_save.attempt_resume_scene = PATH_GAME

	save_current_profile()

func on_segment_completed(completed_segment: int) -> void:
	attempt_segment = completed_segment + 1
	attempt_deaths_this_segment = 0
	attempt_checkpoint_pos = Vector2.INF
	if completed_segment == 1:
		attempt_segment1_resonance = 0.0
		attempt_segment1_milestones.clear()
		attempt_opening_completed = true
		attempt_opening_phase = 10

	# New segment: reset exploration loot claim state
	attempt_claimed_loot_ids = PackedInt32Array()
	_claimed_loot_set.clear()

	# New segment: reset vendor snapshot so you can't reroll by segment-hopping
	attempt_vendor_segment = 0
	attempt_vendor_refreshes = 0
	attempt_vendor_seed = 0
	attempt_vendor_bag = null

	# Milestones
	if completed_segment == 2 or completed_segment == 7:
		pending_augment_pick = true
	var next_doctrine_stage := doctrine_stage_for_completed_segment(completed_segment)
	if next_doctrine_stage != StringName() and not attempt_doctrine_stage_ids.has(next_doctrine_stage):
		pending_big_choice = true
		attempt_pending_doctrine_stage = next_doctrine_stage
		attempt_big_choice_source_segment = completed_segment
		attempt_major_choice_offer_ids.clear()
	attempt_witness_used_segment = 0
	attempt_doctrine_threat_debt = 0.0

	if SaveManager != null and SaveManager.current_save != null:
		SaveManager.current_save.attempt_resume_scene = PATH_HUB_SHOP

	save_current_profile()


func doctrine_stage_for_completed_segment(completed_segment: int) -> StringName:
	match completed_segment:
		3:
			return &"method"
		6:
			return &"doctrine"
		9:
			return &"apotheosis"
		_:
			return &""



# ============================================================
# Major choice (Segment 5 reward)
# ============================================================


func get_major_choice_context_segment() -> int:
	# Big choice happens *after* completing a segment, so attempt_segment may already be advanced.
	# Use the grant segment when a big choice is pending (Segment 5 by design).
	if pending_big_choice:
		if attempt_big_choice_source_segment <= 0:
			return 5
		return attempt_big_choice_source_segment
	return attempt_segment

func on_attempt_failed_die_die() -> void:
	# Keep meta augments; wipe attempt snapshot so Continue returns to Base.
	attempt_active = false
	attempt_segment = 1
	attempt_deaths_this_segment = 0
	attempt_checkpoint_pos = Vector2.INF
	attempt_segment1_layout_version = SEGMENT1_LAYOUT_VERSION
	attempt_segment1_resonance = 0.0
	attempt_segment1_milestones.clear()
	attempt_opening_version = OPENING_SEQUENCE_VERSION
	attempt_opening_mode = &""
	attempt_opening_phase = 0
	attempt_opening_completed = false
	attempt_opening_officer_completed = false
	attempt_opening_bren_committed = false
	pending_augment_pick = false
	pending_big_choice = false
	attempt_big_choice_source_segment = 0
	attempt_major_choice_id = &""
	attempt_pending_doctrine_stage = &""
	attempt_doctrine_stage_ids.clear()
	attempt_doctrine_rules.clear()
	attempt_doctrine_events.clear()
	attempt_witness_used_segment = 0
	attempt_doctrine_threat_debt = 0.0
	attempt_wardstone_radius_mul = 1.0
	attempt_wardstone_slow_mul = 1.0
	attempt_exit_hold_mul = 1.0

	# A fresh historical attempt begins before Bren commits to the work.
	set_followers(0)

	save_current_profile()

func set_attempt_checkpoint(pos: Vector2) -> void:
	attempt_checkpoint_pos = pos
	request_autosave()

func has_segment1_milestone(id: StringName) -> bool:
	return attempt_segment1_milestones.has(id)

func record_segment1_milestone(id: StringName) -> bool:
	if id == &"" or attempt_segment1_milestones.has(id):
		return false
	attempt_segment1_milestones.append(id)
	request_autosave()
	return true

func set_segment1_resonance(value: float) -> void:
	attempt_segment1_resonance = clampf(value, 0.0, 1.0)
	request_autosave()

func set_opening_phase(value: int) -> void:
	attempt_opening_phase = maxi(0, value)
	attempt_opening_version = OPENING_SEQUENCE_VERSION
	request_autosave(0.1)

func mark_opening_completed() -> void:
	attempt_opening_completed = true
	attempt_opening_phase = 10
	attempt_opening_version = OPENING_SEQUENCE_VERSION
	opening_full_intro_seen = true
	request_autosave(0.1)

# ==============================
# Respawn cost: exponential + % tax (prevents “infinite hoard”)
# ==============================

func compute_respawn_cost() -> int:
	var seg: int = maxi(1, attempt_segment)
	var deaths: int = maxi(0, attempt_deaths_this_segment)

	var base_cost: int = 10 + (seg - 1) * 2
	var growth: float = 1.7
	var flat_cost: int = int(ceil(float(base_cost) * pow(growth, float(deaths))))

	# Hoard killer: at least 20% of current followers
	var pct_tax: int = int(ceil(float(maxi(followers, 1)) * 0.20))
	return maxi(flat_cost, pct_tax)

func consume_respawn_cost() -> int:
	var cost: int = compute_respawn_cost()
	attempt_deaths_this_segment += 1
	transaction_followers(-cost, &"reconstruction", {"cost": cost, "death_index": attempt_deaths_this_segment}, false, false)
	request_autosave()
	return cost

# ==============================
# Item market values
# ==============================
func compute_item_value(inst: ItemInstance) -> int:
	# Base "market value" used by both buy and sell.
	# Tuned to avoid runaway exponential costs.
	if inst == null or inst.data == null:
		return 0

	var r: int = maxi(0, int(inst.rarity))
	# Uncapped quadratic growth keeps every rarity increase economically
	# meaningful. The constant term prices the item's worth AS MERGE
	# MATERIAL: at 10 the R0->R1 rank-up loop (buy peer, merge, sell) was
	# Follower-positive at high Luck. Invariant (tested): no vendor
	# buy->merge->sell sequence may net Followers.
	var base: float = 26.0 + float(r) * 18.0 + float(r * r) * 2.5

	var q: float = clampf(absf(float(inst.active_pct())), 0.0, 1.0)
	var quality_mul: float = lerpf(0.90, 1.40, q)
	var stat_value: float = 0.0
	if inst.rolled_mods != null:
		stat_value += absf(inst.rolled_mods.max_hp) * 0.45
		stat_value += absf(inst.rolled_mods.armor) * 2.5
		stat_value += absf(inst.rolled_mods.move_speed) * 0.35
		stat_value += absf(inst.rolled_mods.power) * 60.0
		stat_value += absf(inst.rolled_mods.haste) * 50.0
		stat_value += absf(inst.rolled_mods.luck) * 45.0
	var scripted_value: float = maxf(0.0, inst.data.scripted_value_weight)
	var set_mul: float = 1.15 if not inst.data.set_id.is_empty() else 1.0
	var progress_ratio := clampf(float(inst.upgrade_meter), 0.0, 1.0)
	var next_base: float = 10.0 + float(r + 1) * 18.0 + float((r + 1) * (r + 1)) * 2.5
	var progress_value := maxf(0.0, next_base - base) * progress_ratio

	return int(round(((base + progress_value) * quality_mul + stat_value + scripted_value) * set_mul))

func compute_buy_value(inst: ItemInstance) -> int:
	# What the vendor charges (followers).
	var v: int = compute_item_value(inst)
	return maxi(0, int(ceil(float(v) * LuckResolver.buy_multiplier(run_luck))))

func compute_sell_value(inst: ItemInstance) -> int:
	# What the vendor pays you (followers).
	# Keep a spread so "flip for profit" isn't a thing.
	var v: int = compute_item_value(inst)
	return maxi(0, int(floor(float(v) * 0.55 * LuckResolver.sell_multiplier(run_luck))))


func deliver_guaranteed_item(inst: ItemInstance, prefer_equip: bool = true) -> bool:
	if inst == null or inst.data == null:
		return false

	if prefer_equip and run_inventory != null:
		var slot := int(inst.data.equip_slot)
		if slot >= 0 and slot < Inventory.SLOT_COUNT and run_inventory.is_slot_empty(slot):
			run_inventory.set_item(
				slot,
				inst,
				{"type": Inventory.UIOriginType.SCREEN, "pos": Vector2.ZERO}
			)
			if run_inventory.get_at(slot) == inst:
				return true
		# Same item already equipped: feed the reward into the equipped copy
		# instead of stranding a frozen duplicate stack in the bag.
		if slot >= 0 and slot < Inventory.SLOT_COUNT:
			var equipped := run_inventory.get_at(slot) as ItemInstance
			if equipped != null and equipped.data != null \
			and not equipped.locked and not inst.locked \
			and equipped.data.id == inst.data.id \
			and int(equipped.polarity) == int(inst.polarity):
				if run_inventory.add_or_feed(inst, {"type": Inventory.UIOriginType.SCREEN, "pos": Vector2.ZERO}):
					return true

	if run_bag != null and run_bag.add_instance(inst):
		return true

	if meta_stash == null:
		meta_stash = StashInventory.new()
	var stash_slot := meta_stash.first_empty_slot()
	if stash_slot >= 0:
		meta_stash.set_item(stash_slot, inst)
		request_autosave()
		return true

	var current_scene := get_tree().current_scene
	if current_scene != null:
		var spawner := current_scene.find_child("WorldDropSpawner", true, false)
		if spawner != null and spawner.has_method("spawn_protected"):
			return bool(spawner.call("spawn_protected", inst))

	return false

# ----------------------------
# Dev helpers
# ----------------------------
func dev_grant_test_augments() -> void:
	# Grants a small owned library for UI testing (>=4), ensuring at least one active augment.
	load_augments_from_dir("res://data/augments")
	init_permanent_augments()
	owned_augment_ids = []
	var all: Array[StringName] = []
	for k in augment_db.keys():
		all.append(StringName(str(k)))
	all.shuffle()

	# Ensure one active augment (prefer Hex Blink if present)
	var active_id: StringName = &""
	# Prefer a known active augment if present.
	if augment_db.has(&"augment_blink_hex"):
		active_id = &"augment_blink_hex"
	elif augment_db.has(&"augment_reflect_shield"):
		active_id = &"augment_reflect_shield"
	elif augment_db.has(&"augment_summon_spiderlings"):
		active_id = &"augment_summon_spiderlings"
	else:
		# brute: scan for any augment whose effect scene instances have 'active_action'
		for k2 in augment_db.keys():
			var ad: AugmentData = augment_db.get(k2, null) as AugmentData
			if ad == null:
				continue
			var is_active := false
			for scn in ad.effect_scenes:
				if scn == null:
					continue
				var inst: Node = scn.instantiate()
				if inst != null and inst.get("active_action") != null:
					is_active = true
				inst.free()
				if is_active: break
			if is_active:
				active_id = ad.id
				break

	if active_id != StringName():
		add_owned_augment(active_id)

	# Fill up to 4 owned
	for k3 in all:
		if owned_augment_ids.size() >= 4:
			break
		var sid: StringName = k3
		if sid == StringName():
			continue
		if owned_augment_ids.has(sid):
			continue
		add_owned_augment(sid)

	# Equip first 3 owned
	for i in range(3):
		permanent_augment_ids[i] = (owned_augment_ids[i] if i < owned_augment_ids.size() else StringName())

	permanent_augments_changed.emit(permanent_augment_ids)
	request_autosave()

# ---------------- Hub sell marks ----------------
func toggle_hub_sell_mark(kind: StringName, slot: int) -> void:
	if kind == &"bag":
		if hub_sell_marks_bag.has(slot):
			hub_sell_marks_bag.erase(slot)
		else:
			hub_sell_marks_bag[slot] = true
	elif kind == &"stash":
		if hub_sell_marks_stash.has(slot):
			hub_sell_marks_stash.erase(slot)
		else:
			hub_sell_marks_stash[slot] = true

func is_hub_sell_marked(kind: StringName, slot: int) -> bool:
	if kind == &"bag":
		return hub_sell_marks_bag.has(slot)
	if kind == &"stash":
		return hub_sell_marks_stash.has(slot)
	return false
