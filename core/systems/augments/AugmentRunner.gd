extends Node
class_name AugmentRunner

@export var debug_augments: bool = false

var _active: Dictionary = {} # key(scene_path#slot) -> Node

func refresh() -> void:
	var wanted: Dictionary = {} # key -> { scn: PackedScene, slot: int }

	Global.init_permanent_augments()

	for i in range(Global.permanent_augment_ids.size()):
		var aug_id: StringName = Global.permanent_augment_ids[i]
		if aug_id == StringName():
			continue

		var a := Global.augment_db.get(aug_id, null) as AugmentData
		if a == null:
			continue

		for scn: PackedScene in a.effect_scenes:
			if scn == null:
				continue

			var base := scn.resource_path
			if base == "":
				base = str(scn)

			var key := StringName("%s#%d" % [base, i])
			wanted[key] = {"scn": scn, "slot": i, "aug_id": aug_id, "level": Global.get_augment_level(aug_id) if Global.has_method("get_augment_level") else 1}

	_sync(wanted)

	if debug_augments:
		print("[AugmentRunner] wanted:", wanted.keys())
		print("[AugmentRunner] active :", _active.keys())

func _sync(wanted: Dictionary) -> void:
	# remove old
	var old_keys: Array = _active.keys()
	for k in old_keys:
		if not wanted.has(k):
			var n: Node = _active.get(k, null)
			_active.erase(k)
			if is_instance_valid(n):
				n.queue_free()

	# prune invalid
	var prune_keys: Array = _active.keys()
	for k2 in prune_keys:
		if not is_instance_valid(_active.get(k2, null)):
			_active.erase(k2)


	# update existing nodes when level/id changes (important for Augment Overclock mid-run)
	for k3u in wanted.keys():
		if not _active.has(k3u):
			continue
		var inst_u: Node = _active.get(k3u, null)
		if inst_u == null or not is_instance_valid(inst_u):
			continue

		var entry_u: Dictionary = wanted[k3u]
		var aug_id_u: StringName = entry_u.get("aug_id", StringName())
		var lvl_u: int = int(entry_u.get("level", 1))

		# update metas
		if inst_u.get_meta("augment_id", StringName()) != aug_id_u:
			inst_u.set_meta("augment_id", aug_id_u)

		var old_lvl: int = int(inst_u.get_meta("augment_level", 1))
		if old_lvl != lvl_u:
			inst_u.set_meta("augment_level", lvl_u)
			if inst_u.has_method("set_level"):
				inst_u.call("set_level", lvl_u)

	# add new
	for k3 in wanted.keys():
		if _active.has(k3):
			continue

		var entry: Dictionary = wanted[k3]
		var scn: PackedScene = entry["scn"]
		var slot_idx: int = int(entry["slot"])

		var inst: Node = scn.instantiate()
		add_child(inst)

		# pass player ref
		if inst.has_method("setup"):
			inst.call("setup", get_parent())

		# pass augment id/level (opt-in)
		var aug_id: StringName = entry.get("aug_id", StringName())
		var level: int = int(entry.get("level", 1))
		inst.set_meta("augment_id", aug_id)
		inst.set_meta("augment_level", level)
		if inst.has_method("set_level"):
			inst.call("set_level", level)

		# bind slot index so the badge can find it
		inst.set_meta("hud_slot_index", slot_idx)

		# OPTIONAL: auto-map keys/actions if you add these InputMap actions
		var action := "augment_active_%d" % (slot_idx + 1)
		if InputMap.has_action(action) and inst.get("active_action") != null:
			inst.set("active_action", StringName(action))
			if inst.get("hud_key_text") != null:
				inst.set("hud_key_text", str(slot_idx + 1))

		_active[k3] = inst

func get_children_effects() -> Array:
	return get_children()


func reset_all_cooldowns() -> void:
	for n in get_children():
		if not is_instance_valid(n):
			continue
		if n.has_method("reset_cooldowns"):
			n.call("reset_cooldowns")
