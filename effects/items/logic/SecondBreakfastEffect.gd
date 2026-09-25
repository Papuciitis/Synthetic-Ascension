extends Node2D
class_name SecondBreakfastEffect
## Second Breakfast (handoff §14.3): any real heal grants a delayed second
## portion — half the applied amount, a few seconds later, routed through
## the real healing path under its own source so healing locks, telemetry
## and other listeners see an honest heal. Recursion-proof: the second
## portion never earns a third, and pending portions coalesce instead of
## queueing into a breakfast buffet.

const PORTION_FRACTION := 0.5
const PORTION_DELAY := 3.0
const SOURCE := &"second_breakfast"

var player: Node2D = null
var item: ItemInstance = null
var slot_index: int = -1

var _pending: float = 0.0
var _delay_left: float = 0.0
var telemetry: Dictionary = {"portions": 0, "healed": 0.0}


func get_effects_short(_inst: ItemInstance) -> PackedStringArray:
	return PackedStringArray([
		"Any heal serves a second portion: %d%% of what landed, %.0f s later." % [int(PORTION_FRACTION * 100.0), PORTION_DELAY],
		"Second portions never earn a third.",
	])


func setup_with_item(p: Node, inst: ItemInstance, slot: int) -> void:
	player = p as Node2D
	item = inst
	slot_index = slot


func set_item_instance(inst: ItemInstance) -> void:
	item = inst


func _ready() -> void:
	if RunEvents != null and not RunEvents.player_heal_resolved.is_connected(_on_heal):
		RunEvents.player_heal_resolved.connect(_on_heal)


func _exit_tree() -> void:
	# Unequipping forfeits the pending portion; no meal travels with the bag.
	_pending = 0.0
	if RunEvents != null and RunEvents.player_heal_resolved.is_connected(_on_heal):
		RunEvents.player_heal_resolved.disconnect(_on_heal)


func _on_heal(who: Node, _requested: float, _modified: float, applied: float, source: StringName, blocked: bool) -> void:
	if who != player or blocked or applied <= 0.0:
		return
	if source == SOURCE:
		return  # the recursion guard: a portion is never an appetizer
	# Coalesce: a bigger meal replaces the pending portion, never stacks it.
	var portion := applied * PORTION_FRACTION
	if portion > _pending:
		_pending = portion
	_delay_left = PORTION_DELAY


func _process(delta: float) -> void:
	if _pending <= 0.0:
		return
	_delay_left -= delta
	if _delay_left > 0.0:
		return
	var portion := _pending
	_pending = 0.0
	if player != null and is_instance_valid(player) and player.has_method("heal"):
		telemetry["portions"] = int(telemetry["portions"]) + 1
		telemetry["healed"] = float(telemetry["healed"]) + portion
		# The real healing path: locks, multipliers and listeners all apply.
		player.call("heal", portion, SOURCE)
		if BattleText != null:
			BattleText.popup(player.global_position + Vector2(0, -26), "second breakfast", Color(0.95, 0.85, 0.55, 0.95), 1.1)


func describe() -> Dictionary:
	return {"pending": _pending, "delay_left": _delay_left, "telemetry": telemetry.duplicate()}
