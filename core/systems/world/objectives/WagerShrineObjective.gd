extends Node2D
class_name WagerShrineObjective

const WorldArt := preload("res://core/systems/world/objectives/ObjectiveWorldArt.gd")
var objective_art: Sprite2D

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
## Every tier's band rides the segment's rarity cap (`over_cap_min` /
## `over_cap_max` above `Global.rarity_soft_cap_for(1)`) instead of fixed
## R3-R5 / R5-R7 / R7-R10, so the shrine stops being the segment-1 source
## of R7+ and keeps paying more as the run goes deeper (loot loop pass L5).
const TIERS: Array[Dictionary] = [
	{"stake": 20, "over_cap_min": 0, "over_cap_max": 2, "base_odds": 0.85, "label": "OFFERING"},
	{"stake": 35, "over_cap_min": 1, "over_cap_max": 3, "base_odds": 0.62, "label": "PLEDGE"},
	{"stake": 55, "over_cap_min": 2, "over_cap_max": 4, "base_odds": 0.40, "label": "COVENANT"},
]


## Followers a tier costs at the current segment: the authored stake on the
## run's stage scale (follower economy audit 2026-10-04, P4), so 20 / 35 / 55
## through segment 2 and x3 by segment 10, where a flat 110 had become free.
static func tier_stake(tier: int) -> int:
	if tier < 0 or tier >= TIERS.size():
		return 0
	var market_multiplier: float = Global.market_scale() if Global != null else 1.0
	return int(round(float(TIERS[tier]["stake"]) * market_multiplier))


## The rarity band a tier pays at the current segment (x = min, y = max).
static func tier_band(tier: int) -> Vector2i:
	if tier < 0 or tier >= TIERS.size():
		return Vector2i.ZERO
	var entry: Dictionary = TIERS[tier]
	if entry.has("rarity_min"):
		return Vector2i(int(entry["rarity_min"]), int(entry["rarity_max"]))
	var cap: int = Global.rarity_soft_cap_for(1) if Global != null else 2
	return Vector2i(cap + int(entry.get("over_cap_min", 2)), cap + int(entry.get("over_cap_max", 4)))

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
var _refused_tier: Dictionary = {}
var _collection_lock: WagerLock


## The collection tray is physically shut after settlement, even in a frozen
## grayscale frame. This low fixture never covers an actor's body or feet.
class WagerLock extends Node2D:
	var closed := false

	func set_closed(next_closed: bool) -> void:
		if closed == next_closed:
			return
		closed = next_closed
		queue_redraw()

	func _draw() -> void:
		if not closed:
			return
		draw_rect(Rect2(-30.0, 5.0, 60.0, 17.0), Color(0.16, 0.17, 0.16, 0.96))
		draw_rect(Rect2(-27.0, 7.0, 54.0, 10.0), Color(0.47, 0.45, 0.36, 0.98))
		draw_line(Vector2(-22, 12), Vector2(22, 12), Color(0.23, 0.24, 0.21), 3.0, true)
		for side in [-1.0, 1.0]:
			draw_line(Vector2(side * 20.0, 3.0), Vector2(side * 20.0, 21.0), Color(0.66, 0.61, 0.46), 4.0, true)


func configure(objective_id: int) -> void:
	secondary_objective_id = objective_id


func _ready() -> void:
	add_to_group(&"secondary_objective")
	objective_art = WorldArt.install(self, "wager", 120.0)
	_collection_lock = WagerLock.new()
	_collection_lock.name = "WagerLock"
	_collection_lock.z_as_relative = false
	_collection_lock.z_index = -1
	add_child(_collection_lock)
	update_presentation()
	z_index = 34
	set_process(true)


func _process(delta: float) -> void:
	_pulse += delta
	update_presentation()
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
		update_presentation()
		queue_redraw()
		return

	# Stepping out is how you settle. That is the whole mechanism: there is no
	# confirm button, so the decision is made with your feet while the district
	# is still moving around you.
	if _tier >= 0:
		_settle()
	elif _dwell > 0.0:
		_dwell = 0.0
		update_presentation()
		queue_redraw()


## These observers may be called repeatedly by rendering or a paused preview.
## Only _try_raise_stake() spends Followers; display never advances the dwell.
func purchase_fraction() -> float:
	if _finished or _tier + 1 >= TIERS.size():
		return 0.0
	return clampf((_dwell - seconds_per_tier * float(_tier + 1)) / maxf(0.001, seconds_per_tier), 0.0, 1.0)


func update_presentation() -> void:
	var next_tier := _tier + 1
	var occupied := _player != null and is_instance_valid(_player) and not bool(_player.get("is_dead")) and _player.global_position.distance_squared_to(global_position) <= radius_px * radius_px
	var purchasing := occupied and next_tier < TIERS.size() and _dwell > 0.0 and _can_afford(tier_stake(next_tier)) and not _refused_tier.has(next_tier)
	if objective_art != null:
		objective_art.call("set_state", "spent" if _finished else ("working" if purchasing else "dormant"), purchase_fraction())
	if _collection_lock != null:
		_collection_lock.set_closed(_finished)


func presentation_lines() -> PackedStringArray:
	if _finished:
		return PackedStringArray(["WAGER SETTLED", "%d Followers paid • resolved" % _spent])
	var lines := PackedStringArray()
	if _tier >= 0:
		lines.append("%s %d/%d • %d%%" % [String(TIERS[_tier]["label"]), _tier + 1, TIERS.size(), int(round(odds_for(_tier) * 100.0))])
	else:
		lines.append("WAGER • NO STAKE")
	var next_tier := _tier + 1
	if next_tier < TIERS.size():
		var cost := tier_stake(next_tier)
		if not _can_afford(cost):
			lines.append("Next %d refused • reconstruction reserve" % cost if _refused_tier.has(next_tier) else "Next %d unavailable • reconstruction reserve" % cost)
		else:
			var remaining := maxf(0.0, seconds_per_tier * float(next_tier + 1) - _dwell)
			lines.append("Next %d Followers • hold %.1fs" % [cost, remaining])
	else:
		lines.append("Maximum stake reached")
	if _tier >= 0:
		lines.append("Step out to settle • %d Followers paid" % _spent)
	elif not _can_afford(tier_stake(0)):
		lines.append("More Followers needed before staking")
	else:
		lines.append("Stand to pay • step out to cancel")
	return lines


func _try_raise_stake() -> void:
	var next_tier: int = _tier + 1
	if next_tier >= TIERS.size():
		return
	if _dwell < seconds_per_tier * float(next_tier + 1):
		return
	var stake: int = tier_stake(next_tier)
	if not _can_afford(stake):
		# Held at the last tier they could pay for, and said so - silently
		# refusing to escalate reads as the shrine being broken.
		#
		# Once, not every frame: _dwell is clamped back to the threshold here,
		# so the next frame crosses it again and the whole thing repeated at
		# frame rate, flooding the callout buffer and drowning out every combat
		# number on screen.
		if not _refused_tier.has(next_tier):
			_refused_tier[next_tier] = true
			if BattleText != null and BattleText.has_method("popup"):
				BattleText.popup(global_position, "NOT ENOUGH BELIEF", Color(0.85, 0.55, 0.35, 1.0), 1.15)
		_dwell = seconds_per_tier * float(next_tier + 1)
		return
	_refused_tier.erase(next_tier)
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
	# The stake may never leave a balance a death could not reconstruct from.
	if Global.has_method("reconstruction_survivable"):
		return bool(Global.reconstruction_survivable(int(Global.followers) - stake))
	return Global.followers - stake > 0


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
	update_presentation()
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
	var band := tier_band(tier)
	spawner.set("rarity_min", band.x)
	spawner.set("rarity_max", band.y)
	spawner.set("require_walkable", false)
	spawner.set("scatter_radius", 40.0)
	spawner.global_position = global_position
	get_tree().current_scene.add_child.call_deferred(spawner)


func _draw() -> void:
	var gold := Color(0.78, 0.7, 0.48, 0.84)
	if not _finished:
		WorldArt.draw_boundary(self, Vector2.ZERO, radius_px, gold)
		for index in range(TIERS.size()):
			var angle := -PI * 0.5 + TAU * float(index) / float(TIERS.size())
			var at := Vector2.from_angle(angle) * (radius_px + 10.0)
			draw_circle(at, 7.0, Color(0.06, 0.055, 0.04, 0.9))
			draw_arc(at, 6.0, 0.0, TAU, 20, gold, 1.5, true)
			if index <= _tier:
				draw_rect(Rect2(at - Vector2(3.5, 3.5), Vector2(7.0, 7.0)), gold)
			elif index == _tier + 1:
				var fraction := purchase_fraction()
				if not _can_afford(tier_stake(index)):
					draw_line(at + Vector2(-6, 6), at + Vector2(6, -6), gold, 2.5, true)
				elif fraction > 0.0:
					draw_arc(at, 10.0, -PI * 0.5, -PI * 0.5 + TAU * fraction, 24, gold, 2.5, true)
	var lines := presentation_lines()
	# Keep all three lines above the far-side purchase pip, including the
	# crucial settlement instruction when that pip is partly filled.
	var first_y := -radius_px - 76.0 if not _finished else -radius_px - 17.0
	for index in range(lines.size()):
		var at := Vector2(-220.0, first_y + float(index) * 20.0)
		var font_size := 18 if index == 0 else 15
		var color := Color(0.58, 0.58, 0.51, 0.75) if _finished else gold
		draw_string_outline(ThemeDB.fallback_font, at, lines[index], HORIZONTAL_ALIGNMENT_CENTER, 440.0, font_size, 4, Color(0.025, 0.02, 0.03, 0.9))
		draw_string(ThemeDB.fallback_font, at, lines[index], HORIZONTAL_ALIGNMENT_CENTER, 440.0, font_size, color)
