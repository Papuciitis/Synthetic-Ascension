extends Node
class_name SetRunner

signal effect_added(effect: Node)
signal effect_removed(effect: Node)

@export var debug_sets: bool = false

# key(StringName scene_path) -> Node(effect instance)
var _active_effects: Dictionary = {}

func apply_sets_to_stats(s: Stats, inv: Inventory) -> void:
	if inv == null:
		_clear_all()
		return

	var counts: Dictionary = inv.get_set_counts()
	# key(StringName scene_path) -> { scn: PackedScene, sid: StringName, count: int, avg_r: float, strength: float }
	var wanted: Dictionary = {}

	# Build "wanted" effects + apply tier stat mods
	for sid_v in counts.keys():
		var sid := StringName(str(sid_v))
		var sd := Global.set_db.get(sid, null) as SetData
		if sd == null:
			continue

		var c: int = int(counts[sid_v])
		var avg_r: float = 0.0
		var strength: float = 1.0
		if inv.has_method("get_set_rarity_average"):
			avg_r = float(inv.call("get_set_rarity_average", sid))
		if inv.has_method("get_set_strength"):
			strength = float(inv.call("get_set_strength", sid))

		for t: SetTier in sd.active_tiers(c):
			if t == null:
				continue

			# Apply stat deltas (flat; effects handle rarity scaling)
			t.apply_to(s)

			# Collect effect scenes
			for scn: PackedScene in t.effect_scenes:
				if scn == null:
					continue
				var key := StringName(scn.resource_path)
				if key == StringName():
					# If it's not saved to disk, resource_path can be empty.
					key = StringName(str(scn))
				wanted[key] = {
					"scn": scn,
					"sid": sid,
					"count": c,
					"avg_r": avg_r,
					"strength": strength,
				}

	_sync_effects(wanted)
	_update_scaling(inv, counts)

	if debug_sets:
		print("[SetRunner] wanted:", wanted.keys())
		print("[SetRunner] active :", _active_effects.keys())

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

	# 2) Prune invalid instances (if freed elsewhere)
	var prune_keys: Array = _active_effects.keys()
	for k2 in prune_keys:
		var n2: Node = _active_effects.get(k2, null)
		if not is_instance_valid(n2):
			_active_effects.erase(k2)

	# 3) Add new wanted effects
	for k3 in wanted.keys():
		if _active_effects.has(k3):
			continue

		var meta: Dictionary = wanted[k3]
		var scn: PackedScene = meta.get("scn", null)
		if scn == null:
			continue

		var inst: Node = scn.instantiate()
		add_child(inst)

		var p := get_parent()

		# Prefer setup_set(p, sid, count, avg_r, strength) if available.
		if inst.has_method("setup_set"):
			inst.call("setup_set",
				p,
				meta.get("sid", StringName()),
				int(meta.get("count", 0)),
				float(meta.get("avg_r", 0.0)),
				float(meta.get("strength", 1.0))
			)
		elif inst.has_method("setup"):
			inst.call("setup", p)

		_active_effects[k3] = inst
		effect_added.emit(inst)

func _update_scaling(inv: Inventory, counts: Dictionary) -> void:
	# Update scaling on already-active effects when rarity changes (or upgrades happen),
	# without requiring the effect node to be recreated.
	if inv == null:
		return

	for n in _active_effects.values():
		if n == null or not is_instance_valid(n):
			continue
		if not n.has_method("set_set_scaling"):
			continue

		var sid_v = n.get("source_set_id")
		if typeof(sid_v) != TYPE_STRING_NAME:
			continue
		var sid: StringName = sid_v

		var c := int(counts.get(sid, 0))
		var avg_r := float(inv.call("get_set_rarity_average", sid)) if inv.has_method("get_set_rarity_average") else 0.0
		var strength := float(inv.call("get_set_strength", sid)) if inv.has_method("get_set_strength") else 1.0
		n.call("set_set_scaling", sid, c, avg_r, strength)

func _clear_all() -> void:
	var keys: Array = _active_effects.keys()
	for k in keys:
		var n: Node = _active_effects.get(k, null)
		_active_effects.erase(k)
		if is_instance_valid(n):
			effect_removed.emit(n)
			n.queue_free()

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

func get_active_effect_keys() -> Array:
	return _active_effects.keys()

func refresh_effects(inv: Inventory) -> void:
	# kept for compatibility
	if inv == null:
		_clear_all()
		return

	var counts: Dictionary = inv.get_set_counts()
	var wanted: Dictionary = {}

	for sid_v in counts.keys():
		var sid := StringName(str(sid_v))
		var sd := Global.set_db.get(sid, null) as SetData
		if sd == null:
			continue

		var c: int = int(counts[sid_v])
		var avg_r: float = float(inv.call("get_set_rarity_average", sid)) if inv.has_method("get_set_rarity_average") else 0.0
		var strength: float = float(inv.call("get_set_strength", sid)) if inv.has_method("get_set_strength") else 1.0

		for t: SetTier in sd.active_tiers(c):
			if t == null:
				continue

			for scn: PackedScene in t.effect_scenes:
				if scn == null:
					continue
				var key := StringName(scn.resource_path)
				if key == StringName():
					key = StringName(str(scn))
				wanted[key] = { "scn": scn, "sid": sid, "count": c, "avg_r": avg_r, "strength": strength }

	_sync_effects(wanted)
	_update_scaling(inv, counts)
