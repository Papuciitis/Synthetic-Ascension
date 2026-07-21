extends MajorChoiceEffect
class_name MCE_ModAttemptFloat

@export var property: StringName = &"" # e.g. &"attempt_exit_hold_mul"
@export var multiply: float = 1.0
@export var add: float = 0.0
@export var clamp_min: float = -INF
@export var clamp_max: float = INF

func can_apply(g: Node) -> bool:
	return g != null and property != StringName() and g.has_method("get") and g.has_method("set")

func apply(g: Node) -> void:
	if not can_apply(g):
		return
	var v: float = float(g.get(property))
	v = (v * multiply) + add
	if clamp_min != -INF or clamp_max != INF:
		v = clampf(v, clamp_min, clamp_max)
	g.set(property, v)

func get_preview_lines(_g: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if property == StringName():
		return out

	var prop := String(property)

	if prop == "attempt_exit_hold_mul" and multiply != 1.0 and add == 0.0:
		var pct := (1.0 - multiply) * 100.0
		out.append("• %s Exit Rite hold time" % _fmt_signed_pct(pct))
		return out

	if prop == "attempt_wardstone_radius_mul" and multiply != 1.0 and add == 0.0:
		var pct2 := (multiply - 1.0) * 100.0
		out.append("• %s Wardstone radius" % _fmt_signed_pct(pct2))
		return out

	if prop == "attempt_wardstone_slow_mul" and multiply != 1.0 and add == 0.0:
		# Hard to express as % cleanly (it multiplies a multiplier), so show × value.
		out.append("• Wardstone slow strength ×%.2f" % multiply)
		return out

	# Generic fallback: show the numeric operation compactly.
	var label := prop
	var parts: Array[String] = []
	if multiply != 1.0:
		parts.append("×%.2f" % multiply)
	if add != 0.0:
		parts.append("%+.2f" % add)
	if not parts.is_empty():
		out.append("• %s %s" % [label, " ".join(parts)])
	return out

func _fmt_signed_pct(pct: float) -> String:
	if absf(pct) < 0.01:
		return "+0%"
	# Snap near-integers to avoid ugly decimals.
	if is_equal_approx(pct, float(int(pct))):
		return "%+.0f%%" % pct
	return "%+.1f%%" % pct
