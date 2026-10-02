class_name ArcaneBackdrop
extends Control
## The living painting behind the front-end screens (main menu, Archives).
##
## One painted plate, kept alive without repainting it: the shader drifts
## cloud and mist across masked open air, twinkles stars in the window,
## pulses the castle beam and flickers light pools over the painted flames;
## particles add embers off the candles, dust in the lamplight and arcane
## motes up the beam. The whole stage drifts a few pixels and leans against
## the mouse, so the world reads as a place rather than a picture.
##
## Moods are named uniform targets (see MOODS). set_mood() eases toward one;
## screens call it as the selection moves, so the world answers the choice.
## Reduced motion keeps the light and weather but stops the camera drift and
## the mouse lean, and thins the particles.

const ArcaneParticles := preload("res://ui/widgets/ArcaneParticles.gd")

const NOISE := preload("res://assets/ui/menu/cloud_noise.png")
const SHADER := preload("res://ui/shaders/arcane_backdrop.gdshader")

## Plate coordinates are authored in the 2048 x 1152 plate's pixels and turned
## into UV here, so they can be read straight off the image.
const PLATE_PX := Vector2(2048.0, 1152.0)
const WARM := Color(1.0, 0.6, 0.27)
const CANDLE := Color(1.0, 0.7, 0.36)
const ARCANE := Color(0.42, 0.62, 1.0)

const PROFILES: Dictionary = {
	&"threshold": {
		"plate": "res://assets/ui/menu/threshold_backdrop.jpg",
		"masks": "res://assets/ui/menu/threshold_masks.png",
		# x, top, bottom (plate px), half-width (px)
		"beam": [1292.0, 0.0, 470.0, 11.0],
		# Open sky only: clear of the left cliff and the foreground banner.
		"stars": [760.0, 0.0, 1430.0, 441.0],
		# [x, y, radius px, colour, strength (negative = arcane light), seed]
		"lights": [
			[1541.0, 907.0, 68.0, WARM, 0.34, 0.11],
			[1541.0, 895.0, 222.0, WARM, 0.07, 0.11],
			[1558.0, 652.0, 39.0, CANDLE, 0.26, 0.47],
			[678.0, 1050.0, 44.0, CANDLE, 0.26, 0.83],
			[1576.0, 540.0, 43.0, ARCANE, -0.26, 0.29],
			[1507.0, 676.0, 39.0, ARCANE, -0.22, 0.61],
			[844.0, 671.0, 31.0, ARCANE, -0.30, 0.37],
			[701.0, 949.0, 29.0, ARCANE, -0.24, 0.73],
		],
		"embers": [
			[1541.0, 891.0, 16, 1.0],
			[1558.0, 640.0, 5, 0.6],
			[678.0, 1040.0, 5, 0.6],
		],
		"dust": [789.0, 354.0, 2048.0, 1152.0],
		"motes": [1292.0, 45.0, 1292.0, 441.0],
		"fog": Color(0.6, 0.65, 0.78),
	},
	&"vigil": {
		"plate": "res://assets/ui/menu/vigil_backdrop.jpg",
		"masks": "res://assets/ui/menu/vigil_masks.png",
		"beam": [1872.0, 0.0, 600.0, 10.0],
		"stars": [820.0, 0.0, 2048.0, 300.0],
		"lights": [
			[742.0, 882.0, 64.0, CANDLE, 0.34, 0.21],
			[742.0, 870.0, 240.0, WARM, 0.07, 0.21],
			[482.0, 419.0, 52.0, ARCANE, -0.30, 0.55],
			[1372.0, 822.0, 28.0, ARCANE, -0.26, 0.38],
			[1130.0, 543.0, 24.0, ARCANE, -0.22, 0.66],
			[1308.0, 648.0, 24.0, ARCANE, -0.22, 0.91],
		],
		"embers": [
			[742.0, 862.0, 14, 1.0],
		],
		"dust": [300.0, 300.0, 1400.0, 1152.0],
		"motes": [1872.0, 80.0, 1872.0, 560.0],
		"fog": Color(0.58, 0.63, 0.78),
	},
}

## Uniform targets the backdrop eases toward. Keys missing from a mood fall
## back to `calm`.
const MOODS: Dictionary = {
	&"calm": {
		"exposure": 1.0, "sky_tint": Color(1, 1, 1), "cloud_amount": 1.0, "mist_amount": 1.0,
		"warm_gain": 1.0, "cool_gain": 1.0, "beam_gain": 1.0, "cloud_speed": 1.0,
		"ember": 1.0, "motes": 1.0,
	},
	# Continue: the lamp is lit and waiting.
	&"hearth": {
		"exposure": 1.02, "sky_tint": Color(1.05, 0.98, 0.9), "warm_gain": 1.45, "cool_gain": 0.9,
		"ember": 1.5, "cloud_speed": 0.9,
	},
	# New run: the castle wakes.
	&"arcane": {
		"exposure": 1.03, "sky_tint": Color(0.95, 0.97, 1.06), "cool_gain": 1.3, "beam_gain": 1.4,
		"cloud_speed": 1.7, "motes": 2.0, "ember": 0.8,
	},
	# Archives: dust in the lamplight, the mist settles in.
	&"archive": {
		"sky_tint": Color(1.02, 0.97, 0.92), "warm_gain": 1.2, "mist_amount": 1.35,
		"cloud_speed": 0.7, "ember": 1.1,
	},
	# Settings: the world holds still.
	&"still": {
		"sky_tint": Color(0.97, 0.98, 1.0), "cloud_speed": 0.35, "mist_amount": 0.85, "ember": 0.7,
		"motes": 0.6,
	},
	# Quit: the lights gutter, the weather closes in.
	&"dusk": {
		"exposure": 0.8, "sky_tint": Color(0.84, 0.87, 0.98), "warm_gain": 0.55, "cool_gain": 0.55,
		"beam_gain": 0.45, "cloud_amount": 1.5, "mist_amount": 1.35, "cloud_speed": 1.3, "ember": 0.35,
		"motes": 0.3,
	},
	# Developer mode: something synthetic flickers under the paint.
	&"synthetic": {
		"sky_tint": Color(0.9, 1.03, 1.03), "cool_gain": 1.3, "beam_gain": 1.3, "cloud_speed": 1.2,
		"motes": 1.6,
	},
}

const MOOD_RATE := 2.6
const OVERSCAN := 1.045
const DRIFT_PX := Vector2(16.0, 9.0)
const LEAN_PX := Vector2(12.0, 7.0)

@export var profile: StringName = &"threshold"
@export var mood: StringName = &"calm"

var reduced_motion := false

var _stage: Control
var _plate: TextureRect
var _material: ShaderMaterial
var _profile: Dictionary = {}
var _current: Dictionary = {}
var _target: Dictionary = {}
var _t := 0.0
var _t_cloud := 0.0
var _lean := Vector2.ZERO
var _emitters: Array[Dictionary] = []
## Per light: [strength, seed]; flicker is evaluated here once per frame.
var _lights: Array[Vector2] = []
var _light_amp := PackedFloat32Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_profile = PROFILES.get(profile, PROFILES[&"threshold"])
	_build()
	_current = _resolve_mood(mood)
	_target = _current.duplicate()
	_read_reduced_motion()
	var settings := get_node_or_null("/root/SettingsManager")
	if settings != null and settings.has_signal("settings_changed"):
		settings.connect("settings_changed", _on_settings_changed)
	resized.connect(_layout)
	_layout()
	_apply_uniforms()


func set_mood(next: StringName) -> void:
	if not MOODS.has(next):
		next = &"calm"
	mood = next
	_target = _resolve_mood(next)


func plate_size() -> Vector2:
	return _stage.size if _stage != null else size


func _resolve_mood(mood_name: StringName) -> Dictionary:
	var resolved: Dictionary = (MOODS[&"calm"] as Dictionary).duplicate()
	var overrides: Dictionary = MOODS.get(mood_name, {})
	for key in overrides:
		resolved[key] = overrides[key]
	return resolved


func _build() -> void:
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	_plate = TextureRect.new()
	_plate.name = "Plate"
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.texture = load(String(_profile["plate"])) as Texture2D
	_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plate.stretch_mode = TextureRect.STRETCH_SCALE
	_plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("masks", load(String(_profile["masks"])))
	_material.set_shader_parameter("noise_tex", NOISE)
	_material.set_shader_parameter("fog_color", _profile.get("fog", Color(0.6, 0.65, 0.78)))
	_material.set_shader_parameter("aspect", PLATE_PX.x / PLATE_PX.y)
	var beam: Array = _profile.get("beam", [])
	if beam.size() == 4:
		_material.set_shader_parameter("beam", Vector4(beam[0] / PLATE_PX.x, beam[1] / PLATE_PX.y, beam[2] / PLATE_PX.y, beam[3] / PLATE_PX.y))
	var stars: Array = _profile.get("stars", [])
	if stars.size() == 4:
		_material.set_shader_parameter("star_rect", Vector4(stars[0] / PLATE_PX.x, stars[1] / PLATE_PX.y, stars[2] / PLATE_PX.x, stars[3] / PLATE_PX.y))
	var positions := PackedVector4Array()
	var colours := PackedVector4Array()
	for light: Array in _profile.get("lights", []):
		var colour: Color = light[3]
		positions.append(Vector4(light[0] / PLATE_PX.x, light[1] / PLATE_PX.y, light[2] / PLATE_PX.y, light[5]))
		colours.append(Vector4(colour.r, colour.g, colour.b, light[4]))
		_lights.append(Vector2(float(light[4]), float(light[5])))
	_light_amp.resize(10)
	while positions.size() < 10:
		positions.append(Vector4.ZERO)
		colours.append(Vector4.ZERO)
	_material.set_shader_parameter("light_pos", positions)
	_material.set_shader_parameter("light_col", colours)
	_material.set_shader_parameter("light_count", mini((_profile.get("lights", []) as Array).size(), 10))
	_plate.material = _material
	_stage.add_child(_plate)

	for ember: Array in _profile.get("embers", []):
		var node := ArcaneParticles.embers(int(ember[2]), float(ember[3]))
		_add_emitter(node, Vector2(ember[0], ember[1]), &"ember")
	var dust: Array = _profile.get("dust", [])
	if dust.size() == 4:
		var rect := Rect2(Vector2(dust[0], dust[1]), Vector2(dust[2] - dust[0], dust[3] - dust[1]))
		var node := ArcaneParticles.dust()
		_add_emitter(node, rect.get_center(), &"dust", rect.size * 0.5)
	var motes: Array = _profile.get("motes", [])
	if motes.size() == 4:
		var top := Vector2(motes[0], motes[1])
		var bottom := Vector2(motes[2], motes[3])
		var node := ArcaneParticles.arcane_motes()
		_add_emitter(node, (top + bottom) * 0.5, &"motes", Vector2(10.0, (bottom.y - top.y) * 0.5))


func _add_emitter(node: CPUParticles2D, plate_px: Vector2, kind: StringName, extents_px: Vector2 = Vector2.ZERO) -> void:
	_stage.add_child(node)
	_emitters.append({"node": node, "uv": plate_px / PLATE_PX, "kind": kind, "extents_uv": extents_px / PLATE_PX, "base_amount": node.amount})


func _layout() -> void:
	if _stage == null:
		return
	var cover := maxf(size.x / PLATE_PX.x, size.y / PLATE_PX.y) * OVERSCAN
	_stage.size = PLATE_PX * cover
	_stage.pivot_offset = _stage.size * 0.5
	for emitter in _emitters:
		var node := emitter["node"] as CPUParticles2D
		node.position = (emitter["uv"] as Vector2) * _stage.size
		var extents := (emitter["extents_uv"] as Vector2) * _stage.size
		if extents != Vector2.ZERO:
			node.emission_rect_extents = extents
	_place_stage()


func _place_stage() -> void:
	var centred := (size - _stage.size) * 0.5
	var drift := Vector2.ZERO
	if not reduced_motion:
		drift = Vector2(sin(_t * 0.045) * DRIFT_PX.x, sin(_t * 0.033 + 1.1) * DRIFT_PX.y)
	_stage.position = centred + drift + _lean
	_stage.scale = Vector2.ONE * (1.0 if reduced_motion else 1.0 + 0.006 * sin(_t * 0.05))


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	var blend := 1.0 - exp(-delta * MOOD_RATE)
	for key in _target:
		var to: Variant = _target[key]
		var from: Variant = _current.get(key, to)
		if to is Color:
			_current[key] = (from as Color).lerp(to as Color, blend)
		else:
			_current[key] = lerpf(float(from), float(to), blend)
	_t_cloud += delta * float(_current.get("cloud_speed", 1.0))
	if reduced_motion:
		_lean = Vector2.ZERO
	else:
		var viewport := get_viewport_rect().size
		var mouse := get_viewport().get_mouse_position()
		var norm := Vector2.ZERO
		if viewport.x > 0.0 and viewport.y > 0.0:
			norm = ((mouse / viewport) - Vector2(0.5, 0.5)) * 2.0
			norm = norm.clamp(Vector2(-1, -1), Vector2(1, 1))
		_lean = _lean.lerp(-norm * LEAN_PX, 1.0 - exp(-delta * 1.8))
	_place_stage()
	_apply_uniforms()


func _apply_uniforms() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("t_cloud", _t_cloud)
	for key in ["exposure", "cloud_amount", "mist_amount", "warm_gain", "cool_gain", "beam_gain"]:
		_material.set_shader_parameter(key, float(_current.get(key, 1.0)))
	_material.set_shader_parameter("sky_tint", _current.get("sky_tint", Color.WHITE))
	# Flicker and pulse depend only on time, so they are evaluated here once
	# rather than per pixel: two detuned sines plus a slow third for drift.
	var warm := float(_current.get("warm_gain", 1.0))
	var cool := float(_current.get("cool_gain", 1.0))
	for i in range(_lights.size()):
		var strength := _lights[i].x
		var light_seed := _lights[i].y
		var flick := 0.84 \
			+ 0.10 * sin(_t * (6.5 + light_seed * 2.7) + light_seed * 11.0) \
			+ 0.07 * sin(_t * (13.0 + light_seed * 5.1) + light_seed * 3.0) \
			+ 0.07 * sin(_t * (0.9 + light_seed * 0.7) + light_seed * 17.0)
		_light_amp[i] = absf(strength) * flick * (cool if strength < 0.0 else warm)
	_material.set_shader_parameter("light_amp", _light_amp)
	_material.set_shader_parameter("beam_pulse", 0.82 + 0.18 * sin(_t * 1.6) + 0.08 * sin(_t * 4.3 + 1.3))
	# Particles draw additively, so the mood scales their colour, not alpha.
	var thin := 0.55 if reduced_motion else 1.0
	for emitter in _emitters:
		var node := emitter["node"] as CPUParticles2D
		var kind: StringName = emitter["kind"]
		var level := clampf(float(_current.get("motes" if kind == &"motes" else "ember", 1.0)), 0.0, 2.5)
		if kind == &"dust":
			level = lerpf(1.0, level, 0.4)
		var k := level * thin
		node.modulate = Color(k, k, k, 1.0)
		node.speed_scale = clampf(0.8 + level * 0.2, 0.6, 1.3)


func _read_reduced_motion() -> void:
	var settings := get_node_or_null("/root/SettingsManager")
	if settings != null and settings.has_method("get_value"):
		reduced_motion = bool(settings.call("get_value", &"accessibility", &"reduced_motion", false))


func _on_settings_changed(section: StringName, key: StringName, _value: Variant) -> void:
	if section == &"accessibility" and key == &"reduced_motion":
		_read_reduced_motion()
