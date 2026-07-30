extends Node2D
class_name ItemEffectRunner

signal effect_added(effect: Node)
signal effect_removed(effect: Node)

@export var debug_items: bool = false
@export var watched_slots: Array[int] = [Inventory.SLOT_OFFHAND, Inventory.SLOT_RING]

# key(StringName) -> Node(effect instance)
var _active_effects: Dictionary = {}

var _bound_inv: Inventory = null

func _ready() -> void:
	position = Vector2.ZERO
	set_process(true)
	_rebind_if_needed(true)

func _process(_dt: float) -> void:
	_rebind_if_needed(false)

func _rebind_if_needed(force: bool) -> void:
	var inv: Inventory = Global.run_inventory as Inventory if Global != null else null
	if not force and inv == _bound_inv:
		return

	# disconnect old
	if _bound_inv != null and _bound_inv.changed.is_connected(_on_inventory_changed):
		_bound_inv.changed.disconnect(_on_inventory_changed)

	_bound_inv = inv

	# connect new
	if _bound_inv != null and not _bound_inv.changed.is_connected(_on_inventory_changed):
		_bound_inv.changed.connect(_on_inventory_changed)

	_on_inventory_changed()

func _on_inventory_changed() -> void:
	refresh_effects(_bound_inv)

func refresh_effects(inv: Inventory) -> void:
	if inv == null:
		_clear_all()
		return

	var wanted: Dictionary = {} # key -> {scn, slot, inst}
	for slot in watched_slots:
		var it: ItemInstance = inv.get_at(int(slot)) as ItemInstance
		if it == null or it.data == null:
			continue

		for scn: PackedScene in it.data.get_effect_scenes(it):
			if scn == null:
				continue

			var base := StringName(scn.resource_path)
			if base == StringName():
				base = StringName(str(scn))

			# Slot-suffix ensures the same scene can run independently in multiple slots.
			var key := StringName("%s#%d" % [String(base), int(slot)])
			wanted[key] = {"scn": scn, "slot": int(slot), "inst": it}

	_sync_effects(wanted)

	if debug_items:
		print("[ItemEffectRunner] wanted:", wanted.keys())
		print("[ItemEffectRunner] active :", _active_effects.keys())

func apply_effects_to_stats(s: Stats) -> void:
	if s == null:
		return
	for n in _active_effects.values():
		if is_instance_valid(n) and n.has_method("apply_to_stats"):
			n.call("apply_to_stats", s)


func apply_to_ranged_bullet(bullet: Node, style_id: StringName) -> void:
	if bullet == null:
		return
	for n in _active_effects.values():
		if is_instance_valid(n) and n.has_method("apply_to_ranged_bullet"):
			n.call("apply_to_ranged_bullet", bullet, style_id)

func apply_to_managed_hit_profile(profile: HitProfileAdapter, style_id: StringName) -> void:
	# Compatibility bridge: existing effects (currently Firestone) can mutate the
	# reusable adapter through their old bullet hook. No gameplay bullet Node is
	# instantiated and the manager copies all values before the adapter is reused.
	if profile == null:
		return
	for n in _active_effects.values():
		if is_instance_valid(n) and n.has_method("apply_to_hit_profile"):
			n.call("apply_to_hit_profile", profile, style_id)

func apply_to_magic_impact(impact: Node) -> void:
	if impact == null:
		return
	for n in _active_effects.values():
		if is_instance_valid(n) and n.has_method("apply_to_magic_impact"):
			n.call("apply_to_magic_impact", impact)

func apply_to_melee_slash(slash: Node) -> void:
	if slash == null:
		return
	for n in _active_effects.values():
		if is_instance_valid(n) and n.has_method("apply_to_melee_slash"):
			n.call("apply_to_melee_slash", slash)

func get_move_speed_multiplier() -> float:
	var mul := 1.0
	for n in _active_effects.values():
		if is_instance_valid(n) and n.has_method("get_move_speed_multiplier"):
			mul *= float(n.call("get_move_speed_multiplier"))
	return mul

func get_haste_multiplier() -> float:
	var mul := 1.0
	for n in _active_effects.values():
		if is_instance_valid(n) and n.has_method("get_haste_multiplier"):
			mul *= float(n.call("get_haste_multiplier"))
	return mul

func get_power_multiplier() -> float:
	var mul := 1.0
	for n in _active_effects.values():
		if is_instance_valid(n) and n.has_method("get_power_multiplier"):
			mul *= float(n.call("get_power_multiplier"))
	return mul

func get_damage_taken_multiplier() -> float:
	var mul := 1.0
	for n in _active_effects.values():
		if is_instance_valid(n) and n.has_method("get_damage_taken_multiplier"):
			mul *= float(n.call("get_damage_taken_multiplier"))
	return mul

func _sync_effects(wanted: Dictionary) -> void:
	# 1) Remove effects that are no longer wanted
	var old_keys: Array = _active_effects.keys()
	for k in old_keys:
		if not wanted.has(k):
			var n: Node = _active_effects.get(k, null)
			_active_effects.erase(k)
			if is_instance_valid(n):
				effect_removed.emit(n)
				n.queue_free()

	# 2) Prune invalid instances
	var prune_keys: Array = _active_effects.keys()
	for k2 in prune_keys:
		var n2: Node = _active_effects.get(k2, null)
		if not is_instance_valid(n2):
			_active_effects.erase(k2)

	# 3) Add new wanted effects / update existing with current item instance
	for k3 in wanted.keys():
		var entry: Dictionary = wanted[k3]
		var inst_item: ItemInstance = entry.get("inst", null)
		var slot_idx: int = int(entry.get("slot", -1))

		if _active_effects.has(k3) and is_instance_valid(_active_effects[k3]):
			var existing: Node = _active_effects[k3]
			if existing.has_method("set_item_instance"):
				existing.call("set_item_instance", inst_item)
			existing.set_meta("item_instance", inst_item)
			existing.set_meta("item_slot_index", slot_idx)
			continue

		var scn: PackedScene = entry.get("scn", null)
		if scn == null:
			continue

		var node: Node = scn.instantiate()
		add_child(node)

		# ItemEffectRunner is child of Player, so parent is Player
		var p := get_parent()

		if node.has_method("setup_with_item"):
			node.call("setup_with_item", p, inst_item, slot_idx)
		elif node.has_method("setup"):
			node.call("setup", p)

		if node.has_method("set_item_instance"):
			node.call("set_item_instance", inst_item)

		node.set_meta("item_instance", inst_item)
		node.set_meta("item_slot_index", slot_idx)

		_active_effects[k3] = node
		effect_added.emit(node)

func _clear_all() -> void:
	var keys: Array = _active_effects.keys()
	for k in keys:
		var n: Node = _active_effects.get(k, null)
		_active_effects.erase(k)
		if is_instance_valid(n):
			effect_removed.emit(n)
			n.queue_free()
