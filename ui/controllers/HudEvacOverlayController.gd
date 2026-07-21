extends Node
class_name HudEvacOverlayController

@export var overlay_path: NodePath
@export var label_path: NodePath
@export var vignette_path: NodePath

@export var show_on_unseal: bool = true
@export var show_pressure_threshold: float = 0.0

@export var blink_when_remaining_leq: float = 10.0
@export var base_vignette_strength: float = 0.18
@export var overtime_vignette_add: float = 0.22

var _overlay: Control
var _label: Label
var _vignette: ColorRect
var _vignette_mat: ShaderMaterial
var _td: Node

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_resolve_nodes()
	_bind_director()
	set_process(true)

func _resolve_nodes() -> void:
	var op := overlay_path
	var lp := label_path
	var vp := vignette_path

	if op == NodePath():
		op = NodePath("../EvacOverlay")
	if lp == NodePath():
		lp = NodePath("../EvacOverlay/EvacWarning")
	if vp == NodePath():
		vp = NodePath("../EvacOverlay/Vignette")

	_overlay = get_node_or_null(op) as Control
	_label = get_node_or_null(lp) as Label
	_vignette = get_node_or_null(vp) as ColorRect

	_vignette_mat = null
	if _vignette != null and _vignette.material is ShaderMaterial:
		_vignette_mat = _vignette.material as ShaderMaterial

func _bind_director() -> void:
	_td = get_node_or_null("/root/ThreatDirector")
	if _td == null:
		push_warning("[HudEvacOverlayController] ThreatDirector not found at /root/ThreatDirector")

func _process(_delta: float) -> void:
	if _overlay == null or _label == null:
		_resolve_nodes()
	if _td == null or not is_instance_valid(_td):
		_bind_director()
		return
	_update_from_director()

func _update_from_director() -> void:
	var unsealed := bool(_td.get("gate_unsealed"))
	var pressure := float(_td.get("evac_pressure")) if _td.has_method("get") else 0.0
	var rem := float(_td.get("evac_remaining_sec")) if _td.has_method("get") else 0.0

	# Visibility
	var show := false
	if unsealed and show_on_unseal:
		show = (pressure >= show_pressure_threshold)
	elif unsealed:
		show = (pressure >= show_pressure_threshold)

	_label.visible = show
	if not unsealed:
		_label.visible = false
		_label.modulate.a = 1.0

	# Text + blink
	if _label.visible:
		if rem > 0.0:
			_label.text = "GATE UNSEALED  •  EVAC IN %ds" % int(ceil(rem))
			if rem <= blink_when_remaining_leq:
				_label.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.010)
			else:
				_label.modulate.a = 1.0
		else:
			_label.text = "EVAC NOW!"
			_label.modulate.a = 0.45 + 0.55 * sin(Time.get_ticks_msec() * 0.014)

	# Vignette intensity based on pressure (clamped 0..1)
	if _vignette_mat != null:
		var p := clampf(pressure, 0.0, 1.0)
		var v := base_vignette_strength + p * overtime_vignette_add
		_vignette_mat.set_shader_parameter("vignette_strength", v)
