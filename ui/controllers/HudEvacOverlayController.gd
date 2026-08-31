extends Node
class_name HudEvacOverlayController

@export var overlay_path: NodePath
@export var label_path: NodePath
@export var vignette_path: NodePath
@export var safeguard_prompt_path: NodePath

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
var _safeguard_prompt: Label
var _bound_rite: Node
## One line per controller for a missing ThreatDirector. _process retries the
## bind every frame while _td is null, so this used to be sixty warnings a
## second - and its twin in HudThreatController made it a hundred and twenty.
var _warned_missing_director: bool = false

## How often the overlay re-asks the tree for the live Exit Rite. Godot has no
## "joined a group" notification and a segment builds exactly one rite, so a
## poll it is - four times a second instead of sixty.
const RITE_REBIND_INTERVAL: float = 0.25

var _rebind_accum: float = 0.0
var _painted_once: bool = false
var _last_unsealed: bool = false
var _last_pressure: float = -1.0
var _last_remaining: float = -1.0

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
	var sp := safeguard_prompt_path

	if op == NodePath():
		op = NodePath("../EvacOverlay")
	if lp == NodePath():
		lp = NodePath("../EvacOverlay/EvacWarning")
	if vp == NodePath():
		vp = NodePath("../EvacOverlay/Vignette")
	if sp == NodePath():
		sp = NodePath("../EvacOverlay/SafeguardPrompt")

	_overlay = get_node_or_null(op) as Control
	_label = get_node_or_null(lp) as Label
	_vignette = get_node_or_null(vp) as ColorRect
	_safeguard_prompt = get_node_or_null(sp) as Label

	_vignette_mat = null
	if _vignette != null and _vignette.material is ShaderMaterial:
		_vignette_mat = _vignette.material as ShaderMaterial

func _bind_director() -> void:
	_td = get_node_or_null("/root/ThreatDirector")
	if _td != null:
		return
	if _warned_missing_director:
		return
	_warned_missing_director = true
	push_warning(
		"[HudEvacOverlayController] ThreatDirector autoload missing at /root/ThreatDirector; "
		+ "the evac warning and its vignette stay idle"
	)

func _process(delta: float) -> void:
	if _overlay == null or _label == null:
		_resolve_nodes()
	if _td == null or not is_instance_valid(_td):
		_bind_director()
		return
	_rebind_accum += delta
	if _rebind_accum >= RITE_REBIND_INTERVAL:
		_rebind_accum = 0.0
		_bind_live_rite()
	_update_from_director()


func set_safeguard_prompt(show: bool, count: int) -> void:
	if _safeguard_prompt == null:
		_resolve_nodes()
	if _safeguard_prompt == null:
		return
	_safeguard_prompt.visible = show and count > 0
	_safeguard_prompt.text = "[Interact] Invoke safeguard · %d" % count if _safeguard_prompt.visible else ""


func _bind_live_rite() -> void:
	var rite := get_tree().get_first_node_in_group(&"exit_rite")
	if rite == _bound_rite:
		return
	if _bound_rite != null and is_instance_valid(_bound_rite):
		var old_callback := Callable(self, "_on_safeguard_state_changed")
		if _bound_rite.is_connected("safeguard_state_changed", old_callback):
			_bound_rite.disconnect("safeguard_state_changed", old_callback)
	_bound_rite = rite
	set_safeguard_prompt(false, 0)
	if _bound_rite != null and _bound_rite.has_signal("safeguard_state_changed"):
		var callback := Callable(self, "_on_safeguard_state_changed")
		if not _bound_rite.is_connected("safeguard_state_changed", callback):
			_bound_rite.connect("safeguard_state_changed", callback)
		_on_safeguard_state_changed(
			int(_bound_rite.call("safeguard_count")),
			int(_bound_rite.call("safeguard_capacity")),
			bool(_bound_rite.call("can_invoke_safeguard"))
		)


func _on_safeguard_state_changed(current: int, _capacity: int, can_invoke: bool) -> void:
	set_safeguard_prompt(can_invoke, current)

func _update_from_director() -> void:
	var unsealed := bool(_td.get("gate_unsealed"))
	var pressure := float(_td.get("evac_pressure")) if _td.has_method("get") else 0.0
	var rem := float(_td.get("evac_remaining_sec")) if _td.has_method("get") else 0.0

	# The blink is the only term below with a clock in it. Everything else
	# rewrites the value the label and the vignette already hold, and the
	# director pins pressure and remaining to zero until the gate unseals - so
	# the whole pre-rite segment settles after one paint. The director moves
	# these on its own 5 Hz tick, and the signature below catches every move.
	var blinking := unsealed and (pressure >= show_pressure_threshold) \
		and (rem <= 0.0 or rem <= blink_when_remaining_leq)
	if _painted_once and not blinking \
	and unsealed == _last_unsealed \
	and is_equal_approx(pressure, _last_pressure) \
	and is_equal_approx(rem, _last_remaining):
		return
	_painted_once = true
	_last_unsealed = unsealed
	_last_pressure = pressure
	_last_remaining = rem

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
