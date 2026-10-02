extends Control
## One chronicle in the Archives: a tall card whose upper part is a pointed-arch
## window onto the world with the save's character standing in it, and whose
## lower part is the nameplate (name, race and style, where the attempt stands,
## followers, gear and pack) with Rename and Erase.
##
## The character is the race portrait at PORTRAIT_DIR/<race_id>.png
## (tools/bake_save_portraits.gd bakes them from the in-game sheets; dedicated
## art can overwrite them) unless set_portrait() hands a texture in.
##
## Selection belongs to SaveSelect; the card reports focus (`focused`) and asks
## to open (`pressed`). A click on an unselected card only selects it - the
## click that brings focus never opens - so opening takes a second click, Enter,
## or the controller's accept. R / controller Y renames and Delete / controller
## X erases while focused.

signal pressed
signal focused
signal delete_requested
signal rename_requested

const PORTRAIT_DIR := "res://assets/textures/characters/portraits"
const FLARE := preload("res://assets/ui/menu/flare_star.png")
const ArcaneParticles := preload("res://ui/widgets/ArcaneParticles.gd")
const ArcaneMotion := preload("res://ui/widgets/ArcaneMotion.gd")
const ROMAN: Array[String] = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

## Plate-UV slices of the Archives painting each slot's window looks onto.
const VISTAS: Array[Vector4] = [
	Vector4(1480.0 / 2048.0, 0.0, 568.0 / 2048.0, 640.0 / 1152.0),
	Vector4(760.0 / 2048.0, 120.0 / 1152.0, 560.0 / 2048.0, 640.0 / 1152.0),
	Vector4(1240.0 / 2048.0, 420.0 / 1152.0, 560.0 / 2048.0, 640.0 / 1152.0),
]

const GOLD := Color(0.86, 0.64, 0.36)
const GOLD_DIM := Color(0.6, 0.46, 0.29)
const EMBER := Color(1.0, 0.62, 0.3)
const ARCANE := Color(0.5, 0.68, 1.0)
const BLOOD := Color(0.86, 0.32, 0.24)

@export var hover_scale: float = 1.02
@export var press_scale: float = 0.985

var _slot := 0
var _selected: bool = false
var _has_save: bool = false
var _unreadable: bool = false
var _custom_portrait: Texture2D = null
var _hover := 0.0
var _lit := 0.0
var _t := 0.0
var _seed := 0.0
var _focus_frame := -1
var _open_on_release := false
var _embers: CPUParticles2D
var _crown_flare: TextureRect
var _vista_mat: ShaderMaterial
## What _apply_state last pushed, so a settled card does no per-frame work.
var _applied_warmth := -1.0
var _applied_actions := false
var _applied_selected := false
var _applied_still := false

@onready var card_panel: Panel = $CardPanel as Panel
@onready var window: Control = $Window
@onready var vista: TextureRect = $Window/Vista
@onready var glow: TextureRect = $Window/Glow
@onready var shadow: TextureRect = $Window/Shadow
@onready var figure: TextureRect = $Window/Figure
@onready var sigil: Control = $Window/Sigil
@onready var window_frame: Control = $Window/WindowFrame
@onready var frame: Control = $Frame
@onready var slot_label: Label = $Info/Slot
@onready var name_label: Label = $Info/Name as Label
@onready var meta_label: Label = $Info/Meta as Label
@onready var details_label: Label = $Info/Details as Label
@onready var stats_label: Label = $Info/Stats as Label
@onready var buttons_box: HBoxContainer = $Info/Buttons as HBoxContainer
@onready var btn_delete: Button = $Info/Buttons/Delete as Button
@onready var btn_rename: Button = $Info/Buttons/Rename as Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	pivot_offset = custom_minimum_size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	_vista_mat = vista.material as ShaderMaterial
	if _vista_mat != null and window.size.y > 0.0:
		# The window's arch, as the shader's fraction of the window height.
		_vista_mat.set_shader_parameter("arch", float(window_frame.get("arch_height")) / window.size.y)
	btn_delete.pressed.connect(func() -> void: delete_requested.emit())
	btn_rename.pressed.connect(func() -> void: rename_requested.emit())
	sigil.draw.connect(_draw_sigil)
	focus_entered.connect(_on_focus_entered)

	_embers = ArcaneParticles.embers(10, 0.8)
	_embers.position = Vector2(window.size.x * 0.5, window.size.y - 30.0)
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.emission_rect_extents = Vector2(90, 6)
	_embers.local_coords = true
	_embers.emitting = false
	window.add_child(_embers)
	window.move_child(_embers, window_frame.get_index())

	_crown_flare = TextureRect.new()
	_crown_flare.texture = FLARE
	_crown_flare.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_crown_flare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crown_flare.material = ArcaneParticles.additive()
	_crown_flare.size = Vector2(84, 84)
	_crown_flare.pivot_offset = _crown_flare.size * 0.5
	_crown_flare.modulate = Color(1.0, 0.82, 0.55, 0.0)
	add_child(_crown_flare)
	_place_crown_flare()
	resized.connect(_place_crown_flare)

	buttons_box.modulate.a = 0.0
	_apply_state(true)


func _place_crown_flare() -> void:
	if _crown_flare != null:
		_crown_flare.position = Vector2(size.x * 0.5, 0.5) - _crown_flare.size * 0.5


## A dedicated portrait for this card (overrides the race portrait).
func set_portrait(texture: Texture2D) -> void:
	_custom_portrait = texture
	_apply_state(true)


func set_selected(v: bool) -> void:
	if _selected == v:
		return
	_selected = v
	if v:
		_flare_crown()
	else:
		_tween_scale(hover_scale if _hover > 0.5 else 1.0)
	_apply_state(false)


func set_slot_data(slot: int, save: SaveData, unreadable: bool = false) -> void:
	_slot = slot
	_has_save = save != null
	_unreadable = save == null and unreadable
	_seed = float(slot) * 1.37
	var vista_index := (slot - 1) % VISTAS.size() if slot > 0 else 0
	if _vista_mat != null:
		_vista_mat.set_shader_parameter("region", VISTAS[vista_index])
		_vista_mat.set_shader_parameter("pan_seed", _seed)
		_vista_mat.set_shader_parameter("tint", Color(1.0, 0.86, 0.84) if (save == null and unreadable) else Color.WHITE)
	slot_label.text = "CHRONICLE %s" % (ROMAN[slot - 1] if slot >= 1 and slot <= ROMAN.size() else str(slot))

	if _unreadable:
		# The files exist but SaveManager could not parse them. Presenting this
		# as an empty slot invited a click that overwrote the last good backup.
		name_label.text = "UNREADABLE SAVE"
		meta_label.text = "Delete to reuse this slot"
		details_label.text = "The save files exist but could not be opened."
		stats_label.text = ""
		btn_delete.disabled = false
		btn_rename.disabled = true
		buttons_box.visible = true
		figure.texture = null
		_apply_state(true)
		return

	if not _has_save:
		name_label.text = "EMPTY SLOT"
		meta_label.text = "Begin a new chronicle"
		details_label.text = "A new Pattern can begin here."
		stats_label.text = ""
		btn_delete.disabled = true
		btn_rename.disabled = true
		buttons_box.visible = false
		figure.texture = null
		_apply_state(true)
		return

	buttons_box.visible = true
	btn_delete.disabled = false
	btn_rename.disabled = false

	var character_name: String = save.mortal_name.strip_edges()
	if character_name == "":
		character_name = save.profile_name.strip_edges()
	if character_name == "":
		character_name = "The Arcanist"

	var race_name := save.last_race_id
	var style_name := save.last_style_id
	var r: RaceData = Global.race_db.get(save.last_race_id, null) as RaceData
	if r != null and r.display_name != "":
		race_name = r.display_name
	var st: StyleData = Global.style_db.get(save.last_style_id, null) as StyleData
	if st != null and st.display_name != "":
		style_name = st.display_name

	var segment: int = maxi(1, save.attempt_segment)
	var route: String = "Area 1 · Segment %d — %s" % [segment, _save_status(save)] if save.attempt_active else _save_status(save)
	var gear_count: int = _equipped_count(save.attempt_inventory)
	var bag_count: int = _bag_count(save.attempt_bag)
	var bag_capacity: int = _bag_capacity(save.attempt_bag)

	name_label.text = character_name
	meta_label.text = "%s · %s" % [race_name, style_name] if style_name != "" else race_name
	details_label.text = "%s\n%s Followers · Gear %d/%d · Pack %d/%d" % [
		route,
		_grouped(maxi(0, save.attempt_followers)),
		gear_count,
		Inventory.SLOT_COUNT,
		bag_count,
		bag_capacity,
	]
	stats_label.text = "RUNS %d   ·   BEST %s" % [maxi(0, save.total_runs), _grouped(maxi(0, save.best_followers))]
	figure.texture = _custom_portrait if _custom_portrait != null else _race_portrait(String(save.last_race_id))
	_apply_state(true)


func _race_portrait(race_id: String) -> Texture2D:
	for id in [race_id, "human"]:
		var path := "%s/%s.png" % [PORTRAIT_DIR, id]
		if id != "" and ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


func _save_status(save: SaveData) -> String:
	if not save.attempt_active:
		return "Between attempts"
	var resume_path: String = save.attempt_resume_scene.to_lower()
	if resume_path.contains("hubshop") or resume_path.contains("hubworld"):
		return "Respite"
	if resume_path.contains("game"):
		return "In segment"
	return "Attempt active"


static func _grouped(value: int) -> String:
	var digits := str(value)
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return digits + out


func _equipped_count(inv: Inventory) -> int:
	if inv == null:
		return 0
	var count: int = 0
	for inst: ItemInstance in inv.items:
		if inst != null:
			count += 1
	return count


func _bag_count(bag: BagInventory) -> int:
	if bag == null:
		return 0
	var count: int = 0
	for inst: ItemInstance in bag.slots:
		if inst != null:
			count += 1
	return count


func _bag_capacity(bag: BagInventory) -> int:
	if bag == null:
		return BagInventory.SLOT_COUNT
	return bag.get_slot_count()


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _on_focus_entered() -> void:
	_focus_frame = Engine.get_process_frames()
	focused.emit()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			# Focus is granted before gui_input sees the press, so a press in the
			# frame focus arrived is the selecting click, not an opening one.
			_open_on_release = _selected and _focus_frame != Engine.get_process_frames()
			_tween_scale(press_scale)
		else:
			_tween_scale(hover_scale if _hover > 0.5 else 1.0)
			if _open_on_release and get_global_rect().has_point(mb.global_position):
				pressed.emit()
			_open_on_release = false
		accept_event()
		return
	if event.is_action_pressed(&"ui_accept"):
		pressed.emit()
		accept_event()
	elif event is InputEventJoypadButton and event.pressed:
		var pad := (event as InputEventJoypadButton).button_index
		if pad == JOY_BUTTON_Y and _has_save:
			rename_requested.emit()
			accept_event()
		elif pad == JOY_BUTTON_X and (_has_save or _unreadable):
			delete_requested.emit()
			accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_R and _has_save:
			rename_requested.emit()
			accept_event()
		elif (key == KEY_DELETE or key == KEY_BACKSPACE) and (_has_save or _unreadable):
			delete_requested.emit()
			accept_event()


func _tween_scale(target: float) -> void:
	if ArcaneMotion.reduced():
		scale = Vector2.ONE
		return
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * target, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------------------
# Presentation
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	var inside := is_visible_in_tree() and get_global_rect().has_point(get_global_mouse_position())
	var hover_target := 1.0 if inside else 0.0
	var before := _hover
	_hover = move_toward(_hover, hover_target, delta * 6.0)
	if (before < 0.5) != (_hover < 0.5) and not _selected:
		_tween_scale(hover_scale if _hover >= 0.5 else 1.0)
	_lit = move_toward(_lit, 1.0 if _selected else 0.0, delta * 4.0)
	_apply_state(false)
	var still := ArcaneMotion.reduced()
	if _vista_mat != null and still != _applied_still:
		_applied_still = still
		_vista_mat.set_shader_parameter("drift_amount", 0.0 if still else 1.0)
	# The figure breathes from the feet.
	if figure.texture != null:
		figure.pivot_offset = Vector2(figure.size.x * 0.5, figure.size.y)
		figure.scale = Vector2.ONE if still else Vector2(1.0, 1.0 + 0.007 * sin(_t * 2.1 + _seed))
	glow.modulate.a = (0.55 + 0.45 * maxf(_lit, _hover * 0.6)) * (0.9 + 0.1 * sin(_t * 1.7 + _seed))
	if not _has_save and not still:
		sigil.queue_redraw()


func _apply_state(force: bool) -> void:
	if name_label == null:
		return
	var warmth := maxf(_lit, _hover * 0.55)
	var show_actions := (_has_save or _unreadable) and (_selected or _hover > 0.5)
	var target_alpha := 1.0 if show_actions else 0.0
	if not force and is_equal_approx(warmth, _applied_warmth) and show_actions == _applied_actions \
			and _selected == _applied_selected and is_equal_approx(buttons_box.modulate.a, target_alpha):
		return
	_applied_warmth = warmth
	_applied_actions = show_actions
	_applied_selected = _selected
	if sigil != null:
		sigil.queue_redraw()
	frame.set("glow", warmth)
	window_frame.set("glow", warmth)
	if _vista_mat != null:
		_vista_mat.set_shader_parameter("lit", warmth)
	var show_figure := figure.texture != null
	figure.visible = show_figure
	shadow.visible = show_figure
	sigil.visible = not show_figure
	figure.modulate = Color(0.68, 0.66, 0.64).lerp(Color(1.06, 1.0, 0.94), warmth)
	var glow_colour := EMBER if _has_save else (BLOOD if _unreadable else ARCANE)
	glow.self_modulate = Color(glow_colour, 1.0)
	_embers.emitting = _selected and _has_save
	var name_colour := Color(0.95, 0.83, 0.62).lerp(Color(1.0, 0.9, 0.72), warmth)
	if _unreadable:
		name_colour = Color(0.95, 0.55, 0.45)
	elif not _has_save:
		name_colour = Color(0.8, 0.74, 0.64).lerp(Color(0.95, 0.86, 0.7), warmth)
	name_label.add_theme_color_override("font_color", name_colour)
	buttons_box.mouse_filter = Control.MOUSE_FILTER_PASS if show_actions else Control.MOUSE_FILTER_IGNORE
	for button in [btn_rename, btn_delete]:
		(button as Button).mouse_filter = Control.MOUSE_FILTER_STOP if show_actions else Control.MOUSE_FILTER_IGNORE
	if force:
		buttons_box.modulate.a = target_alpha
	else:
		buttons_box.modulate.a = move_toward(buttons_box.modulate.a, target_alpha, 0.12)


func _flare_crown() -> void:
	if _crown_flare == null:
		return
	if ArcaneMotion.reduced():
		_crown_flare.scale = Vector2.ONE * 0.8
		_crown_flare.rotation = 0.0
		_crown_flare.modulate.a = 0.8
		create_tween().tween_property(_crown_flare, "modulate:a", 0.0, 0.6)
		return
	_crown_flare.scale = Vector2.ONE * 0.2
	_crown_flare.rotation = -PI * 0.25
	_crown_flare.modulate.a = 1.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_crown_flare, "scale", Vector2.ONE * 1.4, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_crown_flare, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(_crown_flare, "modulate:a", 0.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_crown_flare, "scale", Vector2.ONE * 0.6, 0.7)


## The banner's emblem for a slot with nobody in it: rings, a cross, a turning
## crown of ticks. Gold waiting to be claimed; red when the slot is damaged.
func _draw_sigil() -> void:
	var c := Vector2(sigil.size.x * 0.5, sigil.size.y * 0.56)
	var warmth := maxf(_lit, _hover * 0.6)
	var base := BLOOD if _unreadable else GOLD_DIM
	var col := Color(base.lerp(GOLD if not _unreadable else Color(1.0, 0.45, 0.35), warmth), 0.55 + 0.4 * warmth)
	var still := ArcaneMotion.reduced()
	var breathe := 1.0 if still else 1.0 + 0.02 * sin(_t * 1.4 + _seed)
	var r := 66.0 * breathe
	sigil.draw_arc(c, r, 0.0, TAU, 72, col, 1.4, true)
	sigil.draw_arc(c, r * 0.62, 0.0, TAU, 56, Color(col, col.a * 0.8), 1.2, true)
	var spin := _seed if still else _t * 0.12 + _seed
	for i in range(12):
		var a := spin + TAU * float(i) / 12.0
		var inner := r + 5.0
		var outer := r + (12.0 if i % 3 == 0 else 8.0)
		sigil.draw_line(c + Vector2.from_angle(a) * inner, c + Vector2.from_angle(a) * outer, Color(col, col.a * 0.7), 1.2, true)
	# The banner's seal, not a scope: a blade below the rings and a short
	# point above them; nothing crosses the centre but the diamond.
	sigil.draw_line(c + Vector2(0, r + 14.0), c + Vector2(0, r * 1.85), col, 1.4, true)
	sigil.draw_line(c + Vector2(-7, r * 1.55), c + Vector2(7, r * 1.55), col, 1.2, true)
	sigil.draw_line(c + Vector2(0, -r - 14.0), c + Vector2(0, -r * 1.3), Color(col, col.a * 0.8), 1.2, true)
	var inner_r := r * 0.62
	for i in range(4):
		var a := TAU * float(i) / 4.0 + PI * 0.25
		sigil.draw_line(c + Vector2.from_angle(a) * (inner_r - 6.0), c + Vector2.from_angle(a) * (inner_r + 6.0), Color(col, col.a * 0.7), 1.2, true)
	var d := 9.0
	var diamond := PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0), c + Vector2(0, -d)])
	sigil.draw_polyline(diamond, col, 1.6, true)
	sigil.draw_circle(c, 2.6, col)
	if _unreadable:
		var s := r * 0.5
		sigil.draw_line(c + Vector2(-s, -s), c + Vector2(s, s), Color(BLOOD, 0.8), 2.0, true)
		sigil.draw_line(c + Vector2(s, -s), c + Vector2(-s, s), Color(BLOOD, 0.8), 2.0, true)
