extends Node2D
class_name MissingPalisEffect
## The Missing Pālis (Varis, February; the settled half of the idea): the
## missing texture as an item. Wearing it puts a mild wavy distortion on
## the screen — a little stronger for a moment when it is first picked up —
## and the amplitude is HARD-BOUNDED regardless of how many copies, merges
## or rarities exist, per the original readability constraint ("nesastako
## tik daudz, ka neko nevar redzēt"). The delayed-damage mechanic from the
## later brainstorm remains unbuilt on purpose (it is still a proposal).

## One shared overlay for the whole game, whatever tries to stack.
static var _overlay: CanvasLayer = null
static var _owners: int = 0

const AMPLITUDE_IDLE := 1.6      # pixels, the permanent gentle wave
const AMPLITUDE_EQUIP := 5.0     # pixels, the brief hello on equip
const EQUIP_PULSE_SECONDS := 2.0
const WAVE_SPEED := 1.1
const WAVE_FREQUENCY := 9.0

var player: Node2D = null
var item: ItemInstance = null
var slot_index: int = -1
var _pulse_left: float = EQUIP_PULSE_SECONDS


func get_effects_short(_inst: ItemInstance) -> PackedStringArray:
	return PackedStringArray([
		"The world ripples faintly while this is worn. It never gets worse.",
		"A checkerboard where a texture should be. Somebody misplaced a pālis.",
	])


func setup_with_item(p: Node, inst: ItemInstance, slot: int) -> void:
	player = p as Node2D
	item = inst
	slot_index = slot


func set_item_instance(inst: ItemInstance) -> void:
	item = inst


func _ready() -> void:
	_owners += 1
	_pulse_left = EQUIP_PULSE_SECONDS
	if _overlay == null or not is_instance_valid(_overlay):
		_overlay = _build_overlay()
		get_tree().root.add_child(_overlay)
	_overlay.visible = true


func _exit_tree() -> void:
	_owners = maxi(0, _owners - 1)
	if _owners == 0 and _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null


func _process(delta: float) -> void:
	if _pulse_left > 0.0:
		_pulse_left = maxf(0.0, _pulse_left - delta)
	if _overlay == null or not is_instance_valid(_overlay):
		return
	var rect := _overlay.get_node_or_null("Wave") as ColorRect
	if rect == null or rect.material == null:
		return
	# The bound: never above AMPLITUDE_EQUIP, idle at AMPLITUDE_IDLE, and
	# a second copy adds nothing (the overlay is shared and static).
	var pulse: float = _pulse_left / EQUIP_PULSE_SECONDS
	var amplitude: float = AMPLITUDE_IDLE + (AMPLITUDE_EQUIP - AMPLITUDE_IDLE) * pulse
	(rect.material as ShaderMaterial).set_shader_parameter("amplitude_px", amplitude)


static func _build_overlay() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "MissingPalisOverlay"
	layer.layer = 90
	var rect := ColorRect.new()
	rect.name = "Wave"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float amplitude_px = 1.6;
uniform float frequency = 9.0;
uniform float speed = 1.1;

void fragment() {
	vec2 pixel = 1.0 / vec2(textureSize(screen_texture, 0));
	float wave = sin(SCREEN_UV.y * frequency * 6.2831 + TIME * speed * 6.2831);
	vec2 offset = vec2(wave * amplitude_px * pixel.x, 0.0);
	COLOR = texture(screen_texture, SCREEN_UV + offset);
}
"""
	var wave_material := ShaderMaterial.new()
	wave_material.shader = shader
	wave_material.set_shader_parameter("frequency", WAVE_FREQUENCY)
	wave_material.set_shader_parameter("speed", WAVE_SPEED)
	rect.material = wave_material
	layer.add_child(rect)
	return layer


func describe() -> Dictionary:
	return {"owners": _owners, "pulse_left": _pulse_left}
