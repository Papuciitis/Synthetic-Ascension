extends Button

# Used by RaceCard.tscn and PlaystyleCard.tscn
# Expects nodes named:
#   NameLabel
#   %HPValue %ARMValue %SPDValue %POWValue %HSTValue %LCKValue  (unique_name_in_owner=true on each)
# Your .tscn already has these.

@export var hover_scale: float = 1.02
@export var press_scale: float = 0.985
@export var selected_scale: float = 1.03
@export var tween_time: float = 0.08

var data: Resource = null

var _name_label: Label = null
var _hp: Label = null
var _arm: Label = null
var _spd: Label = null
var _pow: Label = null
var _hst: Label = null
var _lck: Label = null

var _base_scale: Vector2 = Vector2.ONE
var _tw: Tween = null


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_base_scale = scale

	_name_label = find_child("NameLabel", true, false) as Label

	# These exist as "unique_name_in_owner" in your tscn, so % lookup is perfect.
	_hp = get_node_or_null("%HPValue") as Label
	_arm = get_node_or_null("%ARMValue") as Label
	_spd = get_node_or_null("%SPDValue") as Label
	_pow = get_node_or_null("%POWValue") as Label
	_hst = get_node_or_null("%HSTValue") as Label
	_lck = get_node_or_null("%LCKValue") as Label

	# Make scaling feel good (scale around center)
	call_deferred("_fix_pivot")

	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_unhover)
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	toggled.connect(_on_toggled)


func _fix_pivot() -> void:
	pivot_offset = size * 0.5


func set_data(display_name: String, res: Resource) -> void:
	data = res
	set_meta("data", res)

	# Name: Race cards pass a display name; style cards pass "" on purpose.
	if display_name != "":
		if _name_label != null:
			_name_label.text = display_name
		else:
			text = display_name

	_apply_stats_from_resource(res)


func _apply_stats_from_resource(res: Resource) -> void:
	if res == null:
		_set_int(_hp, 0.0)
		_set_int(_arm, 0.0)
		_set_int(_spd, 0.0)
		_set_pct(_pow, 0.0)
		_set_pct(_hst, 0.0)
		_set_pct(_lck, 0.0)
		return

	var hp: float = _get_num(res, [&"hp_add", &"hp_bonus", &"hp"])
	var arm: float = _get_num(res, [&"armor_add", &"arm_add", &"armor", &"arm"])
	var spd: float = _get_num(res, [&"speed_add", &"move_speed", &"spd_add", &"speed"])

	var powv: float = _get_num(res, [&"power_add", &"pow_add", &"power", &"pow"])
	var hstv: float = _get_num(res, [&"haste_add", &"hst_add", &"haste", &"hst"])
	var lckv: float = _get_num(res, [&"luck_add", &"lck_add", &"luck", &"lck"])

	_set_int(_hp, hp)
	_set_int(_arm, arm)
	_set_int(_spd, spd)
	_set_pct(_pow, powv)
	_set_pct(_hst, hstv)
	_set_pct(_lck, lckv)


func _get_num(res: Resource, names: Array[StringName]) -> float:
	for n in names:
		# property check
		var has_it := false
		for p in res.get_property_list():
			if p.name == n:
				has_it = true
				break
		if not has_it:
			continue

		var v = res.get(n)
		if typeof(v) == TYPE_INT:
			return float(v)
		if typeof(v) == TYPE_FLOAT:
			return float(v)
	return 0.0


func _set_int(label: Label, v: float) -> void:
	if label == null:
		return
	label.text = "%+d" % int(round(v))


func _set_pct(label: Label, v: float) -> void:
	if label == null:
		return
	# Accept either 0.13 (13%) or 13 (13%)
	var pct: float = v
	if absf(pct) <= 1.0:
		pct *= 100.0
	label.text = "%+d%%" % int(round(pct))


# ---- tactile feel ----

func _tween_to(s: Vector2) -> void:
	if _tw != null and _tw.is_running():
		_tw.kill()
	_tw = create_tween()
	_tw.set_trans(Tween.TRANS_QUAD)
	_tw.set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "scale", s, tween_time)


func _on_hover() -> void:
	if button_pressed:
		_tween_to(_base_scale * selected_scale)
	else:
		_tween_to(_base_scale * hover_scale)


func _on_unhover() -> void:
	if button_pressed:
		_tween_to(_base_scale * selected_scale)
	else:
		_tween_to(_base_scale)


func _on_down() -> void:
	_tween_to(_base_scale * press_scale)


func _on_up() -> void:
	_on_hover()


func _on_toggled(on: bool) -> void:
	if on:
		_tween_to(_base_scale * selected_scale)
	else:
		_tween_to(_base_scale)
