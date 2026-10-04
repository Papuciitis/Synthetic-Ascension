extends Node
## The story in the square (StoryDirector.attach_hub). On arrival, once no
## panel is open (a pending Doctrine opens first), the district just left
## behind is the square's arrival notice; after the segments where the work
## changed hands, Bren's dispatch follows as a dialogue card. Witness lines
## that come due in the square (a sale crossing a milestone) are notices over
## the player. Pausable; it never opens anything over an open panel.

const OPENING_PRESENTATION := preload("res://ui/screens/opening/OpeningPresentation.tscn")
const HubText := preload("res://scenes/hub/ui/HubText.gd")

const NOTICE_DELAY := 0.6
const NOTICE_SECONDS := 4.5
const DISPATCH_DELAY := 2.2
const WITNESS_SECONDS := 4.0
const POLL_SECONDS := 1.0
## Above the arrival point, clear of the player's head.
const NOTICE_RISE := Vector2(0.0, -150.0)
const WITNESS_RISE := Vector2(0.0, -200.0)

var hub: Node2D = null
var _clock: float = 0.0
var _poll: float = 0.0
var _noticed: bool = false
var _dispatched: bool = false
var _busy: bool = false


func setup(world: Node2D) -> void:
	hub = world
	StoryDirector.note_hub_arrival()


func _process(delta: float) -> void:
	if hub == null or _busy or _panel_open():
		return
	_clock += delta
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL_SECONDS
		StoryDirector.note_progress()
		_notice_pending()
	if not _noticed and _clock >= NOTICE_DELAY:
		_noticed = true
		var line := StoryDirector.departure_line()
		if line != "":
			_notice(_arrival_point() + NOTICE_RISE, line, HubText.BODY, NOTICE_SECONDS)
	if not _dispatched and _clock >= DISPATCH_DELAY:
		_dispatched = true
		_present_dispatch()


func _panel_open() -> bool:
	return hub.has_method("_panel_is_open") and bool(hub.call("_panel_is_open"))


func _arrival_point() -> Vector2:
	var arrival: Vector2 = HubWorld.STATION_CELLS["arrival"]
	return arrival * HubWorld.CELL


func _notice(at: Vector2, text: String, colour: Color, seconds: float) -> void:
	var notices: Variant = hub.get("_notice")
	if notices != null and is_instance_valid(notices):
		(notices as Node).call("show_line", at, text, colour, seconds)


func _notice_pending() -> void:
	var player: Variant = hub.get("_player")
	for line in StoryDirector.take_pending():
		var at := _arrival_point()
		if player != null and is_instance_valid(player):
			at = (player as Node2D).global_position
		_notice(at + WITNESS_RISE, String((line as Dictionary).get("text", "")), HubText.GOLD, WITNESS_SECONDS)


func _present_dispatch() -> void:
	# A letter waits for someone to read it (no developer or headless run).
	if not StoryDirector.cards_allowed():
		return
	var dispatch := StoryDirector.bren_dispatch(StoryDirector.completed_segment())
	if dispatch.is_empty():
		return
	var card := OPENING_PRESENTATION.instantiate() as OpeningPresentation
	if card == null:
		return
	_busy = true
	hub.add_child(card)
	if hub.has_method("_stations_enabled"):
		hub.call("_stations_enabled", false)
	var tree := get_tree()
	var was_paused := tree.paused
	tree.paused = true
	await card.present_dialogue(String(dispatch["speaker"]), String(dispatch["role"]), String(dispatch["text"]))
	if is_instance_valid(card):
		card.queue_free()
	if tree != null:
		tree.paused = was_paused
	if hub != null and is_instance_valid(hub) and hub.has_method("_stations_enabled"):
		hub.call("_stations_enabled", true)
	_busy = false
