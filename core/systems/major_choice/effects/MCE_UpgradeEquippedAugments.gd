extends MajorChoiceEffect
class_name MCE_UpgradeEquippedAugments

@export var amount: int = 1
@export var min_level: int = 1
@export var max_level: int = 5

func can_apply(g: Node) -> bool:
	if g == null:
		return false
	var arr: Array = g.get("permanent_augment_ids")
	for a in arr:
		if a != StringName():
			return true
	return false

func apply(g: Node) -> void:
	if g == null:
		return
	var did_change: bool = false
	var arr: Array = g.get("permanent_augment_ids")
	for a in arr:
		var aug_id: StringName = a
		if aug_id == StringName():
			continue
		var lvl: int = int(g.call("get_augment_level", aug_id)) if g.has_method("get_augment_level") else 1
		lvl = clampi(lvl + amount, min_level, max_level)
		if g.has_method("set_augment_level"):
			g.call("set_augment_level", aug_id, lvl)
			did_change = true

	# Force refresh so effects can reconfigure based on level.
	if did_change and g.has_signal("permanent_augments_changed"):
		g.permanent_augments_changed.emit(arr)


func get_preview_lines(g: Node) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if g == null:
		return out

	var arr: Array = g.get("permanent_augment_ids")
	var db: Dictionary = {}
	if g.has_method("get") and g.get("augment_db") != null:
		db = g.get("augment_db")

	for a in arr:
		var aug_id: StringName = a
		if aug_id == StringName():
			continue

		var cur_lvl: int = int(g.call("get_augment_level", aug_id)) if g.has_method("get_augment_level") else 1
		var nxt: int = clampi(cur_lvl + amount, min_level, max_level)

		var nm: String = String(aug_id)
		if db.has(aug_id):
			var ad: Variant = db[aug_id]
			if ad != null and ad is AugmentData:
				nm = (ad as AugmentData).display_name

		out.append("• %s: Lv.%d → Lv.%d" % [nm, cur_lvl, nxt])

	return out
