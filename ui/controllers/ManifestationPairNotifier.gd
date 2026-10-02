extends Control
class_name ManifestationPairNotifier

## Announces an authored pair payoff coming online, and going away again.
##
## Two of a noun is the quiet moment - the HUD counter flashes and that is the
## whole announcement. A PAIR is the loud one: it is the thing the whole layer
## promises, it is not written on any item the player owns, and it can be lost
## by picking the wrong thing up off the ground. Silently losing your engine is
## the worst failure available here, so LOST is announced as loudly as GAINED.
##
## Structurally a copy of SetBreakpointNotifier - UI built in code, tween
## in/hold/out pinned to TWEEN_PAUSE_PROCESS so the card still animates while
## the tree is paused, one card at a time through a serial queue. Deliberately
## not that class itself: it is hard-wired to Inventory.equipment_changed and
## SetData, neither of which a pair has.
##
## Pairs are Phase G. Everything here reads through `has_method`, so on a build
## where the runner has no `get_active_pairs()` this node costs one dictionary
## lookup per equip change and shows nothing.
##
## Presentation (the front end's register): a dark card in a gold double rule,
## a Cinzel caption in the pair's accent, the pair's name in the HUD's sacred
## face, a Garamond line. It fades in with a small settle (only the fade under
## Reduced Motion) on real time.

const OverlayKit := preload("res://ui/widgets/overlays/OverlayKit.gd")
const ArcaneFrameScript := preload("res://ui/components/ArcaneFrame.gd")
const HUD_THEME := preload("res://ui/theme/SyntheticHudTheme.tres")

## Long enough that a ground-pickup shuffle - drop the ring, pick the new one
## up - collapses LOST-then-GAINED into no card at all rather than two.
const DEBOUNCE_SEC: float = 0.25

var _runner: Node = null
var _known: Dictionary = {}
var _queue: Array[Dictionary] = []
var _showing: bool = false
var _debounce: float = -1.0

var _panel: PanelContainer = null
var _title: Label = null
var _name: Label = null
var _detail: Label = null
var _frame: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_build_ui()
	add_to_group(&"manifestation_pair_notifier")
	set_process(true)


func _exit_tree() -> void:
	_release_runner()


func _process(delta: float) -> void:
	if _runner == null or not is_instance_valid(_runner):
		_bind_runner()
		return
	if _debounce < 0.0:
		return
	_debounce -= delta
	if _debounce <= 0.0:
		_debounce = -1.0
		_sample()


# ---------------------------------------------------------------------------
# Runner binding
# ---------------------------------------------------------------------------

func _bind_runner() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var player: Node = tree.get_first_node_in_group("player")
	if player == null:
		return
	var runner: Node = player.get_node_or_null("ManifestationRunner")
	if runner == null or not runner.has_signal("manifestations_changed"):
		return
	_runner = runner
	var cb := Callable(self, "_on_manifestations_changed")
	if not runner.is_connected("manifestations_changed", cb):
		runner.connect("manifestations_changed", cb)
	var lost := Callable(self, "_on_runner_lost")
	if not runner.tree_exiting.is_connected(lost):
		runner.tree_exiting.connect(lost)
	# Seed rather than announce: whatever is already live when this binds was
	# not just gained, and a card on every scene load would be noise.
	_known = _snapshot()


func _release_runner() -> void:
	if _runner == null or not is_instance_valid(_runner):
		_runner = null
		return
	var cb := Callable(self, "_on_manifestations_changed")
	if _runner.is_connected("manifestations_changed", cb):
		_runner.disconnect("manifestations_changed", cb)
	var lost := Callable(self, "_on_runner_lost")
	if _runner.tree_exiting.is_connected(lost):
		_runner.tree_exiting.disconnect(lost)
	_runner = null


func _on_runner_lost() -> void:
	_release_runner()
	_known.clear()
	_queue.clear()
	_debounce = -1.0


func _on_manifestations_changed() -> void:
	_debounce = DEBOUNCE_SEC


# ---------------------------------------------------------------------------
# Diffing
# ---------------------------------------------------------------------------

## id -> the pair's summary dictionary. Cached here rather than asked for on
## demand, because "what did I just lose" cannot be read off the runner after
## the pair has already been freed.
func _snapshot() -> Dictionary:
	var out: Dictionary = {}
	if _runner == null or not is_instance_valid(_runner) or not _runner.has_method("get_active_pairs"):
		return out
	for entry_value in (_runner.call("get_active_pairs") as Array):
		var entry: Dictionary = entry_value
		out[StringName(entry.get("id", &""))] = entry
	return out


func _sample() -> void:
	var after := _snapshot()
	for id in after:
		if not _known.has(id):
			_enqueue(true, after[id])
	for id in _known:
		if not after.has(id):
			_enqueue(false, _known[id])
	_known = after


func _enqueue(gained: bool, pair: Dictionary) -> void:
	_queue.append({"gained": gained, "pair": pair})
	if not _showing:
		_show_next()


# ---------------------------------------------------------------------------
# Presentation
# ---------------------------------------------------------------------------

func _show_next() -> void:
	if _queue.is_empty() or not is_inside_tree():
		_showing = false
		return
	_showing = true
	var message: Dictionary = _queue.pop_front()
	var gained: bool = bool(message.get("gained", false))
	var pair: Dictionary = message.get("pair", {}) as Dictionary
	var nouns: Array = pair.get("nouns", []) as Array

	_title.text = "MANIFESTATION PAIR" if gained else "PAIR LOST"
	_name.text = String(pair.get("name", "")).to_upper()
	_detail.text = _nouns_line(nouns) + "\nTwo lit nouns always light a pair — all ten exist.\nFull protocol recorded in Run Sheet."

	# A pair belongs to both its nouns, so its accent is the midpoint of the two
	# - it should not look like it is one noun's property.
	var accent := _accent_for(nouns)
	_title.modulate = accent if gained else Color(0.7, 0.66, 0.6)
	# The name stays parchment, warmed by the accent: legible on any noun.
	_name.modulate = OverlayKit.PARCHMENT.lerp(accent, 0.35) if gained else Color(0.66, 0.62, 0.56)
	_frame.set("colour", Color(accent.lerp(OverlayKit.GOLD_DIM, 0.55), 0.9) if gained else Color(0.42, 0.36, 0.3, 0.85))
	_frame.set("glow", 0.25 if gained else 0.0)

	_panel.modulate = Color(1, 1, 1, 0)
	_panel.pivot_offset = _panel.size * 0.5
	var pop := gained and not OverlayKit.reduced()
	_panel.scale = Vector2(0.94, 0.94) if pop else Vector2.ONE
	_panel.visible = true
	var tween: Tween = OverlayKit.tween(self)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.18)
	if pop:
		tween.parallel().tween_property(_panel, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.4 if gained else 1.6)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.22)
	tween.finished.connect(func() -> void:
		_panel.visible = false
		_show_next()
	)


func _nouns_line(nouns: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for noun_value in nouns:
		var noun := StringName(noun_value)
		parts.append("%s %s" % [ManifestationNouns.glyph(noun), ManifestationNouns.label(noun)])
	return " × ".join(parts)


func _accent_for(nouns: Array) -> Color:
	if nouns.is_empty():
		return ManifestationNouns.LAYER
	var accent := ManifestationNouns.colour(StringName(nouns[0]))
	if nouns.size() > 1:
		accent = accent.lerp(ManifestationNouns.colour(StringName(nouns[1])), 0.5)
	return accent


## Debug entry point mirroring SetBreakpointNotifier's, so the card can be
## checked without assembling a four-item loadout.
func debug_force_notification(pair: Dictionary, gained: bool = true) -> void:
	_enqueue(gained, pair)


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "ManifestationPairPanel"
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP, true)
	# Below SetBreakpointNotifier's card (124..~220): a run can cross a set
	# breakpoint and light a pair in the same equip, and two cards in one place
	# is one unreadable card.
	_panel.offset_left = -240.0
	_panel.offset_top = 240.0
	_panel.offset_right = 240.0
	_panel.offset_bottom = 326.0
	_panel.pivot_offset = Vector2(240.0, 43.0)
	add_child(_panel)
	_panel.theme = HUD_THEME
	_panel.add_theme_stylebox_override("panel", OverlayKit.shared(&"card"))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 13)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 13)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(margin)
	# After the margin: the box's labels must stay child 0 of the margin.
	_frame = ArcaneFrameScript.new() as Control
	_frame.set("inset", 5.0)
	_panel.add_child(_frame)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.theme_type_variation = &"InstitutionalHeading"
	OverlayKit.style_label(_title, &"caption", 12, Color.WHITE)
	box.add_child(_title)
	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.theme_type_variation = &"SacredHeading"
	_name.add_theme_font_size_override("font_size", 20)
	_name.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(_name)
	_detail = Label.new()
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(436, 0)
	OverlayKit.style_label(_detail, &"body", 15, OverlayKit.BODY)
	box.add_child(_detail)
