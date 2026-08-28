extends Node2D
class_name SegmentProcBuilder

@export var cell_size_px: int = 64

# "Resonance" is just a name for: "enough chaos + belief accumulated to punch through".
@export_range(0.0, 1.0, 0.01) var resonance: float = 0.0

# --- Resonance pacing (proc segments) ---
# Design goals:
# - Gate unseals in ~3 minutes in "normal" play (not < 1 minute).
# - Progress does not stall if the spawn table is temporarily light (ambient gain).
# - Big kill spikes (AOE / chokepoint) don't instantly finish the segment (bonus gain is rate-limited).
@export var resonance_per_kill: float = 0.0010
@export var resonance_per_elite_kill: float = 0.0040
@export var resonance_per_item_rarity: float = 0.0015
@export var resonance_per_sec: float = 0.00342

# Caps how fast *bonus* resonance (kills + items) can be applied.
# This prevents "instant unseal" when a build starts deleting packs.
@export var resonance_bonus_cap_per_sec: float = 0.0030
@export var primary_completion_resonance: float = 0.18

# Early boost so the bar visibly moves in the first ~30s (reduces "job" feeling).
@export var resonance_early_boost_seconds: float = 30.0
@export var resonance_early_boost_mul: float = 1.20

# How often we tick resonance/UI from ambient + buffered bonus.
@export var resonance_tick_interval: float = 0.25
@export_range(0.0, 1.0, 0.01) var gate_marker_reveal_resonance: float = 0.75

# Scenes
const WARDSTONE_SCENE: PackedScene = preload("res://scenes/world/wardstones/Wardstone.tscn")
const EXIT_RITE_SCENE: PackedScene = preload("res://scenes/world/gates/ExitRite.tscn")
const MINIBOSS_ARENA_SCENE: PackedScene = preload("res://scenes/world/events/MiniBossArena.tscn")
const BOSS_ARENA_SCENE: PackedScene = preload("res://scenes/world/events/BossArena.tscn")
const CURSED_VAULT_SCRIPT: Script = preload("res://core/systems/world/CursedVault.gd")

var _res_tick: float = 0.0
var _time_in_segment: float = 0.0
var _pending_bonus_res: float = 0.0

var _cm: ChunkManager = null
var _player: Node2D = null
var _exit_rite: ExitRite = null
var _primary_objective: PrimaryObjective = null
var _segment: int = 1
var _plan: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _theme: SegmentThemeData = null
var _boss_required: bool = false
var _miniboss_required: bool = false
var _miniboss_defeated: bool = false
var _boss_defeated: bool = false
var _primary_completed: bool = false
var _primary_done_count: int = 0
var _primary_total_count: int = 3
var _pressure_phase: StringName = &"recon"
var _secondary_objectives: Array[Dictionary] = []
var _secondary_completed: Dictionary = {}
var _active_secondary_id: int = -1
var _secondary_feedback_token: int = 0
var _rite_safeguard_sources: Dictionary = {}

@export_group("Procedural Debug")
@export var debug_proc_state: bool = false

func _ready() -> void:
	add_to_group(&"segment_proc_builder")
	_segment = (Global.attempt_segment if Global != null else 1)
	if _segment <= 1:
		queue_free()
		return

	_cm = get_tree().get_first_node_in_group("chunk_manager") as ChunkManager
	_player = get_tree().get_first_node_in_group("player") as Node2D

	if _cm == null:
		push_warning("[SegmentProcBuilder] ChunkManager not found.")
		queue_free()
		return
	if _player == null:
		push_warning("[SegmentProcBuilder] Player not found (group 'player').")
		queue_free()
		return

	# Ensure we have a seed for this attempt (Continue-safe).
	if Global != null and Global.attempt_world_seed == 0:
		Global.attempt_world_seed = int(Time.get_unix_time_from_system() * 1000.0) ^ randi()
		Global.save_current_profile()

	var seed_base: int = (Global.attempt_world_seed if Global != null else 1337)
	_theme = SegmentThemePicker.get_theme(_segment, seed_base)
	_boss_required = (_theme != null and _theme.end_mode == "BOSS_GATE")
	_miniboss_required = (_segment == 5)
	_miniboss_defeated = false
	_boss_defeated = false
	_plan = DistrictPlan.generate(_segment, seed_base, _cm.chunk_size_px, _theme)
	_secondary_objectives.clear()
	_secondary_completed.clear()
	_active_secondary_id = -1
	var fallback_secondary_id: int = 1
	for secondary_variant in _plan.get("secondary_objectives", []):
		var secondary: Dictionary = (secondary_variant as Dictionary).duplicate(true)
		if int(secondary.get("id", 0)) <= 0:
			secondary["id"] = fallback_secondary_id
		fallback_secondary_id += 1
		_secondary_objectives.append(secondary)
	var debug_main_route: Array = _plan.get("main_route", [])
	var debug_exploration: Array = _plan.get("exploration_chunks", [])
	var debug_rewards: Array = _plan.get("reward_chunks", [])
	var validation: Dictionary = _plan.get("validation", {}) as Dictionary
	print("[SegmentProcBuilder] Theme=", _theme.label if _theme != null else "Legacy", " main=", debug_main_route.size(), " explore=", debug_exploration.size(), " rewards=", debug_rewards.size(), " validation=", validation)

	_rng.seed = int(_plan.get("seed", 1337)) ^ 0xA53C9E1

	_apply_segment_rules()
	_build_world_from_plan()
	_hook_resonance()
	_hook_secondary_objectives()
	set_process(true)
	_set_pressure_phase(&"recon")
	_push_objective_ui()

	# Initial gate lock state
	_update_gate_lock()
	_update_gate_marker()
	_push_resonance_ui()
	_clear_secondary_objective_ui()
	_announce_secondaries()

func _announce_secondaries() -> void:
	# "A secondary appeared" was a designed feedback moment with no signal
	# behind it: tell the player up front the district holds optional work.
	if _secondary_objectives.is_empty():
		return
	if RunEvents == null or not RunEvents.has_signal("tutorial_tip"):
		return
	var n := _secondary_objectives.size()
	var text := (
		"1 optional signal detected in this district."
		if n == 1
		else "%d optional signals detected in this district." % n
	)
	RunEvents.tutorial_tip.emit(text, 4.0)

func _exit_tree() -> void:
	_unhook_resonance()
	_unhook_secondary_objectives()
	_clear_secondary_objective_ui()
	if Global != null:
		Global.objective_target_pos = Vector2.INF

func _process(delta: float) -> void:
	_check_secondary_objective_discovery()
	if resonance >= 1.0:
		if _pressure_phase != &"collapse":
			_set_pressure_phase(&"collapse")
		_push_objective_ui()
		return

	_time_in_segment += delta
	_res_tick += delta
	if _res_tick < resonance_tick_interval:
		return

	var dt := _res_tick
	_res_tick = 0.0

	# Ambient resonance backbone — but only once the primary objective is
	# done (the pacing test has always described it that way: "finishes near
	# four minutes AFTER primary completion"). Before that, Resonance comes
	# from actions: the relay, wardstones, secondaries, kills and loot.
	var ambient := (resonance_per_sec * dt) if _primary_completed else 0.0

	# Small early boost to reduce "slow start" feel.
	if ambient > 0.0 and resonance_early_boost_seconds > 0.0 and _time_in_segment < resonance_early_boost_seconds:
		var t := clampf(_time_in_segment / resonance_early_boost_seconds, 0.0, 1.0)
		ambient *= lerpf(resonance_early_boost_mul, 1.0, t)

	# Apply buffered bonus resonance at a capped rate (kills/items).
	var bonus_cap := maxf(0.0, resonance_bonus_cap_per_sec) * dt
	var bonus := minf(_pending_bonus_res, bonus_cap)
	_pending_bonus_res -= bonus

	resonance += ambient + bonus
	resonance = clampf(resonance, 0.0, 1.0)
	if resonance >= 0.999 and _pressure_phase != &"collapse":
		_set_pressure_phase(&"collapse")

	_update_gate_lock()
	_update_gate_marker()
	_push_resonance_ui()
	_push_objective_ui()

func _jitter_in_chunk(world_center: Vector2, max_cells: int) -> Vector2:
	# Jitter inside the chunk so wardstones/gate aren't always dead-center.
	# Keep it modest so it stays inside the open plaza/arena that ChunkManager generates.
	if _cm == null:
		return world_center
	var j := float(_cm.cell_size_px) * float(max_cells)
	return world_center + Vector2(_rng.randf_range(-j, j), _rng.randf_range(-j, j))

# ------------------------------------------------------------
# World build
# ------------------------------------------------------------

func _apply_segment_rules() -> void:
	# Theme-driven world feel. Each Area 1 segment now selects a progression-aware
	# district identity while preserving deterministic layouts for the attempt seed.
	if _theme != null:
		_theme.apply_to_chunk_manager(_cm)
		_apply_urban_slice_defaults()
		return

	# Legacy fallback (should rarely happen)
	if _segment == 2:
		_cm.weight_empty = 0.88
		_cm.weight_building = 0.08
		_cm.weight_ruins = 0.04
		_cm.district_lane_width_cells = 14
		_cm.district_plaza_size_cells = 20
		_cm.district_gap_chance = 0.16
		_cm.district_window_chance = 0.14
		_cm.donjon_strength = 0.15
		_cm.donjon_room_attempts = 14
		_cm.donjon_fill_wall_chance = 0.52
		_cm.donjon_ca_steps = 3
	elif _segment == 3:
		_cm.weight_empty = 0.45
		_cm.weight_building = 0.35
		_cm.weight_ruins = 0.20
		_cm.district_lane_width_cells = 10
		_cm.district_plaza_size_cells = 16
		_cm.district_gap_chance = 0.06
		_cm.district_window_chance = 0.10
		_cm.donjon_strength = 0.78
		_cm.donjon_room_attempts = 26
		_cm.donjon_fill_wall_chance = 0.48
		_cm.donjon_ca_steps = 4
	else:
		# Smooth ramp: later segments get a bit denser.
		var t := clampf(float(_segment - 3) / 7.0, 0.0, 1.0)
		_cm.weight_empty = lerpf(0.50, 0.38, t)
		_cm.weight_building = lerpf(0.30, 0.40, t)
		_cm.weight_ruins = lerpf(0.20, 0.22, t)
		_cm.donjon_strength = lerpf(0.55, 0.70, t)
		_cm.donjon_room_attempts = int(round(lerpf(18.0, 24.0, t)))
		_cm.donjon_fill_wall_chance = lerpf(0.52, 0.44, t)
		_cm.donjon_ca_steps = int(round(lerpf(4.0, 5.0, t)))
	_apply_urban_slice_defaults()

func _apply_urban_slice_defaults() -> void:
	_cm.district_sidewalk_width_cells = 1
	_cm.district_sidewalk_corner_pad_cells = 1
	_cm.parcels_chunk_chance = 0.95
	_cm.parcels_chance_per_side = 0.80
	_cm.parcels_max_per_side = 2

func _build_world_from_plan() -> void:
	_cm.clear_manual_blocks()
	var conns: Dictionary = _plan.get("connectors_by_chunk", {})
	var urban_access: Dictionary = _plan.get("urban_access_by_chunk", {})
	var roles: Dictionary = _plan.get("role_by_chunk", {})
	var terrain: Dictionary = _plan.get("terrain_by_chunk", {})
	var arch: Dictionary = _plan.get("archetype_by_chunk", {})
	_cm.configure_procedural_world(
		int(_plan.get("seed", 1337)),
		conns,
		urban_access,
		roles,
		terrain,
		arch
	)

	# Move the player to the segment start and set their default checkpoint.
	# A saved wardstone checkpoint from this attempt takes priority (mirrors
	# Level1Builder): resuming mid-segment used to silently overwrite it and
	# dump the player back at the district entrance.
	var start_world: Vector2 = _plan.get("start_world", Vector2.ZERO)
	if Global != null and Global.attempt_checkpoint_pos != Vector2.INF:
		start_world = Global.attempt_checkpoint_pos
	if _player != null and _player.has_method("set_checkpoint"):
		_player.call("set_checkpoint", start_world, true)
	else:
		_player.global_position = start_world

	# The manager remains dormant until the full semantic plan and checkpoint are
	# installed, so startup creates the center exactly once.
	_cm.start_streaming(start_world)

	# Spawn objective, wardstones and exit gate after chunks exist so visuals sit on top cleanly.
	_spawn_primary_objective()
	_spawn_wardstones()
	_spawn_exit_gate()
	_spawn_segment_events()
	_spawn_secondary_nodes()

func _spawn_primary_objective() -> void:
	var objective_world: Vector2 = _plan.get("primary_world", Vector2.ZERO) as Vector2
	# The type is chosen from the seed rather than hardcoded here. That choice
	# used to live in this function AND its wording lived in _push_objective_ui,
	# which is why there was only ever one objective: a second one meant editing
	# the builder in two places instead of adding a file.
	_primary_objective = PrimaryObjectiveCatalog.create_for(
		_segment, int(_plan.get("seed", 1337)) ^ 0x51A7CE
	)
	if _primary_objective == null:
		push_warning("[SegmentProcBuilder] No primary objective could be built; bypassing the primary gate to keep the run recoverable.")
		_primary_completed = true
		return
	_primary_objective.global_position = objective_world
	_primary_objective.activated.connect(_on_primary_activated)
	_primary_objective.progress_changed.connect(_on_primary_progress_changed)
	_primary_objective.completed.connect(_on_primary_completed)
	add_child(_primary_objective)
	if Global != null:
		Global.objective_target_pos = objective_world

func _spawn_wardstones() -> void:
	var wards: Array = _plan.get("wardstone_world", [])
	for ward_index in range(wards.size()):
		var p: Vector2 = wards[ward_index]
		var s := WARDSTONE_SCENE.instantiate() as Wardstone
		if s == null:
			continue

		# Jitter around the arena center so repeated attempts don't feel identical.
		# Using 3-5 cells keeps us inside the "open core" of arena chunks.
		var max_cells := (5 if _segment == 2 else 4)
		var pos := _jitter_in_chunk(p as Vector2, max_cells)

		s.global_position = pos
		add_child(s)
		# Attuning a wardstone is a meaningful act: it feeds the bar.
		s.activated.connect(_on_wardstone_activated.bind(ward_index))


func _on_wardstone_activated(_stone: Wardstone, ward_index: int) -> void:
	grant_resonance(0.06, true)
	register_rite_safeguard_source(StringName("wardstone:%d" % ward_index))

func _spawn_exit_gate() -> void:
	var p: Vector2 = _plan.get("exit_world", Vector2.ZERO)

	# Jitter the gate inside its gate/plaza chunk.
	# Keep smaller than wardstones so the "end" still reads consistent.
	var pos := _jitter_in_chunk(p, 3)

	_exit_rite = EXIT_RITE_SCENE.instantiate() as ExitRite
	if _exit_rite == null:
		return
	_exit_rite.revealed = _primary_completed
	# The gate can exist in the world after the relay, but its HUD location remains
	# hidden until SegmentProcBuilder triangulates it at the resonance threshold.
	_exit_rite.hide_location_while_locked = true
	_exit_rite.global_position = pos
	add_child(_exit_rite)
	_exit_rite.cleared.connect(_on_gate_cleared)
	_replay_rite_safeguard_sources()
	if not _primary_completed:
		_exit_rite.set_revealed(false)


## Most secondaries are consequences of a chunk ROLE - a loot spawner at a dead
## end, a forced building with an encounter in it. The wager shrine is a
## gameplay node with its own state, so it is spawned imperatively from the plan
## the way the relay, the wardstones and the Exit Rite are.
func _spawn_secondary_nodes() -> void:
	for secondary in _secondary_objectives:
		if StringName(secondary.get("type", &"")) != &"wager_shrine":
			continue
		var shrine := WagerShrineObjective.new()
		shrine.name = "WagerShrine%d" % int(secondary.get("id", 0))
		shrine.configure(int(secondary.get("id", 0)))
		shrine.global_position = _jitter_in_chunk(secondary.get("world", Vector2.ZERO) as Vector2, 3)
		add_child(shrine)


func _spawn_segment_events() -> void:
	# Miniboss arena (required on segment 5; rare optional on later segments).
	var mb_world: Vector2 = _plan.get("miniboss_world", Vector2.ZERO)
	if _segment >= 5 and mb_world != Vector2.ZERO:
		var a := MINIBOSS_ARENA_SCENE.instantiate()
		if a != null:
			# Segment 5 now has a dedicated pre-gate arena chunk. Do not stack the
			# miniboss on top of the Exit Rite; the plan already placed it one chunk earlier.
			var pos := _jitter_in_chunk(mb_world, 2)
			(a as Node2D).global_position = pos
			add_child(a)

	# Cursed Vault (roadmap 2.5): one deliberate risk/reward off the main
	# route, at the reward chunk farthest from the start, from segment 2 on.
	_spawn_cursed_vault()

	# Segment 10: boss arena (capstone). Boss spawns and gate stays locked until dead.
	var b_world: Vector2 = _plan.get("boss_world", Vector2.ZERO)
	if _segment == 10 and b_world != Vector2.ZERO:
		var b := BOSS_ARENA_SCENE.instantiate()
		if b != null:
			(b as Node2D).global_position = _jitter_in_chunk(b_world, 2)
			add_child(b)

func _spawn_cursed_vault() -> void:
	if _segment < 2:
		return
	if Global != null and "debug_cursed_vault" in Global and not bool(Global.get("debug_cursed_vault")):
		return
	var reward_chunks: Array = _plan.get("reward_chunks", [])
	if reward_chunks.is_empty() or _cm == null:
		return
	var start_chunk: Vector2i = _plan.get("start_chunk", Vector2i.ZERO)
	var exit_chunk: Vector2i = _plan.get("exit_chunk", Vector2i(-99999, -99999))
	var best := Vector2i(-99999, -99999)
	var best_distance := -1.0
	for chunk_variant in reward_chunks:
		var chunk := chunk_variant as Vector2i
		if chunk == exit_chunk:
			continue
		var distance := Vector2(chunk - start_chunk).length()
		if distance > best_distance:
			best_distance = distance
			best = chunk
	if best_distance < 0.0:
		return
	var chunk_size := float(_cm.chunk_size_px)
	var center := Vector2((float(best.x) + 0.5) * chunk_size, (float(best.y) + 0.5) * chunk_size)
	var vault := CURSED_VAULT_SCRIPT.new() as Node2D
	vault.name = "CursedVault"
	vault.global_position = _jitter_in_chunk(center, 2)
	add_child(vault)


func grant_resonance(amount: float, immediate: bool = true) -> void:
	if amount <= 0.0:
		return
	if immediate:
		resonance = clampf(resonance + amount, 0.0, 1.0)
		_update_gate_lock()
		_update_gate_marker()
		_push_resonance_ui()
		_push_objective_ui()
		if resonance >= 0.999:
			_set_pressure_phase(&"collapse")
		return
	_pending_bonus_res += amount
	_pending_bonus_res = minf(_pending_bonus_res, 1.0)

func set_boss_defeated() -> void:
	_boss_defeated = true
	_update_gate_lock()
	_push_objective_ui()
	_push_resonance_ui()

func set_miniboss_defeated() -> void:
	_miniboss_defeated = true
	_update_gate_lock()
	_push_objective_ui()
	_push_resonance_ui()

func is_boss_defeated() -> bool:
	return _boss_defeated

# ------------------------------------------------------------
# Gate completion
# ------------------------------------------------------------

func _on_gate_cleared(_r: ExitRite) -> void:
	var game := get_tree().current_scene
	if game != null and game.has_method("complete_segment"):
		var seg: int = (Global.attempt_segment if Global != null else _segment)
		game.call_deferred("complete_segment", seg)
	elif game != null and game.has_method("end_run"):
		game.call_deferred("end_run")

# ------------------------------------------------------------
# Primary objective + pressure phases
# ------------------------------------------------------------

func _on_primary_activated() -> void:
	if _primary_completed:
		return
	_set_pressure_phase(&"disturbance")
	var spawner := get_tree().get_first_node_in_group(&"enemy_spawner") as EnemySpawner
	if spawner != null:
		spawner.spawn_burst(5)
	_push_objective_ui()

func _on_primary_progress_changed(done: int, total: int) -> void:
	_primary_done_count = maxi(0, done)
	_primary_total_count = maxi(1, total)
	_push_objective_ui()

func _on_primary_completed() -> void:
	if _primary_completed:
		return
	_primary_completed = true
	_primary_done_count = _primary_total_count
	grant_resonance(primary_completion_resonance, true)
	if _exit_rite != null:
		_exit_rite.set_revealed(true)
	_update_gate_marker()
	_set_pressure_phase(&"collapse" if resonance >= 0.999 else &"ascension")
	var spawner := get_tree().get_first_node_in_group(&"enemy_spawner") as EnemySpawner
	if spawner != null:
		spawner.spawn_burst(7)
	_update_gate_lock()
	_push_objective_ui()

func _set_pressure_phase(next_phase: StringName) -> void:
	if _pressure_phase == next_phase and next_phase != &"recon":
		return
	_pressure_phase = next_phase
	var label: String = _phase_label(next_phase)
	var director := get_node_or_null("/root/ThreatDirector")
	if director != null and director.has_method("set_segment_phase"):
		director.call("set_segment_phase", next_phase)
	if RunEvents != null and RunEvents.has_signal("segment_phase_changed"):
		RunEvents.segment_phase_changed.emit(next_phase, label)
	if debug_proc_state:
		print("[SegmentProcBuilder] seed=", int(_plan.get("seed", 0)), " phase=", label, " primary=", _primary_completed, " exit_revealed=", _exit_rite != null and _exit_rite.revealed, " validation=", _plan.get("validation", {}))

func _phase_label(phase: StringName) -> String:
	match phase:
		&"disturbance": return "DISTURBANCE"
		&"ascension": return "ASCENSION"
		&"collapse": return "COLLAPSE"
		_: return "RECON"

## The objective owns its own wording; these are the fallbacks for the window
## between "the objective failed to build" and "the run bypassed the gate".
func _primary_title() -> String:
	if _primary_objective != null and is_instance_valid(_primary_objective):
		return _primary_objective.objective_title()
	return "Primary Objective"


func _primary_detail() -> String:
	if _primary_objective != null and is_instance_valid(_primary_objective):
		return _primary_objective.objective_detail()
	return "%d/%d • The exit remains hidden" % [_primary_done_count, _primary_total_count]


func _primary_checklist_label() -> String:
	if _primary_objective != null and is_instance_valid(_primary_objective):
		return _primary_objective.checklist_label()
	return "Primary objective complete"


func _primary_checklist_id() -> StringName:
	if _primary_objective != null and is_instance_valid(_primary_objective):
		return _primary_objective.checklist_id()
	return &"primary"


func _push_objective_ui() -> void:
	if RunEvents == null or not RunEvents.has_signal("objective_changed"):
		return
	if not _primary_completed:
		# Ask the objective what it is called and what it wants. Anything else
		# means every new objective type has to be taught to this function.
		RunEvents.objective_changed.emit(
			"%s • %s" % [_primary_title(), _phase_label(_pressure_phase)],
			_primary_detail()
		)
		_emit_gate_checklist(&"locked", [], "")
		return

	var percent: int = int(round(clampf(resonance, 0.0, 1.0) * 100.0))
	var marker_percent: int = int(round(clampf(gate_marker_reveal_resonance, 0.0, 1.0) * 100.0))
	var resonance_complete: bool = resonance >= 0.999
	var miniboss_complete: bool = (not _miniboss_required) or _miniboss_defeated
	var boss_complete: bool = (not _boss_required) or _boss_defeated
	var gate_ready: bool = resonance_complete and miniboss_complete and boss_complete
	var marker_visible: bool = resonance >= gate_marker_reveal_resonance

	var gate_state: StringName = &"locked"
	if gate_ready:
		gate_state = &"ready"
	elif marker_visible:
		gate_state = &"located"

	var items: Array = []
	items.append({"id": _primary_checklist_id(), "label": _primary_checklist_label(), "done": true})
	items.append({"id": &"resonance", "label": "Resonance 100%% (%d%%)" % percent, "done": resonance_complete})
	if _miniboss_required:
		items.append({"id": &"miniboss", "label": "Miniboss defeated", "done": _miniboss_defeated})
	if _boss_required:
		items.append({"id": &"boss", "label": "District boss defeated", "done": _boss_defeated})

	var guidance: String
	if not marker_visible:
		guidance = "Next: reach %d%% resonance to reveal the gate marker" % marker_percent
	elif not resonance_complete:
		guidance = "Marker revealed • build resonance to 100%"
	elif _miniboss_required and not _miniboss_defeated:
		guidance = "Next: defeat the miniboss guarding the route"
	elif _boss_required and not _boss_defeated:
		guidance = "Next: defeat the district boss"
	else:
		guidance = "All conditions met • follow the orange gate marker"

	# The checklist owns the complete post-primary gate state. Keeping an
	# ordinary objective alive here presents the same rite twice with two
	# different visual grammars, and makes the evacuation banner a third copy
	# once the gate opens.
	RunEvents.objective_changed.emit("", "")
	_emit_gate_checklist(gate_state, items, guidance)


func _emit_gate_checklist(state: StringName, items: Array, next_hint: String) -> void:
	if RunEvents == null or not RunEvents.has_signal("gate_checklist_changed"):
		return
	RunEvents.gate_checklist_changed.emit(state, items, next_hint)

func _check_secondary_objective_discovery() -> void:
	if _secondary_objectives.is_empty() or not is_instance_valid(_player) or not is_instance_valid(_cm):
		if _active_secondary_id != -1:
			_active_secondary_id = -1
			_clear_secondary_objective_ui()
		return
	var chunk_size: float = float(_cm.chunk_size_px)
	if chunk_size <= 0.0:
		return
	var nearby_objective: Dictionary = {}
	var best_distance_sq: float = INF
	var activation_radius: float = chunk_size * 0.72
	var activation_radius_sq: float = activation_radius * activation_radius
	for objective_variant in _secondary_objectives:
		var objective: Dictionary = objective_variant as Dictionary
		var objective_id: int = int(objective.get("id", 0))
		if objective_id <= 0 or _secondary_completed.has(objective_id):
			continue
		var objective_chunk: Vector2i = objective.get("chunk", DistrictPlan.INVALID_CHUNK) as Vector2i
		var fallback_world := Vector2(
			(float(objective_chunk.x) + 0.5) * chunk_size,
			(float(objective_chunk.y) + 0.5) * chunk_size
		)
		var objective_world: Vector2 = objective.get("world", fallback_world) as Vector2
		var distance_sq: float = _player.global_position.distance_squared_to(objective_world)
		if distance_sq <= activation_radius_sq and distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			nearby_objective = objective

	if nearby_objective.is_empty():
		if _active_secondary_id != -1:
			_active_secondary_id = -1
			_clear_secondary_objective_ui()
		return

	var nearby_id: int = int(nearby_objective.get("id", 0))
	if nearby_id == _active_secondary_id:
		return
	_active_secondary_id = nearby_id
	_show_secondary_objective(nearby_objective)

func _show_secondary_objective(objective: Dictionary) -> void:
	if RunEvents == null or not RunEvents.has_signal("secondary_objective_changed"):
		return
	_secondary_feedback_token += 1
	var objective_type: StringName = objective.get("type", &"") as StringName
	var title: String = "SECONDARY • Optional Opportunity"
	var detail: String = "Explore this district pocket for an additional reward."
	match objective_type:
		&"dangerous_alley_cache":
			title = "SECONDARY • Dangerous Alley Cache"
			detail = "Search the alley endpoint for a guarded hidden cache."
		&"searchable_reward_building":
			title = "SECONDARY • Searchable Building"
			detail = "Enter and search the building for its optional reward."
		&"wager_shrine":
			title = "SECONDARY • Wager Shrine"
			detail = "Stand in the shrine to raise the stake. Step out to settle it."
	RunEvents.secondary_objective_changed.emit(title, detail)

func _hook_secondary_objectives() -> void:
	if RunEvents == null or not RunEvents.has_signal("secondary_objective_completed"):
		return
	var callback := Callable(self, "_on_secondary_objective_completed")
	if not RunEvents.secondary_objective_completed.is_connected(callback):
		RunEvents.secondary_objective_completed.connect(callback)

func _unhook_secondary_objectives() -> void:
	if RunEvents == null or not RunEvents.has_signal("secondary_objective_completed"):
		return
	var callback := Callable(self, "_on_secondary_objective_completed")
	if RunEvents.secondary_objective_completed.is_connected(callback):
		RunEvents.secondary_objective_completed.disconnect(callback)

func _on_secondary_objective_completed(objective_id: int) -> void:
	if objective_id <= 0:
		return
	# An alley cache spawning two pickups fires this once per pickup;
	# announce (and later, reward) each secondary exactly once.
	if _secondary_completed.has(objective_id):
		return
	_secondary_completed[objective_id] = true
	register_rite_safeguard_source(StringName("secondary:%d" % objective_id))
	Global.grant_doctrine_secondary_rewards(StringName("secondary:%d" % objective_id))
	# Optional objectives are exactly the "meaningful actions" Resonance is
	# supposed to reward: detours pay progress, not just loot.
	grant_resonance(0.05, true)
	if _active_secondary_id == objective_id:
		_active_secondary_id = -1

	var objective_type: StringName = &""
	for objective_variant in _secondary_objectives:
		var objective := objective_variant as Dictionary
		if int(objective.get("id", 0)) == objective_id:
			objective_type = objective.get("type", &"") as StringName
			break

	var completion_detail: String = "Optional reward secured."
	match objective_type:
		&"dangerous_alley_cache":
			completion_detail = "Guarded alley cache secured."
		&"searchable_reward_building":
			completion_detail = "Building searched • optional reward recovered."
		&"wager_shrine":
			completion_detail = "The wager is settled."

	_secondary_feedback_token += 1
	var feedback_token: int = _secondary_feedback_token
	if RunEvents != null and RunEvents.has_signal("secondary_objective_changed"):
		RunEvents.secondary_objective_changed.emit("✓ SECONDARY COMPLETE", completion_detail)
	if RunEvents != null and RunEvents.has_signal("tutorial_tip"):
		RunEvents.tutorial_tip.emit("Secondary complete • %s" % completion_detail, 2.4)
	_clear_secondary_after_delay(feedback_token)


func register_rite_safeguard_source(source_key: StringName, amount: int = 1) -> int:
	if source_key == StringName() or amount <= 0 or _rite_safeguard_sources.has(source_key):
		return 0
	_rite_safeguard_sources[source_key] = amount
	if _exit_rite == null or not is_instance_valid(_exit_rite):
		return 0
	return _exit_rite.grant_safeguard(source_key, amount)


func _replay_rite_safeguard_sources() -> void:
	if _exit_rite == null or not is_instance_valid(_exit_rite):
		return
	for source_variant in _rite_safeguard_sources.keys():
		var source_key := StringName(str(source_variant))
		_exit_rite.grant_safeguard(source_key, int(_rite_safeguard_sources[source_variant]))

func _clear_secondary_after_delay(feedback_token: int) -> void:
	await get_tree().create_timer(2.4).timeout
	if feedback_token != _secondary_feedback_token:
		return
	_clear_secondary_objective_ui()

func _clear_secondary_objective_ui() -> void:
	_secondary_feedback_token += 1
	if RunEvents != null and RunEvents.has_signal("secondary_objective_changed"):
		RunEvents.secondary_objective_changed.emit("", "")

# ------------------------------------------------------------
# Resonance hooks
# ------------------------------------------------------------

func _hook_resonance() -> void:
	if RunEvents == null:
		return
	var cb1 := Callable(self, "_on_enemy_defeated")
	if not RunEvents.enemy_defeated.is_connected(cb1):
		RunEvents.enemy_defeated.connect(cb1)

	var cb2 := Callable(self, "_on_pickup_to_equip")
	if not RunEvents.pickup_fly_to_equip.is_connected(cb2):
		RunEvents.pickup_fly_to_equip.connect(cb2)

func _unhook_resonance() -> void:
	if RunEvents == null:
		return
	var cb1 := Callable(self, "_on_enemy_defeated")
	if RunEvents.enemy_defeated.is_connected(cb1):
		RunEvents.enemy_defeated.disconnect(cb1)

	var cb2 := Callable(self, "_on_pickup_to_equip")
	if RunEvents.pickup_fly_to_equip.is_connected(cb2):
		RunEvents.pickup_fly_to_equip.disconnect(cb2)

func _on_enemy_defeated(context: RefCounted) -> void:
	if resonance >= 1.0:
		return

	var gain := resonance_per_kill
	if context != null and bool(context.get("is_elite")):
		gain = resonance_per_elite_kill

	_pending_bonus_res += gain
	_pending_bonus_res = minf(_pending_bonus_res, 1.0) # avoid runaway buffer if something goes wild

func _on_pickup_to_equip(_start_global: Vector2, _equip_slot: int, inst: ItemInstance, _upgraded: bool) -> void:
	if inst == null or resonance >= 1.0:
		return
	_pending_bonus_res += float(inst.rarity) * resonance_per_item_rarity
	_pending_bonus_res = minf(_pending_bonus_res, 1.0)

func _update_gate_lock() -> void:
	if _exit_rite == null:
		return
	var should_lock: bool = (not _primary_completed) or (resonance < 0.999) or (_boss_required and not _boss_defeated) or (_miniboss_required and not _miniboss_defeated)
	_exit_rite.set_locked(should_lock)

func _update_gate_marker() -> void:
	if Global == null or not _primary_completed:
		return
	var gate_is_valid: bool = is_instance_valid(_exit_rite)
	var should_show: bool = gate_is_valid and resonance >= gate_marker_reveal_resonance
	Global.objective_target_pos = _exit_rite.global_position if should_show else Vector2.INF

func _gate_conditions_met() -> bool:
	return (
		_primary_completed
		and (not _boss_required or _boss_defeated)
		and (not _miniboss_required or _miniboss_defeated)
	)

func _push_resonance_ui() -> void:
	if RunEvents != null and RunEvents.has_signal("resonance_changed"):
		# Hold the public bar just under the unseal threshold while the gate
		# is still blocked by primary/miniboss/boss: ThreatDirector's
		# overtime, EVAC NOW and the HUD's GATE READY all key off this
		# signal reaching 0.999, and none of them should fire while the
		# Exit Rite cannot actually open (same pattern as Level1Builder).
		var shown := resonance
		if not _gate_conditions_met():
			shown = minf(shown, 0.998)
		RunEvents.resonance_changed.emit(shown)
