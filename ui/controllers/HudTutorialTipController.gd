extends Node
class_name HudTutorialTipController

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

var _queue: Array[Dictionary] = []
var _running: bool = false
var _last_text: String = ""
var _last_shown_msec: int = -1000000000
var _tw: Tween = null
var _shutting_down: bool = false


func _enter_tree() -> void:
	_shutting_down = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hook_run_events()


func _exit_tree() -> void:
	_shutting_down = true
	_queue.clear()
	_running = false
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if RunEvents != null and RunEvents.has_signal("tutorial_tip"):
		var cb := Callable(self, "_on_tutorial_tip")
		if RunEvents.tutorial_tip.is_connected(cb):
			RunEvents.tutorial_tip.disconnect(cb)


func _ready() -> void:
	_resolve_nodes()


func _hook_run_events() -> void:
	if RunEvents != null and RunEvents.has_signal("tutorial_tip"):
		var cb := Callable(self, "_on_tutorial_tip")
		if not RunEvents.tutorial_tip.is_connected(cb):
			RunEvents.tutorial_tip.connect(cb)


func _resolve_nodes() -> void:
	if _panel == null and tutorial_panel_path != NodePath():
		_panel = get_node_or_null(tutorial_panel_path) as PanelContainer
	if _label == null and tutorial_label_path != NodePath():
		_label = get_node_or_null(tutorial_label_path) as Label


func _on_tutorial_tip(text: String, duration: float) -> void:
	enqueue_tip(text, duration)


func enqueue_tip(text: String, duration: float = 2.8) -> void:
	if _shutting_down or not is_inside_tree():
		return
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

	_queue.append({"text": t, "duration": maxf(0.4, duration)})
	if not _running:
		_running = true
		call_deferred("_run_queue")


func _run_queue() -> void:
	if _shutting_down or not is_inside_tree():
		_running = false
		return
	_resolve_nodes()
	if _panel == null or _label == null:
		_queue.clear()
		_running = false
		return

	while _queue.size() > 0 and not _shutting_down and is_inside_tree():
		var tip: Dictionary = _queue.pop_front() as Dictionary
		var t: String = String(tip.get("text", ""))
		var dur: float = float(tip.get("duration", 2.8))

		_last_text = t
		_last_shown_msec = Time.get_ticks_msec()

		_show_now(t)
		var tree: SceneTree = get_tree()
		if tree == null:
			break
		await tree.create_timer(dur, false, true, true).timeout
		if _shutting_down or not is_inside_tree():
			return
		_hide_now()
		tree = get_tree()
		if tree == null:
			return
		await tree.create_timer(gap_sec, false, true, true).timeout
		if _shutting_down or not is_inside_tree():
			return

	_running = false


func _show_now(text: String) -> void:
	_resolve_nodes()
	if _panel == null or _label == null:
		return

	if _tw != null and _tw.is_running():
		_tw.kill()

	_label.text = text
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


func _hide_now() -> void:
	if _panel == null:
		return
	_panel.visible = false
