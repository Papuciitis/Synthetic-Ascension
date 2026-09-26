extends Node2D
class_name GrandmasBazookaEffect
## Grandma's Bazooka (handoff §14.3 idea table, approved 2026-09-26):
## hurt her grandchild and, after a breath, something slow and homing is
## already on its way. Defined identity per the handoff's demands:
## damage min(44, 26 x S), one rocket per 2.5 s at most, fired 1.2 s after
## the wound. Target loss: a dead or vanished attacker passes the grudge
## to the nearest enemy within 400 px of the player; nobody there means
## grandma holds her fire (and her cooldown).

const DELAY := 1.2
const COOLDOWN := 2.5
const BASE_DAMAGE := 26.0
const DAMAGE_CAP := 44.0
const ROCKET_SPEED := 520.0
const ROCKET_RANGE := 900.0
const FALLBACK_RADIUS := 400.0

var player: Node2D = null
var item: ItemInstance = null
var slot_index: int = -1

var _pending_left: float = 0.0
var _pending_target: int = 0
var _cooldown_left: float = 0.0
var telemetry: Dictionary = {"rockets": 0, "retargeted": 0, "held_fire": 0}


func get_effects_short(inst: ItemInstance) -> PackedStringArray:
	return PackedStringArray([
		"%.1f s after something hurts you, a homing rocket answers it (%.0f damage)." % [DELAY, damage_for(inst)],
		"At most one rocket per %.1f s. If the culprit is gone, the nearest enemy inherits the grudge." % COOLDOWN,
		"Grandma remembers.",
	])


func damage_for(inst: ItemInstance) -> float:
	var strength := inst.rarity_effect_multiplier() if inst != null else 1.0
	return minf(DAMAGE_CAP, BASE_DAMAGE * strength)


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
	_pending_left = 0.0
	if RunEvents != null and RunEvents.player_damage_resolved.is_connected(_on_damage_resolved):
		RunEvents.player_damage_resolved.disconnect(_on_damage_resolved)


## Every REAL wound counts — landed, absorbed by a companion, or stopped at
## 1 HP — but evasions and misses anger nobody.
func _on_damage_resolved(who: Node, _raw: float, adjusted: float, _applied: float, source: Node, _kind: StringName, outcome: StringName) -> void:
	if who != player or adjusted <= 0.0:
		return
	if outcome != &"hit" and outcome != &"absorbed" and outcome != &"intercepted":
		return
	if source == null or not is_instance_valid(source) or _cooldown_left > 0.0:
		return
	var handle := EnemyCombat.handle_for_actor(source)
	if handle == 0:
		return
	if _pending_left > 0.0:
		# One grudge at a time; the freshest wound names the target.
		_pending_target = handle
		return
	_pending_left = DELAY
	_pending_target = handle


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if _pending_left <= 0.0:
		return
	_pending_left -= delta
	if _pending_left > 0.0:
		return
	_fire(_pending_target)


func _fire(target: int) -> void:
	if player == null or not is_instance_valid(player):
		return
	if not EnemyWorld.is_valid_handle(target) or EnemyWorld.is_dying(target):
		var fallback := EnemyWorld.nearest_enemy(player.global_position, FALLBACK_RADIUS)
		if fallback == EnemyWorldTypes.INVALID_HANDLE:
			# Nobody left to blame: no rocket, no cooldown spent.
			telemetry["held_fire"] = int(telemetry["held_fire"]) + 1
			return
		telemetry["retargeted"] = int(telemetry["retargeted"]) + 1
		target = fallback
	var profile := HitProfileAdapter.new()
	profile.damage = damage_for(item)
	profile.speed = ROCKET_SPEED
	profile.max_range = ROCKET_RANGE
	profile.collision_radius = 7.0
	profile.seek_handle = target
	profile.seek_turn_degrees = 200.0
	var direction := (EnemyWorld.get_position(target) - player.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	ProjectileManager.spawn_player(player.global_position, direction, profile, player)
	_cooldown_left = COOLDOWN
	telemetry["rockets"] = int(telemetry["rockets"]) + 1
	if BattleText != null:
		BattleText.popup(player.global_position + Vector2(0, -30), "grandma remembers", Color(0.95, 0.75, 0.8, 0.95), 1.2)


func describe() -> Dictionary:
	return {"pending_left": _pending_left, "cooldown_left": _cooldown_left, "telemetry": telemetry.duplicate()}
