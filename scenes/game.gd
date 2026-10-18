extends Node2D

const SEGMENT_PROC_BUILDER_SCRIPT := preload("res://core/systems/world/SegmentProcBuilder.gd")
const SEGMENT1_NARRATIVE_OVERLAY := preload("res://ui/screens/Segment1NarrativeOverlay.tscn")
const TUTORIAL_MODAL_CONTROLLER := preload("res://ui/controllers/TutorialModalController.gd")
const OPENING_SEQUENCE_SCENE := preload("res://core/systems/world/opening/OpeningSequenceController.tscn")
const DEV_SEGMENT_SCENE := preload("res://scenes/world/dev_segment/DevSegment.tscn")
const ENEMY_PROXY_ROOT_SCRIPT := preload("res://core/systems/enemy_world/EnemyProxyRoot.gd")
const ENCOUNTER_DIRECTOR_SCRIPT := preload("res://core/systems/encounters/EncounterDirector.gd")
const ESCAPE_RELEASE_SCRIPT := preload("res://core/systems/world/EscapeRelease.gd")

@export var starting_followers: int = 0 # legacy; Bren now becomes the first follower.
@export var game_over_ui_scene: PackedScene
@export var augment_select_scene: PackedScene

@onready var player: Node = $Player
var hud: Control = null
@onready var chunk_manager: ChunkManager = get_node_or_null("ChunkManager") as ChunkManager
var level1_builder: Node2D = null

# IMPORTANT: only ONE augment_select var (no duplicate @onready + var)
var augment_select: CanvasLayer = null
var _augment_prior_paused: bool = false
var _augment_pause_owned: bool = false
var _augment_transition_pending: bool = false
var _augment_generation: int = 0
signal augment_choices_finished

var _game_over_ui: Control = null
var _run_ended: bool = false
var _segment_completion_running: bool = false
var _tutorial_modals: TutorialModalController = null
var _opening_sequence: OpeningSequenceController = null
var _pause_menu: CanvasLayer = null
var _entry_progressive := false
var _initial_world_ready := true
var _entry_detached_children: Array[Node] = []
var _entry_child_order: Array[Node] = []
var _entry_input_owned := false
var _entry_prior_input_disabled := false
var _entry_stage: StringName = &"scene_children"
var _gameplay_binding_pending := true


func _enter_tree() -> void:
	var progressive_entry := Global != null and Global.claim_progressive_game_entry(self)
	if Global != null and Global.has_pending_peep():
		# Child world processing cannot revive the saved terminal snapshot.
		_disable_failed_world()
		return
	if Global == null or not Global.debug_dev_segment:
		# Keep direct-scene startup synchronous. Routed startup can spread its
		# independent HUD and authored-world construction behind LoadingScrim.
		if progressive_entry:
			_entry_progressive = true
			_initial_world_ready = false
			get_tree().paused = true
			_entry_prior_input_disabled = get_viewport().gui_disable_input
			get_viewport().gui_disable_input = true
			_entry_input_owned = true
			_entry_child_order.assign(get_children())
			for child_name in [&"UI", &"Level1"]:
				var child := get_node_or_null(NodePath(child_name))
				if child != null:
					remove_child(child)
					_entry_detached_children.append(child)
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
	if _entry_progressive:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		while not _entry_detached_children.is_empty():
			var child := _entry_detached_children.pop_front() as Node
			_entry_stage = &"hud" if child.name == &"UI" else &"authored_world"
			var console := child.get_node_or_null("PerformanceOverlay") as PerformanceOverlay
			if console != null:
				console.progressive_initialization = true
			var staged_hud := child.get_node_or_null("HUD") as Control
			if staged_hud != null:
				staged_hud.progressive_initialization = true
			if child is Level1Builder:
				(child as Level1Builder).progressive_initialization = true
			add_child(child)
			if staged_hud != null:
				while not staged_hud.initial_world_ready:
					await get_tree().process_frame
					if not is_inside_tree():
						return
			if console != null:
				while not console.initial_world_ready:
					await get_tree().process_frame
					if not is_inside_tree():
						return
			if child is Level1Builder:
				while not (child as Level1Builder).initial_world_ready:
					await get_tree().process_frame
					if not is_inside_tree():
						return
			await get_tree().process_frame
			if not is_inside_tree():
				return
		var next_index := 0
		for child in _entry_child_order:
			if is_instance_valid(child) and child.get_parent() == self:
				move_child(child, next_index)
				next_index += 1
		_entry_child_order.clear()
	_entry_stage = &"bindings"
	hud = get_node_or_null("UI/HUD") as Control
	level1_builder = get_node_or_null("Level1") as Node2D
	get_tree().paused = _entry_progressive
	if Global != null and Global.has_pending_peep():
		Global.goto_resume()
		return
	# A saved mandatory Binding must own the pause before deferred entry work.
	if Global != null and Global.pending_augment_pick and Global.attempt_segment != 1 and not Global.debug_dev_segment:
		_augment_prior_paused = false
		_augment_pause_owned = true
		get_tree().paused = true
	_pause_menu = preload("res://ui/screens/PauseMenu.tscn").instantiate()
	_pause_menu.resume_scene = Global.PATH_GAME
	_pause_menu.can_open = func() -> bool:
		return _initial_world_ready and not _run_ended and not _segment_completion_running and process_mode != Node.PROCESS_MODE_DISABLED and (hud == null or ((hud.bag_ctl == null or not hud.bag_ctl.is_management_mode()) and not is_instance_valid(hud.get("_ascension_screen"))))
	add_child(_pause_menu)
	move_child(_pause_menu, 0)
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

	if _entry_progressive:
		await get_tree().process_frame
		if not is_inside_tree():
			return
	_entry_stage = &"procedural_world"
	await _setup_segment_world()
	if not is_inside_tree():
		return
	if Global != null and Global.has_pending_peep():
		_disable_failed_world()
		Global.goto_resume()
		return
	_setup_enemy_proxy_root()
	call_deferred("_setup_encounter_director")
	_initial_world_ready = true
	_entry_stage = &"ready"
	release_completed_transition_hold()

	# Narrative opening precedes run-level reward UI on a fresh Segment 1.
	call_deferred("_begin_entry_sequence")


func is_transition_ready() -> bool:
	return _initial_world_ready


func scene_transition_pause_state() -> bool:
	# A second route can arrive while this destination still owns its initial
	# setup freeze. Only a mandatory Binding is then a caller-owned pause.
	if _entry_progressive and not _initial_world_ready:
		return _augment_pause_owned
	return get_tree().paused


func release_completed_transition_hold() -> void:
	if not _initial_world_ready or Global.is_scene_transition_active():
		return
	if _gameplay_binding_pending:
		BalanceRecorder.begin_gameplay(player)
		_gameplay_binding_pending = false
	if _entry_input_owned:
		get_tree().paused = _augment_pause_owned
		_release_entry_input()


func _release_entry_input() -> void:
	if _entry_input_owned:
		get_viewport().gui_disable_input = _entry_prior_input_disabled
		_entry_input_owned = false


func _exit_tree() -> void:
	_release_entry_input()
	for child in _entry_detached_children:
		if is_instance_valid(child) and child.get_parent() == null:
			child.free()
	_entry_detached_children.clear()
	_entry_child_order.clear()


## Authored encounter beats on top of the director's continuous pressure
## (roadmap Phase 2.4). Deferred so the spawner and player exist.
func _setup_encounter_director() -> void:
	if Global != null and "debug_encounter_beats" in Global and not bool(Global.get("debug_encounter_beats")):
		return
	var spawner := get_tree().get_first_node_in_group(&"enemy_spawner")
	var player_node := get_tree().get_first_node_in_group(&"player") as Node2D
	if spawner == null or player_node == null:
		return
	var director := ENCOUNTER_DIRECTOR_SCRIPT.new() as Node
	director.name = "EncounterDirector"
	add_child(director)
	director.call("setup", spawner, player_node)


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
		b.set("progressive_initialization", _entry_progressive)
		add_child(b)
		while _entry_progressive and not bool(b.get("initial_world_ready")):
			await get_tree().process_frame
			if not is_inside_tree():
				return
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
	while Global.is_scene_transition_active():
		await get_tree().process_frame
		if not is_inside_tree():
			return
	if Global != null and Global.debug_dev_segment:
		return
	var seg: int = (Global.attempt_segment if Global != null else 1)
	# The district's arrival line and bulletin wait for the run to be playable.
	StoryDirector.attach_segment(self, seg)
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
	if not is_instance_valid(augment_select) and not _augment_transition_pending:
		_spawn_augment_select()
	if not is_instance_valid(augment_select) and not _augment_transition_pending:
		return
	await augment_choices_finished


func _spawn_augment_select() -> void:
	if is_instance_valid(augment_select) or _augment_transition_pending:
		return
	if augment_select_scene == null:
		push_warning("augment_select_scene is null (missing AugmentSelect.tscn)")
		return
	var screen := augment_select_scene.instantiate() as CanvasLayer
	if screen == null:
		push_warning("Failed to instantiate augment_select_scene")
		return
	# One pause owner spans every earned choice. A second popup must not
	# replace the genuine pre-choice pause with the first popup's pause.
	if not _augment_pause_owned:
		_augment_prior_paused = get_tree().paused
		_augment_pause_owned = true
	get_tree().paused = true
	_augment_generation += 1
	augment_select = screen
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.layer = 100
	$UI.add_child(screen)
	var chosen := Callable(self, "_on_augment_chosen").bind(screen.get_instance_id(), _augment_generation)
	if screen.has_signal("augment_chosen"):
		screen.connect("augment_chosen", chosen)
	elif screen.has_signal("picked"):
		screen.connect("picked", chosen)
	if screen.has_method("open_choose_3"):
		screen.call_deferred("open_choose_3")
	elif screen.has_method("open_for_slot"):
		screen.call_deferred("open_for_slot", 0)


func _on_augment_chosen(a: AugmentData, source_id: int = 0, generation: int = -1) -> void:
	if not is_instance_valid(augment_select) or _augment_transition_pending:
		return
	if source_id != 0 and (augment_select.get_instance_id() != source_id or generation != _augment_generation):
		return
	if a != null:
		if OS.is_debug_build():
			print("[Game] augment received id=%s" % a.id)
		if hud != null and hud.has_method("add_augment_to_next_slot"):
			hud.call("add_augment_to_next_slot", a)
	# AugmentSelect has already applied the card through Global. Global alone
	# consumes the reward and decides whether another earned Binding remains.
	if Global != null:
		Global.save_current_profile()
	var closing := augment_select
	augment_select = null
	_augment_transition_pending = true
	closing.queue_free()
	_after_augment_screen_closed(closing, _augment_generation)


func _after_augment_screen_closed(closing: CanvasLayer, generation: int) -> void:
	var tree := get_tree()
	if is_instance_valid(closing) and closing.is_inside_tree():
		await closing.tree_exited
	# The selecting input release must finish before the next popup exists.
	# World processing stays paused throughout this transition.
	await tree.process_frame
	if not is_inside_tree() or generation != _augment_generation:
		return
	_augment_transition_pending = false
	if Global != null and Global.pending_augment_pick:
		_spawn_augment_select()
	else:
		_unpause_after_augment()


func _unpause_after_augment() -> void:
	if _augment_pause_owned:
		# The pause menu can open over a closing choice (its fly-out and the
		# input-release frame). Hand it the pause rather than running the world
		# under it, where its Resume would restore a pause nothing owns.
		var handed_off := not _augment_prior_paused and is_instance_valid(_pause_menu) and bool(_pause_menu.call("adopt_pause_handoff"))
		if not handed_off:
			get_tree().paused = _augment_prior_paused
	_augment_prior_paused = false
	_augment_pause_owned = false
	_augment_transition_pending = false
	# Reading either offer must not release as a banked spawn wave.
	for spawner_node in get_tree().get_nodes_in_group(&"enemy_spawner"):
		if spawner_node.has_method("reset_spawn_clock"):
			spawner_node.call("reset_spawn_clock")
	if is_instance_valid(augment_select):
		augment_select.queue_free()
	augment_select = null
	augment_choices_finished.emit()
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
	var labels := preload("res://ui/controllers/TutorialInputLabels.gd")
	RunEvents.tutorial_tip.emit("%s to move • Aim at a target • %s to attack" % [labels.movement(), labels.action(&"attack")], 3.0)
	Global.request_autosave()


func complete_segment(completed_segment: int) -> void:
	if _segment_completion_running or _run_ended:
		return
	if Global == null or not Global.begin_segment_completion(completed_segment):
		return
	_segment_completion_running = true
	# The escape is an event before it is a loading screen (2026-10-04 audit):
	# the world exhales around the player for a couple of seconds first.
	await _play_escape_release()
	if _run_ended or Global.has_pending_peep():
		return
	if completed_segment == 1:
		await _present_segment1_overlay(true)
	else:
		await _present_chapter_close(completed_segment)
	if _run_ended or Global.has_pending_peep():
		return
	if Global.finish_segment_completion(completed_segment):
		Global.goto_hub_shop()
	else:
		# An out-of-sequence completion (developer tools today) must not strand
		# the player in a finished segment with the pause menu blocked.
		_segment_completion_running = false
		Global.goto_resume()

func _play_escape_release() -> void:
	if player == null or not is_instance_valid(player) or not (player is Node2D):
		return
	if bool(player.get("is_dead")):
		return
	var release := ESCAPE_RELEASE_SCRIPT.new()
	release.name = "EscapeRelease"
	add_child(release)
	await release.play(player as Node2D)
	if is_instance_valid(release):
		release.queue_free()

## The segment-10 close (story layer F11): a chapter card in Segment 1's
## frame, not an ending - the run continues beyond the wall. Cards never
## block a headless run or a tool that opted out (StoryDirector.cards_allowed),
## and the first-time flag is only marked when the card is actually shown.
func _present_chapter_close(completed_segment: int) -> void:
	if not StoryDirector.cards_allowed():
		return
	var card := StoryDirector.chapter_close_card(completed_segment)
	if card.is_empty():
		return
	var overlay := SEGMENT1_NARRATIVE_OVERLAY.instantiate() as Segment1NarrativeOverlay
	if overlay == null:
		return
	add_child(overlay)
	get_tree().paused = true
	overlay.present_card(String(card.get("eyebrow", "")), String(card.get("title", "")), String(card.get("body", "")), String(card.get("button", "Continue")))
	await overlay.dismissed
	get_tree().paused = false
	overlay.queue_free()

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
	# Terminal intent must be durable before any card can suspend the death
	# sequence. PeeP is the terminal presentation; ordinary rebuilding keeps
	# its existing card and Follower cost.
	if remaining <= 0:
		end_run()
		return
	if _tutorial_modals == null:
		return
	await _tutorial_modals.present_card_and_wait(
		"THE PATTERN COLLAPSES",
		StoryDirector.reconstruction_body(cost, remaining),
		"RECONSTRUCTION"
	)


func _disable_failed_world() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	# Explicitly disable descendants too: ALWAYS nodes ignore their parent's
	# mode, and the root scheduler checks an actor's own mode before dispatch.
	for node in find_children("*", "", true, false):
		node.process_mode = Node.PROCESS_MODE_DISABLED


func _pause_failed_world_until_physics_flush() -> void:
	# Native area/body signals may still be flushing collision queries. Keep
	# this subtree paused without disabling CollisionObjects in that callback.
	if process_mode != Node.PROCESS_MODE_DISABLED:
		process_mode = Node.PROCESS_MODE_PAUSABLE
	for node in find_children("*", "", true, false):
		if node.process_mode in [Node.PROCESS_MODE_ALWAYS, Node.PROCESS_MODE_WHEN_PAUSED]:
			node.process_mode = Node.PROCESS_MODE_PAUSABLE


func _finish_physics_failed_world() -> void:
	_disable_failed_world()
	get_tree().paused = false
	Global.goto_resume()


func end_run() -> void:
	if _run_ended:
		return
	_run_ended = true
	# Freeze world processing before clearing the attempt snapshot. This prevents
	# projectiles and spawners from observing half-reset die-die state.
	get_tree().paused = true
	# Nothing that slowed the clock (a Revelation, a hit-stop) can expire it
	# once the tree is paused; the run's end always hands back real time.
	Engine.time_scale = 1.0

	var is_die_die: bool = (Global != null and Global.followers <= 0)
	var defer_failed_world: bool = is_die_die and Engine.is_in_physics_frame()
	# Read before on_attempt_failed_die_die() resets the attempt snapshot.
	if OS.is_debug_build():
		print("[Game] run ended seg=%d followers=%d wipe=%s" % [
			(Global.attempt_segment if Global != null else -1),
			(Global.followers if Global != null else -1),
			is_die_die,
		])
	if is_die_die and Global != null:
		if defer_failed_world:
			_pause_failed_world_until_physics_flush()
		else:
			_disable_failed_world()
		Global.begin_peep_continuation()

	var projectile_manager: ProjectileSimulationManager = get_node_or_null("/root/ProjectileManager") as ProjectileSimulationManager
	if projectile_manager != null:
		projectile_manager.clear_for_run_end()

	if is_die_die and Global != null:
		# Root-owned DOT ticks must not finish kills after the world is frozen.
		# This is ephemeral combat cleanup after the durable outcome snapshot.
		var enemy_status := get_node_or_null("/root/EnemyStatus") as EnemyStatusService
		if enemy_status != null:
			enemy_status.clear_all()
		if defer_failed_world:
			call_deferred(&"_finish_physics_failed_world")
			return
		get_tree().paused = false
		Global.goto_resume()
		return

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
