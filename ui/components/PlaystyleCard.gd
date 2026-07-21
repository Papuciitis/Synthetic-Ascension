extends Button

var style: StyleData = null

var _name_label: Label = null
var _hp: Label = null
var _ar: Label = null
var _sp: Label = null
var _pw: Label = null
var _hs: Label = null
var _lk: Label = null

func _ready() -> void:
	_name_label = find_child("NameLabel", true, false) as Label
	_hp = find_child("HPValue", true, false) as Label
	_ar = find_child("ARValue", true, false) as Label
	_sp = find_child("SPValue", true, false) as Label
	_pw = find_child("PWValue", true, false) as Label
	_hs = find_child("HSValue", true, false) as Label
	_lk = find_child("LKValue", true, false) as Label


func set_data(display_name: String, res: Resource) -> void:
	style = res as StyleData
	set_meta("data", res)

	# Some of your playstyle cards show name below already.
	# But if you want the in-card label too, this handles it.
	if _name_label != null and display_name != "":
		_name_label.text = display_name

	if style == null:
		_set_num(_hp, 0.0)
		_set_num(_ar, 0.0)
		_set_num(_sp, 0.0)
		_set_pct(_pw, 0.0)
		_set_pct(_hs, 0.0)
		_set_pct(_lk, 0.0)
		return

	# We don’t know your StyleData field names.
	# This will work as long as you name them like hp_add/armor_add/speed_add/power_add/haste_add/luck_add.
	_set_num(_hp, _get_optional_float(style, &"hp_add"))
	_set_num(_ar, _get_optional_float(style, &"armor_add"))
	_set_num(_sp, _get_optional_float(style, &"speed_add"))
	_set_pct(_pw, _get_optional_float(style, &"power_add"))
	_set_pct(_hs, _get_optional_float(style, &"haste_add"))
	_set_pct(_lk, _get_optional_float(style, &"luck_add"))


func _set_num(label: Label, v: float) -> void:
	if label == null:
		return
	label.text = "%+d" % int(round(v))

func _set_pct(label: Label, v: float) -> void:
	if label == null:
		return
	label.text = "%+d%%" % int(round(v * 100.0))

func _get_optional_float(obj: Object, prop: StringName) -> float:
	for p in obj.get_property_list():
		if p.name == prop:
			var val = obj.get(prop)
			if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
				return float(val)
			return 0.0
	return 0.0
