extends Node2D
class_name SevenMileBootsEffect
## 7-Mile Boots, Hand-Me-Downs (handoff §14.3 idea table, approved
## 2026-09-26): dashes reach further, and for a moment afterwards you may
## step back into the boot you left behind. The return is an opportunity,
## not a stance: one window per dash, gone the instant a new dash begins,
## cleared with the scene. The dash itself stays the same authored move —
## fixed speed, longer travel, exactly like a Lunge sets its own distance.

const DASH_BONUS := 0.4              # capped at +60% by scaling
const DASH_BONUS_CAP := 0.6
const RETURN_WINDOW := 1.5

var player: Node2D = null
var item: ItemInstance = null
var slot_index: int = -1

var _boot_at: Vector2 = Vector2.ZERO
var _window_left: float = 0.0
var _was_dashing: bool = false
var telemetry: Dictionary = {"boosted_dashes": 0, "returns": 0}


func get_effects_short(inst: ItemInstance) -> PackedStringArray:
	return PackedStringArray([
		"+%.0f%% dash distance." % (dash_bonus_for(inst) * 100.0),
		"For %.1f s after a dash, press dash again (while it recovers) to step back to where it began." % RETURN_WINDOW,
		"Hand-me-downs. Someone walked far in these.",
	])


func dash_bonus_for(inst: ItemInstance) -> float:
	var strength := inst.rarity_effect_multiplier() if inst != null else 1.0
	return minf(DASH_BONUS_CAP, DASH_BONUS * strength)


func get_dash_distance_multiplier() -> float:
	return 1.0 + dash_bonus_for(item)


func setup_with_item(p: Node, inst: ItemInstance, slot: int) -> void:
	player = p as Node2D
	item = inst
	slot_index = slot


func set_item_instance(inst: ItemInstance) -> void:
	item = inst


func _ready() -> void:
	if RunEvents != null and not RunEvents.player_dashed.is_connected(_on_player_dashed):
		RunEvents.player_dashed.connect(_on_player_dashed)


func _exit_tree() -> void:
	# Scene changes and unequips clear the boot; no cross-room teleports.
	_window_left = 0.0
	if RunEvents != null and RunEvents.player_dashed.is_connected(_on_player_dashed):
		RunEvents.player_dashed.disconnect(_on_player_dashed)


func _on_player_dashed(who: Node, from_position: Vector2, _direction: Vector2) -> void:
	if who != player:
		return
	# A new dash plants a new boot and forfeits the old return.
	_boot_at = from_position
	_window_left = 0.0
	telemetry["boosted_dashes"] = int(telemetry["boosted_dashes"]) + 1


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var dash_state: Variant = player.get("_dash")
	if dash_state == null:
		return
	var dashing: bool = dash_state.is_dashing()
	if _was_dashing and not dashing:
		# The dash just ended: the boot stands where it began.
		_window_left = RETURN_WINDOW
	_was_dashing = dashing
	if _window_left <= 0.0:
		return
	_window_left = maxf(0.0, _window_left - delta)
	queue_redraw()
	# The return: the dash input while the dash itself is still recovering.
	# A ready dash takes priority (the press starts a fresh one instead).
	if Input.is_action_just_pressed(&"dash") and not bool(dash_state.can_start()):
		_return_to_boot()


func _return_to_boot() -> void:
	_window_left = 0.0
	telemetry["returns"] = int(telemetry["returns"]) + 1
	player.global_position = _boot_at
	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO
	if BattleText != null:
		BattleText.popup(_boot_at + Vector2(0, -24), "seven miles back", Color(0.8, 0.85, 0.75, 0.95), 1.1)
	queue_redraw()


func _draw() -> void:
	if _window_left <= 0.0:
		return
	draw_set_transform_matrix(get_global_transform().affine_inverse())
	var fade := clampf(_window_left / RETURN_WINDOW, 0.0, 1.0)
	var texture := load("res://assets/textures/items/rings/seven_mile_boots.png") as Texture2D
	if texture != null:
		var height := 22.0
		var size := texture.get_size() * (height / maxf(float(texture.get_height()), 1.0))
		draw_texture_rect(texture, Rect2(_boot_at - size * 0.5, size), false, Color(1, 1, 1, 0.4 + 0.5 * fade))
	# Pixel-art kit (Batch B, 2026-09-27): a ring sprite replaces the arc around
	# the boot. draw_ring sets no transform of its own (no spin), so the
	# world-space transform above still places it at the boot.
	VfxKit.draw_ring(self, _boot_at, 12.0 + 4.0 * (1.0 - fade), Color(0.85, 0.9, 0.8, 0.5 * fade), 1.5)


func describe() -> Dictionary:
	return {"window_left": _window_left, "boot_at": _boot_at, "telemetry": telemetry.duplicate()}
