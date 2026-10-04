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
const _BUILD_INFO_SCRIPT := preload("res://core/systems/telemetry/BuildInfo.gd")

# -- Scenes
const PATH_MAIN_MENU := UI_DIR + "/screens/MainMenu.tscn"
const PATH_SAVE_SELECT := UI_DIR + "/screens/SaveSelect.tscn"
const PATH_BASE := UI_DIR + "/screens/base.tscn"
const PATH_GAME := SCENES_DIR + "/game.tscn"
const PATH_HUB_SHOP := UI_DIR + "/screens/HubShop.tscn"
## The walkable between-segment hub (2026-09-25 handoff, Phase 5); the old
## HubShop screen remains as its embedded trade panel.
const PATH_HUB_WORLD := "res://scenes/hub/HubWorld.tscn"
# v3: story-pass layout - admissions wing added, full-opening start moved to
# the street entrance. Stale checkpoints and spatial milestones reset.
const SEGMENT1_LAYOUT_VERSION: int = 3
# The authored run shape (integration pass 2026-09-26): segment milestones
# were bare `== 5` / `== 10` literals in the proc-gen; the run itself never
# hard-stops (reward cadence extends past 9 on purpose), so these two are the
# ONLY authored milestones and every reader must use them by name.
const MINIBOSS_SEGMENT: int = 5
const FINAL_SEGMENT: int = 10
# v2: ADMISSION phase inserted after HISTORICAL; saved phase ints >= 2 shift.
const OPENING_SEQUENCE_VERSION: int = 2

const VFX_DIR := "res://assets/vfx/world/augments"
const PATH_VFX_STAMINA_AURA := VFX_DIR + "/VFX_StaminaCoreAura.tscn"

# ============================================================
# Signals
# ============================================================

signal followers_changed(value: int)
signal balance_attempt_boundary(reason: StringName)
signal balance_segment_completed(segment: int)
signal balance_scene_requested(path: String)
signal balance_transaction(before: int, change: int, after: int, reason: StringName, context: Dictionary)
signal followers_transaction(old_value: int, change: int, new_value: int, reason: StringName, context: Dictionary, show_feedback: bool, allow_aggregate: bool)
signal permanent_augments_changed(ids: Array[StringName])
## The profile reached a Grimoire entry for the first time (Grimoire.gd keys).
signal grimoire_discovered(key: String)

## Either of the two world positions the HUD's edge arrow points at has moved,
## appeared or gone. They are plain writes from the segment builders, the
## objectives and the Exit Rite - the rite rewrites its own every frame - so the
## signal is gated on the value actually changing. HudGateOverlayController
## sleeps while both are Vector2.INF and this is what wakes it.
signal hud_target_positions_changed()


# ============================================================
# Run selections (chosen at start of run)
# ============================================================

# Level / segment helpers
var exit_gate_pos: Vector2 = Vector2.INF:
	set(value):
		if exit_gate_pos == value:
			return
		exit_gate_pos = value
		hud_target_positions_changed.emit()
var objective_target_pos: Vector2 = Vector2.INF:
	set(value):
		if objective_target_pos == value:
			return
		objective_target_pos = value
		hud_target_positions_changed.emit()

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
# Advancement-tree prototype fixture: enemies spawn with this much more HP so
# the execute band and chain lengths can be read (the review asks for x3).
# Applies to enemies spawned after the value changes; never saved.
var debug_enemy_hp_scale: float = 1.0
# The review asks that mature routes be played with Revelations disabled
# first, so ordinary fighting has to carry the chaos. Never saved.
var debug_ascension_revelations_enabled: bool = true
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
## Manifestation imprints: rules dissolved by merges this attempt, kept for
## the Hub's imprinter (design note 2026-09-19-manifestation-imprints).
const IMPRINT_CAP := 8
var attempt_imprints: Array[StringName] = []
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
## The V4 advancement tree's run state (ownership, opened Cores, equipment,
## banked Evolution claims); a plain Dictionary so it saves as-is. Rules live
## in AscensionLedger; the combat layer reads it through ascension_ledger().
var attempt_ascension: Dictionary = {}
var _ascension_ledger: AscensionLedger = null

# Attempt-scoped augmentation levels (StringName -> int); defaults to 1
var attempt_augment_levels: Dictionary = {}

# Run rules/mutations (StringName -> Variant)
var attempt_mutations: Dictionary = {}

# Additive attempt stats
var attempt_stat_delta: StatDelta = null

# Bindings and Transcendence (docs/design/2026-10-03-bindings-and-theses.md):
# which equipped augments have Transcended this attempt (String id -> true),
# the pending Binding's dealt cards and how often it was recast. The offer is
# kept so a reload cannot redeal it for free.
var attempt_augment_transcended: Dictionary = {}
var attempt_binding_offer: Array = []
var attempt_binding_recasts: int = 0
## Consecrations paid this Binding (follower economy audit P6): each raises
## one card a grade and the next costs one step more. Kept like the Recast
## count, so a reload cannot reset the price.
var attempt_binding_consecrations: int = 0

# Duos, Facets, the Reliquary and the Burden
# (docs/design/2026-10-03-duos-facets-and-the-reliquary.md): active Duos
# (String duo id -> true), chosen Facets (String augment id -> String facet
# id), Corruption outcomes (String augment id -> String outcome), whether the
# pending Binding was Burdened, Vouchers bought this run and the Hub's
# current Voucher offer with the attempt_segment it was dealt for.
var attempt_augment_duos: Dictionary = {}
var attempt_augment_facets: Dictionary = {}
var attempt_augment_corruptions: Dictionary = {}
var attempt_binding_burdened: bool = false
var attempt_vouchers: Array = []
var attempt_voucher_offer: Array = []
var attempt_voucher_segment: int = 0
## Profile-wide (it survives death): every Grimoire key the profile reached.
var grimoire_entries: Array[String] = []
var _loaded_dice_last_ms: int = -1000000


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
# Gambler's Rite (NEG archetype A7): per-segment registry of distinct NEG base
# items found, the Resonance banked from them and the Followers won. Reset with
# the segment and the attempt; not saved (a reload mid-segment forgives it).
var attempt_gambler_seen: Dictionary = {}
var attempt_gambler_resonance: float = 0.0
var attempt_gambler_followers: int = 0

var _followers: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var vfx_stamina_aura_scene: PackedScene

## The Congregation (follower economy audit 2026-10-04, P5): every Follower
## this attempt RECRUITED, which spending never lowers. Followers are the
## run's money, but the movement is its people: the wallet is the stock you
## spend, the congregation is the crowd you built, and belief's cap and the
## Hub's crowd follow the congregation, so spending what you recruited
## shrinks neither (the research pass's "stock vs flow"; the crowd's one
## exception, sale proceeds, is at congregation_crowd_basis). Saved with the
## run; reset with the attempt.
var attempt_congregation: int = 0
## The wallet reasons that are recruitment. Trades, undo, refunds, Abstain,
## syncs, legacy calls and developer grants are not: selling and undoing could
## otherwise pump the count without a single new believer.
const CONGREGATION_REASONS := {
	&"combat_influence": true, &"secondary_objective": true, &"boss_victory": true,
	&"miniboss_victory": true, &"mass_conversion": true, &"loaded_dice": true,
	&"gamblers_rite": true, &"bren_first_follower": true, &"assistant_commitment": true,
}
## Overtime's fraction of a kill reward not yet paid as a whole Follower (P1).
## In memory only: it is always below one Follower. Reset with the segment,
## the attempt and every loaded save, so one slot's fraction never pays out
## in another (review 2026-10-04).
var _kill_reward_carry: float = 0.0

# ============================================================
# Lifecycle
# ============================================================

func _ready() -> void:
	# The Gambler's Rite listens to item operations; connected after every
	# autoload exists.
	_connect_gambler_listener.call_deferred()
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
	# Balance revision 2 item curves: validated once, loudly, before any
	# instance derives stats. A rejected file leaves the legacy formula.
	if not ItemScaling.load_profiles():
		push_warning("ItemScaling: item profiles rejected; items use the legacy potency formula")
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

var _loading_scrim: LoadingScrim = null


## The card shown over a scene change; created on first use.
func loading_scrim() -> LoadingScrim:
	if _loading_scrim == null or not is_instance_valid(_loading_scrim):
		_loading_scrim = LoadingScrim.new()
		_loading_scrim.name = "LoadingScrim"
		add_child(_loading_scrim)
	return _loading_scrim


func _scene_title(path: String) -> String:
	match path:
		PATH_GAME:
			return "SEGMENT %d" % maxi(1, attempt_segment)
		PATH_HUB_SHOP, PATH_HUB_WORLD:
			return "THE HUB"
		PATH_BASE:
			return "BASE"
		_:
			return ""


func goto_scene(path: String) -> void:
	balance_scene_requested.emit(path)
	# Scene changes are the natural safe point for any deferred combat autosave.
	flush_pending_save()
	# Building the game scene blocks for most of a second; show the card and
	# let it render before the block, so the stall reads as a transition.
	var scrim := loading_scrim()
	scrim.show_for(_scene_title(path), get_tree().current_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	if PerformanceFlightRecorder != null and PerformanceFlightRecorder.has_method("note_scene_change"):
		PerformanceFlightRecorder.note_scene_change(path.get_file().get_basename())
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("[Global] scene change failed: path=%s err=%s" % [path, error_string(err)])

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
	goto_scene(PATH_HUB_WORLD)

func goto_resume() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("to_game")
	# Resume current attempt if one exists; otherwise go to Base.
	if SaveManager == null or SaveManager.current_save == null:
		goto_save_select()
		return
	if SaveManager.current_save.attempt_active:
		goto_scene(resume_scene_for(SaveManager.current_save))
	else:
		goto_base()


## The scene an active attempt resumes into. Pure so tests exercise the real
## mapping: empty and legacy full-screen-shop targets resolve to the walkable
## hub, its compatible successor, preserving the same pending state.
func resume_scene_for(save: SaveData) -> String:
	var path: String = save.attempt_resume_scene
	if path == "" or path == PATH_HUB_SHOP:
		return PATH_HUB_WORLD
	return path


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
		# A balanced buy/sell exchange has economic activity without a wallet
		# change. Preserve the existing feedback/gameplay signal behavior.
		if reason == &"trade" and (int(context.get("buy_value", 0)) > 0 or int(context.get("sell_value", 0)) > 0):
			balance_transaction.emit(old_value, 0, new_value, reason, context)
		return {"old": old_value, "change": 0, "new": new_value, "suppressed": false}
	_followers = new_value
	if actual_change > 0 and CONGREGATION_REASONS.has(reason):
		attempt_congregation += actual_change
	balance_transaction.emit(old_value, actual_change, new_value, reason, context)
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
	_run_taught.clear()
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
	attempt_imprints.clear()
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
## Keeps a dissolved rule as an imprint (newest last, oldest forgotten past
## IMPRINT_CAP, one of each). Returns true when it was new.
func store_imprint(imprint_id: StringName) -> bool:
	if imprint_id == StringName() or ManifestationCatalog.get_def(imprint_id) == null:
		return false
	if attempt_imprints.has(imprint_id):
		return false
	attempt_imprints.append(imprint_id)
	while attempt_imprints.size() > IMPRINT_CAP:
		attempt_imprints.pop_front()
	if RunEvents != null:
		RunEvents.imprint_stored.emit(imprint_id)
	request_autosave()
	return true


func take_imprint(imprint_id: StringName) -> bool:
	if not attempt_imprints.has(imprint_id):
		return false
	attempt_imprints.erase(imprint_id)
	request_autosave()
	return true


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


## The segment's rarity soft cap for a source of the given rank: rarity
## promotions at or above it run at the context's over-cap chance.
func rarity_soft_cap_for(source_rank: int = 0) -> int:
	return floori(float(maxi(1, attempt_segment)) / 3.0) + source_rank + 1


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
	# One cap for every source (loot loop pass L4): an authored band above it
	# keeps its minimum but promotes at the over-cap chance. The old
	# max(rarity_max + 1, ...) exempted any source that asked for a high band.
	context.rarity_soft_cap = rarity_soft_cap_for(source_rank)
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
	# the Followers held. sqrt keeps early followers meaningful and hoarding
	# from snowballing: 25 -> +5%, 100 -> +10%, up to the cap below.
	return minf(belief_power_cap(), 0.01 * sqrt(float(maxi(0, followers))))


## Belief's cap grows with the Congregation, not the wallet (follower economy
## audit 2026-10-04, P5): +15% until 2,500 recruited, then +5% for every
## doubling, at most +30% (20,000 recruited; the audit's +35% was trimmed to
## limit late Power creep). Filling it still takes Followers held, (100 x cap)
## squared: 900 for +30%. Before this the cap sat at +15% from the first 225
## Followers held, about half a minute into segment 2, for the rest of the run.
const BELIEF_CAP_BASE := 0.15
const BELIEF_CAP_PER_DOUBLING := 0.05
const BELIEF_CAP_KNEE := 2500.0
const BELIEF_CAP_CONGREGATION_MAX := 0.30
## Prophet (the Transcended Cult of Personality) and Census of Souls add to
## the congregation's cap instead of replacing it with 0.30 / 0.40.
const BELIEF_CAP_PROPHET := 0.15
const BELIEF_CAP_CENSUS := 0.20
const BELIEF_CAP_CEILING := 0.60


func belief_congregation_cap(congregation: int = -1) -> float:
	var recruited := attempt_congregation if congregation < 0 else congregation
	var doublings := log(maxf(1.0, float(recruited) / BELIEF_CAP_KNEE)) / log(2.0)
	return clampf(BELIEF_CAP_BASE + BELIEF_CAP_PER_DOUBLING * doublings, BELIEF_CAP_BASE, BELIEF_CAP_CONGREGATION_MAX)


func belief_power_cap() -> float:
	var cap := belief_congregation_cap()
	if is_augment_transcended(&"augment_cult_of_personality") and permanent_augment_ids.has(&"augment_cult_of_personality"):
		cap += BELIEF_CAP_PROPHET
	var census := float(get_doctrine_rule(&"belief_power_cap_bonus", 0.0))
	# A run saved before the Congregation carries Census of Souls as the old
	# absolute cap rule (0.40); it keeps the Doctrine's lift, not the number.
	if census <= 0.0 and float(get_doctrine_rule(&"belief_power_cap", 0.0)) > 0.0:
		census = BELIEF_CAP_CENSUS
	return minf(cap + maxf(0.0, census), BELIEF_CAP_CEILING)


## What the Hub's crowd is sized from (HubCrowd): the congregation, or the
## Followers held when they are more (a sale's proceeds, a pre-Congregation
## save). Spending what was recruited never shrinks the crowd between
## visits; the people a sale drew stay only while the wallet holds them, so
## once the proceeds are spent the next Hub sizes from the congregation and
## what is left (review 2026-10-04: this used to promise more).
func congregation_crowd_basis() -> int:
	return maxi(attempt_congregation, followers)

# ============================================================
# Run Sheet stat ledger
# ============================================================

## Every contribution of the stat pass, in order, as {label, stat, before,
## after} rows - so the Run Sheet can answer "why is this stat this high?"
## with the numbers the pass itself used rather than a second derivation.
## Recorded, never recomputed: the pass opens the ledger on its base copy with
## stat_ledger_begin() and calls stat_ledger_step() after each contribution;
## the helper diffs the Stats it is handed against the previous step, so a
## multiplicative step (a slot roll, the Doctrine's Max HP price) records the
## same before/after shape as a flat one. The Global-owned steps below record
## themselves, one row per augment rather than one row per call.
const STAT_LEDGER_FIELDS: Array[StringName] = [
	&"max_hp", &"armor", &"move_speed", &"power", &"haste", &"luck",
]
var last_stat_ledger: Array[Dictionary] = []

## "Teach it once per run" for every first-sight line (elite modifiers, the
## healing lock, the rite's distortion, a ritual interference). Nodes that
## own those lines - the spawner, the player, an ExitRite, the director - are
## re-instantiated per segment, so a flag on them repeated the lesson every
## segment; the run is the unit, and this is the run's registry.
var _run_taught: Dictionary = {}


## True exactly once per run per key; the caller shows the line then.
func teach_once(key: StringName) -> bool:
	if key == StringName() or _run_taught.has(key):
		return false
	_run_taught[key] = true
	return true


func was_taught(key: StringName) -> bool:
	return _run_taught.has(key)


## Starts the lessons over; reset_run_systems calls it, tests call it directly.
func reset_teaching() -> void:
	_run_taught.clear()
var _stat_ledger_prev: Stats = null


func stat_ledger_begin(s: Stats) -> void:
	last_stat_ledger = []
	_stat_ledger_prev = s.copy() if s != null else null


## Appends one row per stat the step changed and moves the baseline. A no-op
## until a pass has opened the ledger, so a caller outside the pass (a test,
## the dev console) applying one step on its own leaves it untouched.
func stat_ledger_step(label: String, s: Stats) -> void:
	if s == null or _stat_ledger_prev == null:
		return
	for field in STAT_LEDGER_FIELDS:
		var before := float(_stat_ledger_prev.get(field))
		var after := float(s.get(field))
		if is_equal_approx(before, after):
			continue
		last_stat_ledger.append({"label": label, "stat": field, "before": before, "after": after})
	_stat_ledger_prev = s.copy()

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
		stat_ledger_step("%s Lv.%d" % [augment_display_name(id).to_upper(), lvl], s)


# ============================================================
# Bindings, Transcendence and the Doctrine families
# (docs/design/2026-10-03-bindings-and-theses.md)
# ============================================================

## Everything a choice wrote into this attempt, cleared together. An
## in-session restart used to keep the last run's taken Doctrines, stat
## delta, augment levels and mutations: the old taken ids then emptied the
## next seg-3 offer and the Hub's departure stayed blocked.
func _reset_attempt_choice_state() -> void:
	attempt_major_choice_offer_ids.clear()
	attempt_major_choice_taken_ids.clear()
	attempt_big_choice_source_segment = 0
	attempt_stat_delta = null
	attempt_augment_levels = {}
	attempt_mutations = {}
	attempt_augment_transcended = {}
	attempt_binding_offer = []
	attempt_binding_recasts = 0
	attempt_binding_consecrations = 0
	attempt_augment_duos = {}
	attempt_augment_facets = {}
	attempt_augment_corruptions = {}
	attempt_binding_burdened = false
	attempt_vouchers = []
	attempt_voucher_offer = []
	attempt_voucher_segment = 0


## The completed segment a pending Binding belongs to: it shows as the next
## segment starts, so it is one behind attempt_segment (the intro pick in
## segment 1 counts as 1).
func binding_segment() -> int:
	return maxi(1, attempt_segment - 1)


## Recast and Abstain exist from the second Binding on: the intro pick is
## how a fresh profile gets its first augment at all.
func binding_can_trade() -> bool:
	return attempt_segment >= 2


func binding_card_count() -> int:
	var count := 3 + int(get_doctrine_rule(&"binding_extra_cards", 0))
	if doctrine_has_thesis(&"circuit"):
		count += 1
	if has_voucher(Vouchers.FOURTH_SEAL):
		count += 1
	return clampi(count, 3, 5)


func binding_grade_multiplier() -> float:
	var mul := maxf(0.0, float(get_doctrine_rule(&"binding_grade_mul", 1.0)))
	if doctrine_has_thesis(&"archive"):
		mul *= 1.5
	if has_voucher(Vouchers.GILDED_INK):
		mul *= Vouchers.GILDED_INK_MUL
	return mul


## The Archive Canon deals nothing below Gilded.
func binding_grade_floor() -> int:
	return 1 if doctrine_has_canon(&"archive") else 0


func binding_free_recasts() -> int:
	return maxi(0, int(get_doctrine_rule(&"binding_free_recasts", 0))) + (1 if doctrine_has_thesis(&"archive") else 0)


## Followers the next Recast of the pending Binding costs (0 while a free
## one remains).
func binding_recast_cost() -> int:
	var free := binding_free_recasts()
	if attempt_binding_recasts < free:
		return 0
	var mul := maxf(0.0, float(get_doctrine_rule(&"binding_recast_mul", 1.0)))
	if has_voucher(Vouchers.RECAST_INDULGENCE):
		mul *= Vouchers.RECAST_MUL
	return AugmentScaling.recast_cost(binding_segment(), attempt_binding_recasts - free, mul)


func binding_abstain_reward() -> int:
	var mul := maxf(0.0, float(get_doctrine_rule(&"binding_abstain_mul", 1.0)))
	if doctrine_has_canon(&"archive"):
		mul *= 2.0
	if has_voucher(Vouchers.TITHE_SERMON):
		mul *= Vouchers.TITHE_MUL
	return AugmentScaling.abstain_reward(binding_segment(), mul)


## What AugmentBinding.build_offer deals from, read from this attempt.
func binding_context() -> Dictionary:
	init_permanent_augments()
	var pool: Array = []
	for id in augment_db.keys():
		pool.append(StringName(id))
	pool.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var ready_ids: Array = []
	for id in permanent_augment_ids:
		if id != StringName() and augment_transcend_ready(id):
			ready_ids.append(id)
	ready_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return get_augment_level(a) > get_augment_level(b))
	var fresh_profile := true
	for id in permanent_augment_ids:
		if id != StringName():
			fresh_profile = false
	return {
		"equipped": permanent_augment_ids.duplicate(),
		"locked": [is_augment_slot_locked(0), is_augment_slot_locked(1), is_augment_slot_locked(2)],
		"pool": pool,
		"transcend_ready": ready_ids,
		"segment": binding_segment(),
		"luck": run_luck,
		"grade_mul": binding_grade_multiplier(),
		"grade_floor": binding_grade_floor(),
		"card_count": binding_card_count(),
		"neg_guarantee": fresh_profile,
		"duo_ready": duos_ready(),
		"facet_ready": facets_ready(),
	}


## The pending Binding's cards, dealt once and kept (a reload shows the same
## cards; only a paid Recast redeals).
func binding_offer() -> Array:
	if not pending_augment_pick:
		return []
	if attempt_binding_offer.is_empty():
		_deal_binding_offer()
	return attempt_binding_offer.duplicate(true)


func _deal_binding_offer() -> void:
	var rng := RandomNumberGenerator.new()
	var seed_val: int = attempt_world_seed if attempt_world_seed != 0 else _rng.randi()
	rng.seed = int(seed_val) ^ (binding_segment() * 0x2545F491) ^ ((attempt_binding_recasts + 1) * 0x9E3779B9) ^ 0xB1D
	attempt_binding_offer = AugmentBinding.build_offer(binding_context(), rng)
	# A Burden covers the whole Binding: its price is already paid, so a
	# Recast deals the new table raised too instead of throwing the raise away.
	if attempt_binding_burdened:
		attempt_binding_offer = AugmentRites.burdened_offer(attempt_binding_offer)
	request_autosave()


## Pays for and deals a new offer. False when it cannot (no Binding, the
## intro pick, too few Followers).
func binding_recast() -> bool:
	if not pending_augment_pick or not binding_can_trade():
		return false
	var cost := binding_recast_cost()
	if cost > 0:
		if followers < cost:
			return false
		var paid := transaction_followers(-cost, &"binding_recast", {"segment": binding_segment()}, true, false)
		if int(paid.get("change", 0)) != -cost:
			return false
	attempt_binding_recasts += 1
	attempt_binding_offer.clear()
	_deal_binding_offer()
	return true


## Followers the next Consecration of the pending Binding costs (P6).
func binding_consecrate_cost() -> int:
	return AugmentRites.consecrate_cost(binding_segment(), attempt_binding_consecrations)


## Whether card `index` of the pending Binding can be Consecrated: from the
## second Binding on (like Recast), and only a graded card below Apocryphal
## whose next grade still adds a level under the Lv.20 cap (review
## 2026-10-04: a capped augment's RANK card was charged for nothing).
func binding_can_consecrate(index: int) -> bool:
	if not pending_augment_pick or not binding_can_trade():
		return false
	var offer := binding_offer()
	if index < 0 or index >= offer.size():
		return false
	var card: Dictionary = offer[index]
	return AugmentRites.consecrate_adds_level(card, get_augment_level(StringName(String(card.get("id", "")))))


## Whether the pending Binding's table holds a card Consecrate raised: a
## Recast deals new cards and throws that paid grade away, so the Binding
## screen asks twice before one (review 2026-10-04).
func binding_offer_consecrated() -> bool:
	for card in attempt_binding_offer:
		if card is Dictionary and bool((card as Dictionary).get(AugmentRites.CONSECRATED_KEY, false)):
			return true
	return false


## Consecrate: pays Followers to raise card `index` one grade, the paid
## counterpart of the Burden (follower economy audit 2026-10-04, P6). The
## raised card is kept with the offer, marked; a Recast deals new cards and
## does not carry it, but the price step stays. False when it cannot be paid
## for.
func binding_consecrate(index: int) -> bool:
	if not binding_can_consecrate(index):
		return false
	var cost := binding_consecrate_cost()
	if followers < cost:
		return false
	var paid := transaction_followers(-cost, &"binding_consecrate", {"segment": binding_segment(), "card": index}, true, false)
	if int(paid.get("change", 0)) != -cost:
		return false
	attempt_binding_offer = AugmentRites.consecrated_offer(attempt_binding_offer, index)
	attempt_binding_consecrations += 1
	request_autosave()
	return true


## Takes Followers instead of a card. Returns what was paid, or -1 when the
## Binding cannot be abstained from.
func binding_abstain() -> int:
	if not pending_augment_pick or not binding_can_trade():
		return -1
	var reward := binding_abstain_reward()
	if reward > 0:
		transaction_followers(reward, &"binding_abstain", {"segment": binding_segment()}, true, false)
	_close_binding()
	return reward


## Resolves one dealt card. A SWAP needs `slot` (an unlocked equipped slot);
## the augment it replaces keeps its run level in the library. A FACET needs
## `facet`, one of the augment's two Facet ids.
func apply_binding_card(card: Dictionary, slot: int = -1, facet: StringName = &"") -> bool:
	if not pending_augment_pick:
		return false
	var dealt: Dictionary = {}
	for offered in attempt_binding_offer:
		if String(offered.get("kind", "")) == String(card.get("kind", "")) and String(offered.get("id", "")) == String(card.get("id", "")):
			dealt = offered
			break
	if dealt.is_empty():
		return false
	var id := StringName(String(dealt["id"]))
	init_permanent_augments()
	if String(dealt["kind"]) == AugmentBinding.KIND_DUO:
		if not AugmentDuos.is_duo(id):
			return false
		for member in AugmentDuos.members(id):
			if not permanent_augment_ids.has(member):
				return false
		attempt_augment_duos[String(id)] = true
		grimoire_note(Grimoire.duo_key(id))
		_close_binding()
		permanent_augments_changed.emit(permanent_augment_ids)
		return true
	if not augment_db.has(id):
		return false
	if String(dealt["kind"]) == AugmentBinding.KIND_FACET:
		if not permanent_augment_ids.has(id) or attempt_augment_facets.has(String(id)) or not AugmentFacets.is_option(id, facet):
			return false
		attempt_augment_facets[String(id)] = String(facet)
		grimoire_note(Grimoire.facet_key(id, facet))
		_close_binding()
		permanent_augments_changed.emit(permanent_augment_ids)
		return true
	var target_level := AugmentBinding.resulting_level(dealt, get_augment_level(id))
	match String(dealt["kind"]):
		AugmentBinding.KIND_TRANSCEND:
			if not permanent_augment_ids.has(id):
				return false
			attempt_augment_transcended[String(id)] = true
			grimoire_note(Grimoire.transcend_key(id))
		AugmentBinding.KIND_RANK:
			if not permanent_augment_ids.has(id):
				return false
		AugmentBinding.KIND_NEW:
			var empty := permanent_augment_ids.find(StringName())
			if empty == -1:
				return false
			set_permanent_augment(empty, id)
		AugmentBinding.KIND_SWAP:
			if slot < 0 or slot >= 3 or is_augment_slot_locked(slot) or permanent_augment_ids.has(id):
				return false
			set_permanent_augment(slot, id)
		_:
			return false
	set_augment_level(id, target_level)
	_close_binding()
	permanent_augments_changed.emit(permanent_augment_ids)
	return true


func _close_binding() -> void:
	pending_augment_pick = false
	attempt_binding_offer.clear()
	attempt_binding_recasts = 0
	attempt_binding_consecrations = 0
	attempt_binding_burdened = false
	request_autosave()


func is_augment_transcended(id: StringName) -> bool:
	return attempt_augment_transcended.has(String(id))


## The name every surface shows: the Transcended name once it has turned.
func augment_display_name(id: StringName) -> String:
	if is_augment_transcended(id):
		var turned := AugmentScaling.transcended_name(id)
		if turned != "":
			return turned
	var data := augment_db.get(id, null) as AugmentData
	return data.display_name if data != null else String(id)


## Lv.5, or Lv.4 under Liturgy of Overclock or the Perfected Engine; the
## Catalyst Primer voucher takes one more off, never below Lv.3.
func augment_transcend_level() -> int:
	var level := clampi(int(get_doctrine_rule(&"augment_transcend_level", AugmentScaling.TRANSCEND_LEVEL)), 1, AugmentScaling.TRANSCEND_LEVEL)
	if has_voucher(Vouchers.CATALYST_PRIMER):
		level = maxi(3, level - 1)
	return level


## What the catalysts are judged against (AugmentScaling.catalyst_holds).
func augment_catalyst_context() -> Dictionary:
	var stats := {"haste": 0.0, "move_speed": 0.0, "armor": 0.0}
	var tree := get_tree()
	var player: Node = tree.get_first_node_in_group(&"player") if tree != null else null
	if player != null:
		var s: Variant = player.get("stats")
		if s is Stats:
			stats = {"haste": (s as Stats).haste, "move_speed": (s as Stats).move_speed, "armor": (s as Stats).armor}
	var disciplines := {}
	if not attempt_ascension.is_empty():
		var ledger := ascension_ledger()
		for node_id in ledger.owned_ids():
			var code := ledger.db.discipline_of(String(node_id))
			if code != "":
				disciplines[code] = true
	var curses := 0
	if run_inventory != null:
		curses = BurdenResolver.resolve(run_inventory, permanent_augment_ids).neg_count
	return {
		"equipped": permanent_augment_ids.duplicate(),
		"stats": stats,
		"disciplines": disciplines,
		"families": doctrine_family_counts(),
		"curses": curses,
		"followers": followers,
		"waive": doctrine_has_canon(&"circuit") or bool(get_doctrine_rule(&"augment_catalyst_waived", false)),
	}


func augment_catalyst_holds(id: StringName) -> bool:
	return AugmentScaling.catalyst_holds(id, augment_catalyst_context())


## Equipped, not yet turned, at the Transcendence level, catalyst held.
func augment_transcend_ready(id: StringName) -> bool:
	if id == StringName() or not AugmentScaling.can_transcend(id) or is_augment_transcended(id):
		return false
	if not permanent_augment_ids.has(id) or get_augment_level(id) < augment_transcend_level():
		return false
	return augment_catalyst_holds(id)


## Transcends every equipped augment that can turn, ignoring level and
## catalyst (The Engine Prays). Returns how many turned.
func transcend_equipped_augments() -> int:
	var turned := 0
	for id in permanent_augment_ids:
		if id != StringName() and AugmentScaling.can_transcend(id) and not is_augment_transcended(id):
			attempt_augment_transcended[String(id)] = true
			grimoire_note(Grimoire.transcend_key(id))
			turned += 1
	if turned > 0:
		permanent_augments_changed.emit(permanent_augment_ids)
		request_autosave()
	return turned


## Augment damage from the Doctrine: the augment_damage_mul rule (Choir,
## Twin Seal, The Engine Prays) times the Circuit Thesis and Canon.
func augment_damage_multiplier() -> float:
	var mul := maxf(0.0, float(get_doctrine_rule(&"augment_damage_mul", 1.0)))
	var circuit := doctrine_family_count(&"circuit")
	if circuit >= 2:
		mul *= 1.2
	if circuit >= 3:
		mul *= 1.5
	return mul


## How many inscribed Doctrines each family holds this attempt.
func doctrine_family_counts() -> Dictionary:
	var counts := {}
	if major_choice_db == null:
		return counts
	for stage in attempt_doctrine_stage_ids:
		var definition := major_choice_db.get_def(StringName(str(attempt_doctrine_stage_ids[stage])))
		if definition != null and definition.family_id != StringName():
			counts[definition.family_id] = int(counts.get(definition.family_id, 0)) + 1
	return counts


func doctrine_family_count(family: StringName) -> int:
	return int(doctrine_family_counts().get(family, 0))


## Two Doctrines of one family: its Thesis.
func doctrine_has_thesis(family: StringName) -> bool:
	return doctrine_family_count(family) >= 2


## Three: its Canon.
func doctrine_has_canon(family: StringName) -> bool:
	return doctrine_family_count(family) >= 3


## Whether a Doctrine stage still has an untaken plate to show, so a stage
## (an Apocrypha late in a long run) never opens an empty screen that would
## hold the Hub's departure forever.
func doctrine_stage_has_plates(stage_id: StringName) -> bool:
	if major_choice_db == null:
		return false
	var any_stage := is_apocrypha_stage(stage_id)
	for definition in major_choice_db.defs:
		if definition == null or not definition.is_doctrine_complete():
			continue
		if not any_stage and definition.stage != stage_id:
			continue
		if definition.unique_per_attempt and attempt_major_choice_taken_ids.has(definition.id):
			continue
		return true
	return false


## Extra Followers one kill recruits on top of its base reward: Cult of
## Personality (Prophet doubles the chance and pays two) and Census of
## Souls. Both kill paths (EnemyLifecycle, EnemyCombatService) call this.
func bonus_kill_followers() -> int:
	var extra := 0
	if permanent_augment_ids.has(&"augment_cult_of_personality"):
		var level := get_augment_level(&"augment_cult_of_personality")
		var chance := 0.10 + 0.05 * float(level - 1) + LuckResolver.extra_follower_chance(run_luck)
		var prophet := is_augment_transcended(&"augment_cult_of_personality")
		if prophet:
			# Prophet doubles the chance; its cap keeps one kill in ten plain.
			chance = minf(0.9, chance * 2.0)
		if _rng.randf() < chance:
			extra += 2 if prophet else 1
	var census := float(get_doctrine_rule(&"kill_follower_chance", 0.0))
	if census > 0.0 and _rng.randf() < census:
		extra += 1
	return extra


## The one kill-reward settlement both death paths use (EnemyLifecycle for
## actors, EnemyCombatService for data-only proxies), so they cannot drift
## apart again (follower economy audit 2026-10-04, P1). Returns the whole
## Followers to pay now; 0 means pay nothing.
## - An enemy authored at 0 (Summoned Minions, the opening's actors) pays 0:
##   no Luck, Cult, Census or elite top-up rides on a body worth nothing. The
##   actor path used to floor every kill at 1 (90 minions paid 90 Followers in
##   the one organic human capture).
## - Overtime's multiplier is a fraction with a running carry, not a per-kill
##   round floored at 1: a 1-Follower body at x0.35 pays 35 over 100 kills
##   (was 100), so Overtime devalues the commonest kill too and the
##   stay-or-leave decision it exists to create is not undone by rounding.
func settle_kill_reward(reward_min: int, reward_max: int, elite_bonus: int, is_elite: bool, overtime_multiplier: float = 1.0) -> int:
	if reward_max <= 0:
		return 0
	var low := maxi(0, reward_min)
	var gain: int = _rng.randi_range(low, maxi(low, reward_max))
	if is_elite:
		gain += maxi(0, elite_bonus)
	# Luck: witnesses of a lucky kill are extra impressed.
	if gain > 0 and _rng.randf() < LuckResolver.extra_follower_chance(run_luck):
		gain += 1
	# Cult of Personality (Prophet once Transcended) and Census of Souls:
	# violence as recruitment seminar.
	if gain > 0:
		gain += bonus_kill_followers()
	if gain <= 0:
		return 0
	_kill_reward_carry += float(gain) * maxf(0.0, overtime_multiplier)
	# The epsilon keeps 100 x 0.35 from settling as 34.999... -> 34.
	var paid := floori(_kill_reward_carry + 0.000001)
	_kill_reward_carry -= float(paid)
	return paid


# ============================================================
# Duos, Facets, the Burden, the Reliquary and the Grimoire
# (docs/design/2026-10-03-duos-facets-and-the-reliquary.md)
# ============================================================

func has_voucher(id: StringName) -> bool:
	return attempt_vouchers.has(String(id))


func duo_level_required() -> int:
	return 2 if has_voucher(Vouchers.CONCORDANCE) else AugmentDuos.LEVEL_REQUIRED


func facet_level_required() -> int:
	return 2 if has_voucher(Vouchers.WHETSTONE) else AugmentFacets.LEVEL_REQUIRED


func _equipped_levels() -> Dictionary:
	var out := {}
	for id in permanent_augment_ids:
		if id != StringName():
			out[String(id)] = get_augment_level(id)
	return out


## Duos whose pair is equipped at the required level and not taken yet.
func duos_ready() -> Array:
	init_permanent_augments()
	return AugmentDuos.ready_duos(permanent_augment_ids, _equipped_levels(), attempt_augment_duos, duo_level_required())


## A Duo acts only while both its augments are equipped.
func augment_duo_active(duo_id: StringName) -> bool:
	if not attempt_augment_duos.has(String(duo_id)):
		return false
	for member in AugmentDuos.members(duo_id):
		if not permanent_augment_ids.has(member):
			return false
	return true


## The chosen Facet id of an augment this run, or &"".
func augment_facet(aug_id: StringName) -> StringName:
	return StringName(str(attempt_augment_facets.get(String(aug_id), "")))


## Equipped augments with Facets, at the required level, none chosen yet.
func facets_ready() -> Array:
	init_permanent_augments()
	var out: Array = []
	for id in permanent_augment_ids:
		if id == StringName() or not AugmentFacets.has_facets(id) or attempt_augment_facets.has(String(id)):
			continue
		if get_augment_level(id) >= facet_level_required():
			out.append(id)
	return out


## Whether BURDEN can raise the pending Binding's grades: from the second
## Binding on, once per Binding, while a card can still rise.
func binding_burden_available() -> bool:
	if not pending_augment_pick or not binding_can_trade() or attempt_binding_burdened:
		return false
	# The relic is bound into the run's bag: with no room it would fall to the
	# profile stash (and leave the run) or onto the floor (and be left behind).
	if not binding_burden_has_room():
		return false
	for card in binding_offer():
		var grade := int(card.get("grade", -1))
		if grade >= 0 and grade < AugmentScaling.GRADE_COUNT - 1:
			return true
	return false


## Raises every graded card one grade; binds a cursed relic into the bag and
## adds Threat debt to the segment (the Burden Writ voucher waives that).
## {ok, relic, threat}.
func binding_burden() -> Dictionary:
	if not binding_burden_available():
		return {"ok": false, "relic": "", "threat": 0.0}
	attempt_binding_offer = AugmentRites.burdened_offer(attempt_binding_offer)
	attempt_binding_burdened = true
	var relic := _bind_burden_relic()
	var threat := 0.0
	if not has_voucher(Vouchers.BURDEN_WRIT):
		threat = AugmentRites.BURDEN_THREAT
		attempt_doctrine_threat_debt += threat
	request_autosave()
	return {"ok": true, "relic": relic, "threat": threat}


func binding_burden_has_room() -> bool:
	return run_bag != null and run_bag.first_empty_slot() != -1


func _bind_burden_relic() -> String:
	var ids := AugmentRites.burden_relic_ids(item_db)
	if ids.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = int(attempt_world_seed) ^ (binding_segment() * 0x51ED27) ^ 0xB0D
	var item_id: String = ids[rng.randi_range(0, ids.size() - 1)]
	var data := item_db.get(item_id, null) as ItemData
	if data == null:
		return ""
	var rarity := clampi(floori(float(binding_segment()) / 2.0), 1, 5)
	var inst := ItemInstance.from_roll(data, rarity, ItemInstance.Polarity.NEG, 0.5, false)
	if run_bag == null or not run_bag.add_instance(inst):
		return ""
	return item_id


func augment_corruption(aug_id: StringName) -> StringName:
	return StringName(str(attempt_augment_corruptions.get(String(aug_id), "")))


func can_corrupt_augment(aug_id: StringName) -> bool:
	return aug_id != StringName() and permanent_augment_ids.has(aug_id) and not attempt_augment_corruptions.has(String(aug_id))


## Corrupts an equipped augment: free, irreversible, once per augment per
## run. Seeded by the attempt, the augment and the segment, so a reload
## deals the same fate. {ok, outcome, before, after}.
func corrupt_augment(aug_id: StringName) -> Dictionary:
	if not can_corrupt_augment(aug_id):
		return {"ok": false}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(attempt_world_seed) ^ int(String(aug_id).hash()) ^ (attempt_segment * 0x2F1B) ^ 0xC0EE
	var outcome := AugmentRites.roll_corruption(rng, run_luck)
	var before := get_augment_level(aug_id)
	var after := AugmentRites.corrupted_level(outcome, before)
	attempt_augment_corruptions[String(aug_id)] = String(outcome)
	set_augment_level(aug_id, after)
	permanent_augments_changed.emit(permanent_augment_ids)
	request_autosave()
	return {"ok": true, "outcome": outcome, "before": before, "after": after}


## The stat pass's Scar step: Max HP x0.9 for each Scarred augment worn.
func apply_augment_scars(s: Stats) -> void:
	if s == null:
		return
	for id in permanent_augment_ids:
		if id != StringName() and augment_corruption(id) == AugmentRites.SCARRED:
			s.max_hp = maxf(1.0, s.max_hp * AugmentRites.SCAR_MAX_HP_MUL)
			stat_ledger_step("SCARRED %s" % augment_display_name(id).to_upper(), s)


## What pouring `donor` into `recipient` would do: {ok, gain, cost,
## per_level, reason}. Priced at this Hub's Binding segment (P4).
func transfusion_preview(recipient: StringName, donor: StringName) -> Dictionary:
	var out := {"ok": false, "gain": 0, "cost": 0, "per_level": AugmentRites.transfusion_cost_per_level(binding_segment()), "reason": ""}
	if recipient == StringName() or not permanent_augment_ids.has(recipient):
		out["reason"] = "the recipient must be equipped"
		return out
	if donor == StringName() or donor == recipient or permanent_augment_ids.has(donor) or not owned_augment_ids.has(donor):
		out["reason"] = "the donor must be an owned augment that is not equipped"
		return out
	# A Corruption's levels are bound to the augment that took the risk.
	# Pouring them on let a spare from the meta library be equipped,
	# corrupted at Lv.1 (where Sundered costs nothing) and drained, over and
	# over: a main augment reached Lv.18-20 at the first Hub visit.
	if attempt_augment_corruptions.has(String(donor)):
		out["reason"] = "a corrupted augment's levels are bound to it"
		return out
	var poured := AugmentRites.transfusion_gain(get_augment_level(donor))
	if poured <= 0:
		out["reason"] = "the donor needs Lv.%d" % AugmentRites.TRANSFUSION_MIN_DONOR
		return out
	# Only the levels the recipient can take are paid for: a recipient near
	# the cap would otherwise pay full price and burn the donor for nothing.
	var gain := mini(poured, AugmentScaling.MAX_LEVEL - get_augment_level(recipient))
	out["gain"] = maxi(0, gain)
	out["cost"] = AugmentRites.transfusion_cost(maxi(0, gain), binding_segment())
	if gain <= 0:
		out["reason"] = "the recipient is at Lv.%d already" % AugmentScaling.MAX_LEVEL
		return out
	if followers < int(out["cost"]):
		out["reason"] = "needs %d Followers" % int(out["cost"])
		return out
	out["ok"] = true
	return out


func transfuse_augment(recipient: StringName, donor: StringName) -> Dictionary:
	var preview := transfusion_preview(recipient, donor)
	if not bool(preview["ok"]):
		return preview
	var cost := int(preview["cost"])
	if cost > 0:
		var paid := transaction_followers(-cost, &"transfusion", {"recipient": String(recipient), "donor": String(donor)}, true, false)
		if int(paid.get("change", 0)) != -cost:
			preview["ok"] = false
			preview["reason"] = "the Followers could not be spent"
			return preview
	set_augment_level(recipient, AugmentScaling.clamp_level(get_augment_level(recipient) + int(preview["gain"])))
	set_augment_level(donor, 1)
	permanent_augments_changed.emit(permanent_augment_ids)
	request_autosave()
	return preview


## The Hub visit's Vouchers, dealt once per segment and kept.
func voucher_offer() -> Array:
	if attempt_voucher_segment != attempt_segment:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(attempt_world_seed) ^ (attempt_segment * 0x6A09E667) ^ 0x70C
		attempt_voucher_offer = Vouchers.deal(rng, attempt_vouchers)
		attempt_voucher_segment = attempt_segment
		request_autosave()
	return attempt_voucher_offer.duplicate()


func voucher_price() -> int:
	return Vouchers.price(binding_segment())


func buy_voucher(id: StringName) -> bool:
	if not voucher_offer().has(String(id)) or has_voucher(id):
		return false
	var cost := voucher_price()
	if followers < cost:
		return false
	var paid := transaction_followers(-cost, &"voucher", {"voucher": String(id)}, true, false)
	if int(paid.get("change", 0)) != -cost:
		return false
	attempt_vouchers.append(String(id))
	request_autosave()
	return true


## Loaded Dice (Lucky Charm + Gambler's Rite): a lucky crit recruits a
## Follower, at most one a second, and only with an enemy near enough to
## witness it - the crit is rolled when the attack is fired, so without that
## a player could recruit by swinging at empty air. player._fire_weapon
## calls this.
func on_lucky_crit(at: Vector2 = Vector2.INF) -> void:
	if not augment_duo_active(AugmentDuos.LOADED_DICE):
		return
	if at != Vector2.INF and EnemyCombat.nearest_enemy(at, AugmentDuos.value(AugmentDuos.LOADED_DICE, "witness_range", 600.0)) == EnemyWorldTypes.INVALID_HANDLE:
		return
	var now := Time.get_ticks_msec()
	if now - _loaded_dice_last_ms < int(AugmentDuos.value(AugmentDuos.LOADED_DICE, "crit_gap_ms", 1000.0)):
		return
	_loaded_dice_last_ms = now
	transaction_followers(1, &"loaded_dice", {}, true, true)


## A run saved before the Grimoire existed (or by another profile's
## build) already holds Transcendences, Duos, Facets and Doctrine families;
## the Grimoire learns them on load, quietly, instead of showing them as
## undiscovered until the next one is taken.
func _backfill_grimoire() -> void:
	var keys: Array[String] = []
	for id in attempt_augment_transcended:
		keys.append(Grimoire.transcend_key(StringName(str(id))))
	for id in attempt_augment_duos:
		keys.append(Grimoire.duo_key(StringName(str(id))))
	for id in attempt_augment_facets:
		keys.append(Grimoire.facet_key(StringName(str(id)), StringName(str(attempt_augment_facets[id]))))
	var families := doctrine_family_counts()
	for family in families:
		if int(families[family]) >= DoctrineFamilies.THESIS_AT:
			keys.append(Grimoire.thesis_key(family))
		if int(families[family]) >= DoctrineFamilies.CANON_AT:
			keys.append(Grimoire.canon_key(family))
	for key in keys:
		if not grimoire_entries.has(key):
			grimoire_entries.append(key)


func grimoire_has(key: String) -> bool:
	return grimoire_entries.has(key)


## Records a Grimoire key the first time the profile reaches it.
func grimoire_note(key: String) -> bool:
	if key == "" or grimoire_entries.has(key):
		return false
	grimoire_entries.append(key)
	grimoire_discovered.emit(key)
	request_autosave()
	return true

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


## The advancement-tree ledger for this attempt, created on first use from
## the selected style so the native Core is always the one the run chose.
## The tree new attempts use. V5 is the shipped default (user decision,
## 2026-09-26 playtest review finding 1); "v4" remains the untouched control
## for A/B runs via this switch. A saved run KEEPS the tree it started with —
## nothing converts an existing ledger, and node ids mean different things
## across versions, so conversion would corrupt receipts.
var new_run_tree_version: String = "v5_ranged"


func ascension_ledger() -> AscensionLedger:
	# Identity, not equality: two fresh states compare equal by value, and the
	# ledger must follow the Dictionary the attempt actually holds.
	if _ascension_ledger == null or not is_same(_ascension_ledger.state, attempt_ascension):
		if attempt_ascension.is_empty():
			attempt_ascension = AscensionLedger.fresh_state(String(selected_style_id), new_run_tree_version)
		var tree := AscensionTreeDB.shared_for(String(attempt_ascension.get("tree_version", "v4")))
		_ascension_ledger = AscensionLedger.new(tree, attempt_ascension)
	# Tithe Ledger (archive Doctrine): every node costs less.
	_ascension_ledger.price_multiplier = maxf(0.0, float(get_doctrine_rule(&"ascension_price_mul", 1.0)))
	return _ascension_ledger


## Tithe Ledger's price: tree refunds return nothing.
func ascension_refunds_forfeit() -> bool:
	return float(get_doctrine_rule(&"ascension_refund_mul", 1.0)) <= 0.0


## Buys a tree node with this run's Followers. Returns the ledger verdict with
## "ok"; on success the Followers are spent through the normal transaction.
func ascension_buy(id: String, chosen_core: String = "") -> Dictionary:
	var ledger := ascension_ledger()
	var verdict := ledger.can_buy(id, followers, chosen_core)
	if not bool(verdict["ok"]):
		return verdict
	var cost := int(verdict["cost"])
	if cost > 0:
		var result := transaction_followers(-cost, &"ascension_purchase", {"node": id}, true, false)
		if int(result.get("change", 0)) != -cost:
			transaction_followers(-int(result.get("change", 0)), &"ascension_refund", {"node": id}, false, false)
			return {"ok": false, "reason": "the Followers could not be spent", "cost": cost}
	ledger.record_purchase(id, cost, chosen_core)
	if PerformanceFlightRecorder != null:
		PerformanceFlightRecorder.record_event(&"ascension", &"purchase", {"node": id, "cost": cost, "core": chosen_core, "spent": int(ledger.state.get("spent", 0))})
	request_autosave()
	return verdict


## True only while the Hub's tree screen is open: refunds are a Hub decision
## (the loot loop pass, L1); the mid-run screen buys and equips only.
var ascension_refund_context_hub: bool = false


## Refunds `share` of the recorded prices (AscensionLedger.refund_share for
## the segment) and only from the Hub; sworn nodes never refund.
func ascension_refund(id: String) -> int:
	if not ascension_refund_context_hub or ascension_refunds_forfeit():
		return 0
	var back := ascension_ledger().refund(id, AscensionLedger.refund_share(attempt_segment))
	if back > 0:
		transaction_followers(back, &"ascension_refund", {"node": id}, true, false)
		request_autosave()
	return back


## Removes one rank of a V5 ranked local, returning the segment's refund
## share of its recorded payment, like every other refund (follower economy
## audit 2026-10-04, P9; it returned the exact receipt, so V5 ranks were a
## free respec at every Hub). A Hub decision, like every other refund.
func ascension_downgrade(id: String) -> int:
	if not ascension_refund_context_hub or ascension_refunds_forfeit():
		return 0
	var back := ascension_ledger().downgrade_rank(id, AscensionLedger.refund_share(attempt_segment))
	if back > 0:
		transaction_followers(back, &"ascension_refund", {"node": id, "downgrade": true}, true, false)
		request_autosave()
	return back


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
		stat_ledger_step("DOCTRINE", s)
	# The vessel family's Thesis and Canon (bindings-and-theses §6).
	var vessel := doctrine_family_count(&"vessel")
	if vessel >= 2:
		s.power += 0.15
		stat_ledger_step("VESSEL THESIS", s)
	if vessel >= 3:
		s.power += 0.25
		stat_ledger_step("VESSEL CANON", s)

func apply_doctrine_final_stat_multipliers(s: Stats) -> void:
	if s == null:
		return
	s.max_hp = maxf(1.0, s.max_hp * doctrine_max_hp_multiplier())
	stat_ledger_step("MAX HP ×%.2f" % doctrine_max_hp_multiplier(), s)


## The Doctrine's Max HP multiplier; under the Vessel Canon every price
## below 1 moves halfway back to 1 (0.7 -> 0.85), gifts above 1 stay.
func doctrine_max_hp_multiplier() -> float:
	var mul := float(get_doctrine_rule(&"max_hp_mul", 1.0))
	if mul < 1.0 and doctrine_has_canon(&"vessel"):
		mul = 1.0 - (1.0 - mul) * 0.5
	return mul

## Manufactured Witness's price: 100, or 8% of the Followers held once that
## is more (follower economy audit 2026-10-04, P4). A flat 100 was free by the
## Apotheosis stage; 8% keeps the insurance below the 20% a death would tax.
const WITNESS_MIN_PRICE := 100
const WITNESS_WALLET_SHARE := 0.08


func manufactured_witness_price() -> int:
	return maxi(WITNESS_MIN_PRICE, int(ceil(float(maxi(0, followers)) * WITNESS_WALLET_SHARE)))


func try_consume_manufactured_witness() -> bool:
	if not bool(get_doctrine_rule(&"manufactured_witness", false)):
		return false
	var price := manufactured_witness_price()
	if attempt_witness_used_segment == attempt_segment or followers < price:
		return false
	var transaction := transaction_followers(
		-price,
		&"manufactured_witness",
		{"segment": attempt_segment, "price": price},
		false,
		false
	)
	if int(transaction.get("change", 0)) != -price:
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
	if attempt_pending_doctrine_stage != StringName() and def.stage != attempt_pending_doctrine_stage and not is_apocrypha_stage(attempt_pending_doctrine_stage):
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
	if def.family_id != StringName():
		var held := doctrine_family_count(def.family_id)
		if held >= DoctrineFamilies.THESIS_AT:
			grimoire_note(Grimoire.thesis_key(def.family_id))
		if held >= DoctrineFamilies.CANON_AT:
			grimoire_note(Grimoire.canon_key(def.family_id))

	# clear offer + flag so you can't get stuck
	attempt_major_choice_offer_ids.clear()
	pending_big_choice = false
	attempt_big_choice_source_segment = 0
	attempt_pending_doctrine_stage = &""
	request_autosave()
	return true

## Test/dev seam: when true, combat autosaves are neither scheduled nor flushed
## (exit-crash bisection; the save path is the main thing a kill arms).
var debug_disable_autosave: bool = false
## Authored encounter beats (EncounterDirector) - off switch for tests and
## benchmarks that need the ambient population only.
var debug_encounter_beats: bool = true
## The Cursed Vault (roadmap 2.5) - off switch for tests that need the bare
## district.
var debug_cursed_vault: bool = true


func _release_autosave_suppression() -> void:
	_suppress_autosave = false


## Equilibrium Sigil (A3): while slotted, pickups never auto-equip.
func equilibrium_curation() -> bool:
	return permanent_augment_ids.has(&"augment_equilibrium_sigil")


## Gravemarch polarity rule (A6): three or more equipped Gravemarch pieces
## NEG turn the Ballast Frame's armour into a life-drain aura and make NEG
## Gravemarch merges deepen.
func gravemarch_curse_active() -> bool:
	if run_inventory == null:
		return false
	var composition: Dictionary = run_inventory.get_set_polarity_composition(&"gravemarch")
	return int(composition.get("neg", 0)) >= BurdenResolver.GRAVEMARCH_CURSE_MIN_PIECES


func gambler_reset_segment() -> void:
	attempt_gambler_seen.clear()
	attempt_gambler_resonance = 0.0
	attempt_gambler_followers = 0


func _connect_gambler_listener() -> void:
	if RunEvents != null and not RunEvents.item_operation.is_connected(_on_item_operation_for_gambler):
		RunEvents.item_operation.connect(_on_item_operation_for_gambler)


func _on_item_operation_for_gambler(kind: StringName, inst: ItemInstance, data: Dictionary) -> void:
	if not permanent_augment_ids.has(&"augment_gamblers_rite"):
		return
	if not GamblersRite.is_new_neg_acquisition(kind, inst, data):
		return
	gambler_note_acquisition(inst)


## Gambler's Rite (A7): one Follower roll per new curse found, Resonance for
## the first of each distinct base item per segment up to the cap.
func gambler_note_acquisition(inst: ItemInstance) -> Dictionary:
	var result := {"follower": false, "resonance": 0.0}
	var item_id := String(inst.data.id) if inst != null and inst.data != null else ""
	var house_edge := is_augment_transcended(&"augment_gamblers_rite")
	var rite_chance := BurdenResolver.gambler_follower_chance(run_luck, house_edge)
	# Loaded Dice (Lucky Charm + Gambler's Rite) adds its points on top.
	if augment_duo_active(AugmentDuos.LOADED_DICE):
		rite_chance = minf(0.85, rite_chance + AugmentDuos.value(AugmentDuos.LOADED_DICE, "rite_bonus", 0.15))
	if _rng.randf() < rite_chance:
		var paid := 2 if house_edge else 1
		transaction_followers(paid, &"gamblers_rite", {"item": item_id}, true, true)
		attempt_gambler_followers += paid
		result["follower"] = true
	if item_id != "" and not attempt_gambler_seen.has(item_id):
		attempt_gambler_seen[item_id] = true
		var grant := minf(BurdenResolver.GAMBLER_RESONANCE_PER_ITEM, BurdenResolver.GAMBLER_RESONANCE_CAP - attempt_gambler_resonance)
		if grant > 0.0:
			attempt_gambler_resonance += grant
			result["resonance"] = grant
			_grant_gambler_resonance(grant)
	return result


func _grant_gambler_resonance(amount: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var builder := tree.get_first_node_in_group(&"segment_proc_builder")
	if builder != null and builder.has_method("grant_resonance"):
		builder.call("grant_resonance", amount, true)
		return
	for node in tree.get_nodes_in_group(&"segment_spawn_filter"):
		if node.has_method("_add_resonance"):
			node.call("_add_resonance", amount, true)
			return


func request_autosave(delay: float = 0.6) -> void:
	if debug_disable_autosave:
		return
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


## The engine's finalization after quit() has an intermittent access
## violation on this build (script/resource cycles keep RID-holding resources
## alive past server teardown; see docs/2026-08-27-improvement-backlog.md
## D1). Player-facing quits flush everything that matters and then end the
## process before finalization runs. Tests call get_tree().quit() directly and
## keep their exit codes.
var hard_exit_on_quit: bool = true


func request_quit() -> void:
	flush_pending_save()
	if PerformanceFlightRecorder != null and PerformanceFlightRecorder.has_method("flush_reports"):
		PerformanceFlightRecorder.flush_reports()
	if hard_exit_on_quit and not OS.has_feature("editor"):
		OS.kill(OS.get_process_id())
		return
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush_pending_save()
		if PerformanceFlightRecorder != null and PerformanceFlightRecorder.has_method("flush_reports"):
			PerformanceFlightRecorder.flush_reports()
		if hard_exit_on_quit and not OS.has_feature("editor"):
			OS.kill(OS.get_process_id())


func _exit_tree() -> void:
	_cancel_autosave_timer()
	# Application shutdown: release script-static caches that hold RID-backed
	# resources (textures/materials). Script statics destruct during script
	# server teardown — after rendering cleanup has begun — which is the window
	# the intermittent exit segfault lives in.
	_WORLD_ART_SCRIPT.release_static_caches()
	GroundSplatRenderer.release_static_caches()
	EnemyProjectile.release_static_caches()
	AugmentActiveBadge.release_static_caches()
	ManifestationCatalog.release_static_caches()
	ManifestationPairCatalog.release_static_caches()


func flush_pending_save() -> void:
	_cancel_autosave_timer()
	if not _autosave_dirty or debug_disable_autosave:
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
	balance_attempt_boundary.emit(&"save_loaded")
	_suppress_autosave = true
	# If anything below aborts, the suppression must not silently disable
	# every later autosave; the deferred release runs after the normal one.
	_release_autosave_suppression.call_deferred()
	if save.save_version > SaveData.CURRENT_SAVE_VERSION:
		push_warning(
			"Save slot %d was written by a newer build (save_version %d > %d, game %s); loading best-effort."
			% [save.slot_index, save.save_version, SaveData.CURRENT_SAVE_VERSION, save.game_version]
		)

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
	grimoire_entries.clear()
	for grimoire_key in save.meta_grimoire:
		var clean_key := String(grimoire_key).strip_edges()
		if clean_key != "" and not grimoire_entries.has(clean_key):
			grimoire_entries.append(clean_key)
	# A story saved before the story layer is seeded from the runs this
	# profile already has (story review 2026-10-04).
	StoryDirector.load_state(save.meta_story, {"runs": save.total_runs, "active": save.attempt_active})
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
	ItemScaling.rebuild(meta_stash.slots)



	# Attempt snapshot (Continue)
	attempt_active = save.attempt_active
	if attempt_active:
		attempt_segment = max(1, save.attempt_segment)
		attempt_deaths_this_segment = max(0, save.attempt_deaths_this_segment)
		attempt_checkpoint_pos = save.attempt_checkpoint_pos
		attempt_world_seed = save.attempt_world_seed
		if int(save.get("attempt_rng_state")) != 0:
			_rng.state = int(save.get("attempt_rng_state"))
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
		attempt_imprints.clear()
		for imprint_id in save.get("attempt_imprints"):
			attempt_imprints.append(StringName(imprint_id))
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
		attempt_ascension = save.attempt_ascension.duplicate(true)
		_ascension_ledger = null
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
			attempt_ascension = {}
			_ascension_ledger = null

		attempt_augment_levels = save.attempt_augment_levels.duplicate(true)
		attempt_mutations = save.attempt_mod_mutations.duplicate(true)
		attempt_stat_delta = save.attempt_mod_stat_delta
		attempt_augment_transcended = save.attempt_augment_transcended.duplicate(true)
		attempt_binding_offer = save.attempt_binding_offer.duplicate(true)
		attempt_binding_recasts = maxi(0, int(save.attempt_binding_recasts))
		attempt_binding_consecrations = maxi(0, int(save.attempt_binding_consecrations))
		attempt_augment_duos = save.attempt_augment_duos.duplicate(true)
		attempt_augment_facets = save.attempt_augment_facets.duplicate(true)
		attempt_augment_corruptions = save.attempt_augment_corruptions.duplicate(true)
		attempt_binding_burdened = bool(save.attempt_binding_burdened)
		attempt_vouchers = save.attempt_vouchers.duplicate()
		attempt_voucher_offer = save.attempt_voucher_offer.duplicate()
		attempt_voucher_segment = int(save.attempt_voucher_segment)
		# A run saved before the Congregation existed (-1) starts it from the
		# Followers it holds: a floor, never a guess above what was earned.
		attempt_congregation = int(save.attempt_congregation) if int(save.attempt_congregation) >= 0 else maxi(0, int(save.attempt_followers))
		# The carry is not saved: a Continue into this attempt, possibly from
		# another slot's run, starts it at zero (review 2026-10-04).
		_kill_reward_carry = 0.0
		_backfill_grimoire()

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
		# Derived stats are recomputed from id, rank and meter on every load
		# (no feeding, no rerolling), so a save made under older item curves
		# adopts the current balance revision while keeping its progress exact.
		if run_inventory != null:
			ItemScaling.rebuild(run_inventory.items)
		if run_bag != null:
			ItemScaling.rebuild(run_bag.slots)

		# Vendor snapshot (HubShop anti-reroll)
		attempt_vendor_segment = int(save.attempt_vendor_segment) if save.has_method("get") else int(save.attempt_vendor_segment)
		attempt_vendor_refreshes = int(save.attempt_vendor_refreshes)
		attempt_vendor_seed = int(save.attempt_vendor_seed)
		attempt_vendor_bag = save.attempt_vendor_bag

		if attempt_vendor_bag != null and attempt_vendor_bag.has_method("_ensure_size"):
			attempt_vendor_bag._ensure_size()
			ItemScaling.rebuild(attempt_vendor_bag.slots)

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
		attempt_imprints.clear()
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
		attempt_ascension = {}
		_ascension_ledger = null
		attempt_witness_used_segment = 0
		attempt_doctrine_threat_debt = 0.0
		attempt_augment_levels = {}
		gambler_reset_segment()
		attempt_mutations = {}
		attempt_stat_delta = null
		attempt_augment_transcended = {}
		attempt_binding_offer = []
		attempt_binding_recasts = 0
		attempt_binding_consecrations = 0
		attempt_augment_duos = {}
		attempt_augment_facets = {}
		attempt_augment_corruptions = {}
		attempt_binding_burdened = false
		attempt_vouchers = []
		attempt_voucher_offer = []
		attempt_voucher_segment = 0
		attempt_congregation = 0
		_kill_reward_carry = 0.0

		run_inventory = null
		run_bag = null
		set_followers(0)

	_suppress_autosave = false
func write_save(save: SaveData) -> void:
	_suppress_autosave = true
	save.save_version = SaveData.CURRENT_SAVE_VERSION
	save.game_version = String(_BUILD_INFO_SCRIPT.version())
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
	save.meta_grimoire = grimoire_entries.duplicate()
	save.meta_story = StoryDirector.state_for_save()
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
		save.attempt_ascension = attempt_ascension.duplicate(true)
		save.attempt_witness_used_segment = attempt_witness_used_segment
		save.attempt_doctrine_threat_debt = attempt_doctrine_threat_debt

		save.attempt_augment_levels = attempt_augment_levels.duplicate(true)
		save.attempt_mod_mutations = attempt_mutations.duplicate(true)
		save.attempt_mod_stat_delta = attempt_stat_delta
		save.attempt_augment_transcended = attempt_augment_transcended.duplicate(true)
		save.attempt_binding_offer = attempt_binding_offer.duplicate(true)
		save.attempt_binding_recasts = attempt_binding_recasts
		save.attempt_binding_consecrations = attempt_binding_consecrations
		save.attempt_augment_duos = attempt_augment_duos.duplicate(true)
		save.attempt_augment_facets = attempt_augment_facets.duplicate(true)
		save.attempt_augment_corruptions = attempt_augment_corruptions.duplicate(true)
		save.attempt_binding_burdened = attempt_binding_burdened
		save.attempt_vouchers = attempt_vouchers.duplicate()
		save.attempt_voucher_offer = attempt_voucher_offer.duplicate()
		save.attempt_voucher_segment = attempt_voucher_segment
		save.attempt_congregation = attempt_congregation

		# Attempt identity
		save.attempt_race_id = selected_race_id
		save.attempt_style_id = selected_style_id
		save.attempt_weapon_id = selected_weapon_id

		save.attempt_checkpoint_pos = attempt_checkpoint_pos
		save.attempt_world_seed = attempt_world_seed
		save.attempt_rng_state = int(_rng.state)
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
		var imprints := PackedStringArray()
		for imprint_id in attempt_imprints:
			imprints.append(String(imprint_id))
		save.attempt_imprints = imprints
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
		save.attempt_ascension = {}
		save.attempt_witness_used_segment = 0
		save.attempt_doctrine_threat_debt = 0.0
		save.attempt_augment_levels = {}
		save.attempt_mod_mutations = {}
		save.attempt_mod_stat_delta = null
		save.attempt_augment_transcended = {}
		save.attempt_binding_offer = []
		save.attempt_binding_recasts = 0
		save.attempt_binding_consecrations = 0
		save.attempt_augment_duos = {}
		save.attempt_augment_facets = {}
		save.attempt_augment_corruptions = {}
		save.attempt_binding_burdened = false
		save.attempt_vouchers = []
		save.attempt_voucher_offer = []
		save.attempt_voucher_segment = 0
		save.attempt_congregation = 0

		# Attempt identity reset
		save.attempt_race_id = selected_race_id
		save.attempt_style_id = selected_style_id
		save.attempt_weapon_id = selected_weapon_id

		save.attempt_checkpoint_pos = Vector2.INF
		save.attempt_world_seed = 0
		save.attempt_rng_state = 0
		save.attempt_imprints = PackedStringArray()
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
	balance_attempt_boundary.emit(&"restarted")
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
	attempt_congregation = 0
	_kill_reward_carry = 0.0
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
	_reset_attempt_choice_state()
	attempt_ascension = {}
	_ascension_ledger = null
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
	balance_segment_completed.emit(completed_segment)
	if not attempt_ascension.is_empty():
		ascension_ledger().note_segment_completed(completed_segment)
		# Guaranteed Evolution opportunities after segments 6 and 9, then every
		# third segment. A qualified recipe is bought with the claim at the tree;
		# with none, the claim stays banked (V4 "Purchase and recipe rules").
		if completed_segment == 6 or completed_segment == 9 or (completed_segment > 9 and (completed_segment - 9) % 3 == 0):
			ascension_ledger().grant_evolution_claim()
			request_autosave()
	attempt_segment = completed_segment + 1
	attempt_deaths_this_segment = 0
	# Overtime's unpaid fraction belongs to the segment that earned it.
	_kill_reward_carry = 0.0
	gambler_reset_segment()
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

	# Milestones. A Binding follows every segment (was 2 and 7 only): the
	# augment pick is the run's recurring spike (bindings-and-theses §3).
	if completed_segment >= 1:
		pending_augment_pick = true
		attempt_binding_offer.clear()
		attempt_binding_recasts = 0
		attempt_binding_consecrations = 0
		attempt_binding_burdened = false
	var next_doctrine_stage := doctrine_stage_for_completed_segment(completed_segment)
	if next_doctrine_stage != StringName() and not attempt_doctrine_stage_ids.has(next_doctrine_stage) and doctrine_stage_has_plates(next_doctrine_stage):
		pending_big_choice = true
		attempt_pending_doctrine_stage = next_doctrine_stage
		attempt_big_choice_source_segment = completed_segment
		attempt_major_choice_offer_ids.clear()
	attempt_witness_used_segment = 0
	attempt_doctrine_threat_debt = 0.0

	if SaveManager != null and SaveManager.current_save != null:
		SaveManager.current_save.attempt_resume_scene = PATH_HUB_WORLD

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
			# Apocrypha: after the third stage the Doctrine keeps arriving every
			# three segments, drawn from every untaken plate of any stage.
			if completed_segment > 9 and (completed_segment - 9) % 3 == 0:
				return StringName("%s%d" % [APOCRYPHA_PREFIX, completed_segment])
			return &""


const APOCRYPHA_PREFIX := "apocrypha_"


func is_apocrypha_stage(stage_id: StringName) -> bool:
	return String(stage_id).begins_with(APOCRYPHA_PREFIX)



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
	balance_attempt_boundary.emit(&"failed")
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
	_reset_attempt_choice_state()
	attempt_ascension = {}
	_ascension_ledger = null
	attempt_witness_used_segment = 0
	attempt_doctrine_threat_debt = 0.0
	attempt_wardstone_radius_mul = 1.0
	attempt_wardstone_slow_mul = 1.0
	attempt_exit_hold_mul = 1.0

	# A fresh historical attempt begins before Bren commits to the work.
	attempt_congregation = 0
	_kill_reward_carry = 0.0
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
	return reconstruction_cost_for(followers)


## The reconstruction cost a death would charge against `balance`: the flat
## segment/death cost or a 20% tax on the balance, whichever is larger.
func reconstruction_cost_for(balance: int) -> int:
	var seg: int = maxi(1, attempt_segment)
	var deaths: int = maxi(0, attempt_deaths_this_segment)
	var base_cost: int = 10 + (seg - 1) * 2
	var growth: float = 1.7
	var flat_cost: int = int(ceil(float(base_cost) * pow(growth, float(deaths))))
	var pct_tax: int = int(ceil(float(maxi(balance, 1)) * 0.20))
	# Census of Souls' price: reconstruction costs half again.
	var doctrine_mul := maxf(0.0, float(get_doctrine_rule(&"reconstruction_cost_mul", 1.0)))
	return int(ceil(float(maxi(flat_cost, pct_tax)) * doctrine_mul))


## Whether a death at `balance` reconstructs the player: the cost is paid
## first and a balance of zero afterwards ends the Ascension (player.die),
## so the balance must exceed the cost, not merely cover it. The Hub's
## warning and the wager shrine's stake floor read this rule.
func reconstruction_survivable(balance: int) -> bool:
	return balance - reconstruction_cost_for(balance) > 0


## The one reserve rule for spenders that must never strand the run (follower
## economy audit 2026-10-04, P7): true when paying `amount` now still leaves
## a balance a death reconstructs from. The tithes refuse a payment this
## rejects; they used to stop at "balance - 1 >= cost", which leaves exactly
## the flat cost and a death then ends the run.
func spend_survivable(amount: int) -> bool:
	return amount <= 0 or reconstruction_survivable(followers - amount)


## The Exchange's reserve warning for the balance a spend would leave, or ""
## when a death still reconstructs from it. One line for every spender that
## warns instead of refusing: the Exchange's trade and the Binding's Recast
## and Consecrate (review 2026-10-04: the Binding, at the start of a
## segment, could strand the run without a word).
func reserve_warning_text(after: int) -> String:
	if reconstruction_survivable(after):
		return ""
	return "⚠ %d Followers left — not above the next reconstruction cost (%d). Death would end the Ascension." % [after, reconstruction_cost_for(after)]

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
	# Balance revision 2 (section 5.2): the rarity component is
	# RarityMath.rank_price at integer rank, and a banked meter is worth
	# exactly the lerp to the next rank, so both endpoints come from one
	# helper. The constant term prices the item's worth AS MERGE MATERIAL.
	# Invariant (LootLoopTest, AuditClosureTest): no vendor
	# buy->merge->sell sequence may net Followers.
	var rarity_value: float = RarityMath.fractional_rank_price(r, float(inst.upgrade_meter))

	var q: float = clampf(absf(float(inst.active_pct())), 0.0, 1.0)
	var quality_mul: float = lerpf(0.90, 1.40, q)
	var stat_value: float = 0.0
	if inst.rolled_mods != null:
		stat_value += absf(inst.rolled_mods.max_hp) * 0.30
		stat_value += absf(inst.rolled_mods.armor) * 0.80
		stat_value += absf(inst.rolled_mods.move_speed) * 0.35
		stat_value += absf(inst.rolled_mods.power) * 60.0
		stat_value += absf(inst.rolled_mods.haste) * 50.0
		stat_value += absf(inst.rolled_mods.luck) * 35.0
	var scripted_value: float = maxf(0.0, inst.data.scripted_value_weight)
	var set_mul: float = 1.15 if not inst.data.set_id.is_empty() else 1.0
	return int(round((rarity_value * quality_mul + stat_value + scripted_value) * set_mul))

## The stage price scale for everything a Hub or a district sells per visit
## (follower economy audit 2026-10-04, P2): vendor buys and restocks,
## imprints and wager stakes. Keyed to the segment the Hub sends you into
## (attempt_segment): x1.0 through Hub 1, then +25% a segment (Hub 2 x1.25,
## Hub 4 x1.75, Hub 9 x3.0). Income grows ~7x from Hub 1 to Hub 9 while the
## whole shelf grew 2.8x; prices that do not follow the income driver are the
## one combination the research pass says to avoid. Tree prices stay fixed so
## "save toward X" stays legible; a future Reach would plug in here.
func market_scale(segment: int = -1) -> float:
	var seg := attempt_segment if segment < 0 else segment
	return 1.0 + 0.25 * float(maxi(0, seg - 2))


func compute_buy_value(inst: ItemInstance) -> int:
	# What the vendor charges (followers), on the stage scale (P2). Selling
	# stays unscaled, so the buyback spread only widens with depth and no
	# buy -> sell (or buy -> merge -> sell) sequence can net Followers.
	var v: int = compute_item_value(inst)
	return maxi(0, int(ceil(float(v) * LuckResolver.buy_multiplier(run_luck) * market_scale())))

func compute_sell_value(inst: ItemInstance) -> int:
	# What the vendor pays you (followers).
	# Keep a spread so "flip for profit" isn't a thing.
	var v: int = compute_item_value(inst)
	return maxi(0, int(floor(float(v) * 0.55 * LuckResolver.sell_multiplier(run_luck))))


func deliver_guaranteed_item(inst: ItemInstance, prefer_equip: bool = true) -> bool:
	var op := BalanceItemContext.begin(&"reward", {"prefer_equip": prefer_equip})
	var ok := _deliver_guaranteed_item(inst, prefer_equip)
	BalanceItemContext.end(op)
	return ok


func _deliver_guaranteed_item(inst: ItemInstance, prefer_equip: bool = true) -> bool:
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
