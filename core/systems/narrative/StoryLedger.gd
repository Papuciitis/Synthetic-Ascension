extends RefCounted
## Keeps StoryDirector.state current from signals the run already emits, so
## the story never has to catch anything at the moment of a death: the peak
## of Followers, reconstructions and milestones (Global's Follower signals),
## the attempt's boundaries and completed segments (the balance boundary
## signals), what dealt the killing blow (RunEvents.player_damage_resolved,
## the last hit before player_life_event "death") and the inner gate's
## keeper falling (boss_cleared). It only writes story memory; nothing in
## the game reacts to it. Created once per session by StoryDirector.ensure().

## A death is put down to the last hit if it landed this recently.
const CAUSE_WINDOW_MS := 2000

var _cause: String = ""
var _cause_ms: int = -1000000


func bind() -> void:
	if Global != null:
		Global.followers_changed.connect(_on_followers_changed)
		Global.followers_transaction.connect(_on_followers_transaction)
		Global.balance_attempt_boundary.connect(_on_attempt_boundary)
		Global.balance_segment_completed.connect(_on_segment_completed)
	if RunEvents != null:
		RunEvents.player_damage_resolved.connect(_on_player_damage)
		RunEvents.player_paid_health.connect(_on_paid_health)
		RunEvents.player_life_event.connect(_on_life_event)
		RunEvents.boss_cleared.connect(_on_boss_cleared)


func _on_followers_changed(value: int) -> void:
	StoryDirector.note_followers(value)


func _on_followers_transaction(old_value: int, _change: int, new_value: int, reason: StringName, _context: Dictionary, _show_feedback: bool, _allow_aggregate: bool) -> void:
	if reason == &"reconstruction":
		StoryDirector.note_reconstruction()
	# A load or a reset only restates the balance; it was never a gain.
	if reason != &"system_sync" and new_value > old_value:
		StoryDirector.note_follower_gain(old_value, new_value)


func _on_attempt_boundary(reason: StringName) -> void:
	match reason:
		&"restarted":
			StoryDirector.begin_attempt()
		&"failed":
			StoryDirector.close_account()


func _on_segment_completed(segment: int) -> void:
	StoryDirector.note_segment_completed(segment)


func _on_player_damage(_player: Node, _raw: float, _adjusted: float, applied: float, source: Node, kind: StringName, outcome: StringName) -> void:
	if outcome != &"hit" or applied <= 0.0:
		return
	_cause = StoryDirector.cause_id(source, kind)
	_cause_ms = Time.get_ticks_msec()


func _on_paid_health(_player: Node, _amount: float, _reason: StringName) -> void:
	_cause = "self"
	_cause_ms = Time.get_ticks_msec()


func _on_life_event(player: Node, kind: StringName) -> void:
	if kind != &"death":
		return
	var cause := _cause if Time.get_ticks_msec() - _cause_ms <= CAUSE_WINDOW_MS else ""
	var tree := player.get_tree() if player != null and player.is_inside_tree() else null
	var rite := false
	var boss := -1
	if tree != null:
		rite = not tree.get_nodes_in_group(&"exit_rite_channeling").is_empty()
		if not tree.get_nodes_in_group(&"boss").is_empty():
			boss = 1
		elif not tree.get_nodes_in_group(&"miniboss").is_empty():
			boss = 0
	StoryDirector.note_death(cause, rite, boss)


func _on_boss_cleared(_boss: Node, tier: int) -> void:
	if tier == 0:
		StoryDirector.note_record("inner_ward")
