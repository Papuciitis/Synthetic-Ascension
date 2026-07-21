extends Control

signal pressed
signal delete_requested
signal rename_requested

@export var base_bg := Color(0.18, 0.18, 0.18)
@export var base_border := Color(0.10, 0.10, 0.10)
@export var hover_border := Color(1.0, 0.55, 0.20, 1.0)
@export var selected_border := Color(1.0, 0.55, 0.20, 1.0)

@export var corner_radius := 14
@export var border_width := 2

@export var hover_scale: float = 1.02
@export var press_scale: float = 0.985
@export var tween_time: float = 0.08

var _selected: bool = false
var _has_save: bool = false
var _hover_count: int = 0

var _card_style: StyleBoxFlat
var _bottom_style: StyleBoxFlat

var _base_scale: Vector2 = Vector2.ONE
var _tw_scale: Tween = null
var _tw_actions: Tween = null

@onready var card_panel: Panel = $CardPanel as Panel
@onready var bottom_panel: PanelContainer = $CardPanel/RootVBox/BottomPanel as PanelContainer
@onready var name_label: Label = $CardPanel/RootVBox/BottomPanel/Margin/InfoVBox/Name as Label
@onready var meta_label: Label = $CardPanel/RootVBox/BottomPanel/Margin/InfoVBox/Meta as Label
@onready var stats_label: Label = $CardPanel/RootVBox/BottomPanel/Margin/InfoVBox/Stats as Label
@onready var buttons_box: HBoxContainer = $CardPanel/RootVBox/BottomPanel/Margin/InfoVBox/Buttons as HBoxContainer
@onready var btn_delete: Button = $CardPanel/RootVBox/BottomPanel/Margin/InfoVBox/Buttons/Delete as Button
@onready var btn_rename: Button = $CardPanel/RootVBox/BottomPanel/Margin/InfoVBox/Buttons/Rename as Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_base_scale = scale
	call_deferred("_fix_pivot")

	btn_delete.focus_mode = Control.FOCUS_NONE
	btn_rename.focus_mode = Control.FOCUS_NONE
	btn_delete.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_rename.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	btn_delete.pressed.connect(func() -> void:
		delete_requested.emit()
	)
	btn_rename.pressed.connect(func() -> void:
		rename_requested.emit()
	)

	card_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	bottom_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	card_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_bind_hover(card_panel)
	_bind_hover(bottom_panel)
	_bind_hover(btn_delete)
	_bind_hover(btn_rename)

	card_panel.gui_input.connect(_on_card_gui_input)
	bottom_panel.gui_input.connect(_on_card_gui_input)

	_build_styles()
	_update_visuals(true)


func _fix_pivot() -> void:
	pivot_offset = size * 0.5


func _bind_hover(c: Control) -> void:
	if c == null:
		return
	c.mouse_entered.connect(func() -> void:
		_hover_count += 1
		_update_visuals()
		_tween_scale_to(_base_scale * hover_scale)
	)
	c.mouse_exited.connect(func() -> void:
		_hover_count = max(0, _hover_count - 1)
		_update_visuals()
		if _hover_count > 0:
			_tween_scale_to(_base_scale * hover_scale)
		else:
			_tween_scale_to(_base_scale)
	)


func _on_card_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null:
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return

	if mb.pressed:
		_tween_scale_to(_base_scale * press_scale)
		accept_event()
		return

	pressed.emit()
	if _hover_count > 0:
		_tween_scale_to(_base_scale * hover_scale)
	else:
		_tween_scale_to(_base_scale)
	accept_event()


func _tween_scale_to(s: Vector2) -> void:
	if _tw_scale != null and _tw_scale.is_running():
		_tw_scale.kill()
	_tw_scale = create_tween()
	_tw_scale.set_trans(Tween.TRANS_QUAD)
	_tw_scale.set_ease(Tween.EASE_OUT)
	_tw_scale.tween_property(self, "scale", s, tween_time)


func set_selected(v: bool) -> void:
	_selected = v
	_update_visuals()


func set_slot_data(slot: int, save: SaveData) -> void:
	_has_save = (save != null)

	if not _has_save:
		name_label.text = "Slot %d — EMPTY" % slot
		meta_label.text = "Click to create"
		stats_label.text = ""
		btn_delete.disabled = true
		btn_rename.disabled = true

		buttons_box.visible = false
		buttons_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_update_visuals(true)
		return

	buttons_box.visible = true
	btn_delete.disabled = false
	btn_rename.disabled = false

	name_label.text = "Slot %d — %s" % [slot, save.profile_name]

	var race_name := save.last_race_id
	var style_name := save.last_style_id

	var r: RaceData = Global.race_db.get(save.last_race_id, null) as RaceData
	if r != null and r.display_name != "":
		race_name = r.display_name

	var st: StyleData = Global.style_db.get(save.last_style_id, null) as StyleData
	if st != null and st.display_name != "":
		style_name = st.display_name

	meta_label.text = "%s • %s" % [race_name, style_name]
	stats_label.text = "Runs: %d • Best: %d" % [save.total_runs, save.best_followers]

	_update_visuals(true)


func _build_styles() -> void:
	_card_style = StyleBoxFlat.new()
	_card_style.corner_radius_top_left = corner_radius
	_card_style.corner_radius_top_right = corner_radius
	_card_style.corner_radius_bottom_left = corner_radius
	_card_style.corner_radius_bottom_right = corner_radius
	_card_style.set_border_width_all(border_width)
	_card_style.border_color = base_border
	_card_style.bg_color = base_bg
	_card_style.shadow_size = 12
	_card_style.shadow_offset = Vector2(0, 8)
	_card_style.shadow_color = Color(0, 0, 0, 0.34)
	card_panel.add_theme_stylebox_override("panel", _card_style)

	_bottom_style = StyleBoxFlat.new()
	_bottom_style.bg_color = Color(0, 0, 0, 0.60)
	_bottom_style.set_border_width_all(2)
	_bottom_style.border_color = Color(0.12, 0.12, 0.12, 1)
	_bottom_style.corner_radius_top_left = corner_radius
	_bottom_style.corner_radius_top_right = corner_radius
	_bottom_style.corner_radius_bottom_left = corner_radius
	_bottom_style.corner_radius_bottom_right = corner_radius
	bottom_panel.add_theme_stylebox_override("panel", _bottom_style)


func _update_visuals(force: bool = false) -> void:
	if _card_style == null:
		return

	var hovered := (_hover_count > 0)

	var border: Color = base_border
	var warm_tint := Color(0.22, 0.13, 0.05, 1.0)

	if _selected and hovered:
		border = selected_border.lerp(hover_border, 0.65)
	elif _selected:
		border = selected_border
	elif hovered:
		border = hover_border

	_card_style.border_color = border

	var bg: Color = base_bg
	if _selected and hovered:
		bg = base_bg.lerp(warm_tint, 0.28).lightened(0.04)
	elif _selected:
		bg = base_bg.lerp(warm_tint, 0.18).lightened(0.02)
	elif hovered:
		bg = base_bg.lerp(warm_tint, 0.10).lightened(0.02)

	_card_style.bg_color = bg

	_set_actions_visible((_selected or hovered) and _has_save, force)


func _set_actions_visible(v: bool, force: bool = false) -> void:
	if not _has_save or not buttons_box.visible:
		return

	var target_a: float = 1.0 if v else 0.0
	buttons_box.mouse_filter = Control.MOUSE_FILTER_STOP if v else Control.MOUSE_FILTER_IGNORE

	if force:
		var m := buttons_box.modulate
		m.a = target_a
		buttons_box.modulate = m
		return

	if _tw_actions != null and _tw_actions.is_running():
		_tw_actions.kill()

	_tw_actions = create_tween()
	_tw_actions.set_trans(Tween.TRANS_QUAD)
	_tw_actions.set_ease(Tween.EASE_OUT)

	var from := buttons_box.modulate
	var to := from
	to.a = target_a
	_tw_actions.tween_property(buttons_box, "modulate", to, 0.10)
