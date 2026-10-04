extends RefCounted
## Keeps StoryDirector.state current from signals the run already emits, so
## the story never has to catch anything at the moment of a death: the
## witnesses (the Congregation) with their milestones, and reconstructions
## (Global.followers_transaction), the attempt's boundaries and completed
## segments (the balance boundary signals), what dealt the killing blow
## (RunEvents.player_damage_resolved, the last hit before player_life_event
## "death") and the inner gate's keeper falling (boss_cleared). It only
## writes story memory; nothing in the game reacts to it. Created once per
## session by StoryDirector.ensure().

## A death is put down to the last hit if it landed this recently.
const CAUSE_WINDOW_MS := 2000

var _cause: String = ""
var _cause_ms: int = -1000000


func bind() -> void:
	if Global != null:
		Global.followers_transaction.connect(_on_followers_transaction)
		Global.balance_attempt_boundary.connect(_on_attempt_boundary)
		Global.balance_segment_completed.connect(_on_segment_completed)
	if RunEvents != null:
		RunEvents.player_damage_resolved.connect(_on_player_damage)
		RunEvents.player_paid_health.connect(_on_paid_health)
		RunEvents.player_life_event.connect(_on_life_event)
		RunEvents.boss_cleared.connect(_on_boss_cleared)


func _on_followers_transaction(_old_value: int, change: int, new_value: int, reason: StringName, _context: Dictionary, _show_feedback: bool, _allow_aggregate: bool) -> void:
	# player.die() charges the cost on every death, the fatal one too, and
	# rebuilds the player only when Followers remain after it: a charge that
	# empties the balance ends the run. Counting every charge put one
	# reconstruction too many on nearly every account and noted RECONSTRUCTION
	# on a first death that rebuilt no one (story review 2026-10-04).
	if reason == &"reconstruction" and new_value > 0:
		StoryDirector.note_reconstruction()
	# The witnesses are the Congregation, the people this attempt recruited
	# (Global.CONGREGATION_REASONS): spending never lowers it, and the square's
	# crowd already follows it. A sale, an undo, a refund, Abstain, a load or
	# a developer grant moves the wallet but recruits no one, so none of them
	# raises the peak or reaches a milestone (story review 2026-10-04: the
	# witness counts followed the wallet). Global has counted this gain by
	# the time the signal arrives.
	if change > 0 and Global.CONGREGATION_REASONS.has(reason):
		var recruited := Global.attempt_congregation
		StoryDirector.note_recruits(recruited - change, recruited)


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
