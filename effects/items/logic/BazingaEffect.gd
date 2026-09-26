extends Node2D
class_name BazingaEffect
## Bazinga (handoff §14.3 idea table, approved 2026-09-26): a dodge worth
## laughing at leaves a sound decoy where you WERE. V1 scope, per the
## review's warning against inventing systems: the engine has no aggro
## redirection, so the decoy's distraction is mechanical hesitation — up to
## six nearby enemies briefly stumble at half speed toward the noise (their
## original speeds restored, validity-guarded). The laugh is bounded: one
## decoy at a time, at most one per 6 s.
##
## A near miss is a REAL dodge: a lucky evasion, or a hit that broke on
## dash invulnerability.

const RADIUS := 220.0
const HESITATE_SECONDS := 1.1
const COOLDOWN := 6.0
const MAX_VICTIMS := 6

var player: Node2D = null
var item: ItemInstance = null
var slot_index: int = -1

var _cooldown_left: float = 0.0
var _decoy_at: Vector2 = Vector2.ZERO
var _decoy_left: float = 0.0
var _slowed: Dictionary = {}         # handle -> original speed
var telemetry: Dictionary = {"decoys": 0, "hesitations": 0}


func get_effects_short(_inst: ItemInstance) -> PackedStringArray:
	return PackedStringArray([
		"A narrow dodge drops a sound decoy where you stood: nearby enemies hesitate toward it for %.1f s." % HESITATE_SECONDS,
		"At most one decoy per %.0f s. The joke lands harder than they do." % COOLDOWN,
	])


func setup_with_item(p: Node, inst: ItemInstance, slot: int) -> void:
	player = p as Node2D
	item = inst
	slot_index = slot


func set_item_instance(inst: ItemInstance) -> void:
	item = inst


func _ready() -> void:
	if RunEvents != null and not RunEvents.player_damage_resolved.is_connected(_on_damage_resolved):
		RunEvents.player_damage_resolved.connect(_on_damage_resolved)


func _exit_tree() -> void:
	_restore_all()
	if RunEvents != null and RunEvents.player_damage_resolved.is_connected(_on_damage_resolved):
		RunEvents.player_damage_resolved.disconnect(_on_damage_resolved)


func _on_damage_resolved(who: Node, _raw: float, _adjusted: float, _applied: float, _source: Node, _kind: StringName, outcome: StringName) -> void:
	if who != player or _cooldown_left > 0.0:
		return
	var near_miss := outcome == &"evaded"
	if outcome == &"invulnerable":
		var dash_state: Variant = player.get("_dash")
		near_miss = dash_state != null and bool(dash_state.is_dashing())
	if not near_miss:
		return
	_drop_decoy()


func _drop_decoy() -> void:
	_cooldown_left = COOLDOWN
	_decoy_at = player.global_position
	_decoy_left = HESITATE_SECONDS
	telemetry["decoys"] = int(telemetry["decoys"]) + 1
	var candidates: Array[int] = []
	EnemyWorld.gather_in_radius(_decoy_at, RADIUS, candidates)
	var victims := 0
	for handle in candidates:
		if victims >= MAX_VICTIMS:
			break
		if _slowed.has(handle) or EnemyWorld.is_dying(handle):
			continue
		var speed := EnemyWorld.get_speed(handle)
		if speed <= 0.0:
			continue
		_slowed[handle] = speed
		EnemyWorld.set_speed(handle, speed * 0.5)
		victims += 1
	telemetry["hesitations"] = int(telemetry["hesitations"]) + victims
	if BattleText != null:
		BattleText.popup(_decoy_at + Vector2(0, -20), "*bazinga*", Color(0.95, 0.9, 0.6, 0.95), 1.2)


func _restore_all() -> void:
	for handle in _slowed.keys():
		if EnemyWorld.is_valid_handle(int(handle)) and not EnemyWorld.is_dying(int(handle)):
			EnemyWorld.set_speed(int(handle), float(_slowed[handle]))
	_slowed.clear()


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if _decoy_left <= 0.0:
		return
	_decoy_left -= delta
	queue_redraw()
	if _decoy_left <= 0.0:
		_restore_all()
		queue_redraw()


func _draw() -> void:
	if _decoy_left <= 0.0:
		return
	draw_set_transform_matrix(get_global_transform().affine_inverse())
	var fade := clampf(_decoy_left / HESITATE_SECONDS, 0.0, 1.0)
	var wave := 1.0 - fade
	draw_arc(_decoy_at, 10.0 + 26.0 * wave, 0.0, TAU, 32, Color(0.95, 0.9, 0.6, 0.6 * fade), 2.0, true)
	draw_arc(_decoy_at, 6.0 + 14.0 * wave, 0.0, TAU, 24, Color(0.95, 0.9, 0.6, 0.4 * fade), 1.5, true)


func describe() -> Dictionary:
	return {"cooldown_left": _cooldown_left, "decoy_left": _decoy_left, "slowed": _slowed.size(), "telemetry": telemetry.duplicate()}
