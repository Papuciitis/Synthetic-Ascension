extends Button
class_name MajorChoiceCard
## A thesis plate of the Ascension Doctrine, held like the augment pick's
## cards (ui/augments/AugmentCard.gd): the face (seal, stage, title, gift,
## price, consequence) is laid out flat in its own SubViewport and shown
## through card_tilt.gdshader, so it leans toward the cursor in real
## perspective, catches a glare as it turns, and is glazed by a sweep of
## light when the plates are dealt and when one is chosen or inscribed.
##
## The face viewport renders only when something on it changes. Motion
## integrates real elapsed time and every tween ignores the time scale, so the
## plates behave the same over a paused or slowed world. Under Reduced Motion
## the plates do not lean, rise or stagger; they fade in and glow.
##
## Behaviour is the plate's old contract: a press emits `focused`, focus and
## keyboard navigation are the Button's own, and the copy nodes keep their
## names (GiftText, PriceText, ConsequenceText).

signal focused(card: MajorChoiceCard)

const ChamberKit := preload("res://ui/widgets/chambers/ChamberKit.gd")

@export var base_bg := Color(0.032, 0.028, 0.024, 0.98)
@export var base_border := Color(0.32, 0.27, 0.16, 1.0)
@export var hover_border := Color(0.76, 0.50, 0.18, 1.0)
@export var focused_border := Color(0.94, 0.68, 0.28, 1.0)
## Square, institutional geometry: the plate's face has no rounded corners.
@export var corner_radius := 0
@export var border_width := 1

## Degrees the plate leans at the edge of the cursor's reach: less than an
## augment card, since a plate is read while it is held.
const MAX_YAW := 11.0
const MAX_PITCH := 8.0
const STIFFNESS := 150.0
const DAMPING := 16.0
const DEAL_STAGGER := 0.13
const LIFT_PX := 14.0
const HOVER_SCALE := 1.025

var choice_id: StringName = &""
var def_ref: MajorChoiceDef = null
var _focused_plate := false
var _quieted := false
var _hovered := false

@onready var seal_label: Label = $FaceViewport/Face/Margin/VBox/SealLine/Sigil/Seal
@onready var stage_role_label: Label = $FaceViewport/Face/Margin/VBox/StageRole
@onready var title_label: Label = $FaceViewport/Face/Margin/VBox/Title
@onready var family_label: Label = $FaceViewport/Face/Margin/VBox/Family
@onready var gift_text: Label = $FaceViewport/Face/Margin/VBox/GiftText
@onready var price_text: Label = $FaceViewport/Face/Margin/VBox/PriceText
@onready var consequence_text: Label = $FaceViewport/Face/Margin/VBox/ConsequencePlate/Margin/VBox/ConsequenceText

@onready var _surface: TextureRect = $Surface
@onready var _shadow: TextureRect = $Shadow
@onready var _viewport: SubViewport = $FaceViewport
@onready var _frame: Control = $FaceViewport/Face/Frame
@onready var _sigil: Control = $FaceViewport/Face/Margin/VBox/SealLine/Sigil
@onready var _glow: TextureRect = $FaceViewport/Face/Glow
@onready var _flare: TextureRect = $FaceViewport/Face/Flare

var _mat: ShaderMaterial
var _hover := 0.0
var _focus_amt := 0.0
var _sel := 0.0
var _quiet := 0.0
var _tilt := Vector2.ZERO
var _tilt_vel := Vector2.ZERO
var _lift := 0.0
var _deal := 1.0
var _deal_delay := 0.0
var _dealt := false
var _leave := 0.0
var _leave_drop := 0.0
var _last_ticks := 0
var _dirty_frames := 0
var _drawn_sel := -1.0
var _sweep_tw: Tween = null
var _flare_tw: Tween = null
var _leave_tw: Tween = null
var _press_tw: Tween = null
var _sent_tilt := Vector2(INF, INF)
var _sent_glare := -1.0
var _sent_shade := -1.0
var _sent_frame := -1.0
var _sent_glow := -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	focus_mode = Control.FOCUS_ALL
	clip_contents = false
	_mat = _surface.material as ShaderMaterial
	_viewport.size = Vector2i(custom_minimum_size)
	_surface.texture = _viewport.get_texture()
	_surface.size = custom_minimum_size
	_mat.set_shader_parameter("rect_size", custom_minimum_size)
	pivot_offset = custom_minimum_size * 0.5
	_sigil.draw.connect(_draw_sigil)
	_dress_copy()
	_last_ticks = Time.get_ticks_usec()
	focus_entered.connect(_mark_dirty.bind(2))
	focus_exited.connect(_mark_dirty.bind(2))
	button_down.connect(_press_down)
	button_up.connect(_press_up)
	pressed.connect(func() -> void:
		focused.emit(self)
	)
	_mark_dirty(3)


func _dress_copy() -> void:
	var gift_head := get_node_or_null("FaceViewport/Face/Margin/VBox/GiftHeader") as Label
	var price_head := get_node_or_null("FaceViewport/Face/Margin/VBox/PriceHeader") as Label
	var cons_head := get_node_or_null("FaceViewport/Face/Margin/VBox/ConsequencePlate/Margin/VBox/ConsequenceHeader") as Label
	if gift_head != null:
		gift_head.add_theme_color_override("font_color", ChamberKit.GOLD)
	if price_head != null:
		price_head.add_theme_color_override("font_color", Color(0.86, 0.42, 0.32))
	if cons_head != null:
		cons_head.add_theme_color_override("font_color", ChamberKit.GOLD_DIM)
	title_label.add_theme_color_override("font_color", ChamberKit.PARCHMENT)
	stage_role_label.add_theme_color_override("font_color", ChamberKit.GOLD_DIM)
	family_label.add_theme_color_override("font_color", Color(ChamberKit.MUTED, 0.85))
	gift_text.add_theme_color_override("font_color", Color(0.88, 0.84, 0.75))
	price_text.add_theme_color_override("font_color", Color(0.9, 0.74, 0.66))
	_set_consequence_colour(false)
	seal_label.add_theme_color_override("font_color", ChamberKit.GOLD)


func set_def(definition: MajorChoiceDef, _preview: PackedStringArray, seal_index: int = 1) -> void:
	def_ref = definition
	choice_id = definition.id if definition != null else &""
	if definition == null:
		return
	seal_label.text = ChamberKit.roman(seal_index)
	stage_role_label.text = "%s  ·  %s" % [String(definition.stage).to_upper(), String(definition.offer_role).to_upper()]
	title_label.text = definition.title
	# The family count and what this plate would awaken (Thesis at two,
	# Canon at three: bindings-and-theses §6).
	var held := int(Global.doctrine_family_count(definition.family_id)) if Global != null and Global.has_method("doctrine_family_count") else 0
	family_label.text = DoctrineFamilies.plate_line(definition.family_id, held)
	gift_text.text = definition.gift_text
	price_text.text = definition.price_text
	consequence_text.text = definition.consequence_text
	tooltip_text = get_detail_text()
	_mark_dirty(3)
	if not _dealt:
		_dealt = true
		_start_deal()


func set_plate_focused(value: bool) -> void:
	var was := _focused_plate
	_focused_plate = value
	_set_consequence_colour(value)
	seal_label.add_theme_color_override("font_color", ChamberKit.GOLD_BRIGHT if value else ChamberKit.GOLD)
	if value:
		_quieted = false
	if value and not was:
		_glaze(0.0)
		_ignite()
	elif was and not value:
		_extinguish()
	_mark_dirty(2)


## Another plate holds the seal: this one steps back a little.
func set_quieted(value: bool) -> void:
	_quieted = value and not _focused_plate


func get_detail_text(_max_bullets: int = 999) -> String:
	if def_ref == null:
		return ""
	var detail := "%s\n\nGIFT\n%s\n\nPRICE\n%s\n\nCONSEQUENCE\n%s" % [
		def_ref.title,
		def_ref.gift_text,
		def_ref.price_text,
		def_ref.consequence_text,
	]
	if Global != null and Global.has_method("doctrine_family_count"):
		var awakening := DoctrineFamilies.awakening_line(def_ref.family_id, Global.doctrine_family_count(def_ref.family_id))
		if awakening != "":
			detail += "\n\n" + awakening
	return detail


func _set_consequence_colour(lit: bool) -> void:
	consequence_text.add_theme_color_override("font_color", Color(1.0, 0.9, 0.72) if lit else Color(0.78, 0.73, 0.64))
	_mark_dirty(1)


func _mark_dirty(frames: int = 1) -> void:
	_dirty_frames = maxi(_dirty_frames, frames)


# ---------------------------------------------------------------------------
# The seal
# ---------------------------------------------------------------------------

func _draw_sigil() -> void:
	var c := _sigil.size * 0.5
	var lit := clampf(_sel, 0.0, 1.0)
	var col := ChamberKit.GOLD_DIM.lerp(ChamberKit.GOLD_BRIGHT, lit)
	if lit > 0.01:
		_sigil.draw_circle(c, 20.0, Color(0.3, 0.16, 0.06, 0.55 * lit))
	_sigil.draw_arc(c, 24.0, 0.0, TAU, 56, Color(col, 0.95), 1.3, true)
	_sigil.draw_arc(c, 19.5, 0.0, TAU, 48, Color(col, 0.45), 1.0, true)
	for i in range(4):
		var dir := Vector2.UP.rotated(float(i) * PI * 0.5)
		_sigil.draw_line(c + dir * 25.5, c + dir * 29.5, Color(col, 0.8), 1.2, true)
	for i in range(4):
		var dir2 := Vector2.UP.rotated(PI * 0.25 + float(i) * PI * 0.5)
		var p := c + dir2 * 24.0
		var r := 2.2
		_sigil.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), Color(col, 0.9))


# ---------------------------------------------------------------------------
# Motion (real time; see the class note)
# ---------------------------------------------------------------------------

func _start_deal() -> void:
	_deal = 0.0
	if ChamberKit.reduced():
		_deal_delay = 0.0
		_tilt = Vector2.ZERO
	else:
		# Dealt from below, leaning back, one after another along the row.
		_deal_delay = DEAL_STAGGER * float(get_index())
		_tilt = Vector2(-34.0, 12.0 * (float(get_index()) - 1.0))
	_tilt_vel = Vector2.ZERO
	modulate.a = 0.0


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := clampf(float(now - _last_ticks) / 1000000.0, 0.0, 0.05)
	_last_ticks = now
	var still := ChamberKit.reduced()

	if _deal < 1.0:
		if _deal_delay > 0.0:
			_deal_delay -= dt
		else:
			var was := _deal
			_deal = minf(1.0, _deal + dt / (0.3 if still else 0.6))
			if was < 0.62 and _deal >= 0.62:
				_glaze(0.0)
	var deal_ease := 1.0 - pow(1.0 - _deal, 3.0)
	modulate.a = deal_ease * (1.0 - _leave) * (0.55 if disabled else 1.0)

	var inside := not disabled and _leave <= 0.0 and is_visible_in_tree() and get_global_rect().has_point(get_global_mouse_position())
	_hovered = inside
	_hover = move_toward(_hover, 1.0 if inside else 0.0, dt * 6.0)
	_focus_amt = move_toward(_focus_amt, 1.0 if has_focus() else 0.0, dt * 6.0)
	_sel = move_toward(_sel, 1.0 if _focused_plate else 0.0, dt * 5.0)
	_quiet = move_toward(_quiet, 1.0 if _quieted else 0.0, dt * 4.0)

	var target := Vector2.ZERO
	if inside and not still:
		var rel := (get_local_mouse_position() / size - Vector2(0.5, 0.5)) * 2.0
		rel = rel.clamp(Vector2(-1, -1), Vector2(1, 1))
		# The side under the cursor presses away, as a fingertip on a plate would.
		target = Vector2(-rel.y * MAX_PITCH, rel.x * MAX_YAW)
	if still:
		_tilt = Vector2.ZERO
		_tilt_vel = Vector2.ZERO
	else:
		if _deal < 1.0 and _deal_delay > 0.0:
			target = _tilt
		var accel := (target - _tilt) * STIFFNESS - _tilt_vel * DAMPING
		_tilt_vel += accel * dt
		_tilt += _tilt_vel * dt
		# At rest the plate lies exactly flat, so its text stays crisp.
		if target == Vector2.ZERO and _tilt.length() < 0.02 and _tilt_vel.length() < 0.05:
			_tilt = Vector2.ZERO
			_tilt_vel = Vector2.ZERO

	var lift_target := maxf(_hover, maxf(_sel * 0.85, _focus_amt * 0.5))
	_lift = move_toward(_lift, lift_target, dt * 5.0)
	var rise := 0.0 if still else (1.0 - deal_ease) * 90.0 + _leave_drop
	var lift_px := 0.0 if still else _lift * LIFT_PX
	_surface.position = Vector2(0.0, rise - lift_px)
	scale = Vector2.ONE * (1.0 if still else lerpf(1.0, HOVER_SCALE, _hover))
	_shadow.modulate.a = (0.5 + _lift * 0.35) * deal_ease * (1.0 - _leave)
	_shadow.position = Vector2(-22.0 - _tilt.y * 0.6, 8.0 + lift_px + rise)

	if _tilt.distance_to(_sent_tilt) > 0.004:
		_sent_tilt = _tilt
		_mat.set_shader_parameter("tilt", _tilt)
	var glare := _hover * 0.5 + _sel * 0.08
	if absf(glare - _sent_glare) > 0.004:
		_sent_glare = glare
		_mat.set_shader_parameter("glare", glare)
		_mat.set_shader_parameter("foil", _hover * 0.35)
	var shade := (0.7 if disabled else 1.0) * (1.0 - _quiet * 0.3)
	if absf(shade - _sent_shade) > 0.004:
		_sent_shade = shade
		_mat.set_shader_parameter("shade", shade)

	# The face: frame glow, seal and lamp follow hover, focus and the seal.
	var frame_glow := maxf(_hover * 0.7, maxf(_focus_amt * 0.55, _sel))
	if absf(frame_glow - _sent_frame) > 0.01:
		_sent_frame = frame_glow
		_frame.set("glow", frame_glow)
		_mark_dirty(1)
	var lamp := 0.3 + 0.7 * maxf(_sel, _hover * 0.45)
	if absf(lamp - _sent_glow) > 0.01:
		_sent_glow = lamp
		_glow.modulate.a = lamp
		_mark_dirty(1)
	if absf(_sel - _drawn_sel) > 0.01:
		_drawn_sel = _sel
		_sigil.queue_redraw()
		_mark_dirty(1)
	if _flare_tw != null and _flare_tw.is_running():
		_mark_dirty(1)

	if _dirty_frames > 0:
		_dirty_frames -= 1
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## One sweep of glaze across the face.
func _glaze(delay: float) -> void:
	if _sweep_tw != null and _sweep_tw.is_running():
		_sweep_tw.kill()
	_mat.set_shader_parameter("sweep", -0.4)
	_sweep_tw = ChamberKit.tween(self)
	if delay > 0.0:
		_sweep_tw.tween_interval(delay)
	_sweep_tw.tween_method(func(v: float) -> void: _mat.set_shader_parameter("sweep", v), -0.4, 1.5, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## The seal takes: its star flares and then rests lit.
func _ignite(peak: float = 1.5) -> void:
	if _flare_tw != null and _flare_tw.is_running():
		_flare_tw.kill()
	_flare_tw = ChamberKit.tween(self)
	if ChamberKit.reduced():
		_flare.scale = Vector2.ONE * 0.85
		_flare.rotation = 0.0
		_flare_tw.tween_property(_flare, "modulate:a", 0.5, 0.15)
		return
	_flare.scale = Vector2.ONE * 0.25
	_flare.rotation = -PI * 0.25
	_flare.modulate.a = 1.0
	_flare_tw.set_parallel(true)
	_flare_tw.tween_property(_flare, "scale", Vector2.ONE * peak, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flare_tw.tween_property(_flare, "rotation", 0.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_flare_tw.chain().tween_property(_flare, "scale", Vector2.ONE * 0.85, 0.5).set_trans(Tween.TRANS_SINE)
	_flare_tw.parallel().tween_property(_flare, "modulate:a", 0.5, 0.5)


func _extinguish() -> void:
	if _flare_tw != null and _flare_tw.is_running():
		_flare_tw.kill()
	_flare_tw = ChamberKit.tween(self)
	_flare_tw.tween_property(_flare, "modulate:a", 0.0, 0.2)


## The chosen plate at inscription: glazed, its seal blazing, raised.
func play_inscribe() -> void:
	_focused_plate = true
	_glaze(0.0)
	_ignite(2.1)


## A plate not chosen sinks away from the table.
func play_dismiss() -> void:
	if _leave_tw != null and _leave_tw.is_running():
		_leave_tw.kill()
	_leave_tw = ChamberKit.tween(self).set_parallel(true)
	_leave_tw.tween_method(func(v: float) -> void: _leave = v, _leave, 1.0, 0.18 if ChamberKit.reduced() else 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if not ChamberKit.reduced():
		_leave_tw.tween_method(func(v: float) -> void: _leave_drop = v, 0.0, 46.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _press_down() -> void:
	if ChamberKit.reduced():
		return
	if _press_tw != null and _press_tw.is_running():
		_press_tw.kill()
	_surface.pivot_offset = _surface.size * 0.5
	_press_tw = ChamberKit.tween(self)
	_press_tw.tween_property(_surface, "scale", Vector2.ONE * 0.975, 0.05)


func _press_up() -> void:
	if _press_tw != null and _press_tw.is_running():
		_press_tw.kill()
	_press_tw = ChamberKit.tween(self)
	_press_tw.tween_property(_surface, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
