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
@export var resonance_per_kill: float = 0.0005
@export var resonance_per_elite_kill: float = 0.0018
@export var resonance_per_item_rarity: float = 0.0008
@export var resonance_per_sec: float = 0.0040

# Caps how fast *bonus* resonance (kills + items) can be applied.
# This prevents "instant unseal" when a build starts deleting packs.
@export var resonance_bonus_cap_per_sec: float = 0.0018

# Early boost so the bar visibly moves in the first ~30s (reduces "job" feeling).
@export var resonance_early_boost_seconds: float = 30.0
@export var resonance_early_boost_mul: float = 1.20

# How often we tick resonance/UI from ambient + buffered bonus.
@export var resonance_tick_interval: float = 0.25

# Scenes
const WARDSTONE_SCENE: PackedScene = preload("res://scenes/world/wardstones/Wardstone.tscn")
const EXIT_RITE_SCENE: PackedScene = preload("res://scenes/world/gates/ExitRite.tscn")
const MINIBOSS_ARENA_SCENE: PackedScene = preload("res://scenes/world/events/MiniBossArena.tscn")
const BOSS_ARENA_SCENE: PackedScene = preload("res://scenes/world/events/BossArena.tscn")

var _res_tick: float = 0.0
var _time_in_segment: float = 0.0
var _pending_bonus_res: float = 0.0

var _cm: ChunkManager = null
var _player: Node2D = null
var _exit_rite: ExitRite = null
var _segment: int = 1
var _plan: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _theme: SegmentThemeData = null
var _boss_required: bool = false
var _miniboss_required: bool = false
var _miniboss_defeated: bool = false
var _boss_defeated: bool = false

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

	_rng.seed = int(_plan.get("seed", 1337)) ^ 0xA53C9E1

	_apply_segment_rules()
	_build_world_from_plan()
	_hook_resonance()
	set_process(true)

	# Initial gate lock state
	_update_gate_lock()
	_push_resonance_ui()

func _exit_tree() -> void:
	_unhook_resonance()

func _process(delta: float) -> void:
	if resonance >= 1.0:
		return

	_time_in_segment += delta
	_res_tick += delta
	if _res_tick < resonance_tick_interval:
		return

	var dt := _res_tick
	_res_tick = 0.0

	# Ambient resonance backbone (keeps pacing consistent even if spawns are light).
	var ambient := resonance_per_sec * dt

	# Small early boost to reduce "slow start" feel.
	if resonance_early_boost_seconds > 0.0 and _time_in_segment < resonance_early_boost_seconds:
		var t := clampf(_time_in_segment / resonance_early_boost_seconds, 0.0, 1.0)
		ambient *= lerpf(resonance_early_boost_mul, 1.0, t)

	# Apply buffered bonus resonance at a capped rate (kills/items).
	var bonus_cap := maxf(0.0, resonance_bonus_cap_per_sec) * dt
	var bonus := minf(_pending_bonus_res, bonus_cap)
	_pending_bonus_res -= bonus

	resonance += ambient + bonus
	resonance = clampf(resonance, 0.0, 1.0)

	_update_gate_lock()
	_push_resonance_ui()

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
	# Theme-driven world feel.
	# Segment 2: Explore (fixed)
	# Segment 3: Escape (fixed)
	# Others: random mix per attempt/segment seed (deterministic)
	if _theme != null:
		_theme.apply_to_chunk_manager(_cm)
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

func _build_world_from_plan() -> void:
	_cm.generation_enabled = true
	_cm.clear_manual_blocks()
	_cm.clear_chunk_archetypes()

	# Apply connectors (donjon-style chunk coherency)
	_cm.clear_chunk_connectors()
	var conns: Dictionary = _plan.get("connectors_by_chunk", {})
	for k2 in conns.keys():
		var cc2: Vector2i = k2
		_cm.set_chunk_connectors(cc2, int(conns[k2]))

	# Apply archetypes
	var arch: Dictionary = _plan.get("archetype_by_chunk", {})
	for k in arch.keys():
		var cc: Vector2i = k
		_cm.set_chunk_archetype(cc, arch[k] as StringName)

	# Use the segment seed for chunk hashing (stable within attempt).
	_cm.world_seed = int(_plan.get("seed", 1337))

	# Move the player to the segment start and set their default checkpoint.
	var start_world: Vector2 = _plan.get("start_world", Vector2.ZERO)
	if _player != null and _player.has_method("set_checkpoint"):
		_player.call("set_checkpoint", start_world, true)
	else:
		_player.global_position = start_world

	# Force a rebuild so chunks created while generation_enabled was false are regenerated.
	_cm.reset_world()

	# Spawn wardstones + exit gate (after chunks exist so visuals sit on top cleanly).
	_spawn_wardstones()
	_spawn_exit_gate()
	_spawn_segment_events()

func _spawn_wardstones() -> void:
	var wards: Array = _plan.get("wardstone_world", [])
	for p in wards:
		var s := WARDSTONE_SCENE.instantiate() as Wardstone
		if s == null:
			continue

		# Jitter around the arena center so repeated attempts don't feel identical.
		# Using 3-5 cells keeps us inside the "open core" of arena chunks.
		var max_cells := (5 if _segment == 2 else 4)
		var pos := _jitter_in_chunk(p as Vector2, max_cells)

		s.global_position = pos
		add_child(s)

func _spawn_exit_gate() -> void:
	var p: Vector2 = _plan.get("exit_world", Vector2.ZERO)

	# Jitter the gate inside its gate/plaza chunk.
	# Keep smaller than wardstones so the "end" still reads consistent.
	var pos := _jitter_in_chunk(p, 3)

	_exit_rite = EXIT_RITE_SCENE.instantiate() as ExitRite
	if _exit_rite == null:
		return
	_exit_rite.global_position = pos
	add_child(_exit_rite)
	_exit_rite.cleared.connect(_on_gate_cleared)


func _spawn_segment_events() -> void:
	# Miniboss arena (required on segment 5; rare optional on later segments).
	var mb_world: Vector2 = _plan.get("miniboss_world", Vector2.ZERO)
	if _segment >= 5 and mb_world != Vector2.ZERO:
		var a := MINIBOSS_ARENA_SCENE.instantiate()
		if a != null:
			var pos := _jitter_in_chunk(mb_world, 2)

			# Segment 5 teaching beat: spawn the miniboss near the exit gate so the player
			# can't miss that bosses exist (still locked until the miniboss is defeated).
			if _segment == 5 and _exit_rite != null:
				var edge: int = int(_plan.get("exit_edge", 0))
				var offset := Vector2.ZERO
				match edge:
					0: # exit north → place south of the gate
						offset = Vector2(0, 260)
					1: # exit east → place west of the gate
						offset = Vector2(-260, 0)
					2: # exit south → place north of the gate
						offset = Vector2(0, -260)
					3: # exit west → place east of the gate
						offset = Vector2(260, 0)
				pos = _exit_rite.global_position + offset + Vector2(float(_rng.randi_range(-40, 40)), float(_rng.randi_range(-40, 40)))

			(a as Node2D).global_position = pos
			add_child(a)

	# Segment 10: boss arena (capstone). Boss spawns and gate stays locked until dead.
	var b_world: Vector2 = _plan.get("boss_world", Vector2.ZERO)
	if _segment == 10 and b_world != Vector2.ZERO:
		var b := BOSS_ARENA_SCENE.instantiate()
		if b != null:
			(b as Node2D).global_position = _jitter_in_chunk(b_world, 2)
			add_child(b)

func grant_resonance(amount: float, immediate: bool = true) -> void:
	if amount <= 0.0:
		return
	if immediate:
		resonance = clampf(resonance + amount, 0.0, 1.0)
		_update_gate_lock()
		_push_resonance_ui()
		return
	_pending_bonus_res += amount
	_pending_bonus_res = minf(_pending_bonus_res, 1.0)

func set_boss_defeated() -> void:
	_boss_defeated = true
	_update_gate_lock()

func set_miniboss_defeated() -> void:
	_miniboss_defeated = true
	_update_gate_lock()

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
# Resonance hooks
# ------------------------------------------------------------

func _hook_resonance() -> void:
	if RunEvents == null:
		return
	var cb1 := Callable(self, "_on_enemy_killed")
	if not RunEvents.enemy_killed.is_connected(cb1):
		RunEvents.enemy_killed.connect(cb1)

	var cb2 := Callable(self, "_on_pickup_to_equip")
	if not RunEvents.pickup_fly_to_equip.is_connected(cb2):
		RunEvents.pickup_fly_to_equip.connect(cb2)

func _unhook_resonance() -> void:
	if RunEvents == null:
		return
	var cb1 := Callable(self, "_on_enemy_killed")
	if RunEvents.enemy_killed.is_connected(cb1):
		RunEvents.enemy_killed.disconnect(cb1)

	var cb2 := Callable(self, "_on_pickup_to_equip")
	if RunEvents.pickup_fly_to_equip.is_connected(cb2):
		RunEvents.pickup_fly_to_equip.disconnect(cb2)

func _on_enemy_killed(_who: Node, enemy: Node, _pos: Vector2) -> void:
	if resonance >= 1.0:
		return

	var gain := resonance_per_kill
	if enemy != null and enemy.has_method("get"):
		var elite: bool = bool(enemy.get("is_elite"))
		if elite:
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
	var should_lock: bool = (resonance < 0.999) or (_boss_required and not _boss_defeated) or (_miniboss_required and not _miniboss_defeated)
	_exit_rite.set_locked(should_lock)

func _push_resonance_ui() -> void:
	if RunEvents != null and RunEvents.has_signal("resonance_changed"):
		RunEvents.resonance_changed.emit(resonance)
