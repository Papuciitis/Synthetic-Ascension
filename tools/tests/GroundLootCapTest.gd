extends Node

# Ordinary drops on the ground are capped: past the cap the lowest-rarity,
# oldest ordinary pickup leaves when a new one lands; exploration loot and
# player-placed drops are never culled; health pickups have their own cap.
#
# Run: <godot> --headless --path . res://tools/tests/GroundLootCapTest.tscn

const ITEM_SCENE = preload("res://scenes/world/pickups/ItemPickup.tscn")
const HEALTH_SCENE = preload("res://scenes/world/pickups/HealthPickup.tscn")

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _drop(rarity: int, exploration: bool = false, persistent: bool = false) -> ItemPickup:
	var pickup := ITEM_SCENE.instantiate() as ItemPickup
	var instance := ItemInstance.new()
	instance.rarity = rarity
	pickup.item_instance = instance
	pickup.is_exploration_loot = exploration
	pickup.persistent_world_drop = persistent
	pickup.position = Vector2(randf() * 400.0, randf() * 400.0)
	add_child(pickup)
	return pickup


func _live(group: StringName) -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group(group):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			out.append(node)
	return out


func _run() -> void:
	var cap := GroundLootCap.ITEM_CAP
	var kept_exploration := _drop(0, true)
	var kept_persistent := _drop(0, false, true)
	var rare := _drop(4)
	for _i in range(cap + 30):
		_drop(0)
	await get_tree().process_frame
	await get_tree().process_frame
	var live := _live(GroundLootCap.ITEM_GROUP)
	_check(live.size() <= cap, "ordinary drops are held at the cap (%d of cap %d)" % [live.size(), cap])
	_check(is_instance_valid(kept_exploration) and not kept_exploration.is_queued_for_deletion(), "exploration loot survives the cull")
	_check(is_instance_valid(kept_persistent) and not kept_persistent.is_queued_for_deletion(), "a player-placed drop survives the cull")
	_check(is_instance_valid(rare) and not rare.is_queued_for_deletion(), "the rare drop survives while commons leave first")
	var newest := _drop(0)
	await get_tree().process_frame
	_check(is_instance_valid(newest) and not newest.is_queued_for_deletion() and _live(GroundLootCap.ITEM_GROUP).size() <= cap, "the newcomer stays and an older common leaves")

	for _i in range(GroundLootCap.HEALTH_CAP + 15):
		var health := HEALTH_SCENE.instantiate()
		health.position = Vector2(randf() * 400.0, randf() * 400.0)
		add_child(health)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_live(GroundLootCap.HEALTH_GROUP).size() <= GroundLootCap.HEALTH_CAP, "health pickups are held at their cap (%d)" % _live(GroundLootCap.HEALTH_GROUP).size())
	print("GroundLootCapTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
