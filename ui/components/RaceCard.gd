extends Button

var race: RaceData = null

# Cached UI
var _name_label: Label = null
var _hp: Label = null
var _ar: Label = null
var _sp: Label = null
var _pw: Label = null
var _hs: Label = null
var _lk: Label = null

func _ready() -> void:
	# These names must match nodes inside RaceCard.tscn (we’ll set them next)
	_name_label = find_child("NameLabel", true, false) as Label
	_hp = find_child("HPValue", true, false) as Label
	_ar = find_child("ARValue", true, false) as Label
	_sp = find_child("SPValue", true, false) as Label
	_pw = find_child("PWValue", true, false) as Label
	_hs = find_child("HSValue", true, false) as Label
	_lk = find_child("LKValue", true, false) as Label

	# Put the race identity and its stat panel at the top of the image card.
	var vbox := get_node_or_null("VBox") as VBoxContainer
	var text_panel := get_node_or_null("VBox/TextPanel") as PanelContainer
	if vbox != null and text_panel != null:
		vbox.move_child(text_panel, 0)


func set_data(display_name: String, res: Resource) -> void:
	race = res as RaceData
	set_meta("data", res)

	if _name_label != null:
		_name_label.text = display_name
	else:
		text = display_name

	if race == null:
		_set_num(_hp, 0.0)
		_set_num(_ar, 0.0)
		_set_num(_sp, 0.0)
		_set_pct(_pw, 0.0)
		_set_pct(_hs, 0.0)
		_set_pct(_lk, 0.0)
		return

	# These three are confirmed from your debug prints:
	_set_num(_hp, float(race.hp_add))
	_set_num(_ar, float(race.armor_add))
	_set_num(_sp, float(race.speed_add))

	# Optional stats (only if RaceData has them; else show 0)
	_set_pct(_pw, _get_optional_float(race, &"power_add"))
	_set_pct(_hs, _get_optional_float(race, &"haste_add"))
	_set_pct(_lk, _get_optional_float(race, &"luck_add"))


func _set_num(label: Label, v: float) -> void:
	if label == null:
		return
	label.text = "%+d" % int(round(v))


func _set_pct(label: Label, v: float) -> void:
	if label == null:
		return
	# If your data is stored as 0.08 = 8%, this converts it nicely.
	label.text = "%+d%%" % int(round(v * 100.0))


func _get_optional_float(obj: Object, prop: StringName) -> float:
	# If the property exists and is numeric, return it; otherwise 0.
	for p in obj.get_property_list():
		if p.name == prop:
			var val = obj.get(prop)
			if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
				return float(val)
			return 0.0
	return 0.0
