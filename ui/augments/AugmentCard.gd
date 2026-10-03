extends Button
## An augment offer as a card you can hold. The face (art in an arched window,
## name, a line of flavour) is laid out flat in its own SubViewport and shown
## through card_tilt.gdshader, so it leans toward the cursor in real
## perspective, catches a glare that slides as it turns, and is glazed by a
## sweep of light when it is dealt and when it is picked.
##
## AugmentSelect shows the offer with Engine.time_scale at 0, so nothing here
## may wait on scaled time: motion integrates real elapsed time and every tween
## ignores the time scale.

signal picked(augment: AugmentData, card_node: Control)
signal hovered(augment: AugmentData, card_node: Control)
signal unhovered(card_node: Control)

const ArcaneMotion := preload("res://ui/widgets/ArcaneMotion.gd")
const OverlayKit := preload("res://ui/widgets/overlays/OverlayKit.gd")

## Degrees the card leans at the very edge of the cursor's reach.
const MAX_YAW := 17.0
const MAX_PITCH := 14.0
## Spring that carries the lean: stiff enough to feel held, damped enough to
## settle with one small overshoot.
const STIFFNESS := 150.0
const DAMPING := 15.0
const HOVER_SCALE := 1.065
const DEAL_STAGGER := 0.12

var data: AugmentData = null
## The Binding card this face shows ({kind, id, grade}); empty for a bare
## augment (the old offer shape, still used by probes).
var card_entry: Dictionary = {}

var icon_rect: TextureRect = null
var name_label: Label = null
var desc_label: Label = null

var _surface: TextureRect
var _shadow: TextureRect
var _viewport: SubViewport
var _badge: Label
var _frame: Control
var _art_frame: Control
var _mat: ShaderMaterial
var _hovered := false
var _hover := 0.0
var _tilt := Vector2.ZERO
var _tilt_vel := Vector2.ZERO
var _lift := 0.0
var _idle_t := 0.0
var _last_ticks := 0
var _dealt := false
var _deal := 1.0
var _deal_delay := 0.0
var _sweep_tw: Tween = null
## Set when this card is the one picked: it stays lit for the flight to the
## slot while the others, locked by AugmentSelect, sink away.
var _picked := false
var _flown := false
var _sink := 0.0
var _press_tw: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	focus_mode = Control.FOCUS_NONE
	clip_contents = false
	_surface = $Surface
	_shadow = $Shadow
	_viewport = $FaceViewport
	_badge = $FaceViewport/Face/Badge
	_frame = $FaceViewport/Face/Frame
	_art_frame = $FaceViewport/Face/ArtWindow/ArtFrame
	icon_rect = $FaceViewport/Face/ArtWindow/Icon
	name_label = $FaceViewport/Face/Name
	desc_label = $FaceViewport/Face/Desc
	desc_label.max_lines_visible = 3
	_mat = _surface.material as ShaderMaterial
	# Lay the face out at its logical size but render it at the screen's real
	# scale (and the hover lift), so its text stays crisp above 1080p.
	var k := maxf(1.0, get_viewport().get_final_transform().get_scale().x) * HOVER_SCALE
	_viewport.size = Vector2i((custom_minimum_size * k).ceil())
	_viewport.size_2d_override = Vector2i(custom_minimum_size)
	_viewport.size_2d_override_stretch = true
	_surface.texture = _viewport.get_texture()
	_surface.size = custom_minimum_size
	_mat.set_shader_parameter("rect_size", custom_minimum_size)
	pivot_offset = custom_minimum_size * 0.5
	_last_ticks = Time.get_ticks_usec()

	_apply_data()

	mouse_entered.connect(func() -> void:
		_hovered = true
		if data != null:
			hovered.emit(data, self)
	)
	mouse_exited.connect(func() -> void:
		_hovered = false
		unhovered.emit(self)
	)
	pressed.connect(func() -> void:
		if data != null:
			_picked = true
			_glaze(0.0)
			picked.emit(data, self)
	)
	button_down.connect(_press_down)
	button_up.connect(_press_up)


func set_data(a: AugmentData) -> void:
	data = a
	# AugmentSelect may call set_data() right after add_child(), before this node is ready.
	if is_node_ready():
		_apply_data()


## A Binding card: the augment and what the card does to it.
func set_offer(a: AugmentData, entry: Dictionary) -> void:
	card_entry = entry.duplicate()
	set_data(a)


func is_transcend_card() -> bool:
	return String(card_entry.get("kind", "")) == AugmentBinding.KIND_TRANSCEND


func _apply_data() -> void:
	if data == null or name_label == null:
		return
	var transcend := is_transcend_card()
	if transcend:
		name_label.text = AugmentScaling.transcended_name(data.id)
	elif Global != null and Global.has_method("augment_display_name"):
		name_label.text = Global.augment_display_name(data.id)
	else:
		name_label.text = data.display_name
	var blurb := String(data.card_blurb).strip_edges()
	if blurb == "":
		blurb = _card_flavor(data.description)
	desc_label.text = _card_flavor(AugmentScaling.transcend_rule(data.id), 120) if transcend else blurb
	desc_label.visible = true
	icon_rect.texture = data.icon
	_badge.text = badge_text()
	var tint := grade_colour()
	_badge.add_theme_color_override("font_color", tint)
	_frame.set("colour", Color(tint, 0.85))
	_frame.set("glow_colour", tint.lightened(0.35))
	_art_frame.set("colour", Color(tint, 0.7))
	if not _dealt:
		_dealt = true
		_start_deal()


## The line above the name: what the card does and at what grade.
func badge_text() -> String:
	if card_entry.is_empty():
		var owned := false
		if Global != null and Global.get("permanent_augment_ids") is Array:
			owned = (Global.permanent_augment_ids as Array).has(data.id)
		return "◆  RANK UP  ◆" if owned else ""
	var current := Global.get_augment_level(data.id) if Global != null else 1
	var after := AugmentBinding.resulting_level(card_entry, current)
	var grade := AugmentScaling.grade_name(int(card_entry.get("grade", 0)))
	match String(card_entry.get("kind", "")):
		AugmentBinding.KIND_TRANSCEND:
			return "◆  TRANSCEND  ·  Lv.%d  ◆" % after
		AugmentBinding.KIND_RANK:
			return "%s  ·  Lv.%d → %d" % [grade, current, after]
		AugmentBinding.KIND_SWAP:
			return "%s  ·  SWAP  ·  Lv.%d" % [grade, after]
	return "%s  ·  NEW  ·  Lv.%d" % [grade, after]


## Gold for a Transcendence, the item rarity colours for the grades
## (Etched green, Gilded blue, Sanctified violet, Apocryphal ember).
func grade_colour() -> Color:
	if card_entry.is_empty():
		return OverlayKit.GOLD
	if is_transcend_card():
		return OverlayKit.GOLD_BRIGHT
	return OverlayKit.rarity_colour(AugmentScaling.grade_rarity_index(int(card_entry.get("grade", 0))))


func _card_flavor(s: String, max_chars: int = 95) -> String:
	var t := s.strip_edges()
	if t == "":
		return ""

	# Flatten newlines so wrapping behaves predictably.
	t = t.replace("\n", " ").replace("\r", " ")
	while t.find("  ") != -1:
		t = t.replace("  ", " ")

	if t.length() <= max_chars:
		return t

	var cut := t.substr(0, max_chars)
	var last_space := cut.rfind(" ")
	if last_space >= int(max_chars * 0.6):
		cut = cut.substr(0, last_space)
	return cut + "…"


# ---------------------------------------------------------------------------
# Motion (real time; see the class note)
# ---------------------------------------------------------------------------

func _start_deal() -> void:
	if ArcaneMotion.reduced():
		_deal = 1.0
		_deal_delay = 0.0
		_tilt = Vector2.ZERO
		_tilt_vel = Vector2.ZERO
		modulate.a = 1.0
		return
	# Dealt from below, leaning back, one after another along the row. No yaw
	# at that pitch: a turned corner would swing outside the inflated quad.
	_deal = 0.0
	_deal_delay = DEAL_STAGGER * float(get_index())
	_tilt = Vector2(-38.0, 0.0)
	_tilt_vel = Vector2.ZERO
	modulate.a = 0.0


## AugmentFlyVfx has captured this card and flies the copy; stop drawing it.
func hide_for_flight() -> void:
	_flown = true


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := clampf(float(now - _last_ticks) / 1000000.0, 0.0, 0.05)
	_last_ticks = now
	_idle_t += dt

	if _deal < 1.0:
		if _deal_delay > 0.0:
			_deal_delay -= dt
		else:
			var was := _deal
			_deal = minf(1.0, _deal + dt / 0.55)
			if was < 0.62 and _deal >= 0.62:
				_glaze(0.0)
	var deal_ease := 1.0 - pow(1.0 - _deal, 3.0)
	_sink = move_toward(_sink, 1.0 if (disabled and not _picked) else 0.0, dt * 4.0)
	modulate.a = 0.0 if _flown else deal_ease * (1.0 - _sink * 0.6)
	var still := ArcaneMotion.reduced()

	var target := Vector2.ZERO
	var inside := (not disabled and get_global_rect().has_point(get_global_mouse_position())) or _picked
	_hovered = inside
	_hover = move_toward(_hover, 1.0 if inside else 0.0, dt * 6.0)
	if still:
		target = Vector2.ZERO
	elif inside:
		var rel := (get_local_mouse_position() / size - Vector2(0.5, 0.5)) * 2.0
		rel = rel.clamp(Vector2(-1, -1), Vector2(1, 1))
		# The side under the cursor presses away, as a fingertip on a card would.
		target = Vector2(-rel.y * MAX_PITCH, rel.x * MAX_YAW)
	else:
		# At rest the card still breathes, a degree either way.
		target = Vector2(sin(_idle_t * 0.9 + get_index() * 1.7) * 1.2, sin(_idle_t * 0.7 + get_index()) * 1.5)
	if _deal < 1.0 and _deal_delay > 0.0:
		target = _tilt
	var accel := (target - _tilt) * STIFFNESS - _tilt_vel * DAMPING
	_tilt_vel += accel * dt
	_tilt += _tilt_vel * dt
	_lift = move_toward(_lift, _hover, dt * 5.0)

	var rise := (1.0 - deal_ease) * 90.0 + _sink * 26.0
	_surface.position = Vector2(0.0, rise - _lift * 10.0)
	var lift_scale := 1.0 if still else lerpf(1.0, HOVER_SCALE, maxf(_lift, 1.0 if _picked else 0.0))
	scale = Vector2.ONE * lift_scale * (1.0 - _sink * 0.04)
	if still:
		_tilt = Vector2.ZERO
		_tilt_vel = Vector2.ZERO
	_shadow.modulate.a = (0.55 + _lift * 0.3) * deal_ease
	_shadow.position = Vector2(-18.0 - _tilt.y * 0.6, 6.0 + _lift * 14.0 + rise)
	_mat.set_shader_parameter("tilt", _tilt)
	_mat.set_shader_parameter("glare", _hover)
	_mat.set_shader_parameter("foil", _hover * 0.8)
	_mat.set_shader_parameter("shade", 1.0 - _sink * 0.35)
	_frame.set("glow", _hover)
	_art_frame.set("glow", _hover * 0.8)


## One sweep of glaze across the face.
func _glaze(delay: float) -> void:
	if _sweep_tw != null and _sweep_tw.is_running():
		_sweep_tw.kill()
	_mat.set_shader_parameter("sweep", -0.4)
	_sweep_tw = create_tween().set_ignore_time_scale(true)
	_sweep_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if delay > 0.0:
		_sweep_tw.tween_interval(delay)
	# Past the far corner (the diagonal ends at 1.4) so no lit wedge is left.
	_sweep_tw.tween_method(func(v: float) -> void: _mat.set_shader_parameter("sweep", v), -0.4, 1.9, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _press_down() -> void:
	if ArcaneMotion.reduced():
		return
	if _press_tw != null and _press_tw.is_running():
		_press_tw.kill()
	_press_tw = create_tween().set_ignore_time_scale(true)
	_press_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_press_tw.tween_property(_surface, "scale", Vector2.ONE * 0.97, 0.05)
	_surface.pivot_offset = _surface.size * 0.5


func _press_up() -> void:
	if ArcaneMotion.reduced():
		_surface.scale = Vector2.ONE
		return
	if _press_tw != null and _press_tw.is_running():
		_press_tw.kill()
	_press_tw = create_tween().set_ignore_time_scale(true)
	_press_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_press_tw.tween_property(_surface, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
