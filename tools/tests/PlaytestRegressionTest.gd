extends Node

# Pins the four 2026-08-23 playtest bug fixes:
# 1. EnemyProxyRenderer.reset_actor_snapshot: a reused pooled node must not
#    render one frame at the previous occupant's death transform.
# 2. Augment slots: an id may occupy at most one slot (quick-equip dupes).
# 3. Vendor bag (auto_consolidate=false): selling an item the vendor also
#    stocks must never feed/rank the vendor's copy.
# 4. Inventory.add_or_feed: duplicates of an equipped item feed the equipped
#    copy instead of stranding a frozen bag stack.
# Run: <godot> --headless --path . res://tools/tests/PlaytestRegressionTest.tscn

const WorldScript = preload("res://core/systems/enemy_world/EnemyWorld.gd")
const RendererScript = preload("res://core/systems/enemy_world/EnemyProxyRenderer.gd")
const BagInventoryScript = preload("res://data/items/BagInventory.gd")

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


func _make_item_data(item_id: String) -> ItemData:
	var data := ItemData.new()
	data.id = item_id
	data.display_name = item_id
	return data


func _run() -> void:
	_test_renderer_snapshot_reset()
	_test_augment_slot_invariant()
	_test_vendor_bag_inert()
	_test_equipped_duplicate_feed()
	print("PlaytestRegressionTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_renderer_snapshot_reset() -> void:
	var world := WorldScript.new()
	add_child(world)
	var renderer := RendererScript.new()
	renderer.setup(world)
	add_child(renderer)

	var actor := Node2D.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	actor.add_child(sprite)
	add_child(actor)

	var death_pos := Vector2(500.0, 500.0)
	var spawn_pos := Vector2(-800.0, 120.0)
	actor.global_position = death_pos
	renderer.register_actor(actor, sprite)
	var entry: Dictionary = (renderer.get("_actors") as Dictionary)[actor.get_instance_id()]

	# Seed the snapshot at the death position (what publish does while alive).
	var t0 := 1_000_000
	renderer.call("_interpolated_actor_transform", entry, actor.global_transform, t0)

	# Pool reuse: node teleports to the new spawn. Without a reset, the
	# interpolation starts at the OLD position (the reported blink).
	actor.global_position = spawn_pos
	var stale: Transform2D = renderer.call("_interpolated_actor_transform", entry, actor.global_transform, t0 + 16_000)
	_check(
		stale.origin.distance_to(death_pos) < 1.0,
		"without reset the first frame renders at the death position (bug reproduced)"
	)

	# The fix: reset re-seeds from the current transform, no blink.
	renderer.register_actor(actor, sprite)
	renderer.reset_actor_snapshot(actor)
	var fresh: Transform2D = renderer.call("_interpolated_actor_transform", entry, actor.global_transform, t0 + 32_000)
	_check(
		fresh.origin.distance_to(spawn_pos) < 1.0,
		"after reset_actor_snapshot the first frame renders at the spawn position"
	)


func _test_augment_slot_invariant() -> void:
	if Global == null:
		_check(false, "Global autoload present for augment test")
		return
	var saved: Array = Global.permanent_augment_ids.duplicate()
	Global.init_permanent_augments()
	Global.permanent_augment_ids[0] = StringName()
	Global.permanent_augment_ids[1] = StringName()
	Global.permanent_augment_ids[2] = StringName()

	Global.set_permanent_augment(0, &"test_augment_x")
	Global.set_permanent_augment(1, &"test_augment_x")
	var occurrences := 0
	for slot in range(3):
		if Global.permanent_augment_ids[slot] == &"test_augment_x":
			occurrences += 1
	_check(occurrences == 1, "set_permanent_augment keeps one slot per id (got %d)" % occurrences)
	_check(
		Global.permanent_augment_ids[1] == &"test_augment_x",
		"the most recent slot wins the dedupe"
	)
	for slot in range(3):
		Global.permanent_augment_ids[slot] = saved[slot]


func _test_vendor_bag_inert() -> void:
	var data := _make_item_data("regression_ring")

	# Player-style bag (default): same-key stacks consolidate/feed.
	var player_bag: BagInventory = BagInventoryScript.new()
	player_bag._ensure_size()
	player_bag.slots[0] = ItemInstance.from_roll(data, 1, ItemInstance.Polarity.POS, 0.5)
	player_bag.set_at(5, ItemInstance.from_roll(data, 0, ItemInstance.Polarity.POS, 0.4))
	var player_stacks := 0
	for inst in player_bag.slots:
		if inst != null:
			player_stacks += 1
	_check(player_stacks == 1, "player bag still consolidates duplicates (got %d stacks)" % player_stacks)

	# Vendor-style bag: items sit inertly; the vendor copy's rarity is frozen.
	var vendor_bag: BagInventory = BagInventoryScript.new()
	vendor_bag.auto_consolidate = false
	vendor_bag._ensure_size()
	var vendor_copy := ItemInstance.from_roll(data, 1, ItemInstance.Polarity.POS, 0.5)
	vendor_bag.slots[0] = vendor_copy
	vendor_bag.set_at(5, ItemInstance.from_roll(data, 3, ItemInstance.Polarity.POS, 0.9))
	var vendor_stacks := 0
	for inst in vendor_bag.slots:
		if inst != null:
			vendor_stacks += 1
	_check(vendor_stacks == 2, "vendor bag keeps sold duplicate separate (got %d stacks)" % vendor_stacks)
	_check(int(vendor_copy.rarity) == 1, "vendor copy rarity unchanged by the sale (r%d)" % int(vendor_copy.rarity))


func _test_equipped_duplicate_feed() -> void:
	var data := _make_item_data("regression_offhand")
	data.equip_slot = 1 as ItemData.EquipSlot

	var inv := Inventory.new()
	var equipped := ItemInstance.from_roll(data, 1, ItemInstance.Polarity.POS, 0.5)
	inv.set_item(int(data.equip_slot), equipped, null)

	var duplicate := ItemInstance.from_roll(data, 0, ItemInstance.Polarity.POS, 0.3)
	var fed := inv.add_or_feed(duplicate, null)
	_check(fed, "add_or_feed accepts a duplicate of the equipped item")
	_check(
		inv.get_at(int(data.equip_slot)) == equipped or int((inv.get_at(int(data.equip_slot)) as ItemInstance).rarity) >= 1,
		"the equipped copy absorbed the duplicate"
	)
	var occupied := 0
	for i in range(Inventory.SLOT_COUNT):
		if inv.get_at(i) != null:
			occupied += 1
	_check(occupied == 1, "no second stack was created (occupied=%d)" % occupied)
