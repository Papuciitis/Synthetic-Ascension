extends CanvasLayer
class_name FirstEncounterOverlay

signal dismissed
signal freeze_released

const FREEZE_SECONDS := 0.8
const VISIBLE_SECONDS := 5.8
const FADE_SECONDS := 0.55
const SCREEN_MARGIN := 24.0
const TOP_MARGIN := 64.0

@onready var _root: Control = $Root
@onready var _tether: Control = $Root/Tether
@onready var _card: PanelContainer = $Root/Card
@onready var _eyebrow: Label = $Root/Card/Margin/VBox/Eyebrow
@onready var _title: Label = $Root/Card/Margin/VBox/Identity/Title
@onready var _image: TextureRect = $Root/Card/Margin/VBox/Identity/Portrait
@onready var _role: Label = $Root/Card/Margin/VBox/Role
@onready var _ratings: Label = $Root/Card/Margin/VBox/Ratings
@onready var _counter: Label = $Root/Card/Margin/VBox/Counter

var _target: Node2D = null
var _last_target_screen := Vector2.ZERO
var _elapsed := 0.0
var _pause_owned := false
var _presented := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 225
	_root.visible = false


func present(
	entry: Dictionary,
	target: Node2D,
	texture: Texture2D = null,
	ratings_text: String = ""
) -> void:
	_target = target
	_elapsed = 0.0
	_presented = true
	_pause_owned = false
	_root.modulate = Color.WHITE
	_eyebrow.text = "FIRST ENCOUNTER  //  ARCHETYPE INDEXED"
	_title.text = String(entry.get("name", "UNKNOWN ARCHETYPE")).to_upper()
	_role.text = "ROLE  //  %s" % String(entry.get("role", "Unclassified"))
	_ratings.text = _compact_ratings(ratings_text)
	_counter.text = "COUNTER  //  %s" % String(entry.get("counter", "Observe and adapt."))
	_image.texture = texture
	_image.visible = texture != null
	_root.visible = true

	var tree := get_tree()
	if tree != null and not tree.paused:
		tree.paused = true
		_pause_owned = true
	call_deferred("_update_geometry")


func _process(delta: float) -> void:
	if not _presented:
		return
	_elapsed += maxf(0.0, delta)
	_update_geometry()
	if _pause_owned and _elapsed >= FREEZE_SECONDS:
		_release_pause()
	if _elapsed >= VISIBLE_SECONDS:
		_dismiss()
		return
	var fade_start := VISIBLE_SECONDS - FADE_SECONDS
	if _elapsed > fade_start:
		_root.modulate.a = clampf((VISIBLE_SECONDS - _elapsed) / FADE_SECONDS, 0.0, 1.0)


func is_freeze_active() -> bool:
	return _pause_owned and _elapsed < FREEZE_SECONDS


func debug_target_screen_point() -> Vector2:
	return _last_target_screen


func _compact_ratings(text: String) -> String:
	var clean := text.strip_edges()
	if clean.is_empty():
		return "CLASSIFICATION  //  UNRESOLVED"
	return clean.replace("  •  ", "   /   ").replace(" • ", "   /   ")


func _update_geometry() -> void:
	if not _presented or _card == null or _tether == null:
		return
	var viewport_size := _root.size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = get_viewport().get_visible_rect().size
	if _target_is_live(_target):
		_last_target_screen = _target.get_global_transform_with_canvas().origin
	_last_target_screen = Vector2(
		clampf(_last_target_screen.x, SCREEN_MARGIN, viewport_size.x - SCREEN_MARGIN),
		clampf(_last_target_screen.y, TOP_MARGIN, viewport_size.y - SCREEN_MARGIN)
	)

	var card_size := _card.size
	if card_size.x < 1.0 or card_size.y < 1.0:
		card_size = _card.custom_minimum_size
	var rect := _choose_card_rect(viewport_size, _last_target_screen, card_size)
	_card.position = rect.position
	var card_point := _nearest_card_edge(rect, _last_target_screen)
	_tether.set_points(card_point, _last_target_screen)


func _choose_card_rect(viewport_size: Vector2, target_point: Vector2, card_size: Vector2) -> Rect2:
	var candidates: Array[Vector2] = [
		target_point + Vector2(76.0, -card_size.y * 0.5),
		target_point + Vector2(-card_size.x - 76.0, -card_size.y * 0.5),
		target_point + Vector2(-card_size.x * 0.5, -card_size.y - 76.0),
		target_point + Vector2(-card_size.x * 0.5, 76.0),
	]
	var reserved: Array[Rect2] = [
		Rect2(0, 0, minf(350.0, viewport_size.x * 0.22), minf(390.0, viewport_size.y * 0.42)),
		Rect2(maxf(0.0, viewport_size.x - 470.0), 0, minf(470.0, viewport_size.x), minf(220.0, viewport_size.y * 0.25)),
		Rect2(maxf(0.0, viewport_size.x * 0.5 - 210.0), maxf(0.0, viewport_size.y - 160.0), 420.0, 160.0),
		Rect2(maxf(0.0, viewport_size.x - 520.0), maxf(0.0, viewport_size.y - 155.0), 520.0, 155.0),
	]
	var best := Rect2(Vector2.ZERO, card_size)
	var best_score := INF
	for candidate in candidates:
		var clamped := Vector2(
			clampf(candidate.x, SCREEN_MARGIN, maxf(SCREEN_MARGIN, viewport_size.x - card_size.x - SCREEN_MARGIN)),
			clampf(candidate.y, TOP_MARGIN, maxf(TOP_MARGIN, viewport_size.y - card_size.y - SCREEN_MARGIN))
		)
		var rect := Rect2(clamped, card_size)
		var score := rect.get_center().distance_to(target_point) * 0.08
		if rect.grow(26.0).has_point(target_point):
			score += 10000.0
		for blocked in reserved:
			var overlap := rect.intersection(blocked)
			score += overlap.get_area() * 0.12
		if score < best_score:
			best_score = score
			best = rect
	return best


func _nearest_card_edge(rect: Rect2, target_point: Vector2) -> Vector2:
	var point := Vector2(
		clampf(target_point.x, rect.position.x, rect.end.x),
		clampf(target_point.y, rect.position.y, rect.end.y)
	)
	if rect.has_point(target_point):
		point = rect.get_center()
	return point


func _release_pause() -> void:
	if not _pause_owned:
		return
	var tree := get_tree()
	var handed_off := tree != null and tree.paused and _offer_pause_handoff()
	_pause_owned = false
	if tree != null and tree.paused and not handed_off:
		tree.paused = false
	freeze_released.emit()


## A management screen can open during the recognition freeze. It could not
## claim the already-paused tree at that instant, so transfer ownership before
## releasing ours instead of letting combat run for a frame underneath it.
func _offer_pause_handoff() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	for owner in tree.get_nodes_in_group(&"pause_handoff_owner"):
		if owner.has_method("adopt_pause_handoff") and bool(owner.call("adopt_pause_handoff")):
			return true
	return false


func _target_is_live(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return false
	if bool(target.get_meta(&"__in_pool", false)):
		return false
	if target.process_mode == Node.PROCESS_MODE_DISABLED:
		return false
	return target.is_visible_in_tree()


func _dismiss() -> void:
	if not _presented:
		return
	_release_pause()
	_presented = false
	_root.visible = false
	_tether.clear_points()
	dismissed.emit()


func _exit_tree() -> void:
	_release_pause()
