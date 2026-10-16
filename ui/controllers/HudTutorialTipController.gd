extends Node
class_name HudTutorialTipController

const StatusIcons := preload("res://core/combat/CombatStatusIcons.gd")

# Shows tutorial tips in the GateOverlay/TutorialTip panel.
#
# - Queues tips so they never overlap.
# - Dedupe prevents the same tip from spamming.
# - Uses ignore-time-scale timers so it still works during pause / timescale=0.

@export var tutorial_panel_path: NodePath
@export var tutorial_label_path: NodePath

@export var dedupe_ms: int = 2500
@export var gap_sec: float = 0.12

var _panel: PanelContainer = null
var _label: Label = null
var _icons: HBoxContainer = null

var _queue: Array[Dictionary] = []
var _running: bool = false
var _last_text: String = ""
var _last_shown_msec: int = -1000000000
var _tw: Tween = null


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hook_run_events()


func _ready() -> void:
	_resolve_nodes()


func _exit_tree() -> void:
	_queue.clear()
	_running = false
	if _tw != null and _tw.is_running():
		_tw.kill()


func _hook_run_events() -> void:
	if RunEvents != null and RunEvents.has_signal("tutorial_tip"):
		var cb := Callable(self, "_on_tutorial_tip")
		if not RunEvents.tutorial_tip.is_connected(cb):
			RunEvents.tutorial_tip.connect(cb)
	if RunEvents != null and RunEvents.has_signal("illustrated_tutorial_tip"):
		var cb := Callable(self, "_on_illustrated_tutorial_tip")
		if not RunEvents.illustrated_tutorial_tip.is_connected(cb):
			RunEvents.illustrated_tutorial_tip.connect(cb)


func _resolve_nodes() -> void:
	if _panel == null and tutorial_panel_path != NodePath():
		_panel = get_node_or_null(tutorial_panel_path) as PanelContainer
	if _label == null and tutorial_label_path != NodePath():
		_label = get_node_or_null(tutorial_label_path) as Label
	if _icons == null and _panel != null:
		_icons = _panel.get_node_or_null("Margin/Row/StatusIcons") as HBoxContainer


func _on_tutorial_tip(text: String, duration: float) -> void:
	enqueue_tip(text, duration)


func _on_illustrated_tutorial_tip(text: String, duration: float, icon_ids: Array[StringName]) -> void:
	enqueue_tip(text, duration, icon_ids)


func enqueue_tip(text: String, duration: float = 2.8, icon_ids: Array[StringName] = []) -> void:
	_resolve_nodes()
	if _panel == null or _label == null:
		return

	var t := text.strip_edges()
	if t == "":
		return

	var now_msec := Time.get_ticks_msec()

	# Dedupe: ignore if the same text was just shown.
	if t == _last_text and (now_msec - _last_shown_msec) < dedupe_ms:
		return

	# Dedupe: ignore if already queued.
	for d: Dictionary in _queue:
		if String(d.get("text", "")) == t:
			return

	_queue.append({"text": t, "duration": maxf(0.4, duration), "icons": icon_ids.duplicate()})
	if not _running:
		_running = true
		call_deferred("_run_queue")


func _run_queue() -> void:
	_resolve_nodes()
	if not _queue_context_is_valid():
		_abort_queue()
		return

	while _queue.size() > 0:
		if not _queue_context_is_valid():
			_abort_queue()
			return
		var tip: Dictionary = _queue.pop_front() as Dictionary
		var t: String = String(tip.get("text", ""))
		var dur: float = float(tip.get("duration", 2.8))

		_last_text = t
		_last_shown_msec = Time.get_ticks_msec()

		_show_now(t, tip.get("icons", []))
		var tree: SceneTree = get_tree()
		if tree == null:
			_abort_queue()
			return
		await tree.create_timer(dur, false, true, true).timeout
		if not _queue_context_is_valid():
			_abort_queue()
			return
		_hide_now()
		tree = get_tree()
		if tree == null:
			_abort_queue()
			return
		await tree.create_timer(gap_sec, false, true, true).timeout

	_running = false


func _queue_context_is_valid() -> bool:
	return (
		is_inside_tree()
		and get_tree() != null
		and _panel != null
		and is_instance_valid(_panel)
		and _label != null
		and is_instance_valid(_label)
	)


func _abort_queue() -> void:
	_queue.clear()
	_running = false


func _show_now(text: String, icon_ids: Array[StringName] = []) -> void:
	_resolve_nodes()
	if _panel == null or _label == null:
		return

	if _tw != null and _tw.is_running():
		_tw.kill()

	_label.text = text
	_show_icons(icon_ids)
	_panel.visible = true
	_panel.modulate.a = 1.0
	_panel.scale = Vector2.ONE

	# Small "pop" when time is running.
	if Engine.time_scale > 0.0:
		_panel.scale = Vector2.ONE * 0.98
		_tw = create_tween()
		_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tw.set_trans(Tween.TRANS_QUAD)
		_tw.set_ease(Tween.EASE_OUT)
		_tw.tween_property(_panel, "scale", Vector2.ONE, 0.14)


func _show_icons(ids: Array[StringName]) -> void:
	if _icons == null:
		return
	for child in _icons.get_children():
		_icons.remove_child(child)
		child.queue_free()
	var shown: Array[StringName] = []
	for id in ids:
		if shown.has(id):
			continue
		var art := StatusIcons.texture(id)
		if art == null:
			continue
		var badge := TextureRect.new()
		badge.custom_minimum_size = Vector2(40.0, 40.0)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.texture = art
		_icons.add_child(badge)
		shown.append(id)
	_icons.visible = not shown.is_empty()


func _hide_now() -> void:
	if _panel == null:
		return
	_panel.visible = false
