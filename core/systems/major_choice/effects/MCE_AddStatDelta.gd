extends MajorChoiceEffect
class_name MCE_AddStatDelta

@export var delta: StatDelta = null

func can_apply(g: Node) -> bool:
	return g != null and delta != null

func apply(g: Node) -> void:
	if delta == null:
		return
	if g.get("attempt_stat_delta") == null:
		g.set("attempt_stat_delta", StatDelta.new())
	var cur: StatDelta = g.get("attempt_stat_delta") as StatDelta
	cur.max_hp += delta.max_hp
	cur.armor += delta.armor
	cur.move_speed += delta.move_speed
	cur.power += delta.power
	cur.haste += delta.haste
	cur.luck += delta.luck

func get_preview_lines(_g: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if delta == null:
		return out

	if absf(delta.max_hp) > 0.0001:
		out.append("• Max HP %s" % _fmt_num(delta.max_hp))
	if absf(delta.armor) > 0.0001:
		out.append("• Armor %s" % _fmt_num(delta.armor))
	if absf(delta.move_speed) > 0.0001:
		out.append("• Move Speed %s" % _fmt_num(delta.move_speed))

	if absf(delta.power) > 0.0001:
		out.append("• Power %s" % _fmt_pct(delta.power))
	if absf(delta.haste) > 0.0001:
		out.append("• Haste %s" % _fmt_pct(delta.haste))
	if absf(delta.luck) > 0.0001:
		out.append("• Luck %s" % _fmt_pct(delta.luck))

	return out

func _fmt_num(v: float) -> String:
	var prefix := ("+" if v > 0.0 else "")
	if is_equal_approx(v, float(int(v))):
		return "%s%d" % [prefix, int(v)]
	return "%s%.1f" % [prefix, v]

func _fmt_pct(v: float) -> String:
	var p := v * 100.0
	var prefix := ("+" if p > 0.0 else "")
	if is_equal_approx(p, float(int(p))):
		return "%s%.0f%%" % [prefix, p]
	return "%s%.1f%%" % [prefix, p]
