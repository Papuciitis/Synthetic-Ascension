extends Node

@export var value_label_path: NodePath
@export var bar_path: NodePath
@export var detail_label_path: NodePath
@export var tooltip_target_path: NodePath
@export var tooltip_scene: PackedScene
@export var tier_size: float = 25.0
@export var tooltip_offset: Vector2 = Vector2(14, 14)


var _value: Label
var _bar: ProgressBar
var _detail: Label
var _tooltip_target: Control
var _tooltip: Control


var _td: Node
var _last_threat: float = -999999.0
var _tip_text: String = ""

# The last multipliers received, kept so the tooltip can be rebuilt between
# emissions: the power-contrast countdown moves while no multiplier does.
var _hp_mul: float = 1.0
var _dmg_mul: float = 1.0
var _spd_mul: float = 1.0
var _spawn_mul: float = 1.0
var _elite_bonus: float = 0.0
var _contrast_key: int = 0

func _ready() -> void:
	_resolve_nodes()
	_bind_director()
	_bind_hover()
	_set_tooltip_visible(false)
	set_process(true)

func _exit_tree() -> void:
	if _tooltip != null and is_instance_valid(_tooltip):
		_tooltip.queue_free()

func _resolve_nodes() -> void:
	# ThreatController is a sibling of TopLeft, so defaults use ../TopLeft/...
	var vp: NodePath = value_label_path
	var bp: NodePath = bar_path
	var dp: NodePath = detail_label_path
	var tp: NodePath = tooltip_target_path

	if vp == NodePath():
		vp = NodePath("../TopLeft/Margin/VBox/ThreatRow/ThreatValue")
	if bp == NodePath():
		bp = NodePath("../TopLeft/Margin/VBox/ThreatRow/ThreatBar")
	if dp == NodePath():
		dp = NodePath("../TopLeft/Margin/VBox/ThreatRow/ThreatDetail")
	if tp == NodePath():
		tp = NodePath("../TopLeft/Margin/VBox/ThreatRow")

	_value = get_node_or_null(vp) as Label
	_bar = get_node_or_null(bp) as ProgressBar
	_detail = get_node_or_null(dp) as Label
	_tooltip_target = get_node_or_null(tp) as Control


func _bind_director() -> void:
	_td = get_node_or_null("/root/ThreatDirector")
	if _td == null:
		push_warning("[HudThreatController] ThreatDirector not found at /root/ThreatDirector")
		return

	if _td.has_signal("threat_changed"):
		var cb := Callable(self, "_on_threat_changed")
		if not _td.is_connected("threat_changed", cb):
			_td.connect("threat_changed", cb)

	if _td.has_signal("multipliers_changed"):
		var cb2 := Callable(self, "_on_multipliers_changed")
		if not _td.is_connected("multipliers_changed", cb2):
			_td.connect("multipliers_changed", cb2)

	if _td.has_signal("power_threshold_noted"):
		var cb3 := Callable(self, "_on_power_threshold_noted")
		if not _td.is_connected("power_threshold_noted", cb3):
			_td.connect("power_threshold_noted", cb3)

	# Force initial draw
	_on_threat_changed(float(_td.get("threat")))
	_on_multipliers_changed(
		float(_td.get("enemy_hp_mul")),
		float(_td.get("enemy_damage_mul")),
		float(_td.get("enemy_speed_mul")),
		float(_td.get("spawn_interval_mul")),
		float(_td.get("elite_bonus"))
	)

func _bind_hover() -> void:
	if _tooltip_target == null:
		# fall back to bar or value
		_tooltip_target = _bar if _bar != null else (_value as Control)
	if _tooltip_target == null:
		return

	_tooltip_target.mouse_filter = Control.MOUSE_FILTER_STOP

	var enter_cb := Callable(self, "_on_hover_entered")
	var exit_cb := Callable(self, "_on_hover_exited")
	if not _tooltip_target.is_connected("mouse_entered", enter_cb):
		_tooltip_target.connect("mouse_entered", enter_cb)
	if not _tooltip_target.is_connected("mouse_exited", exit_cb):
		_tooltip_target.connect("mouse_exited", exit_cb)

func _ensure_tooltip() -> void:
	if _tooltip != null and is_instance_valid(_tooltip):
		return

	if tooltip_scene == null:
		tooltip_scene = load("res://ui/widgets/ThreatTooltip.tscn") as PackedScene
		if tooltip_scene == null:
			return

	_tooltip = tooltip_scene.instantiate() as Control
	if _tooltip == null:
		return

	_tooltip.visible = false
	_tooltip.top_level = true
	_tooltip.z_index = 999

	# Add to the same parent as this controller (HUD root)
	get_parent().add_child(_tooltip)

func _set_tooltip_visible(v: bool) -> void:
	if _tooltip != null:
		_tooltip.visible = v

func _on_hover_entered() -> void:
	_ensure_tooltip()
	if _tooltip == null:
		return

	_set_tooltip_visible(true)
	_apply_tooltip_text()


	_update_tooltip_position()

func _on_hover_exited() -> void:
	_set_tooltip_visible(false)

func _apply_tooltip_text() -> void:
	if _tooltip == null:
		return
	if _tooltip.has_method("set_text"):
		_tooltip.call("set_text", _tip_text)
	elif _tooltip is Label:
		(_tooltip as Label).text = _tip_text

func _update_tooltip_position() -> void:
	if _tooltip == null or not _tooltip.visible:
		return

	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var pos: Vector2 = get_viewport().get_mouse_position() + tooltip_offset

	# Clamp inside viewport
	var s: Vector2 = _tooltip.size
	if s.x <= 0.0 or s.y <= 0.0:
		# size not ready yet; try minimum size
		s = _tooltip.get_combined_minimum_size()

	pos.x = clampf(pos.x, 8.0, maxf(8.0, vp_size.x - s.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, vp_size.y - s.y - 8.0))

	_tooltip.global_position = pos

func _process(_delta: float) -> void:
	if _td == null or not is_instance_valid(_td):
		_bind_director()
		return

	# Reacquire UI nodes if HUD got reloaded
	if _value == null or _bar == null:
		_resolve_nodes()
		_bind_hover()

	var t: float = float(_td.get("threat"))
	if absf(t - _last_threat) > 0.01:
		_on_threat_changed(t)
	_last_threat = t

	# The contrast countdown moves while no multiplier does, so the held-scaling
	# line is re-rendered on the second it changes rather than on the next emit.
	if _contrast_seconds() != _contrast_key:
		_rebuild_tip_text()

	_update_tooltip_position()

func _on_threat_changed(t: float) -> void:
	var ts: float = tier_size
	if ts <= 0.0:
		ts = 25.0

	var tier: int = int(floor(t / ts)) + 1
	var within: float = fmod(t, ts) / ts

	if _value != null:
		_value.text = "T%d  %.1f" % [tier, t]
	if _bar != null:
		_bar.max_value = 1.0
		_bar.value = clampf(within, 0.0, 1.0)

func _on_multipliers_changed(hp_mul: float, dmg_mul: float, spd_mul: float, spawn_mul: float, elite_bonus: float) -> void:
	_hp_mul = hp_mul
	_dmg_mul = dmg_mul
	_spd_mul = spd_mul
	_spawn_mul = spawn_mul
	_elite_bonus = elite_bonus
	_rebuild_tip_text()


## The vision's "these guys nearly killed me earlier" beat: the director holds
## enemy HP and damage scaling still for a while after a power threshold, and
## nothing used to say so. The label is the director's own ("3 Manifestations
## active"); the seconds are the window it just opened.
func _on_power_threshold_noted(id: StringName, label: String) -> void:
	_rebuild_tip_text()
	if RunEvents == null or not RunEvents.has_signal("tutorial_tip"):
		return
	var what: String = label if label.strip_edges() != "" else String(id).capitalize()
	if _contrast_key > 0:
		RunEvents.tutorial_tip.emit("%s — enemy scaling held for %ds." % [what, _contrast_key], 4.0)
	else:
		RunEvents.tutorial_tip.emit("%s." % what, 4.0)


## Whole seconds left on the power-contrast window, 0 when it is closed.
func _contrast_seconds() -> int:
	if _td == null or not is_instance_valid(_td) or not _td.has_method("power_contrast_seconds_left"):
		return 0
	return int(ceil(float(_td.call("power_contrast_seconds_left"))))


func _rebuild_tip_text() -> void:
	var hp_mul: float = _hp_mul
	var dmg_mul: float = _dmg_mul
	var spd_mul: float = _spd_mul
	var spawn_rate: float = 1.0 / maxf(_spawn_mul, 0.001)
	_contrast_key = _contrast_seconds()

	var heat_pct: int = 0
	var ot: float = 0.0
	var loot: int = 0
	var unsealed: bool = false
	var phase: String = ""
	var rite: bool = false
	var rite_spawn: float = 1.0
	var rite_elite: float = 0.0
	if _td != null:
		var v = _td.get("heat")
		if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			heat_pct = int(clampf(float(v), 0.0, 1.0) * 100.0)
		v = _td.get("overtime")
		if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			ot = float(v)
		v = _td.get("loot_rarity_bonus")
		if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
			loot = int(v)
		v = _td.get("gate_unsealed")
		if typeof(v) == TYPE_BOOL:
			unsealed = bool(v)
		v = _td.get("segment_phase")
		if typeof(v) == TYPE_STRING_NAME or typeof(v) == TYPE_STRING:
			phase = String(v)
		v = _td.get("rite_channel_active")
		if typeof(v) == TYPE_BOOL:
			rite = bool(v)
		v = _td.get("rite_spawn_factor")
		if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			rite_spawn = float(v)
		v = _td.get("rite_elite_add")
		if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			rite_elite = float(v)

	# Player language, not raw tuning floats.
	var lines: PackedStringArray = []
	lines.append("Enemies: %+d%% health · %+d%% damage · %+d%% speed" % [
		int(round((hp_mul - 1.0) * 100.0)),
		int(round((dmg_mul - 1.0) * 100.0)),
		int(round((spd_mul - 1.0) * 100.0)),
	])
	if spawn_rate < 0.999:
		lines.append("Spawns %d%% faster" % int(round((1.0 - spawn_rate) * 100.0)))
	elif spawn_rate > 1.001:
		lines.append("Spawns %d%% slower" % int(round((spawn_rate - 1.0) * 100.0)))
	lines.append("District heat: %d%%" % heat_pct)
	if phase != "":
		lines.append("District phase: %s" % phase.to_upper())
	# Additive on top of the spawner's own roll (spawner.gd), so it reads as one.
	lines.append("Elite chance +%d%% on top of the spawner's own" % int(round(_elite_bonus * 100.0)))
	if rite:
		lines.append("Exit Rite channelling — spawn pacing ×%.2f, elites +%d%%" % [rite_spawn, int(round(rite_elite * 100.0))])
	if unsealed:
		lines.append("OVERTIME ×%.1f — the city is done tolerating you. Leave." % ot)
	if loot > 0:
		lines.append("Loot rarity +%d from the danger" % loot)
	if _contrast_key > 0:
		lines.append("Enemy scaling held — %ds" % _contrast_key)
	_tip_text = "\n".join(lines)

	# Keep inline detail empty (prevents HUD stretching if label exists)
	if _detail != null:
		_detail.text = ""

	_apply_tooltip_text()
