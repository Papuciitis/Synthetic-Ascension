extends Node
## The story inside a segment (StoryDirector.attach_segment). Once the run is
## playable (the Binding chosen, the opening over) it gives the district's
## arrival line as a tip and the Registry's bulletin: a card the first time a
## profile meets it, a tip in later accounts. Witness lines that came due
## (Follower milestones) follow as tips, and the records that progress has
## reached are noted. Pausable, so every card and choice is waited out.

## Unpaused play before the arrival line: lets the Binding's card clear.
const ARRIVAL_DELAY := 1.2
const ARRIVAL_SECONDS := 5.5
const BULLETIN_SECONDS := 4.5
const WITNESS_SECONDS := 4.5
## How often pending lines and progress are looked at.
const POLL_SECONDS := 1.0

var segment: int = 1
var _game: Node = null
var _played: float = 0.0
var _poll: float = 0.0
var _arrived: bool = false
var _busy: bool = false


func setup(game: Node, seg: int) -> void:
	_game = game
	segment = maxi(1, seg)
	# Segment 1's arrival is the opening itself.
	_arrived = segment <= 1


func _process(delta: float) -> void:
	_played += delta
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL_SECONDS
		StoryDirector.note_progress()
		if not _busy and _run_is_playable():
			_tip_pending()
	if not _arrived and not _busy and _played >= ARRIVAL_DELAY and _run_is_playable():
		_arrived = true
		_present_arrival()


func _run_is_playable() -> bool:
	if _game == null or not is_instance_valid(_game):
		return false
	var picker: Variant = _game.get("augment_select")
	if picker != null and is_instance_valid(picker):
		return false
	var opening: Variant = _game.get("_opening_sequence")
	return opening == null or not is_instance_valid(opening)


func _present_arrival() -> void:
	var info := StoryDirector.arrival(segment)
	if info.is_empty():
		return
	_busy = true
	var card: Dictionary = info.get("bulletin", {})
	if not card.is_empty():
		var modals := get_tree().get_first_node_in_group(&"tutorial_modal_controller") as TutorialModalController
		if modals != null:
			await modals.present_card_and_wait(String(card["title"]), String(card["body"]), StoryLines.BULLETIN_EYEBROW, true)
	if not is_inside_tree():
		return
	_tip(String(info.get("tip", "")), ARRIVAL_SECONDS)
	_tip(String(info.get("bulletin_tip", "")), BULLETIN_SECONDS)
	_busy = false


func _tip_pending() -> void:
	for line in StoryDirector.take_pending():
		_tip(String((line as Dictionary).get("text", "")), WITNESS_SECONDS)


func _tip(text: String, seconds: float) -> void:
	if text != "" and RunEvents != null:
		RunEvents.tutorial_tip.emit(text, seconds)
