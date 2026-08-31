extends Node2D

const SEGMENT_PROC_BUILDER_SCRIPT := preload("res://core/systems/world/SegmentProcBuilder.gd")
const SEGMENT1_NARRATIVE_OVERLAY := preload("res://ui/screens/Segment1NarrativeOverlay.tscn")
const TUTORIAL_MODAL_CONTROLLER := preload("res://ui/controllers/TutorialModalController.gd")
const OPENING_SEQUENCE_SCENE := preload("res://core/systems/world/opening/OpeningSequenceController.tscn")
const DEV_SEGMENT_SCENE := preload("res://scenes/world/dev_segment/DevSegment.tscn")
const ENEMY_PROXY_ROOT_SCRIPT := preload("res://core/systems/enemy_world/EnemyProxyRoot.gd")
const ENCOUNTER_DIRECTOR_SCRIPT := preload("res://core/systems/encounters/EncounterDirector.gd")

@export var starting_followers: int = 0 # legacy; Bren now becomes the first follower.
@export var game_over_ui_scene: PackedScene
@export var augment_select_scene: PackedScene

@onready var player: Node = $Player
@onready var hud: Control = $UI/HUD
@onready var chunk_manager: ChunkManager = get_node_or_null("ChunkManager") as ChunkManager
@onready var level1_builder: Node2D = get_node_or_null("Level1") as Node2D

# IMPORTANT: only ONE augment_select var (no duplicate @onready + var)
var augment_select: CanvasLayer = null
var _augment_prior_paused: bool = false

var _game_over_ui: Control = null
var _run_ended: bool = false
var _segment_completion_running: bool = false
var _tutorial_modals: TutorialModalController = null
var _opening_sequence: OpeningSequenceController = null


func _enter_tree() -> void:
	if Global == null or not Global.debug_dev_segment:
		return
	# Strip normal-world children before their _ready callbacks can allocate
	# chunks, navigation buffers, spawn services, or handcrafted geometry.
	for child_name in [&"ChunkManager", &"FlowFieldNav", &"Spawner", &"WorldDropSpawner", &"Level1"]:
		var child := get_node_or_null(NodePath(child_name))
		if child == null:
			continue
		remove_child(child)
		child.queue_free()


func _ready() -> void:
	get_tree().paused = false
	_tutorial_modals = TUTORIAL_MODAL_CONTROLLER.new() as TutorialModalController
	add_child(_tutorial_modals)

	# Ensure there is an active attempt (Base should start it, but this is a safety net).
	if Global != null and not Global.attempt_active:
		# If you entered Game directly, start a fresh attempt.
		Global.start_new_attempt()
		if Global.attempt_segment == 1 and not Global.has_segment1_milestone(&"assistant_commitment"):
			Global.set_followers(0)

	# Repair attempts created by 0.23.0-0.23.2, where start_new_attempt could
	# mark the attempt active without constructing its inventory containers.
	# Preserve any valid container; create only the missing side before HUD and
	# pickup systems bind to it below.
	if Global != null and Global.attempt_active:
		if Global.run_inventory == null:
			Global.reset_run_inventory()
		if Global.run_bag == null:
			Global.reset_run_bag_inventory()

	# Mark resume target as Game. Unvalidated: this is a resume-marker write on
	# the scene-entry frame; the preceding transition save was fully validated.
	if SaveManager != null and SaveManager.current_save != null:
		SaveManager.current_save.attempt_resume_scene = Global.PATH_GAME
		Global.save_current_profile(false)

	# HUD bindings
	if hud != null:
		hud.bind_inventory(Global.run_inventory)
		hud.bind_bag(Global.run_bag)
		hud.bind_player(player)
		hud.set_followers(Global.followers)

	# Followers -> HUD
	if Global != null and hud != null:
		var cb := Callable(hud, "set_followers")
		if not Global.followers_changed.is_connected(cb):
			Global.followers_changed.connect(cb)

	# Autosave on inventory/bag changes (throttled in Global)
	if Global != null:
		if Global.run_inventory != null:
			var inv_cb := Callable(self, "_on_inventory_changed")
			if not Global.run_inventory.changed.is_connected(inv_cb):
				Global.run_inventory.changed.connect(inv_cb)

		if Global.run_bag != null:
			var bag_cb := Callable(self, "_on_bag_changed")
			if not Global.run_bag.changed.is_connected(bag_cb):
				Global.run_bag.changed.connect(bag_cb)

	# Cache selected data once
	var race_data: RaceData = null
	var style_data: StyleData = null
	if Global != null:
		race_data = Global.race_db.get(Global.selected_race_id, null) as RaceData
		style_data = Global.style_db.get(Global.selected_style_id, null) as StyleData

	# Initial compute (race+style+inventory)
	if player != null and player.has_method("recompute_run_stats"):
		player.call("recompute_run_stats", race_data, style_data)

	# Recompute whenever inventory changes
	if Global != null and Global.run_inventory != null:
		var stats_cb := func() -> void:
			var r: RaceData = Global.race_db.get(Global.selected_race_id, null) as RaceData
			var st: StyleData = Global.style_db.get(Global.selected_style_id, null) as StyleData
			if player != null and player.has_method("recompute_run_stats"):
				player.call("recompute_run_stats", r, st)
		if not Global.run_inventory.changed.is_connected(stats_cb):
			Global.run_inventory.changed.connect(stats_cb)

	if OS.is_debug_build():
		print("[Game] ready seg=%d race=%s style=%s seed=%d" % [
			(Global.attempt_segment if Global != null else -1),
			Global.selected_race_id,
			Global.selected_style_id,
			(Global.attempt_world_seed if Global != null else 0),
		])

	_setup_segment_world()
	_setup_enemy_proxy_root()
	call_deferred("_setup_encounter_director")

	# Narrative opening precedes run-level reward UI on a fresh Segment 1.
	call_deferred("_begin_entry_sequence")


## Authored encounter beats on top of the director's continuous pressure
## (roadmap Phase 2.4). Deferred so the spawner and player exist.
func _setup_encounter_director() -> void:
	if Global != null and "debug_encounter_beats" in Global and not bool(Global.get("debug_encounter_beats")):
		return
	var spawner := get_tree().get_first_node_in_group(&"enemy_spawner")
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if spawner == null or player == null:
		return
	var director := ENCOUNTER_DIRECTOR_SCRIPT.new() as Node
	director.name = "EncounterDirector"
	add_child(director)
	director.call("setup", spawner, player)


func _setup_enemy_proxy_root() -> void:
	if Global == null or not Global.enemy_proxy_rollout:
		return
	var proxy_root := ENEMY_PROXY_ROOT_SCRIPT.new() as Node2D
	proxy_root.name = "EnemyProxyRoot"
	add_child(proxy_root)
	# The batched enemy visuals must draw above the world builder and the
	# chunk canvas items that stream in later; enemy nodes historically
	# rendered above them purely by spawning later in the tree. Deferred
	# METHOD, not deferred move_child: call_deferred captures argument
	# values at schedule time, which froze the target index mid-setup.
	call_deferred("_move_enemy_proxy_root_to_front")



func _move_enemy_proxy_root_to_front() -> void:
	var proxy_root := get_node_or_null("EnemyProxyRoot")
	if proxy_root != null:
		move_child(proxy_root, get_child_count() - 1)


func _setup_segment_world() -> void:
	if Global != null and Global.debug_dev_segment:
		_setup_dev_segment()
		return

	var seg: int = (Global.attempt_segment if Global != null else 1)

	# Segment 1 is handcrafted (Level1Builder). Segments 2+ use procedural chunks + a procedural builder.
	if seg == 1:
		if chunk_manager != null:
			chunk_manager.generation_enabled = false
		# Level1Builder will self-run (and self-disable for seg != 1).
		return

	# Segments 2+: ensure the handcrafted builder is gone/inert, then spawn the procedural builder.
	if chunk_manager != null:
		chunk_manager.generation_enabled = true

	if level1_builder != null and is_instance_valid(level1_builder):
		level1_builder.queue_free()

	var b := SEGMENT_PROC_BUILDER_SCRIPT.new() as Node2D
	if b != null:
		add_child(b)
	else:
		push_warning("Failed to instantiate SegmentProcBuilder")


func _setup_dev_segment() -> void:
	Global.debug_performance_lab = true
	PerformanceFlightRecorder.set_enabled(true)
	if chunk_manager != null:
		chunk_manager.generation_enabled = false
		chunk_manager.queue_free()
	var flow_field := get_node_or_null("FlowFieldNav")
	if flow_field != null:
		flow_field.queue_free()
	if level1_builder != null and is_instance_valid(level1_builder):
		level1_builder.queue_free()
	var spawner := get_node_or_null("Spawner")
	if spawner != null:
		spawner.queue_free()
	var world_drop_spawner := get_node_or_null("WorldDropSpawner")
	if world_drop_spawner != null:
		world_drop_spawner.queue_free()
	var prototype := DEV_SEGMENT_SCENE.instantiate()
	if prototype != null:
		add_child(prototype)
	else:
		push_warning("Failed to instantiate DevSegment")


func _begin_entry_sequence() -> void:
	if Global != null and Global.debug_dev_segment:
		return
	var seg: int = (Global.attempt_segment if Global != null else 1)
	if seg == 1 and Global != null and not Global.attempt_opening_completed:
		_opening_sequence = OPENING_SEQUENCE_SCENE.instantiate() as OpeningSequenceController
		if _opening_sequence != null:
			add_child(_opening_sequence)
			await _opening_sequence.run_sequence(player as Node2D, level1_builder as Level1Builder)
			_opening_sequence.queue_free()
			_opening_sequence = null

	# Segment 1 stages the first build choice inside the level (the evidence
	# store beat); the run-start picker remains for direct later-segment
	# entries where no store exists.
	if Global != null and Global.pending_augment_pick and seg != 1:
		_spawn_augment_select()
	else:
		call_deferred("_tutorial_intro_sequence")

func _on_inventory_changed() -> void:
	if Global != null:
		Global.request_autosave()


func _on_bag_changed() -> void:
	if Global != null:
		Global.request_autosave()


# Mid-level build choice (Segment 1 evidence store). Same picker as run
# start, but sequenced: awaits the choice, restores the prior pause state,
# and resets spawn clocks so reading the offer cannot bank a wave.
func present_augment_pick_and_wait() -> void:
	if Global == null or not Global.pending_augment_pick:
		return
	if augment_select != null and is_instance_valid(augment_select):
		return
	_spawn_augment_select()
	if augment_select == null:
		return
	if augment_select.has_signal("augment_chosen"):
		await augment_select.augment_chosen


func _spawn_augment_select() -> void:
	if augment_select_scene == null:
		push_warning("augment_select_scene is null (missing AugmentSelect.tscn)")
		return

	augment_select = augment_select_scene.instantiate() as CanvasLayer
	if augment_select == null:
		push_warning("Failed to instantiate augment_select_scene")
		return

	$UI.add_child(augment_select)

	# make sure UI works while paused
	augment_select.process_mode = Node.PROCESS_MODE_ALWAYS
	augment_select.layer = 100

	# Pause the game while choosing; remember what to restore.
	_augment_prior_paused = get_tree().paused
	get_tree().paused = true

	# connect signal
	if augment_select.has_signal("augment_chosen"):
		augment_select.connect("augment_chosen", Callable(self, "_on_augment_chosen"))
	elif augment_select.has_signal("picked"):
		augment_select.connect("picked", Callable(self, "_on_augment_chosen"))

	# open deferred so AugmentSelect is READY first
	if augment_select.has_method("open_choose_3"):
		augment_select.call_deferred("open_choose_3")
	elif augment_select.has_method("open_for_slot"):
		augment_select.call_deferred("open_for_slot", 0)


func _on_augment_chosen(a: AugmentData) -> void:
	# Even if a == null, unpause so the run can proceed.
	if a != null:
		if OS.is_debug_build():
			print("[Game] augment received id=%s" % a.id)

		# HUD display (optional; AugmentSelect already writes into Global.permanent_augment_ids)
		if hud != null and hud.has_method("add_augment_to_next_slot"):
			hud.call("add_augment_to_next_slot", a)

	if Global != null:
		Global.pending_augment_pick = false
		Global.save_current_profile()

	_unpause_after_augment()


func _unpause_after_augment() -> void:
	get_tree().paused = _augment_prior_paused
	_augment_prior_paused = false

	# A pause the player spent reading must not release as a banked wave.
	for spawner_node in get_tree().get_nodes_in_group(&"enemy_spawner"):
		if spawner_node.has_method("reset_spawn_clock"):
			spawner_node.call("reset_spawn_clock")

	# Remove overlay so it can't visually cover tutorial tips.
	if augment_select != null and is_instance_valid(augment_select):
		augment_select.queue_free()
	augment_select = null

	# Start tutorial intro AFTER the run is actually playable.
	call_deferred("_tutorial_intro_sequence")


func _tutorial_intro_sequence() -> void:
	# Only show ONE intro tip. Everything else is taught by real events.
	if Global == null or Global.tip_shown_intro_move:
		return

	# Ensure we are really running.
	while get_tree().paused:
		await get_tree().process_frame

	# Let HUD settle/bind.
	await get_tree().process_frame
	await get_tree().process_frame

	if RunEvents == null or (not RunEvents.has_signal("tutorial_tip")):
		return

	Global.tip_shown_intro_move = true
	RunEvents.tutorial_tip.emit("WASD to move • Aim with mouse • Click to attack", 3.0)
	Global.request_autosave()


func complete_segment(completed_segment: int) -> void:
	if _segment_completion_running:
		return
	_segment_completion_running = true
	if completed_segment == 1:
		await _present_segment1_overlay(true)
	if Global != null:
		Global.on_segment_completed(completed_segment)
	Global.goto_hub_shop()

func _present_segment1_overlay(completion: bool) -> void:
	if not completion:
		return
	var overlay := SEGMENT1_NARRATIVE_OVERLAY.instantiate() as Segment1NarrativeOverlay
	if overlay == null:
		return
	add_child(overlay)
	get_tree().paused = true
	overlay.present_completion(Global.mortal_name if Global != null else "The Arcanist")
	await overlay.dismissed
	get_tree().paused = false
	overlay.queue_free()

func present_reconstruction(cost: int, remaining: int) -> void:
	if _tutorial_modals == null:
		return
	var mortal: String = Global.mortal_name if Global != null else "The Arcanist"
	if remaining > 0:
		await _tutorial_modals.present_card_and_wait(
			"THE PATTERN COLLAPSES",
			"Your followers preserve the sequence.\n\nTheir belief reconstructs %s at the last rewritten Wardstone.\n\nFollowers lost: %d\nFollowers remaining: %d" % [mortal, cost, remaining],
			"RECONSTRUCTION"
		)
	else:
		await _tutorial_modals.present_card_and_wait(
			"THE PATTERN CANNOT BE RESTORED",
			"No one remains who can complete the sequence.\n\nThis Ascension ends here.",
			"ASCENSION FAILED"
		)


func end_run() -> void:
	if _run_ended:
		return
	_run_ended = true
	# Freeze world processing before clearing the attempt snapshot. This prevents
	# projectiles and spawners from observing half-reset die-die state.
	get_tree().paused = true
	var projectile_manager: ProjectileSimulationManager = get_node_or_null("/root/ProjectileManager") as ProjectileSimulationManager
	if projectile_manager != null:
		projectile_manager.clear_for_run_end()

	var is_die_die: bool = (Global != null and Global.followers <= 0)
	# Read before on_attempt_failed_die_die() resets the attempt snapshot.
	if OS.is_debug_build():
		print("[Game] run ended seg=%d followers=%d wipe=%s" % [
			(Global.attempt_segment if Global != null else -1),
			(Global.followers if Global != null else -1),
			is_die_die,
		])
	if is_die_die and Global != null:
		# Wipe attempt snapshot; keep meta augments/upgrades.
		Global.on_attempt_failed_die_die()

	# The tree is already paused above; without a game-over UI there would be
	# no input path to unpause it, so fall back to the menu instead.
	if game_over_ui_scene == null:
		push_error("end_run: game_over_ui_scene is null; returning to the main menu")
		_quit_to_menu()
		return

	_game_over_ui = game_over_ui_scene.instantiate() as Control
	if _game_over_ui == null:
		push_error("end_run: failed to instantiate game_over_ui_scene; returning to the main menu")
		_quit_to_menu()
		return

	_game_over_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_game_over_ui.z_index = 1000
	$UI.add_child(_game_over_ui)

	if _game_over_ui.has_signal("restart_requested"):
		_game_over_ui.restart_requested.connect(_restart_run)
	if _game_over_ui.has_signal("menu_requested"):
		_game_over_ui.menu_requested.connect(_quit_to_menu)
	if _game_over_ui.has_signal("quit_requested"):
		_game_over_ui.quit_requested.connect(_quit_game)


func _restart_run() -> void:
	get_tree().paused = false

	if Global != null:
		Global.start_new_attempt()

	get_tree().reload_current_scene()


func _quit_to_menu() -> void:
	get_tree().paused = false

	if is_instance_valid(_game_over_ui):
		_game_over_ui.queue_free()

	if SaveManager != null and SaveManager.current_save != null:
		SaveManager.current_save.attempt_resume_scene = Global.PATH_GAME
	if Global != null:
		Global.save_current_profile()
		Global.goto_main_menu()


func _quit_game() -> void:
	get_tree().paused = false
	if Global != null:
		Global.save_current_profile()
	Global.request_quit()
