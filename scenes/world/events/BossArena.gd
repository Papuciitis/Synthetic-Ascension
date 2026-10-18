extends Node2D
class_name BossArena

@export var trigger_radius: float = 320.0
@export var spawn_offset: Vector2 = Vector2(0, -90)

@export_group("Random Archetype (50/50)")
@export var tank_boss_scenes: Array[PackedScene] = [
	preload("res://scenes/world/bosses/BossBulldozer.tscn"),
]
@export var mage_boss_scenes: Array[PackedScene] = [
	preload("res://scenes/world/bosses/BossArcanist.tscn"),
]

@export var tank_title: String = "Boss: The Bulldozer"
@export var mage_title: String = "Boss: The Arcanist"
## A brief role-specific entrance line beside the name, no cinematic.
@export var tank_entrance: String = "The ground shudders. The Bulldozer braces to charge."
@export var mage_entrance: String = "The air fractures. The Arcanist raises its array."

@export var boss_portrait: Texture2D = preload("res://ui/boss/portraits/bulldozer_s10_v2.png")

@export_group("Tuning")
@export var hp_mult: float = 22.0
@export var speed_mult: float = 0.95

@export var hp_mult_per_segment: float = 4.5
@export var damage_taken_mul: float = 0.55
@export var hit_cap_ratio: float = 0.08
@export var kb_mul: float = 0.22
@export var kb_decay_mult: float = 3.0


@export_group("Leash / Return")
@export var leash_radius: float = 900.0
@export var disengage_radius: float = 1200.0
@export var heal_pct_per_sec_while_returning: float = 0.015

@export_group("Rewards")
@export var fill_resonance_on_clear: bool = true
@export var bonus_followers_on_clear: int = 25

@export_group("Gate Lock")
@export var gate_path: NodePath  # optional, if you want this arena to unlock a specific gate

@onready var trigger: Area2D = $Trigger
@onready var trigger_shape: CollisionShape2D = $Trigger/CollisionShape2D

var _spawned: bool = false
var _spawn_in_progress: bool = false
var _retry_not_before_ms: int = 0
var _cleared: bool = false
var _boss: Node = null
var _gate: Node = null

var _title: String = ""
var _is_tank: bool = false


func _ready() -> void:
	if trigger_shape != null and trigger_shape.shape is CircleShape2D:
		(trigger_shape.shape as CircleShape2D).radius = trigger_radius

	if trigger != null:
		if not trigger.body_entered.is_connected(_on_body_entered):
			trigger.body_entered.connect(_on_body_entered)

	if gate_path != NodePath():
		_gate = get_node_or_null(gate_path)

	if RunEvents != null and RunEvents.has_signal("enemy_killed"):
		var cb := Callable(self, "_on_enemy_killed")
		if not RunEvents.enemy_killed.is_connected(cb):
			RunEvents.enemy_killed.connect(cb)

	if Global != null and Global.is_arena_cleared(&"boss"):
		# Defeated earlier this attempt (Continue rebuilt the segment): no
		# second fight or payout. Its earned state returns once the builder is.
		_cleared = true
		_disable_trigger_deferred()
		set_process(false)
		_restore_cleared.call_deferred()
		return

	set_process(true)
	queue_redraw()


func _restore_cleared() -> void:
	var builder := get_tree().get_first_node_in_group("segment_proc_builder") as SegmentProcBuilder
	if builder != null:
		builder.restore_arena_clear(&"boss", 1.0 if fill_resonance_on_clear else 0.0)
	if _gate != null and is_instance_valid(_gate) and _gate.has_method("set_boss_defeated"):
		_gate.call("set_boss_defeated", true)
	Global.restore_pending_arena_rewards()
	queue_free()


func _process(_delta: float) -> void:
	# Backup trigger: if collision layers change, proximity still spawns the boss.
	if _cleared or _spawned or _spawn_in_progress:
		return
	if Time.get_ticks_msec() < _retry_not_before_ms:
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return
	if global_position.distance_to(p.global_position) <= trigger_radius:
		call_deferred("_spawn")


func _draw() -> void:
	draw_circle(Vector2.ZERO, trigger_radius, Color(0.55, 0.25, 1.0, 0.05))
	draw_arc(Vector2.ZERO, trigger_radius, 0.0, TAU, 64, Color(0.55, 0.25, 1.0, 0.35), 3.0, true)


func _on_body_entered(body: Node) -> void:
	if _cleared or _spawned or _spawn_in_progress:
		return
	if body == null or not body.is_in_group("player"):
		return
	# body_entered fires during physics query flushing; defer any state changes/spawns.
	call_deferred("_spawn")


func _disable_trigger_deferred() -> void:
	if trigger != null:
		trigger.set_deferred("monitoring", false)
		trigger.set_deferred("monitorable", false)
	if trigger_shape != null:
		trigger_shape.set_deferred("disabled", true)


func _make_rng(tag: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var s: int = 777
	if Global != null:
		s = int(Global.attempt_world_seed)
		s ^= int(Global.attempt_segment) * 20011
	s ^= int(floor(global_position.x)) * 83492791
	s ^= int(floor(global_position.y)) * 19349663
	s ^= tag
	rng.seed = s
	return rng


func _pick_archetype() -> PackedScene:
	var rng := _make_rng(0xB055) # 'BOSS'
	_is_tank = (rng.randi() & 1) == 0

	var scenes: Array[PackedScene] = tank_boss_scenes if _is_tank else mage_boss_scenes

	# Fallback: if the chosen bucket is empty, flip archetype and try the other.
	if scenes.is_empty():
		_is_tank = not _is_tank
		scenes = tank_boss_scenes if _is_tank else mage_boss_scenes

	if scenes.is_empty():
		return null

	_title = tank_title if _is_tank else mage_title
	return scenes[rng.randi_range(0, scenes.size() - 1)]


func _apply_boss_rewards_and_rules(en: EnemyActor) -> void:
	en.set_meta("arena_reward_kind", &"boss")
	en.set_meta("arena_reward_segment", Global.attempt_segment)
	en.set_meta("arena_reward_seed", Global.attempt_world_seed)
	# Boss identity + leash metadata (used by EnemyActor.gd).
	en.add_to_group(&"boss")
	en.add_to_group(&"boss_like")
	en.set_meta("boss_archetype", ("tank" if _is_tank else "mage"))
	en.set_meta("boss_home_pos", en.global_position)
	en.set_meta("boss_leash_radius", leash_radius)
	en.set_meta("boss_disengage_radius", disengage_radius)
	en.set_meta("boss_heal_pct_per_sec", heal_pct_per_sec_while_returning)

	# Scale + mitigation.
	var seg := int(Global.attempt_segment) if Global != null else 10
	var eff_hp_mult := hp_mult + float(seg) * hp_mult_per_segment
	en.set_meta("damage_taken_mul", damage_taken_mul)
	en.set_meta("hit_cap_ratio", hit_cap_ratio)
	en.set_meta("boss_kb_mul", kb_mul)
	en.knockback_decay *= kb_decay_mult

	en.configure_health(en.max_hp * eff_hp_mult, true)
	en.scale_move_speed(speed_mult)
	# Normal spawns already initialized the final form in EnemyInit. Keep
	# reconfiguration available for callers applying arena rules to a ready actor.
	if int(en.get_meta(&"boss_visual_tier", -1)) != 1:
		preload("res://scenes/world/bosses/BossAppearance.gd").apply(en, 1)

	# Settlement uses the existing drop pool and quality roll, with a guaranteed
	# count instead of the ordinary enemy probability gate.
	var rmin := clampi(2 + int(floor(float(seg) * 0.55)), 2, 20)
	var rmax := clampi(rmin + 2, rmin, 20)

	en.drop_chance = 1.0
	en.drop_instance_roll = true
	en.drop_rarity_min = rmin
	en.drop_rarity_max = rmax
	en.drop_amount_min = 3 + int(floor(float(seg) * 0.20))
	en.drop_amount_max = en.drop_amount_min + 2


func _spawn() -> void:
	if _spawned or _cleared or _spawn_in_progress:
		return
	if Time.get_ticks_msec() < _retry_not_before_ms:
		return
	_spawn_in_progress = true

	var scene: PackedScene = _pick_archetype()
	if scene == null:
		_spawn_in_progress = false
		_retry_not_before_ms = Time.get_ticks_msec() + 1000
		push_warning("BossArena has no valid boss scene; gate trigger remains available for retry.")
		return

	var e: Node = scene.instantiate()
	if e == null or not (e is EnemyActor):
		if e != null:
			e.free()
		_spawn_in_progress = false
		_retry_not_before_ms = Time.get_ticks_msec() + 1000
		push_warning("BossArena scene did not instantiate an EnemyActor; gate trigger remains available for retry.")
		return
	var spawn_filter := get_node_or_null("/root/DebugEnemySpawnFilter")
	if spawn_filter != null and spawn_filter.has_method("is_enemy_enabled"):
		var enemy_actor := e as EnemyActor
		var enemy_id := StringName(enemy_actor.spec.id) if enemy_actor.spec != null else &""
		if not bool(spawn_filter.call("is_enemy_enabled", enemy_id, true)):
			e.free()
			_spawn_in_progress = false
			_retry_not_before_ms = Time.get_ticks_msec() + 1000
			return

	_spawned = true
	if PerformanceFlightRecorder != null:
		PerformanceFlightRecorder.record_event(&"encounter", &"boss_started", {"position": str(global_position)})
	_spawn_in_progress = false
	_disable_trigger_deferred()
	_boss = e
	# EnemyInit reads this during readiness: avoid loading and constructing
	# the S5 form just to replace it with S10 on the same entrance frame.
	e.set_meta(&"boss_visual_tier", 1)
	add_child(e)
	if spawn_filter != null and spawn_filter.has_method("record_spawn"):
		spawn_filter.call("record_spawn", StringName((e as EnemyActor).spec.id))

	if e is Node2D:
		(e as Node2D).global_position = global_position + spawn_offset

	if e is EnemyActor:
		var en := e as EnemyActor
		_apply_boss_rewards_and_rules(en)

		if RunEvents != null and RunEvents.has_signal("boss_spawned"):
			# tier 1 = boss
			RunEvents.boss_spawned.emit(en, 1, preload("res://scenes/world/bosses/BossAppearance.gd").portrait_for(en, 1, boss_portrait), _title)

	if RunEvents != null and RunEvents.has_signal("tutorial_tip"):
		RunEvents.tutorial_tip.emit(tank_entrance if _is_tank else mage_entrance, 3.0)


func _on_enemy_killed(_who: Node, enemy: Node, _pos: Vector2) -> void:
	if _cleared:
		return
	if enemy == null or enemy != _boss:
		return

	if not Global.settle_arena_rewards(enemy as EnemyActor, &"boss", bonus_followers_on_clear, 1.0 if fill_resonance_on_clear else 0.0):
		return
	_cleared = true
	if PerformanceFlightRecorder != null:
		PerformanceFlightRecorder.record_event(&"encounter", &"boss_cleared", {"position": str(global_position)})

	# Signal UI
	if RunEvents != null and RunEvents.has_signal("boss_cleared"):
		RunEvents.boss_cleared.emit(enemy, 1)

	# Optional explicit gate node.
	if _gate != null and is_instance_valid(_gate):
		if _gate.has_method("set_boss_defeated"):
			_gate.call("set_boss_defeated", true)

	queue_free()
