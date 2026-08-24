extends Node2D
class_name WagerShrineObjective

## A secondary that is a DECISION rather than a detour.
##
## The two secondaries the districts had were both "go to a place and then do
## the thing the place does": walk down an alley and pick up a cache, or enter a
## building and clear the room inside it. Both are fine and neither asks the
## player anything - the only choice is whether to make the trip at all.
##
## This one asks. Standing in the shrine raises the stake through three tiers,
## each costing more Followers and paying a better roll; stepping out resolves
## at whatever tier you reached. Followers are money AND lives, so raising the
## stake is spending your own reconstructions, and Luck bends the odds - which
## is the design doc's "opportunities affected by Luck" and its "additional
## risk" in the same object.
##
## It cannot take your last life: the stake is refused below the cost of a
## reconstruction, so a greedy player can go broke but never strand themselves.

signal resolved(shrine: WagerShrineObjective, tier: int, won: bool)

## Followers staked and the rarity band bought, per tier. Deliberately steep -
## a wager the player takes automatically is not a wager.
const TIERS: Array[Dictionary] = [
	{"stake": 8, "rarity_min": 3, "rarity_max": 5, "base_odds": 0.85, "label": "OFFERING"},
	{"stake": 22, "rarity_min": 5, "rarity_max": 7, "base_odds": 0.62, "label": "PLEDGE"},
	{"stake": 55, "rarity_min": 7, "rarity_max": 10, "base_odds": 0.40, "label": "COVENANT"},
]

const LOOT_SPAWNER_SCENE: PackedScene = preload("res://scenes/world/pickups/ExplorationLootSpawner.tscn")

@export var radius_px: float = 118.0
@export var seconds_per_tier: float = 2.2
@export var activation_radius_px: float = 620.0

var secondary_objective_id: int = 0

var _player: Node2D = null
var _dwell: float = 0.0
var _tier: int = -1
var _spent: int = 0
var _finished: bool = false
var _announced: bool = false
var _pulse: float = 0.0


func configure(objective_id: int) -> void:
	secondary_objective_id = objective_id


func _ready() -> void:
	add_to_group(&"secondary_objective")
	z_index = 34
	set_process(true)


func _process(delta: float) -> void:
	_pulse += delta
	if _finished:
		queue_redraw()
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
	if _player == null:
		return
	if bool(_player.get("is_dead")):
		return

	var distance_sq := _player.global_position.distance_squared_to(global_position)
	if not _announced and distance_sq <= activation_radius_px * activation_radius_px:
		_announced = true
		if RunEvents != null and RunEvents.has_signal("secondary_objective_changed"):
			RunEvents.secondary_objective_changed.emit(
				"SECONDARY • Wager Shrine",
				"Stand in the shrine to raise the stake. Step out to settle it."
			)

	if distance_sq <= radius_px * radius_px:
		_dwell += delta
		_try_raise_stake()
		queue_redraw()
		return

	# Stepping out is how you settle. That is the whole mechanism: there is no
	# confirm button, so the decision is made with your feet while the district
	# is still moving around you.
	if _tier >= 0:
		_settle()
	elif _dwell > 0.0:
		_dwell = 0.0
		queue_redraw()


func _try_raise_stake() -> void:
	var next_tier: int = _tier + 1
	if next_tier >= TIERS.size():
		return
	if _dwell < seconds_per_tier * float(next_tier + 1):
		return
	var stake: int = int(TIERS[next_tier]["stake"])
	if not _can_afford(stake):
		# Held at the last tier they could pay for, and said so - silently
		# refusing to escalate reads as the shrine being broken.
		if BattleText != null and BattleText.has_method("popup"):
			BattleText.popup(global_position, "NOT ENOUGH BELIEF", Color(0.85, 0.55, 0.35, 1.0), 1.15)
		_dwell = seconds_per_tier * float(next_tier + 1)
		return
	_tier = next_tier
	_spent += stake
	if Global != null:
		Global.transaction_followers(-stake, &"wager_shrine", {"tier": next_tier}, true, false)
	if BattleText != null and BattleText.has_method("popup"):
		BattleText.popup(
			global_position,
			"%s  -%d" % [String(TIERS[next_tier]["label"]), stake],
			Color(0.98, 0.82, 0.36, 1.0),
			1.25 + 0.1 * float(next_tier)
		)


## Never the last reconstruction. A player can go broke here; they must not be
## able to strand themselves.
func _can_afford(stake: int) -> bool:
	if Global == null:
		return false
	var floor_cost: int = 0
	if Global.has_method("compute_respawn_cost"):
		floor_cost = int(Global.compute_respawn_cost())
	return Global.followers - stake >= floor_cost


func odds_for(tier: int) -> float:
	if tier < 0 or tier >= TIERS.size():
		return 0.0
	var base: float = float(TIERS[tier]["base_odds"])
	var luck: float = Global.run_luck if Global != null else 0.0
	# Same curve every other Luck-facing system uses, so a Luck build feels this
	# the way it feels drops.
	return clampf(base + LuckResolver.rarity_promotion_bonus(luck), 0.05, 0.97)


func _settle() -> void:
	_finished = true
	var tier: int = _tier
	var won: bool = false
	if tier >= 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(hash("wager:%d:%d:%d" % [secondary_objective_id, tier, _spent]))
		won = rng.randf() <= odds_for(tier)
		if won:
			_pay_out(tier)

	if BattleText != null and BattleText.has_method("popup"):
		BattleText.popup(
			global_position,
			"THE SHRINE ANSWERS" if won else "THE SHRINE IS SILENT",
			Color(0.45, 0.98, 0.72, 1.0) if won else Color(0.85, 0.40, 0.36, 1.0),
			1.45
		)
	if RunEvents != null and RunEvents.has_signal("secondary_objective_completed") and secondary_objective_id != 0:
		RunEvents.secondary_objective_completed.emit(secondary_objective_id)
	resolved.emit(self, tier, won)
	queue_redraw()


func _pay_out(tier: int) -> void:
	if LOOT_SPAWNER_SCENE == null:
		return
	var spawner := LOOT_SPAWNER_SCENE.instantiate() as Node2D
	if spawner == null:
		return
	# The shrine has already validated its own spot, so the spawner's own
	# walkability test - which asks the ChunkManager - would only refuse it.
	spawner.set("loot_id", maxi(1, secondary_objective_id + tier + 1))
	spawner.set("spawn_chance", 1.0)
	spawner.set("count_min", 1)
	spawner.set("count_max", 1 if tier < 2 else 2)
	spawner.set("rarity_min", int(TIERS[tier]["rarity_min"]))
	spawner.set("rarity_max", int(TIERS[tier]["rarity_max"]))
	spawner.set("require_walkable", false)
	spawner.set("scatter_radius", 40.0)
	spawner.global_position = global_position
	get_tree().current_scene.add_child.call_deferred(spawner)


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_pulse * 2.6)
	if _finished:
		var spent_colour := Color(0.42, 0.42, 0.46, 0.75)
		draw_arc(Vector2.ZERO, radius_px, 0.0, TAU, 64, spent_colour, 3.0, true)
		draw_circle(Vector2.ZERO, 20.0, Color(spent_colour.r, spent_colour.g, spent_colour.b, 0.25))
		return

	var gold := Color(0.98, 0.82, 0.36, 0.95)
	draw_circle(Vector2.ZERO, radius_px, Color(gold.r, gold.g, gold.b, 0.05))
	draw_arc(Vector2.ZERO, radius_px, 0.0, TAU, 64, Color(gold.r, gold.g, gold.b, 0.45), 4.0, true)
	draw_circle(Vector2.ZERO, 26.0 + pulse * 3.0, Color(gold.r, gold.g, gold.b, 0.22))

	# One filled pip per tier bought, one hollow per tier still on offer, so the
	# stake is readable at a glance without a panel.
	for index in range(TIERS.size()):
		var angle := -PI * 0.5 + TAU * float(index) / float(TIERS.size())
		var at := Vector2.RIGHT.rotated(angle) * (radius_px * 0.62)
		if index <= _tier:
			draw_circle(at, 13.0, gold)
		else:
			draw_arc(at, 13.0, 0.0, TAU, 24, Color(gold.r, gold.g, gold.b, 0.55), 3.0, true)

	if _tier >= 0:
		var text := "%s  •  %d%%" % [String(TIERS[_tier]["label"]), int(round(odds_for(_tier) * 100.0))]
		draw_string(ThemeDB.fallback_font, Vector2(-150.0, -radius_px - 26.0), text, HORIZONTAL_ALIGNMENT_CENTER, 300.0, 22, gold)
	else:
		draw_string(ThemeDB.fallback_font, Vector2(-150.0, -radius_px - 26.0), "WAGER SHRINE", HORIZONTAL_ALIGNMENT_CENTER, 300.0, 22, Color(gold.r, gold.g, gold.b, 0.8))
