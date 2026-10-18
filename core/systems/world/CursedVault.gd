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
const WORLD_ART := preload("res://core/systems/world/objectives/ObjectiveWorldArt.gd")
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
## The channel's last drawn fraction. Static physical states and signs latch
## independently below; unchanged idle state never requests another repaint.
## -1.0 is "never painted": the first _process always repaints.
var _drawn_progress := -1.0
var _opened := false
var _announced := false
var _player: Node2D = null
var _reward: Node = null
var _holding := false
var _paused := false
var _art: Sprite2D
var _prompt: Label
var _presentation_key := ""
var _paid_safeguards := 0
var _fixtures: VaultFixtures

class VaultFixtures extends Node2D:
	var channel := 0.0
	var spent := false
	var draining := false
	var paused := false
	var sacrifices := 0
	var denies_healing := false
	func _draw() -> void:
		if not spent:
			for side in [-1.0, 1.0]:
				var x: float = float(side) * (24.0 + 11.0 * channel)
				draw_line(Vector2(x, -15), Vector2(x, 9), Color(0.68, 0.61, 0.43), 4.0, true)
			if draining:
				draw_polyline(PackedVector2Array([Vector2(-7, 32), Vector2(0, 39), Vector2(7, 32)]), Color(0.87, 0.72, 0.52), 2.0, true)
			elif paused:
				for x in [-4.0, 4.0]:
					draw_line(Vector2(x, 30), Vector2(x, 39), Color(0.77, 0.74, 0.64), 2.5, true)
			if denies_healing:
				var warning := Vector2(0, 50)
				draw_circle(warning, 11.0, Color(0.06, 0.05, 0.04, 0.9))
				draw_line(warning + Vector2(-6, 0), warning + Vector2(6, 0), Color(0.84, 0.72, 0.54), 3.0, true)
				draw_line(warning + Vector2(0, -6), warning + Vector2(0, 6), Color(0.84, 0.72, 0.54), 3.0, true)
				draw_line(warning + Vector2(-8, 8), warning + Vector2(8, -8), Color(0.08, 0.065, 0.045), 5.0, true)
				draw_line(warning + Vector2(-8, 8), warning + Vector2(8, -8), Color(0.9, 0.56, 0.37), 2.0, true)
		# Same pointed shields as the Rite; spent sacrifices leave broken sockets.
		for index in range(sacrifices):
			var at := Vector2((float(index) - float(sacrifices - 1) * 0.5) * 13.0, -43.0)
			var shield := PackedVector2Array([at + Vector2(-8, -9) * 0.65, at + Vector2(8, -9) * 0.65, at + Vector2(7, 1) * 0.65, at + Vector2(0, 10) * 0.65, at + Vector2(-7, 1) * 0.65])
			draw_colored_polygon(shield, Color(0.09, 0.12, 0.10, 0.9) if spent else Color(0.64, 0.75, 0.67, 0.94))
			draw_polyline(PackedVector2Array([shield[0], shield[1], shield[2], shield[3], shield[4], shield[0]]), Color(0.49, 0.61, 0.53, 0.80), 1.5, true)
			if spent:
				draw_line(at + Vector2(-6, 5), at + Vector2(6, -5), Color(0.05, 0.06, 0.045), 4.0, true)
				draw_line(at + Vector2(-6, 5), at + Vector2(6, -5), Color(0.72, 0.68, 0.51, 0.8), 1.0, true)
			else:
				draw_line(at + Vector2(0, -5) * 0.65, at + Vector2(0, 3) * 0.65, Color(0.16, 0.23, 0.19, 0.94), 1.5, true)


func _ready() -> void:
	add_to_group(&"cursed_vault")
	z_index = 5
	set_process(true)
	_art = WORLD_ART.install(self, "vault", 76.0)
	_fixtures = VaultFixtures.new()
	_fixtures.name = "VaultFasteners"
	_fixtures.z_as_relative = false
	_fixtures.z_index = -10
	add_child(_fixtures)
	_prompt = Label.new()
	_prompt.name = "VaultCommitment"
	_prompt.position = Vector2(-190, 82)
	_prompt.size = Vector2(380, 150)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_color", Color(0.9, 0.86, 0.75))
	_prompt.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.05, 0.95))
	_prompt.add_theme_constant_override("outline_size", 5)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)
	_sync_presentation()


func _process(delta: float) -> void:
	if _opened:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
		if _player == null:
			_holding = false
			_paused = true
			_sync_presentation()
			return
	if bool(_player.get("is_dead")):
		_holding = false
		_paused = true
		_sync_presentation()
		return
	_paused = false
	var distance := global_position.distance_to(_player.global_position)
	_holding = distance <= open_radius
	if not _announced and distance <= approach_radius:
		announce()
	if distance <= open_radius:
		_progress = minf(_progress + delta, open_time)
		if _progress >= open_time:
			_open()
	elif _progress > 0.0:
		# Stepping out bleeds progress rather than voiding it.
		_progress = maxf(0.0, _progress - delta * 0.5)
	_sync_presentation()
	if _progress != _drawn_progress:
		# The bleed's last step lands exactly on 0.0 while _drawn_progress is
		# still positive, so the frame that wipes the ring is painted too.
		_drawn_progress = _progress
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
	_paid_safeguards = int(billed.get("safeguards", 0))
	_sync_presentation()
	if PerformanceFlightRecorder != null and bool(PerformanceFlightRecorder.get("enabled")):
		var details := {"rarity": reward_rarity_min}
		details.merge(billed)
		PerformanceFlightRecorder.record_event(&"encounter", &"vault_opened", details)
	opened.emit(self)
	_drawn_progress = _progress
	queue_redraw()
	# Nothing here moves again: _opened is latched, _progress is frozen, and the
	# rest of _draw reads exports fixed before the vault entered the tree.
	set_process(false)


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


func presentation_state() -> String:
	if _opened:
		return "spent"
	if _paused and _progress > 0.0:
		return "paused"
	if _holding:
		return "working"
	return "draining" if _progress > 0.0 else "dormant"


## This is the same configured bill _apply_cost pays, shown before commitment.
func commitment_lines() -> PackedStringArray:
	if _opened:
		return PackedStringArray(["VAULT EMPTY / SPENT"])
	var lines := PackedStringArray(["Guaranteed Manifestation" if guarantee_manifestation else "High-rarity equipment"])
	var prices := PackedStringArray()
	if cost_all_safeguards:
		prices.append("Spends all %d safeguards" % _safeguard_count())
	if not cost_beats.is_empty():
		if cost_beats == [&"hunter", &"charger_wedge"]:
			prices.append("Calls Hunter + wedge")
		else:
			prices.append("%d encounter requests" % cost_beats.size())
	elif cost_all_safeguards:
		prices.append("No extra encounter")
	if cost_heal_lock_sec > 0.0:
		prices.append("No healing for %d s" % int(round(cost_heal_lock_sec)))
	lines.append_array(prices)
	if _paused and _progress > 0.0:
		lines.append("Opening paused")
	else:
		lines.append("Opening %d%% · hold inside" % int(progress() * 100.0) if _holding else ("Opening decays outside" if _progress > 0.0 else "Stand inside · hold %.0f s" % open_time))
	return lines


func _safeguard_count() -> int:
	if not is_inside_tree():
		return 0
	var rite := _find_rite()
	return int(rite.call("safeguard_count")) if rite != null and rite.has_method("safeguard_count") else 0


func _sync_presentation() -> void:
	if _art == null or _prompt == null:
		return
	var near := _player != null and is_instance_valid(_player) and global_position.distance_squared_to(_player.global_position) <= approach_radius * approach_radius
	var text := "\n".join(commitment_lines())
	var state := presentation_state()
	var key := "%s|%s|%s|%d" % [state, text, near, int(progress() * 64.0)]
	if key == _presentation_key:
		return
	_presentation_key = key
	_art.call("set_state", state, progress())
	_fixtures.channel = progress()
	_fixtures.spent = _opened
	_fixtures.draining = state == "draining"
	_fixtures.paused = state == "paused"
	_fixtures.denies_healing = cost_heal_lock_sec > 0.0
	_fixtures.sacrifices = (_paid_safeguards if _opened else _safeguard_count()) if cost_all_safeguards else 0
	_fixtures.queue_redraw()
	_prompt.text = text
	_prompt.visible = near
	queue_redraw()


func _draw() -> void:
	if not _opened:
		WORLD_ART.draw_boundary(self, Vector2.ZERO, open_radius, Color(0.68, 0.56, 0.48, 0.7), progress())
	# Fallback mechanical block remains useful before the painted family imports.
	if _art == null or _art.texture == null:
		_draw_vault_body()


func _draw_vault_body() -> void:
	draw_rect(Rect2(-46, -29, 92, 66), Color(0.035, 0.03, 0.025, 0.45))
	draw_rect(Rect2(-40, -28, 80, 56), Color(0.32, 0.33, 0.3))
	draw_rect(Rect2(-31, -20, 62, 37), Color(0.07, 0.065, 0.06))
	if _opened:
		draw_rect(Rect2(-34, -46, 68, 23), Color(0.44, 0.44, 0.37))
		draw_line(Vector2(-22, 10), Vector2(22, 10), Color(0.19, 0.18, 0.15), 2.0, true)
	else:
		draw_rect(Rect2(-32, -21, 64, 40), Color(0.43, 0.44, 0.38))
		draw_line(Vector2(-27, -1), Vector2(27, -1), Color(0.17, 0.17, 0.14), 2.0, true)
		draw_rect(Rect2(-6, -8, 12, 16), Color(0.67, 0.61, 0.42))
		draw_circle(Vector2(0, -1), 2, Color(0.08, 0.07, 0.06))
