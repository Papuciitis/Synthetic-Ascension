extends Node2D
class_name TraumaEffect
## Trauma (handoff §14.3, made concrete): the body adapts to whatever hurt
## it most recently. A MAJOR hit (a real loss of at least 15% of max HP)
## teaches a resistance against that one source category; the next major
## hit from a DIFFERENT category replaces the lesson. Never blanket
## immunity: one category at a time, the reduction is capped, and the
## teaching hit itself is never reduced retroactively.

const MAJOR_HIT_FRACTION := 0.15
const BASE_REDUCTION := 0.30
const REDUCTION_CAP := 0.40

var player: Node2D = null
var item: ItemInstance = null
var slot_index: int = -1

## The learned category: an enemy spec id, or the damage kind for sources
## without a spec (self damage, hazards). Empty until the first lesson.
var learned_category: StringName = &""
var telemetry: Dictionary = {"lessons": 0, "reduced_hits": 0}


func get_effects_short(inst: ItemInstance) -> PackedStringArray:
	return PackedStringArray([
		"A hit for 15%%+ of max HP teaches %.0f%% resistance against that source." % (reduction_for(inst) * 100.0),
		"The next major wound from something else replaces the lesson.",
		"One scar at a time. It does not forget forward.",
	])


func reduction_for(inst: ItemInstance) -> float:
	var strength := inst.rarity_effect_multiplier() if inst != null else 1.0
	return minf(REDUCTION_CAP, BASE_REDUCTION * strength)


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
	# Unequipping forgets the lesson; scars do not travel in the bag.
	learned_category = &""
	if RunEvents != null and RunEvents.player_damage_resolved.is_connected(_on_damage_resolved):
		RunEvents.player_damage_resolved.disconnect(_on_damage_resolved)


static func category_of(source: Node, kind: StringName) -> StringName:
	if source != null and is_instance_valid(source):
		var spec: Variant = source.get("spec") if "spec" in source else null
		if spec != null and spec.get("id") != null:
			return StringName(spec.get("id"))
	return kind if kind != StringName() else &"unknown"


## The learning half: only a real HP loss teaches (outcome "hit"), only a
## major one, and the teaching hit itself was already resolved at full
## damage — the resistance starts with the NEXT hit.
func _on_damage_resolved(who: Node, _raw: float, _adjusted: float, applied: float, source: Node, kind: StringName, outcome: StringName) -> void:
	if who != player or outcome != &"hit" or applied <= 0.0:
		return
	var max_hp := float(player.get("max_hp")) if player != null else 100.0
	if max_hp <= 0.0 or applied < MAJOR_HIT_FRACTION * max_hp:
		return
	var category := category_of(source, kind)
	if category == learned_category:
		return
	learned_category = category
	telemetry["lessons"] = int(telemetry["lessons"]) + 1
	if BattleText != null and player != null:
		BattleText.popup(player.global_position + Vector2(0, -30), "learned: %s" % String(category).trim_prefix("enemy_"), Color(0.8, 0.75, 0.7, 0.95), 1.3)


## The protection half, consulted per incoming hit by the player.
func get_damage_taken_multiplier_for(source: Node, kind: StringName) -> float:
	if learned_category == &"":
		return 1.0
	if category_of(source, kind) != learned_category:
		return 1.0
	telemetry["reduced_hits"] = int(telemetry["reduced_hits"]) + 1
	return 1.0 - reduction_for(item)


func describe() -> Dictionary:
	return {"learned": learned_category, "reduction": reduction_for(item), "telemetry": telemetry.duplicate()}
