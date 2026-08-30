extends Node2D
class_name CursedVault

## The run's one deliberate "fuck it, let's do this" (roadmap Phase 2.5, §7
## 12-15 min): an off-route vault with a visible reward - a guaranteed
## Manifestation on a high-rarity item - and an explicit cost. Opening is a
## choice, not an ambush: the player has to stand inside it for open_time
## while the cost is announced, and the moment it opens the world answers
## with a hunter and a wedge. Built from script (zone + drawing) so it needs
## no scene; the segment builder places one at a reward chunk.

signal opened(vault: CursedVault)

const PICKUP_SCENE := preload("res://scenes/world/pickups/ItemPickup.tscn")
const COLOUR := Color(0.85, 0.42, 0.95, 1.0)
## Emphasis of the approach popup (BattleText.popup's entry_scale).
const ANNOUNCE_POPUP_SCALE: float = 1.3
## How long the approach line stays on the tip channel.
const ANNOUNCE_TIP_SECONDS: float = 4.0

@export var approach_radius := 320.0
@export var open_radius := 64.0
@export var open_time := 3.0
@export var reward_rarity_min := 4
@export var reward_rarity_max := 5
@export var guarantee_manifestation := true
## Beats requested through the EncounterDirector the moment the vault opens.
@export var cost_beats: Array[StringName] = [&"hunter", &"charger_wedge"]
## The rite's last-chance vault (plan 2.8): opening it takes every safeguard
## the Exit Rite holds. The rite is found up the parent chain (it spawns the
## vault as its child), then by group.
@export var cost_all_safeguards: bool = false
## Healing is sealed for this long once the vault opens (plan 2.5). The
## player owns the lock; one without it simply pays the other costs.
@export var cost_heal_lock_sec: float = 45.0
## What the approach popup says. The rite's last chance (plan 2.8) is this
## vault under another name, so the vault owns its announce - one popup, one
## line - and nothing of its own overdraws what its spawner said.
@export var announce_label: String = "CURSED VAULT"
## The line's opening - what the vault is and pays - ahead of the costs.
@export var announce_line: String = "Stand in the vault to open it: a guaranteed Manifestation."

var _progress := 0.0
var _opened := false
var _announced := false
var _player: Node2D = null
var _reward: Node = null


func _ready() -> void:
	add_to_group(&"cursed_vault")
	z_index = 5
	set_process(true)


func _process(delta: float) -> void:
	if _opened:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
		if _player == null:
			return
	if bool(_player.get("is_dead")):
		return
	var distance := global_position.distance_to(_player.global_position)
	if not _announced and distance <= approach_radius:
		announce()
	if distance <= open_radius:
		_progress = minf(_progress + delta, open_time)
		if _progress >= open_time:
			_open()
	elif _progress > 0.0:
		# Stepping out bleeds progress rather than voiding it.
		_progress = maxf(0.0, _progress - delta * 0.5)
	queue_redraw()


func progress() -> float:
	return clampf(_progress / maxf(open_time, 0.001), 0.0, 1.0)


func is_opened() -> bool:
	return _opened


func reward() -> Node:
	return _reward


## Announces the vault once: the approach check calls it, and a spawner that
## wants the moment marked at once (the rite's last chance) calls it first.
## Later calls say nothing.
func announce() -> void:
	if _announced:
		return
	_announced = true
	if BattleText != null and BattleText.has_method("popup"):
		BattleText.popup(global_position, announce_label, COLOUR, ANNOUNCE_POPUP_SCALE)
	if RunEvents != null and RunEvents.has_signal("tutorial_tip"):
		RunEvents.tutorial_tip.emit(announcement(), ANNOUNCE_TIP_SECONDS)


## The "fuck it" moment is only a decision if the whole bill is on the sign.
func announcement() -> String:
	var costs := PackedStringArray()
	if not cost_beats.is_empty():
		costs.append("Something will come for you.")
	if cost_all_safeguards:
		costs.append("It takes every safeguard.")
	if cost_heal_lock_sec > 0.0:
		costs.append("No healing for %ds." % int(round(cost_heal_lock_sec)))
	if costs.is_empty():
		return announce_line
	return announce_line + " " + " ".join(costs)


func _open() -> void:
	_opened = true
	_reward = _spawn_reward()
	var billed := _apply_cost()
	if PerformanceFlightRecorder != null and bool(PerformanceFlightRecorder.get("enabled")):
		var details := {"rarity": reward_rarity_min}
		details.merge(billed)
		PerformanceFlightRecorder.record_event(&"encounter", &"vault_opened", details)
	opened.emit(self)
	queue_redraw()


func _spawn_reward() -> Node:
	if Global == null or Global.item_db.is_empty():
		return null
	var rng: RandomNumberGenerator = Global._rng
	var keys: Array = Global.item_db.keys()
	var data: ItemData = null
	for _attempt in range(8):
		data = Global.get_item_data(str(Global.pick_weighted_item_id(rng, keys)))
		if data != null and int(data.equip_slot) >= 0:
			break
	if data == null:
		return null
	var context := Global.build_item_drop_context(reward_rarity_min, reward_rarity_max, &"vault", 1)
	var inst: ItemInstance = ItemGenerator.create_instance(data, context, rng)
	if inst == null:
		return null
	if guarantee_manifestation and not inst.has_manifestation():
		var pool: Array[ManifestationDef] = ManifestationCatalog.pool_for_slot(int(data.equip_slot))
		if not pool.is_empty():
			inst.manifestation_id = pool[rng.randi_range(0, pool.size() - 1)].id
	var pickup := PICKUP_SCENE.instantiate() as ItemPickup
	if pickup == null:
		return null
	pickup.item_instance = inst
	pickup.item_id = str(data.id)
	pickup.amount = 1
	pickup.pickup_delay = 0.4
	pickup.is_exploration_loot = true
	pickup.global_position = global_position + Vector2(0.0, -24.0)
	var host: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	host.add_child(pickup)
	return pickup


## Bills every configured cost and says what was taken, for the recorder.
func _apply_cost() -> Dictionary:
	if BattleText != null and BattleText.has_method("popup"):
		BattleText.popup(global_position, "THE VAULT ANSWERS", Color(1.0, 0.45, 0.35, 1.0), 1.3)
	var billed := {"beats": 0, "safeguards": 0, "heal_lock_sec": 0.0}
	var director := get_tree().get_first_node_in_group(&"encounter_director")
	if director != null and director.has_method("try_spawn_beat"):
		for id in cost_beats:
			director.call("try_spawn_beat", id)
			billed["beats"] = int(billed["beats"]) + 1
	if cost_all_safeguards:
		billed["safeguards"] = _drain_rite_safeguards()
	if cost_heal_lock_sec > 0.0 and _player != null and is_instance_valid(_player) and _player.has_method("lock_healing"):
		_player.call("lock_healing", cost_heal_lock_sec, &"cursed_vault")
		billed["heal_lock_sec"] = cost_heal_lock_sec
	return billed


func _drain_rite_safeguards() -> int:
	var rite := _find_rite()
	if rite == null:
		return 0
	var drained := 0
	if rite.has_method("drain_safeguards"):
		drained = int(rite.call("drain_safeguards", &"cursed_vault"))
	elif rite.has_method("consume_safeguard"):
		# Older rite: spend the buffer one charge at a time (bounded, so a
		# rite that never says no cannot hang the frame).
		for _attempt in range(64):
			if not bool(rite.call("consume_safeguard")):
				break
			drained += 1
	if drained > 0 and BattleText != null and BattleText.has_method("popup"):
		BattleText.popup(global_position + Vector2(0.0, 22.0), "SAFEGUARDS TAKEN", Color(1.0, 0.91, 0.62, 1.0), 1.2)
	return drained


func _find_rite() -> Node:
	var node := get_parent()
	while node != null:
		if node.is_in_group(&"exit_rite"):
			return node
		node = node.get_parent()
	return get_tree().get_first_node_in_group(&"exit_rite")


func _draw() -> void:
	var alpha := 0.18 if not _opened else 0.06
	draw_arc(Vector2.ZERO, open_radius, 0.0, TAU, 48, Color(COLOUR.r, COLOUR.g, COLOUR.b, alpha + 0.3), 2.0, true)
	draw_circle(Vector2.ZERO, open_radius, Color(COLOUR.r, COLOUR.g, COLOUR.b, alpha))
	if not _opened and _progress > 0.0:
		draw_arc(Vector2.ZERO, open_radius + 8.0, -PI * 0.5, -PI * 0.5 + TAU * progress(), 48, COLOUR, 4.0, true)
	# LAST CHANCE tell: the rite's safeguard pips, drawn inside the vault - it
	# eats them. Static; nothing here pulses.
	if cost_all_safeguards:
		var pip_alpha := 0.35 if _opened else 0.95
		for index in range(3):
			var pip := Vector2.from_angle(deg_to_rad(-90.0 + 120.0 * float(index))) * (open_radius * 0.45)
			draw_circle(pip, 4.5, Color(0.12, 0.10, 0.07, pip_alpha * 0.9))
			draw_circle(pip, 2.7, Color(1.0, 0.91, 0.62, pip_alpha))
