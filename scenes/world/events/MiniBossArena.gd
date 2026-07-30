extends Node2D
class_name MiniBossArena

@export var trigger_radius: float = 260.0
@export var spawn_offset: Vector2 = Vector2(0, -80)

@export_group("Random Archetype (50/50)")
@export var tank_boss_scenes: Array[PackedScene] = [
	preload("res://scenes/world/bosses/BossBulldozer.tscn"),
]
@export var mage_boss_scenes: Array[PackedScene] = [
	preload("res://scenes/world/bosses/BossArcanist.tscn"),
]

@export var tank_title: String = "Mini-Boss: Bulldozer"
@export var mage_title: String = "Mini-Boss: Arcanist"

@export var tank_portrait: Texture2D = preload("res://ui/boss/portraits/miniboss_portrait_01.png")
@export var mage_portrait: Texture2D = preload("res://ui/boss/portraits/miniboss_portrait_02.png")

@export_group("Tuning")
@export var hp_mult: float = 8.0
@export var speed_mult: float = 0.92
@export var scale_mult: float = 1.35

@export var hp_mult_per_segment: float = 1.8
@export var damage_taken_mul: float = 0.65
@export var hit_cap_ratio: float = 0.12
@export var kb_mul: float = 0.28
@export var kb_decay_mult: float = 2.4


@export_group("Leash / Return")
@export var leash_radius: float = 750.0
@export var disengage_radius: float = 1050.0
@export var heal_pct_per_sec_while_returning: float = 0.010

@export_group("Rewards")
@export var grant_resonance_on_clear: float = 0.18
@export var bonus_followers_on_clear: int = 8

@onready var trigger: Area2D = $Trigger
@onready var trigger_shape: CollisionShape2D = $Trigger/CollisionShape2D

var _spawned: bool = false
var _spawn_in_progress: bool = false
var _retry_not_before_ms: int = 0
var _cleared: bool = false
var _enemy: Node = null

var _title: String = ""
var _portrait: Texture2D = null
var _is_tank: bool = false


func _ready() -> void:
	if trigger_shape != null and trigger_shape.shape is CircleShape2D:
		(trigger_shape.shape as CircleShape2D).radius = trigger_radius

	if trigger != null:
		if not trigger.body_entered.is_connected(_on_body_entered):
			trigger.body_entered.connect(_on_body_entered)

	if RunEvents != null and RunEvents.has_signal("enemy_killed"):
		var cb := Callable(self, "_on_enemy_killed")
		if not RunEvents.enemy_killed.is_connected(cb):
			RunEvents.enemy_killed.connect(cb)

	set_process(true)
	queue_redraw()


func _process(_delta: float) -> void:
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
	# Simple world marker: an outlined ring so players can spot the arena.
	draw_circle(Vector2.ZERO, trigger_radius, Color(1, 0.4, 0.2, 0.06))
	draw_arc(Vector2.ZERO, trigger_radius, 0.0, TAU, 64, Color(1, 0.4, 0.2, 0.35), 3.0, true)


func _on_body_entered(body: Node) -> void:
	if _cleared or _spawned or _spawn_in_progress:
		return
	if body == null or not body.is_in_group("player"):
		return
	call_deferred("_spawn")


func _disable_trigger_deferred() -> void:
	if trigger != null:
		trigger.set_deferred("monitoring", false)
		trigger.set_deferred("monitorable", false)
	if trigger_shape != null:
		trigger_shape.set_deferred("disabled", true)


func _make_rng(tag: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var s: int = 1337
	if Global != null:
		s = int(Global.attempt_world_seed)
		s ^= int(Global.attempt_segment) * 10007
	s ^= int(floor(global_position.x)) * 73856093
	s ^= int(floor(global_position.y)) * 19349663
	s ^= tag
	rng.seed = s
	return rng


func _pick_archetype() -> PackedScene:
	var rng := _make_rng(0x4D1B055) # 'MINIBOSS'
	_is_tank = (rng.randi() & 1) == 0

	var scenes: Array[PackedScene] = tank_boss_scenes if _is_tank else mage_boss_scenes
	if scenes.is_empty():
		_is_tank = not _is_tank
		scenes = tank_boss_scenes if _is_tank else mage_boss_scenes

	var scene: PackedScene = null
	if not scenes.is_empty():
		scene = scenes[rng.randi_range(0, scenes.size() - 1)]

	_title = tank_title if _is_tank else mage_title
	_portrait = tank_portrait if _is_tank else mage_portrait
	return scene


func _apply_miniboss_rules(en: EnemyActor) -> void:
	en.add_to_group(&"miniboss")
	en.add_to_group(&"boss_like")
	en.set_meta("boss_archetype", ("tank" if _is_tank else "mage"))
	en.set_meta("boss_home_pos", en.global_position)
	en.set_meta("boss_leash_radius", leash_radius)
	en.set_meta("boss_disengage_radius", disengage_radius)
	en.set_meta("boss_heal_pct_per_sec", heal_pct_per_sec_while_returning)

	var seg := int(Global.attempt_segment) if Global != null else 5
	var eff_hp_mult := hp_mult + float(seg) * hp_mult_per_segment
	en.set_meta("damage_taken_mul", damage_taken_mul)
	en.set_meta("hit_cap_ratio", hit_cap_ratio)
	en.set_meta("boss_kb_mul", kb_mul)
	en.knockback_decay *= kb_decay_mult

	en.max_hp *= eff_hp_mult
	en.hp = en.max_hp
	en.speed *= speed_mult
	en.scale *= Vector2(scale_mult, scale_mult)

	# Strong loot scaling by segment (uses built-in EnemyDrops).
	var rmin := clampi(1 + int(floor(float(seg) * 0.45)), 1, 20)
	var rmax := clampi(rmin + 1, rmin, 20)

	en.drop_chance = 1.0
	en.drop_instance_roll = true
	en.drop_rarity_min = rmin
	en.drop_rarity_max = rmax
	en.drop_amount_min = 2 + int(floor(float(seg) * 0.15))
	en.drop_amount_max = en.drop_amount_min + 1


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
		push_warning("MiniBossArena has no valid boss scene; trigger remains available for retry.")
		return

	var e: Node = scene.instantiate()
	if e == null or not (e is EnemyActor):
		if e != null:
			e.free()
		_spawn_in_progress = false
		_retry_not_before_ms = Time.get_ticks_msec() + 1000
		push_warning("MiniBossArena scene did not instantiate an EnemyActor; trigger remains available for retry.")
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
		PerformanceFlightRecorder.record_event(&"encounter", &"miniboss_started", {"position": str(global_position)})
	_spawn_in_progress = false
	_disable_trigger_deferred()
	_enemy = e
	add_child(e)
	if spawn_filter != null and spawn_filter.has_method("record_spawn"):
		spawn_filter.call("record_spawn", StringName((e as EnemyActor).spec.id))

	if e is Node2D:
		(e as Node2D).global_position = global_position + spawn_offset

	if e is EnemyActor:
		var en := e as EnemyActor
		_apply_miniboss_rules(en)

		if RunEvents != null and RunEvents.has_signal("boss_spawned"):
			# tier 0 = miniboss
			RunEvents.boss_spawned.emit(en, 0, _portrait, _title)

	if RunEvents != null and RunEvents.has_signal("tutorial_tip"):
		RunEvents.tutorial_tip.emit("A mini-boss stirs nearby…", 2.5)


func _on_enemy_killed(_who: Node, enemy: Node, _pos: Vector2) -> void:
	if _cleared:
		return
	if enemy == null or enemy != _enemy:
		return

	_cleared = true
	if PerformanceFlightRecorder != null:
		PerformanceFlightRecorder.record_event(&"encounter", &"miniboss_cleared", {"position": str(global_position)})

	if RunEvents != null and RunEvents.has_signal("boss_cleared"):
		RunEvents.boss_cleared.emit(enemy, 0)

	# Rewards: small resonance bump + followers.
	var builder := get_tree().get_first_node_in_group("segment_proc_builder") as SegmentProcBuilder
	if builder != null:
		builder.set_miniboss_defeated()
		builder.grant_resonance(grant_resonance_on_clear, true)

	if Global != null and bonus_followers_on_clear > 0:
		Global.transaction_followers(bonus_followers_on_clear, &"miniboss_victory", {}, true, false)

	if RunEvents != null and RunEvents.has_signal("tutorial_tip"):
		RunEvents.tutorial_tip.emit("Mini-boss defeated. Resonance surges.", 3.0)

	queue_free()
