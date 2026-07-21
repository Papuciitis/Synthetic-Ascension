extends Area2D
class_name ItemPickup

@onready var icon_sprite: Sprite2D = $Icon
@onready var vfx: PickupVfx = get_node_or_null("Vfx") as PickupVfx

@export var item_id: String = "":
	set(v):
		item_id = v
		if is_inside_tree():
			_update_visual()

@export var amount: int = 1
@export var pickup_delay: float = 0.25
@export var drop_pickup_delay: float = 1.0 # minimum delay if this pickup is a dropped instance
@export var debug_pickup: bool = false
@export var is_exploration_loot: bool = false # set true for exploration cache drops
@export var max_icon_px: float = 32.0 # max width/height in pixels (world size)

# If set, pickup uses this full instance (dropped from bag/equip) instead of item_id/amount
var item_instance: ItemInstance = null

var _pickup_ready: bool = false
var _picked: bool = false


func _ready() -> void:
	# Start disabled, enable after a short delay (prevents instant re-pickup)
	monitoring = false
	monitorable = false
	_pickup_ready = false
	_picked = false

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	# If this pickup represents a dropped instance, enforce minimum delay.
	if item_instance != null:
		pickup_delay = max(pickup_delay, drop_pickup_delay)

	_update_visual()

	# VFX wire + start locked until ready
	if vfx != null:
		vfx.bind_icon(icon_sprite)
		vfx.set_locked(true)
		if vfx.has_method("set_exploration"):
			vfx.call("set_exploration", is_exploration_loot)

	_enable_pickup_later()


# Public API for WorldDropSpawner (keeps spawner clean)
func play_throw(start_pos: Vector2, end_pos: Vector2, throw_time: float, arc_height: float, land_scale: float, land_time: float) -> void:
	if vfx != null:
		vfx.play_throw(start_pos, end_pos, throw_time, arc_height, land_scale, land_time)
	else:
		global_position = end_pos


func _dbg(args: Array) -> void:
	if not debug_pickup:
		return
	prints(args)


func _is_player(n: Node) -> bool:
	if n == null:
		return false
	if n.is_in_group("player"):
		return true
	var p: Node = n.get_parent()
	return p != null and p.is_in_group("player")


func _get_screen_pos_of_pickup() -> Vector2:
	# "screen-space" (CanvasLayer-space) position for UI VFX origins.
	# In Godot 4, viewport canvas transform includes camera.
	return get_viewport().get_canvas_transform() * global_position


func _set_bag_origin(screen_pos: Vector2) -> void:
	if Global.run_bag != null and Global.run_bag.has_method("set_pending_ui_origin"):
		Global.run_bag.call("set_pending_ui_origin", screen_pos)


func _clear_bag_origin() -> void:
	if Global.run_bag != null and Global.run_bag.has_method("clear_pending_ui_origin"):
		Global.run_bag.call("clear_pending_ui_origin")


func _try_pickup() -> void:
	if _picked or not _pickup_ready:
		return

	# UI fly origin (screen/canvas space)
	var start_screen: Vector2 = _get_screen_pos_of_pickup()

	var origin := {"type": 1, "pos": start_screen}
	# Don't lock the pickup if globals aren't ready
	if Global.run_inventory == null:
		push_warning("run_inventory is null")
		return
	if Global.run_bag == null:
		push_warning("run_bag is null")
		return

	_picked = true

	# -------------------------
	# MODE A: pickup carries a full ItemInstance (dropped from bag/equip)
	# -------------------------
	if item_instance != null and item_instance.data != null:
		var inst: ItemInstance = item_instance
		var slot_a: int = inst.data.equip_slot

		_dbg(["[PICKUP INST]", "id=", inst.data.id, "slot=", slot_a, "inst_id=", inst.get_instance_id()])

		# Equip the whole instance if slot is empty
		if slot_a >= 0 and slot_a < Inventory.SLOT_COUNT and Global.run_inventory.is_slot_empty(slot_a):
			Global.run_inventory.set_item(slot_a, inst, origin)
			_dbg(["[PICKUP INST] EQUIPPED", "slot=", slot_a])
			queue_free()
			return

		# Otherwise, add the instance back into the bag (keeps its state)
		_set_bag_origin_from_pickup_world()
		var ok_inst: bool = Global.run_bag.add_instance(inst)
		if ok_inst:
			_dbg(["[PICKUP INST] BAGGED"])
			queue_free()
			return

		# Bag full -> keep it on ground
		_clear_bag_origin()
		_dbg(["[PICKUP INST] BAG FULL (leave on ground)"])
		_picked = false
		return

	# -------------------------
	# MODE B: normal pickup (item_id + amount) — roll per copy ONCE
	# -------------------------
	var item_data: ItemData = Global.get_item_data(item_id)
	if item_data == null:
		push_warning("Item id not found in DB: " + item_id)
		_picked = false
		return

	var copies: int = maxi(1, amount)
	var slot: int = item_data.equip_slot
	var r: int = 0 # later: pickups can carry rarity too

	_dbg(["[PICKUP]", "id=", item_data.id, "slot=", slot, "copies=", copies])

	for i in range(copies):
		# roll per copy (ONE roll, used either for equip/feed or bag)
		var roll_pct: float = Global.roll_percent(Global.run_luck, item_data.pct_min, item_data.pct_max)
		var pol: int = (ItemInstance.Polarity.POS if roll_pct >= 0.0 else ItemInstance.Polarity.NEG)

		_dbg(["[ROLL]", "i=", i, "roll=", String.num(roll_pct, 3),
			"pol=", ("POS" if pol == ItemInstance.Polarity.POS else "NEG")])

		var consumed := false

		# Try equip / auto-feed equipped if it has a valid slot
		if slot >= 0 and slot < Inventory.SLOT_COUNT:
			var equipped2: ItemInstance = Global.run_inventory.get_at(slot) as ItemInstance

			# Empty equip slot -> equip this roll as a new instance
			if equipped2 == null:
				var equipped_inst: ItemInstance = ItemInstance.from_roll(item_data, r, pol, roll_pct)
				Global.run_inventory.set_item(slot, equipped_inst, origin)
				_dbg(["[EQUIP NEW]", "slot=", slot, "inst_id=", equipped_inst.get_instance_id()])
				consumed = true

			# Same id + rarity + polarity -> feed roll into equipped item
			elif equipped2.data != null \
			and equipped2.data.id == item_data.id \
			and equipped2.polarity == pol:
				Global.run_inventory.feed_roll_into(slot, roll_pct, origin)
				_dbg(["[EQUIP FEED]", "slot=", slot, "inst_id=", equipped2.get_instance_id()])
				consumed = true

		# If not consumed by equip/feed, put THIS SAME ROLL into the bag
		if not consumed:
			_set_bag_origin_from_pickup_world()
			var ok: bool = Global.run_bag.add_roll(item_data, r, pol, roll_pct)
			if not ok:
				_clear_bag_origin()
				_dbg(["[BAG FULL] leave pickup on ground", "remaining=", (copies - i)])
				amount = copies - i
				_picked = false
				return
			_dbg(["[BAG ADD]", "roll=", String.num(roll_pct, 3)])

	_dbg(["[PICKUP DONE]", item_data.display_name, "x", copies])
	var sm := get_node_or_null("/root/SfxManager")
	if sm != null:
		sm.call("play_2d", &"pickup", global_position)
	queue_free()


func _enable_pickup_later() -> void:
	if pickup_delay <= 0.0:
		monitorable = true
		monitoring = true
		_pickup_ready = true
		if vfx != null:
			vfx.set_locked(false)
		return

	await get_tree().create_timer(pickup_delay).timeout
	if not is_inside_tree():
		return

	monitorable = true
	monitoring = true
	_pickup_ready = true

	if vfx != null:
		vfx.set_locked(false)

func _world_to_screen(p_world: Vector2) -> Vector2:
	# Godot 4 (2D): world/canvas -> screen using the viewport canvas transform (includes Camera2D)
	return get_viewport().get_canvas_transform() * p_world


func _set_bag_origin_from_pickup_world() -> void:
	_set_bag_origin(_world_to_screen(global_position))
	
func _on_area_entered(a: Area2D) -> void:
	if _is_player(a):
		_try_pickup()


func _on_body_entered(b: Node2D) -> void:
	if _is_player(b):
		_try_pickup()


func _update_visual() -> void:
	if icon_sprite == null:
		return

	var tex: Texture2D = null
	if item_instance != null and item_instance.data != null:
		tex = item_instance.data.icon
	else:
		var d: ItemData = Global.get_item_data(item_id)
		if d != null:
			tex = d.icon

	icon_sprite.texture = tex
	icon_sprite.visible = (tex != null)

	if tex != null:
		_fit_icon_to_max(tex)

	# Optional: tint ONLY when polarity is known (bag-dropped instances)
	if item_instance != null:
		var is_pos := (item_instance.polarity == ItemInstance.Polarity.POS)
		icon_sprite.modulate = (Color(0.85, 1.0, 1.0, 1.0) if is_pos else Color(1.0, 0.75, 0.8, 1.0))
	else:
		icon_sprite.modulate = Color(1, 1, 1, 1)


func _fit_icon_to_max(tex: Texture2D) -> void:
	if max_icon_px <= 0.0:
		icon_sprite.scale = Vector2.ONE
		return

	var sz: Vector2 = tex.get_size()
	var max_dim: float = maxf(sz.x, sz.y)
	if max_dim <= 0.0:
		icon_sprite.scale = Vector2.ONE
		return

	# Only scale down (never scale up)
	var factor: float = minf(1.0, max_icon_px / max_dim)
	icon_sprite.scale = Vector2.ONE * factor
	icon_sprite.centered = true
