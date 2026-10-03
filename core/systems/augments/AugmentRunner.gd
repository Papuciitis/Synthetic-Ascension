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
			wanted[key] = {
				"scn": scn, "slot": i, "aug_id": aug_id,
				"level": Global.get_augment_level(aug_id) if Global.has_method("get_augment_level") else 1,
				"transcended": Global.is_augment_transcended(aug_id) if Global.has_method("is_augment_transcended") else false,
				"facet": Global.augment_facet(aug_id) if Global.has_method("augment_facet") else &"",
			}

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

		# A Transcendence lands mid-run (a Binding, The Engine Prays).
		var turned_u: bool = bool(entry_u.get("transcended", false))
		if bool(inst_u.get_meta("augment_transcended", false)) != turned_u:
			inst_u.set_meta("augment_transcended", turned_u)
			if inst_u.has_method("set_transcended"):
				inst_u.call("set_transcended", turned_u)

		# A Facet is chosen mid-run (a Binding's FACET card).
		var facet_u: StringName = StringName(str(entry_u.get("facet", "")))
		if StringName(str(inst_u.get_meta("augment_facet", ""))) != facet_u:
			inst_u.set_meta("augment_facet", facet_u)
			if inst_u.has_method("set_facet"):
				inst_u.call("set_facet", facet_u)

	# add new
	for k3 in wanted.keys():
		if _active.has(k3):
			continue

		var entry: Dictionary = wanted[k3]
		var scn: PackedScene = entry["scn"]
		var slot_idx: int = int(entry["slot"])

		var inst: Node = scn.instantiate()

		# Metas must exist BEFORE add_child: effects resolve their input
		# action from hud_slot_index inside _ready(), which fires during
		# add_child — the old order made every effect see slot -1 first.
		var aug_id: StringName = entry.get("aug_id", StringName())
		var level: int = int(entry.get("level", 1))
		var turned: bool = bool(entry.get("transcended", false))
		var facet: StringName = StringName(str(entry.get("facet", "")))
		inst.set_meta("augment_id", aug_id)
		inst.set_meta("augment_level", level)
		inst.set_meta("augment_transcended", turned)
		inst.set_meta("augment_facet", facet)
		inst.set_meta("hud_slot_index", slot_idx)

		add_child(inst)

		# pass player ref
		if inst.has_method("setup"):
			inst.call("setup", get_parent())

		if inst.has_method("set_level"):
			inst.call("set_level", level)
		if inst.has_method("set_transcended"):
			inst.call("set_transcended", turned)
		if inst.has_method("set_facet"):
			inst.call("set_facet", facet)

		# OPTIONAL: auto-map keys/actions if you add these InputMap actions
		var action := "augment_active_%d" % (slot_idx + 1)
		if InputMap.has_action(action) and inst.get("active_action") != null:
			inst.set("active_action", StringName(action))
			if inst.get("hud_key_text") != null:
				inst.set("hud_key_text", str(slot_idx + 1))

		_active[k3] = inst

## Runtime multipliers the augment effects expose (Litany of Wounds' Haste),
## aggregated the way SetRunner and ItemEffectRunner aggregate theirs.
func get_haste_multiplier() -> float:
	var mul := 1.0
	for n in get_children():
		if is_instance_valid(n) and n.has_method("get_haste_multiplier"):
			mul *= float(n.call("get_haste_multiplier"))
	return mul


func get_power_multiplier() -> float:
	var mul := 1.0
	for n in get_children():
		if is_instance_valid(n) and n.has_method("get_power_multiplier"):
			mul *= float(n.call("get_power_multiplier"))
	return mul


func get_children_effects() -> Array:
	return get_children()


## The live effect node of an equipped augment, or null: Duos reach their
## partner through this (Phantom Step's blink asks the Spirit Slash to cut).
func effect_for(aug_id: StringName) -> Node:
	for n in get_children():
		if is_instance_valid(n) and StringName(str(n.get_meta("augment_id", ""))) == aug_id:
			return n
	return null


# ---------------------------------------------------------------- Mass Conversion

## Mass Conversion (Apotheosis Doctrine): an elite the player kills pays
## Followers and one level to a random equipped augment, at most once per
## MASS_CONVERSION_GAP seconds of play.
const MASS_CONVERSION_FOLLOWERS := 40
const MASS_CONVERSION_GAP := 20.0
var _mass_conversion_cooldown: float = 0.0


func _ready() -> void:
	if RunEvents != null and not RunEvents.enemy_defeated.is_connected(_on_enemy_defeated):
		RunEvents.enemy_defeated.connect(_on_enemy_defeated)


func _exit_tree() -> void:
	if RunEvents != null and RunEvents.enemy_defeated.is_connected(_on_enemy_defeated):
		RunEvents.enemy_defeated.disconnect(_on_enemy_defeated)


func _process(delta: float) -> void:
	if _mass_conversion_cooldown > 0.0:
		_mass_conversion_cooldown = maxf(0.0, _mass_conversion_cooldown - delta)


func _on_enemy_defeated(context: RefCounted) -> void:
	if context == null or not bool(context.get("is_elite")):
		return
	if Global == null or not bool(Global.get_doctrine_rule(&"mass_conversion", false)):
		return
	if context.get("source") != get_parent():
		return
	mass_conversion(context.get("position"))


## Pays the conversion if the gap allows; returns the augment that rose.
func mass_conversion(at: Variant = null) -> StringName:
	if _mass_conversion_cooldown > 0.0:
		return StringName()
	_mass_conversion_cooldown = MASS_CONVERSION_GAP
	Global.transaction_followers(MASS_CONVERSION_FOLLOWERS, &"mass_conversion", {}, true, false)
	var equipped: Array[StringName] = []
	for id in Global.permanent_augment_ids:
		if id != StringName():
			equipped.append(id)
	if equipped.is_empty():
		return StringName()
	var chosen: StringName = equipped[Global._rng.randi_range(0, equipped.size() - 1)]
	Global.set_augment_level(chosen, AugmentScaling.clamp_level(Global.get_augment_level(chosen) + 1))
	Global.permanent_augments_changed.emit(Global.permanent_augment_ids)
	if at is Vector2 and BattleText != null:
		BattleText.popup(at, "CONVERTED  ·  %s +1" % Global.augment_display_name(chosen).to_upper(), Color(0.95, 0.8, 0.4, 1.0), 1.4)
	return chosen


func reset_all_cooldowns() -> void:
	for n in get_children():
		if not is_instance_valid(n):
			continue
		if n.has_method("reset_cooldowns"):
			n.call("reset_cooldowns")
