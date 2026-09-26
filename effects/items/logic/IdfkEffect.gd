extends Node2D
class_name IdfkEffect
## IDFK (handoff §14.3 idea table, approved 2026-09-26): nobody knows what
## it does — until you notice. The rule is fixed and learnable, never
## random: stand still for 0.6 s and your attacks hit harder until you
## move. The item leaves clues ("…" when it arms); after the eighth arming
## the description simply becomes "Oh."

const ARM_SECONDS := 0.6
const STILL_SPEED := 4.0
const POWER_BONUS := 0.10            # capped at +16% by scaling
const POWER_BONUS_CAP := 0.16
const DISCOVERIES_NEEDED := 8

var player: Node2D = null
var item: ItemInstance = null
var slot_index: int = -1

var _still_for: float = 0.0
var _armed: bool = false
var _armings: int = 0
var telemetry: Dictionary = {"armings": 0, "discovered": false}


func get_effects_short(inst: ItemInstance) -> PackedStringArray:
	if _armings >= DISCOVERIES_NEEDED:
		return PackedStringArray([
			"Oh.",
			"+%.0f%% Power after standing still for %.1f s; moving ends it." % [power_bonus_for(inst) * 100.0, ARM_SECONDS],
		])
	return PackedStringArray([
		"IDFK. Something helps, sometimes.",
		"It leaves clues.",
	])


func power_bonus_for(inst: ItemInstance) -> float:
	var strength := inst.rarity_effect_multiplier() if inst != null else 1.0
	return minf(POWER_BONUS_CAP, POWER_BONUS * strength)


func get_power_multiplier() -> float:
	return 1.0 + power_bonus_for(item) if _armed else 1.0


func setup_with_item(p: Node, inst: ItemInstance, slot: int) -> void:
	player = p as Node2D
	item = inst
	slot_index = slot


func set_item_instance(inst: ItemInstance) -> void:
	item = inst


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var moving := true
	if player is CharacterBody2D:
		moving = (player as CharacterBody2D).velocity.length() > STILL_SPEED
	if moving:
		_still_for = 0.0
		_armed = false
		return
	_still_for += delta
	if not _armed and _still_for >= ARM_SECONDS:
		_armed = true
		_armings += 1
		telemetry["armings"] = _armings
		if _armings >= DISCOVERIES_NEEDED:
			telemetry["discovered"] = true
		if BattleText != null:
			var line := "…" if _armings < DISCOVERIES_NEEDED else "Oh."
			BattleText.popup(player.global_position + Vector2(0, -26), line, Color(0.8, 0.8, 0.9, 0.8), 1.0)


func describe() -> Dictionary:
	return {"armed": _armed, "armings": _armings, "telemetry": telemetry.duplicate()}
