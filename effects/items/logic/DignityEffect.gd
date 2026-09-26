extends Node2D
class_name DignityEffect
## Dignity (handoff §14.3, made concrete): power carried upright. While the
## standard is held, attacks hit harder; a hit that costs 25%+ of max HP
## knocks it out of your hands, and it stands where you were struck until
## you walk back over it. Softlock-proof by construction: it drops exactly
## where the player was standing (always reachable), it walks itself back
## after a patience timer, and it returns on segment end and on unequip.

const POWER_BONUS := 0.08
const DROP_HIT_FRACTION := 0.25
const AUTO_RETURN_SECONDS := 60.0
const RECOVER_RADIUS := 30.0

var player: Node2D = null
var item: ItemInstance = null
var slot_index: int = -1

var intact: bool = true
var _drop_at: Vector2 = Vector2.ZERO
var _auto_return_left: float = 0.0
var telemetry: Dictionary = {"drops": 0, "recoveries": 0, "auto_returns": 0}


func get_effects_short(inst: ItemInstance) -> PackedStringArray:
	return PackedStringArray([
		"+%.0f%% Power while your dignity is intact." % (power_bonus_for(inst) * 100.0),
		"A hit for 25%%+ of max HP drops it where you stand; walk back to pick it up.",
		"It returns by itself after %.0f s. Dignity always does, eventually." % AUTO_RETURN_SECONDS,
	])


func power_bonus_for(inst: ItemInstance) -> float:
	var strength := inst.rarity_effect_multiplier() if inst != null else 1.0
	return minf(0.14, POWER_BONUS * strength)


func setup_with_item(p: Node, inst: ItemInstance, slot: int) -> void:
	player = p as Node2D
	item = inst
	slot_index = slot


func set_item_instance(inst: ItemInstance) -> void:
	item = inst


func _ready() -> void:
	if RunEvents != null and not RunEvents.player_damage_resolved.is_connected(_on_damage_resolved):
		RunEvents.player_damage_resolved.connect(_on_damage_resolved)
	if Global != null and Global.has_signal("balance_segment_completed"):
		if not Global.balance_segment_completed.is_connected(_on_segment_completed):
			Global.balance_segment_completed.connect(_on_segment_completed)


func _exit_tree() -> void:
	intact = true
	if RunEvents != null and RunEvents.player_damage_resolved.is_connected(_on_damage_resolved):
		RunEvents.player_damage_resolved.disconnect(_on_damage_resolved)
	if Global != null and Global.has_signal("balance_segment_completed"):
		if Global.balance_segment_completed.is_connected(_on_segment_completed):
			Global.balance_segment_completed.disconnect(_on_segment_completed)


func get_power_multiplier() -> float:
	return 1.0 + power_bonus_for(item) if intact else 1.0


func _on_damage_resolved(who: Node, _raw: float, _adjusted: float, applied: float, _source: Node, _kind: StringName, outcome: StringName) -> void:
	if who != player or outcome != &"hit" or applied <= 0.0 or not intact:
		return
	var max_hp := float(player.get("max_hp")) if player != null else 100.0
	if max_hp <= 0.0 or applied < DROP_HIT_FRACTION * max_hp:
		return
	intact = false
	_drop_at = player.global_position
	_auto_return_left = AUTO_RETURN_SECONDS
	telemetry["drops"] = int(telemetry["drops"]) + 1
	if BattleText != null:
		BattleText.popup(_drop_at + Vector2(0, -24), "dignity dropped", Color(0.85, 0.8, 0.7, 0.95), 1.2)


func _restore(reason: String) -> void:
	if intact:
		return
	intact = true
	if reason == "recovered":
		telemetry["recoveries"] = int(telemetry["recoveries"]) + 1
	elif reason == "auto":
		telemetry["auto_returns"] = int(telemetry["auto_returns"]) + 1
	if BattleText != null and player != null:
		BattleText.popup(player.global_position + Vector2(0, -24), "dignity restored", Color(0.95, 0.88, 0.6, 1.0), 1.2)


func _on_segment_completed(_segment: int) -> void:
	_restore("segment")


func _process(delta: float) -> void:
	if intact:
		return
	# Recovery: walking back over the standard where it fell.
	if player != null and is_instance_valid(player) and player.global_position.distance_to(_drop_at) <= RECOVER_RADIUS:
		_restore("recovered")
		return
	_auto_return_left -= delta
	if _auto_return_left <= 0.0:
		_restore("auto")
		return
	queue_redraw()


func _draw() -> void:
	if intact:
		return
	draw_set_transform_matrix(get_global_transform().affine_inverse())
	var texture := load("res://assets/textures/items/rings/dignity.png") as Texture2D
	if texture != null:
		# Fixed world height: the dropped standard reads at the same size
		# whatever resolution the icon art ships at.
		var size: Vector2 = texture.get_size() * (44.0 / maxf(texture.get_size().y, 1.0))
		draw_texture_rect(texture, Rect2(_drop_at - size * 0.5, size), false)
	var wave := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 300.0)
	draw_arc(_drop_at, RECOVER_RADIUS * (0.8 + 0.2 * wave), 0.0, TAU, 32, Color(0.95, 0.88, 0.6, 0.35 + 0.25 * wave), 1.5, true)


func describe() -> Dictionary:
	return {"intact": intact, "drop_at": _drop_at, "auto_return_left": _auto_return_left, "telemetry": telemetry.duplicate()}
