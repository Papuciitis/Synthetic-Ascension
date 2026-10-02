extends Control
## A New Chronicle: who walks out of the Archive (ancestry), how they fight
## (path) and the mortal's name, before the run begins.
##
## The left column lists the races, the right the playstyles, both as
## ChoiceTiles in a ButtonGroup. The centre is the vessel: the chosen race's
## portrait in an arched window over the path's sigil, the combined stat
## changes, and the name. Back returns to the Archives; Begin starts the run.
## Selection, naming and the start itself work exactly as before.

const ChoiceTileScript := preload("res://ui/components/ChoiceTile.gd")
const ArcaneMotion := preload("res://ui/widgets/ArcaneMotion.gd")
const ArcaneParticles := preload("res://ui/widgets/ArcaneParticles.gd")
const PORTRAIT_DIR := "res://assets/textures/characters/portraits"

const UP := Color(0.93, 0.83, 0.6)
const DOWN := Color(0.86, 0.48, 0.4)
const ZERO := Color(0.55, 0.5, 0.44)
## The six numbers every race and path changes, as [label, property names, percent].
const STATS: Array = [
	["HP", ["hp_add", "hp", "health_add", "health"], false],
	["AR", ["armor_add", "arm_add", "armor", "armour_add"], false],
	["SP", ["speed_add", "move_speed", "spd_add", "speed"], false],
	["PW", ["pow_add", "power_add", "power", "pow"], true],
	["HS", ["haste_add", "haste", "attack_speed", "atk_speed"], true],
	["LK", ["luck_add", "luck", "lck_add", "lck"], true],
]
## How far each stat has to move to count as a race's or path's defining
## trait, and the words for having much or little of it.
const TRAIT_SCALE: Array = [30.0, 8.0, 25.0, 10.0, 10.0, 30.0]
const TRAIT_WORDS: Array = [
	["hard to kill", "frail"],
	["heavily armoured", "lightly armoured"],
	["fleet of foot", "slow"],
	["strikes hard", "strikes soft"],
	["quick-handed", "slow-handed"],
	["favoured by luck", "unlucky"],
]
const STYLE_LINES: Dictionary = {
	"magic": "Fights through sigils and spellwork.",
	"melee": "Fights up close, blade to blade.",
	"ranged": "Fights from afar; nothing should reach you.",
}
const STYLE_MOODS: Dictionary = {"magic": &"arcane", "melee": &"hearth", "ranged": &"still"}

@onready var races_grid: VBoxContainer = find_child("RacesGrid", true, false) as VBoxContainer
@onready var styles_box: VBoxContainer = find_child("StylesGrid", true, false) as VBoxContainer
@onready var back_btn: Button = find_child("BackToSaves", true, false) as Button
@onready var start_btn: Button = find_child("StartRun", true, false) as Button
@onready var mortal_name_edit: LineEdit = find_child("MortalName", true, false) as LineEdit
@onready var replay_opening_toggle: CheckBox = find_child("ReplayOpening", true, false) as CheckBox
@onready var backdrop: Control = $Backdrop
@onready var curtain: ColorRect = $Curtain
@onready var figure: TextureRect = find_child("Figure", true, false) as TextureRect
@onready var sigil: Control = find_child("Sigil", true, false) as Control
@onready var glow: TextureRect = find_child("Glow", true, false) as TextureRect
@onready var vessel_label: Label = find_child("Vessel", true, false) as Label
@onready var summary_label: RichTextLabel = find_child("Summary", true, false) as RichTextLabel
@onready var window: Control = find_child("Window", true, false) as Control

var race_group := ButtonGroup.new()
var style_group := ButtonGroup.new()

var selected_race: RaceData
var selected_style: StyleData

## Empty so the first preview always applies the restored path's mood.
var _sigil_kind := ""
var _figure_rest_y := 0.0
var _sigil_pulse := 0.0
var _t := 0.0
var _figure_tw: Tween = null
var _embers: CPUParticles2D


func _ready() -> void:
	if races_grid == null or styles_box == null:
		push_error("Base: RacesGrid / StylesGrid not found. Check base.tscn node names.")
		return
	race_group.allow_unpress = false
	style_group.allow_unpress = false

	if mortal_name_edit != null:
		mortal_name_edit.text = Global.mortal_name
		mortal_name_edit.text_changed.connect(func(_value: String) -> void: _update_start_state())
	if replay_opening_toggle != null:
		replay_opening_toggle.button_pressed = Global != null and Global.opening_replay_full_next_run
		replay_opening_toggle.visible = Global != null and Global.opening_full_intro_seen
		replay_opening_toggle.toggled.connect(_on_replay_opening_toggled)
	if sigil != null:
		sigil.draw.connect(_draw_sigil)
	if figure != null:
		_figure_rest_y = figure.position.y
	var vista := find_child("Vista", true, false) as CanvasItem
	if vista != null and vista.material is ShaderMaterial:
		(vista.material as ShaderMaterial).set_shader_parameter("drift_amount", 0.0 if ArcaneMotion.reduced() else 1.0)

	_embers = ArcaneParticles.embers(12, 0.8)
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.emission_rect_extents = Vector2(110, 6)
	_embers.local_coords = true
	if window != null:
		window.add_child(_embers)
		window.move_child(_embers, figure.get_index())

	_populate_races()
	_populate_styles()

	if back_btn != null and not back_btn.pressed.is_connected(_on_back_to_saves_pressed):
		back_btn.pressed.connect(_on_back_to_saves_pressed)
	if start_btn != null and not start_btn.pressed.is_connected(_on_start_run_pressed):
		start_btn.pressed.connect(_on_start_run_pressed)

	_update_start_state()
	_update_preview(false)
	_play_intro()


# ============================================================
# Populate
# ============================================================

func _populate_races() -> void:
	_clear_children(races_grid)
	var keys: Array = Global.race_db.keys()
	keys.sort()
	var chosen: Button = null
	for k in keys:
		var id: String = String(k)
		var rd: RaceData = Global.race_db.get(id, null) as RaceData
		if rd == null:
			continue
		var tile := ChoiceTileScript.new() as Button
		tile.name = "Race_%s" % id
		tile.custom_minimum_size = Vector2(0, 142)
		tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tile.button_group = race_group
		races_grid.add_child(tile)
		tile.call("configure", "portrait", _get_display_name(rd, id).to_upper(), _trait_line(rd), _stat_entries(rd), _bust(id))
		var rd_local: RaceData = rd
		tile.pressed.connect(func() -> void:
			tile.button_pressed = true
			selected_race = rd_local
			_commit_selection()
			_update_preview(true)
		)
		if chosen == null or id == String(Global.selected_race_id):
			chosen = tile
	if chosen != null:
		chosen.button_pressed = true
		chosen.emit_signal("pressed")


func _populate_styles() -> void:
	_clear_children(styles_box)
	var keys: Array = Global.style_db.keys()
	keys.sort()
	var chosen: Button = null
	for k in keys:
		var id: String = String(k)
		var sd: StyleData = Global.style_db.get(id, null) as StyleData
		if sd == null:
			continue
		var tile := ChoiceTileScript.new() as Button
		tile.name = "Style_%s" % id
		tile.custom_minimum_size = Vector2(0, 190)
		tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tile.button_group = style_group
		styles_box.add_child(tile)
		var line: String = STYLE_LINES.get(id.to_lower(), "")
		tile.call("configure", id.to_lower(), _get_display_name(sd, id).to_upper(), line, _stat_entries(sd))
		var sd_local: StyleData = sd
		tile.pressed.connect(func() -> void:
			tile.button_pressed = true
			selected_style = sd_local
			_commit_selection()
			_update_preview(true)
		)
		if chosen == null or id == String(Global.selected_style_id):
			chosen = tile
	if chosen != null:
		chosen.button_pressed = true
		chosen.emit_signal("pressed")


## The upper part of the race portrait, for the tile's window.
func _bust(race_id: String) -> Texture2D:
	var full := _portrait(race_id)
	if full == null:
		return null
	var crop := AtlasTexture.new()
	crop.atlas = full
	var full_size := full.get_size()
	crop.region = Rect2(0, 0, full_size.x, full_size.y * 0.62)
	return crop


func _portrait(race_id: String) -> Texture2D:
	var path := "%s/%s.png" % [PORTRAIT_DIR, race_id]
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _stat_values(data: Resource) -> Array[float]:
	var values: Array[float] = []
	var src: Object = data
	if data != null and _has_prop(data, &"mods"):
		var mods_res: Resource = data.get("mods") as Resource
		if mods_res != null:
			src = mods_res
	for entry: Array in STATS:
		var v := _get_first_number(src, PackedStringArray(entry[1]))
		if entry[2] and absf(v) <= 2.0:
			v *= 100.0
		values.append(v)
	return values


func _stat_entries(data: Resource) -> Array:
	var values := _stat_values(data)
	var out: Array = []
	for i in range(STATS.size()):
		out.append([STATS[i][0], values[i], STATS[i][2]])
	return out


## A race's defining traits, read off its numbers: its strongest and weakest.
func _trait_line(data: Resource) -> String:
	var values := _stat_values(data)
	var best := -1
	var worst := -1
	for i in range(values.size()):
		var n: float = values[i] / TRAIT_SCALE[i]
		if n > 0.2 and (best < 0 or n > values[best] / TRAIT_SCALE[best]):
			best = i
		if n < -0.2 and (worst < 0 or n < values[worst] / TRAIT_SCALE[worst]):
			worst = i
	var parts: Array[String] = []
	if best >= 0:
		parts.append(String(TRAIT_WORDS[best][0]))
	if worst >= 0:
		parts.append(String(TRAIT_WORDS[worst][1]))
	if parts.is_empty():
		return "Even in every measure."
	return _sentence(parts)


func _sentence(parts: Array[String]) -> String:
	var text := ", but ".join(parts) if parts.size() == 2 else parts[0]
	return text.substr(0, 1).to_upper() + text.substr(1) + "."


# ============================================================
# The vessel (centre preview)
# ============================================================

func _update_preview(animate: bool) -> void:
	if figure == null:
		return
	var race_id := String(Global.selected_race_id)
	var style_id := String(Global.selected_style_id).to_lower()
	var race_name := _get_display_name(selected_race, race_id) if selected_race != null else race_id
	var style_name := _get_display_name(selected_style, style_id) if selected_style != null else style_id
	vessel_label.text = ("%s  ·  %s" % [race_name, style_name]).to_upper()
	var portrait := _portrait(race_id)
	var still := ArcaneMotion.reduced() or not animate
	if portrait != figure.texture:
		if _figure_tw != null and _figure_tw.is_running():
			_figure_tw.kill()
		figure.texture = portrait
		# Always from the rest pose, so a quick run of switches never sinks it.
		figure.position.y = _figure_rest_y
		figure.modulate.a = 1.0
		if not still:
			figure.modulate.a = 0.0
			figure.position.y = _figure_rest_y + 14.0
			_figure_tw = create_tween().set_parallel(true)
			_figure_tw.tween_property(figure, "modulate:a", 1.0, 0.35)
			_figure_tw.tween_property(figure, "position:y", _figure_rest_y, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if style_id != _sigil_kind:
		_sigil_kind = style_id
		_sigil_pulse = 0.0 if still else 1.0
		if backdrop != null and backdrop.has_method("set_mood"):
			backdrop.call("set_mood", STYLE_MOODS.get(style_id, &"hearth"))
	# The combined changes the run starts with.
	var totals: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for data: Resource in [selected_race, selected_style]:
		if data == null:
			continue
		var values := _stat_values(data)
		for i in range(totals.size()):
			totals[i] += values[i]
	var parts: Array[String] = []
	for i in range(STATS.size()):
		var v: float = totals[i]
		var shown := ("%+d%%" % roundi(v)) if STATS[i][2] else ("%+d" % roundi(v))
		var colour := UP if v > 0.0 else (DOWN if v < 0.0 else ZERO)
		parts.append("[color=#%s]%s[/color] [color=#%s]%s[/color]" % [ZERO.to_html(false), STATS[i][0], colour.to_html(false), shown])
	summary_label.text = "[center]%s[/center]" % "    ".join(parts)
	sigil.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	var still := ArcaneMotion.reduced()
	_sigil_pulse = move_toward(_sigil_pulse, 0.0, delta * 1.6)
	if figure != null and figure.texture != null:
		figure.pivot_offset = Vector2(figure.size.x * 0.5, figure.size.y)
		figure.scale = Vector2.ONE if still else Vector2(1.0, 1.0 + 0.006 * sin(_t * 2.1))
	if glow != null:
		glow.modulate.a = 0.75 + (0.0 if still else 0.15 * sin(_t * 1.5)) + _sigil_pulse * 0.4
	if _embers != null and window != null:
		_embers.position = Vector2(window.size.x * 0.5, window.size.y - 34.0)
		_embers.emitting = not still
	if sigil != null and (not still or _sigil_pulse > 0.0):
		sigil.queue_redraw()


func _draw_sigil() -> void:
	# The path's mark rides above the figure like a halo, clear of the body.
	var c := Vector2(sigil.size.x * 0.5, sigil.size.y * 0.13)
	var grow := 1.0 + _sigil_pulse * 0.12
	var col := Color(0.86, 0.64, 0.36, 0.5 + _sigil_pulse * 0.4)
	var spin := 0.0 if ArcaneMotion.reduced() else _t
	ChoiceTileScript.StyleSigil.draw(sigil, _sigil_kind, c, minf(sigil.size.x, sigil.size.y) * 0.085 * grow, col, spin, 0.4 + _sigil_pulse)
	# A slow ring of degree ticks around the mark.
	var r := minf(sigil.size.x, sigil.size.y) * 0.135
	for i in range(36):
		var a := TAU * float(i) / 36.0 + spin * 0.04
		var inner := r - (7.0 if i % 9 == 0 else 3.0)
		sigil.draw_line(c + Vector2.from_angle(a) * inner, c + Vector2.from_angle(a) * r, Color(col, col.a * 0.6), 1.0, true)


func _play_intro() -> void:
	var still := ArcaneMotion.reduced()
	if curtain != null:
		curtain.visible = true
		curtain.color.a = 1.0
		var fade := create_tween()
		fade.tween_property(curtain, "color:a", 0.0, 0.5 if still else 0.9).set_trans(Tween.TRANS_SINE)
		fade.tween_callback(func() -> void: curtain.visible = false)
	var delay := 0.2
	for column in [races_grid, styles_box]:
		for tile in column.get_children():
			var c := tile as Control
			c.modulate.a = 0.0
			var tw := create_tween()
			tw.tween_interval(delay)
			tw.tween_property(c, "modulate:a", 1.0, 0.4)
			delay += 0.0 if still else 0.06
	var focus := create_tween()
	focus.tween_interval(delay)
	focus.tween_callback(func() -> void:
		if get_viewport().gui_get_focus_owner() == null and start_btn != null and not start_btn.disabled:
			start_btn.call("select_quietly")
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_to_saves_pressed()


# ============================================================
# Selection / Start
# ============================================================

func _commit_selection() -> void:
	if selected_race != null:
		Global.selected_race_id = selected_race.id
	if selected_style != null:
		Global.selected_style_id = selected_style.id
		Global.selected_weapon_id = selected_style.id

	# Optional: store in tree meta so Global.sync_run_selection_from_tree_meta can pull it too
	var tree := get_tree()
	tree.set_meta("run_race_id", Global.selected_race_id)
	tree.set_meta("run_style_id", Global.selected_style_id)

	if OS.is_debug_build():
		print("[Base] commit selection race=%s style=%s weapon=%s" % [
			Global.selected_race_id, Global.selected_style_id, Global.selected_weapon_id
		])
	_update_start_state()


func _update_start_state() -> void:
	if start_btn == null:
		return
	var has_name: bool = mortal_name_edit != null and mortal_name_edit.text.strip_edges() != ""
	var ok: bool = (selected_race != null and selected_style != null and has_name)
	start_btn.disabled = not ok
	start_btn.focus_mode = Control.FOCUS_ALL if ok else Control.FOCUS_NONE
	if start_btn.has_method("_apply_visuals"):
		start_btn.call("_apply_visuals")


# ============================================================
# Data helpers
# ============================================================

func _get_first_number(obj: Object, names: PackedStringArray) -> float:
	if obj == null:
		return 0.0
	for prop_name in names:
		var prop: StringName = StringName(prop_name)
		if _has_prop(obj, prop):
			var v: Variant = obj.get(prop)
			if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
				return float(v)
	return 0.0


func _clear_children(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()


func _get_display_name(res: Resource, fallback: String) -> String:
	if res != null and _has_prop(res, &"display_name"):
		var v: Variant = res.get("display_name")
		if typeof(v) == TYPE_STRING and String(v) != "":
			return String(v)
	return fallback


func _has_prop(obj: Object, prop: StringName) -> bool:
	for p in obj.get_property_list():
		if p.name == prop:
			return true
	return false


# ============================================================
# Buttons
# ============================================================

func _on_back_to_saves_pressed() -> void:
	Global.goto_save_select()


func _on_start_run_pressed() -> void:
	_commit_selection()
	if mortal_name_edit == null or mortal_name_edit.text.strip_edges() == "":
		return
	Global.mortal_name = mortal_name_edit.text.strip_edges()

	# Starting a new campaign attempt. (Die-die is the only thing that resets this.)
	if Global != null:
		Global.start_new_attempt()

	Global.goto_game()


func _on_replay_opening_toggled(enabled: bool) -> void:
	if Global == null:
		return
	Global.opening_replay_full_next_run = enabled
	Global.save_current_profile()
