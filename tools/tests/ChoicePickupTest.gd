extends Node

# "Take one" pickups (the evidence store's POS / NEG pair): taking one of a
# choice group seals the others away and announces the choice.
#
# Run: <godot> --headless --path . --quit-after 3000 res://tools/tests/ChoicePickupTest.tscn

const PICKUP := preload("res://scenes/world/pickups/ItemPickup.tscn")

var _passes := 0
var _failures := 0
var _taken: Array = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _make_data(item_id: String) -> ItemData:
	var data := ItemData.new()
	data.id = item_id
	data.display_name = item_id
	data.equip_slot = ItemData.EquipSlot.RING
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	return data


func _pickup(inst: ItemInstance, group: int, at: Vector2) -> ItemPickup:
	var pickup := PICKUP.instantiate() as ItemPickup
	pickup.item_instance = inst
	pickup.item_id = String(inst.data.id)
	pickup.choice_group = group
	pickup.pickup_delay = 0.0
	pickup.global_position = at
	add_child(pickup)
	return pickup


func _run() -> void:
	Global.start_new_attempt()
	RunEvents.choice_pickup_taken.connect(func(group: int, inst: ItemInstance) -> void: _taken.append([group, inst]))
	var data := _make_data("evidence_ring")
	var blessed := ItemInstance.from_roll(data, 3, ItemInstance.Polarity.POS, 0.7, false)
	var cursed := ItemInstance.from_roll(data, 3, ItemInstance.Polarity.NEG, 0.9, false)
	var a := _pickup(blessed, 31, Vector2(100, 0))
	var b := _pickup(cursed, 31, Vector2(200, 0))
	var loose := _pickup(ItemInstance.from_roll(_make_data("loose_ring"), 1, ItemInstance.Polarity.POS, 0.5, false), 0, Vector2(300, 0))
	await get_tree().process_frame
	_check(a.is_in_group(GroundLootCap.ITEM_GROUP) and b.is_in_group(GroundLootCap.ITEM_GROUP), "both pickups sit in the ground item group")
	a.call("_collect")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not is_instance_valid(b), "taking the blessed copy seals the cursed one away")
	_check(is_instance_valid(loose), "a pickup outside the group is untouched")
	_check(_taken.size() == 1 and int(_taken[0][0]) == 31 and _taken[0][1] == blessed, "the choice is announced once with its group and the taken instance")
	_check(Global.run_inventory.get_at(ItemData.EquipSlot.RING) == blessed or Global.run_bag.get_slot_count() > 0, "the taken copy reached the player")
	print("ChoicePickupTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
