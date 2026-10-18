extends "res://tools/dev/S10BossTelegraphPreview.gd"
## Controlled art evidence in actual Segment 2 Game. Never a human-played fight.
const VAULT_SCRIPT := preload("res://core/systems/world/CursedVault.gd")
const RITE_SCENE := preload("res://scenes/world/gates/ExitRite.tscn")
const RITUAL_SCRIPT := preload("res://core/systems/world/RitualInterference.gd")
const GRUNT_SCENE := "res://scenes/world/enemies/EnemyGrunt.tscn"
const MODES := [
	{"size": Vector2i(1280, 720), "reduced": false, "suffix": "normal"},
	{"size": Vector2i(960, 540), "reduced": false, "suffix": "small"},
	{"size": Vector2i(960, 540), "reduced": true, "suffix": "reduced"},
]
var _cm: ChunkManager
var _builder: SegmentProcBuilder
var _notes: Array[Dictionary] = []
var _panels := 0
var _minimum_visible_enemies := 0

func _enter_tree() -> void:
	_out = "res://.superpowers/sdd/2026-10-18-objective-visual-rework/risk-captures/"
	super._enter_tree()
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is ItemPickup:
			_lock_pickup.call_deferred(node))

func _run() -> void:
	get_tree().create_timer(140.0).timeout.connect(func() -> void:
		_fail("bounded capture timeout")
		_write_manifest(false)
		get_tree().quit(1))
	if DisplayServer.get_name() == "headless":
		_fail("native graphical renderer required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	AudioServer.set_bus_mute(0, true)
	StoryDirector.cards_override = 0
	Global.apply_save(SaveData.new())
	Global.debug_dev_mode = true
	Global.debug_dev_segment = false
	Global.debug_player_god_mode = true
	Global.debug_encounter_beats = false
	Global.selected_style_id = "ranged"
	Global.start_new_attempt()
	Global.attempt_segment = 2
	Global.attempt_world_seed = WORLD_SEED
	Global.attempt_opening_completed = true
	Global.attempt_opening_phase = 10
	Global.pending_augment_pick = false
	Global.pending_big_choice = false
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	SettingsManager.set_value(&"accessibility", &"combat_flash", "full", false)
	get_window().title = "Synthetic Ascension / controlled objective risk review"
	get_window().mode = Window.MODE_WINDOWED
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_size = PROJECT_VIEWPORT
	get_window().content_scale_factor = 1.0
	get_window().size = Vector2i(1280, 720)
	Engine.max_fps = 60
	_game = GAME.instantiate() as Node2D
	_game.get_node("Spawner").process_mode = Node.PROCESS_MODE_DISABLED
	_game.get_node("Player").disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	_game.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	_player = _game.get_node("Player") as Node2D
	_camera = _player.get_node("Camera2D") as Camera2D
	_cm = _game.get_node("ChunkManager") as ChunkManager
	await _settle_world()
	_quiet_tutorials()
	get_tree().paused = false
	FollowerFeedbackUI.call("_process", 10.0) # Expire unrelated entry notices too.
	_builder = get_tree().get_first_node_in_group(&"segment_proc_builder") as SegmentProcBuilder
	if _builder == null:
		_fail("missing actual Segment 2 builder")
		_write_manifest(false)
		get_tree().quit(1)
		return
	_builder.set_process(false)
	for group: StringName in [&"primary_objective", &"secondary_objective", &"wardstones", &"exit_rite"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			node.process_mode = Node.PROCESS_MODE_DISABLED
			if node is CanvasItem:
				node.visible = false
	_origin = _player.global_position
	var plan: Dictionary = _builder.get("_plan")
	_notes.append({"kind": "world", "attempt_seed": WORLD_SEED, "actual_plan_seed": plan.get("seed"), "presentation": "frozen actual Game, immortal player, controlled transitions; no played-fight claim"})
	var secondaries: Array = _builder.get("_secondary_objectives")
	var found_cache := false
	var found_building := false
	for secondary: Dictionary in secondaries:
		if String(secondary.get("type")) == "dangerous_alley_cache":
			found_cache = true
			await _capture_cache(secondary)
		elif String(secondary.get("type")) == "searchable_reward_building":
			found_building = true
			await _capture_building(secondary)
	if not found_cache or not found_building:
		_fail("actual plan must contain the seeded cache and searchable building")
	await _visit(_origin)
	_cm.set_process(false)
	_freeze(_game)
	for singleton: String in ["EnemySimulationScheduler", "EnemyIndex", "ThreatDirector", "EnemyWorld", "EnemyCombat", "EnemyStatus", "ProjectileManager", "HitFeel"]:
		var service := get_node_or_null("/root/" + singleton)
		if service != null:
			service.set_process(false)
			service.set_physics_process(false)
	_clear_risk_enemies()
	await _frames(2)
	await _capture_vaults()
	await _capture_last_chance()
	await _capture_ritual()
	if _panels != 8 or _captures.size() != 24:
		_fail("expected eight panels / 24 images; got %d / %d" % [_panels, _captures.size()])
	if SaveManager.debug_save_writes != _save_writes_before or SaveManager.current_save != null:
		_fail("unexpected profile write or selection")
	_write_manifest(_failures == 0 and _captures.size() == 24)
	print("ObjectiveRiskReworkPreview: captures=%d panels=%d complete=%s failures=%d save_writes=%d" % [_captures.size(), _panels, str(_failures == 0 and _captures.size() == 24), _failures, SaveManager.debug_save_writes - _save_writes_before])
	_clear_risk_enemies()
	if is_instance_valid(_game):
		_game.queue_free()
	await _frames(4)
	await RenderingServer.frame_post_draw
	get_tree().quit(1 if _failures else 0)

func _settle_world() -> void:
	for frame in range(360):
		await get_tree().process_frame
		if frame > 20 and _cm.debug_chunk_queue().is_empty() and _cm.pending_blocker_stage_count() == 0:
			return
	_fail("world streaming did not settle")

func _visit(at: Vector2) -> void:
	_cm.set_process(true)
	_player.global_position = at + Vector2(0, 700)
	_camera.position = Vector2(0, -700)
	_camera.reset_smoothing()
	_camera.force_update_scroll()
	await _settle_world()
	await _frames(20)
	_quiet_tutorials()
	get_tree().paused = false
	_cm.set_process(false)
	for pickup: Node in get_tree().get_nodes_in_group(GroundLootCap.ITEM_GROUP):
		_lock_pickup(pickup)
	for volume: Node in get_tree().get_nodes_in_group(&"indoor_volume"):
		(volume as Area2D).monitoring = false

func _lock_pickup(node: Node) -> void:
	if not is_instance_valid(node):
		return
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is Area2D:
		node.collision_mask = 0
		node.collision_layer = 0
		node.monitoring = false

func _aim(at: Vector2) -> void:
	_camera.position = at - _player.global_position
	_camera.reset_smoothing()
	_camera.force_update_scroll()

func _capture_cache(info: Dictionary) -> void:
	await _visit(info.get("world", Vector2.ZERO))
	var pickups: Array[Node2D] = []
	for node: Node in get_tree().get_nodes_in_group(GroundLootCap.ITEM_GROUP):
		if int(node.get("secondary_objective_id")) == int(info["id"]):
			pickups.append(node as Node2D)
	if pickups.size() != 2:
		_fail("seeded cache expected two genuine tagged pickups, found %d" % pickups.size())
	var at: Vector2 = pickups[0].global_position if not pickups.is_empty() else info.get("world", Vector2.ZERO)
	_player.global_position = at + Vector2(0, 170)
	_aim(at)
	RunEvents.objective_changed.emit("CACHE / ACTUAL GENERATED REWARDS", "Frozen real loose pickups at the planned alley; no chest staged")
	var note := "Actual plan id %d, chunk %s, role %s; %d genuine tagged pickups after streaming; player deliberately outside magnet radius" % [int(info["id"]), str(info.get("chunk")), String(_cm.get_chunk_role(info.get("chunk"))), pickups.size()]
	_notes.append({"kind": "cache", "id": info["id"], "pickups": pickups.size(), "note": note})
	await _capture_modes("cache-approach", note)

func _capture_building(info: Dictionary) -> void:
	await _visit(info.get("world", Vector2.ZERO))
	var room: IndoorVolume
	for volume: Node in get_tree().get_nodes_in_group(&"indoor_volume"):
		if int(volume.get("secondary_objective_id")) == int(info["id"]):
			room = volume as IndoorVolume
			break
	if room == null:
		_fail("actual planned building has no tagged IndoorVolume")
		return
	var center := room.global_position
	_player.global_position = center + Vector2(0, float(room.size_cells.y * room.cell_size_px) * 0.5 + 130)
	_aim(center)
	RunEvents.objective_changed.emit("SEARCHABLE BUILDING / APPROACH", "Actual seeded doorway and security invitation")
	await _capture_modes("building-exterior", "Actual generated parcel, roof and presentation at its real carved door")
	_player.global_position = center
	_aim(center)
	room.body_entered.emit(_player)
	await _frames(35)
	var ids: Array = (room.get("_encounter_enemy_ids") as Array).duplicate()
	if ids.is_empty():
		_fail("production building entry created no local security")
	for id: int in ids:
		var enemy := instance_from_id(id) as Node
		if is_instance_valid(enemy):
			_freeze(enemy)
	_minimum_visible_enemies = ids.size()
	RunEvents.objective_changed.emit("SEARCHABLE BUILDING / SECURITY", "Production entry and roof signal; local enemies frozen for review")
	await _capture_modes("building-interior", "Production body_entered signal fades roof and starts %d actual local enemies; frozen, not a played fight" % ids.size())
	_minimum_visible_enemies = 0
	for id: int in ids:
		var enemy := instance_from_id(id) as Node
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.call("take_damage", 1000000000.0, _player)
	for _frame in range(120):
		await get_tree().process_frame
		if bool(room.get("_encounter_completed")):
			break
	await _frames(5)
	var cleared := bool(room.get("_encounter_completed"))
	var reward_present := bool(room.call("_has_floor_reward"))
	if not cleared or not reward_present:
		_fail("actual lethal-damage building control did not clear and produce its floor reward")
	await _frames(65) # Let the real payout's pickup-delay visual unlock in every size.
	RunEvents.objective_changed.emit("SEARCHABLE BUILDING / CLEARED", "Actual lethal damage staged the clear and production floor payout")
	await _capture_modes("building-reward", "Actual production damage/death cleanup: security cleared=%s; real floor reward=%s; no human victory claim" % [str(cleared), str(reward_present)])
	_notes.append({"kind": "building", "id": info["id"], "actual_enemies": ids.size(), "actual_clear": cleared, "actual_reward": reward_present})
	BattleText.call("_process", 20.0)

func _capture_vaults() -> void:
	_stage = _new_stage()
	_reset_healing_control()
	var vaults: Array[CursedVault] = []
	for index in range(3):
		var vault := VAULT_SCRIPT.new() as CursedVault
		vault.position = _origin + Vector2(-500 + index * 500, 20)
		_stage.add_child(vault)
		vault.set_process(false)
		vault.set("_player", _player)
		vaults.append(vault)
		_label(Vector2(-665 + index * 500, -105), Vector2(330, 44), ["CLOSED", "HOLD 53% / STAGED", "OPENED / ACTUAL PAYOUT"][index], 22)
	var before := _game.get_children()
	_player.global_position = vaults[2].global_position + Vector2(0, 20)
	vaults[2]._process(vaults[2].open_time)
	await _frames(3)
	_adopt(before)
	await _frames(65)
	var paid := vaults[2].reward() as ItemPickup
	var locked := float(_player.call("healing_locked_seconds"))
	if not vaults[2].is_opened() or not _manifestation_reward(paid) or not is_equal_approx(locked, 45.0):
		_fail("genuine ordinary vault opening must pay Manifestation and bill 45 seconds healing")
	_player.global_position = vaults[1].global_position + Vector2(0, 40)
	vaults[1].set("_progress", 1.6)
	vaults[1].set("_holding", true)
	for vault: CursedVault in vaults:
		vault.call("_sync_presentation")
	_freeze(_stage)
	for enemy: Node in get_tree().get_nodes_in_group(&"enemies"):
		_freeze(enemy)
	_aim(_origin)
	_quiet_tutorials()
	get_tree().paused = false
	RunEvents.objective_changed.emit("VAULTS / CONTROLLED STATES", "Closed / staged 53% / genuine open, Manifestation payout and 45 s healing bill")
	_notes.append({"kind": "vaults", "working_fraction_staged": 1.6 / 3.0, "opened_via_actual_hold": vaults[2].is_opened(), "actual_manifestation_reward": _manifestation_reward(paid), "actual_healing_lock": locked, "encounter": "unchanged production request path, actual placement remains conditional"})
	await _capture_modes("vault-states", "Left closed and center 53% hold are controlled snapshots. Right genuinely opened through production hold; real Manifestation pickup and 45 s healing lock. No opened flag fabricated")
	_stage.queue_free()
	_clear_risk_enemies()
	await _frames(3)
	BattleText.call("_process", 20.0)

func _capture_last_chance() -> void:
	_stage = _new_stage()
	_reset_healing_control()
	var rite := RITE_SCENE.instantiate() as ExitRite
	rite.position = _origin
	_stage.add_child(rite)
	rite.set_revealed(true)
	rite.set_locked(false)
	rite.set("_hold", rite.hold_time * 0.85)
	rite.get("_progress_ledger").call("update_fraction", 0.85)
	for index in range(rite.safeguard_capacity()):
		rite.grant_safeguard(StringName("risk-preview:%d" % index))
	_player.global_position = _origin + Vector2(-95, 90)
	rite.call("_spawn_last_chance_vault")
	var vault := rite.get("_last_chance_vault") as CursedVault
	if vault == null:
		_fail("production Last Chance spawning failed")
		return
	var safeguards := rite.safeguard_count()
	_player.global_position = vault.global_position + Vector2(0, 24)
	vault.set("_player", _player)
	vault._process(0.0)
	rite.set("_player_inside", _player.global_position.distance_to(rite.global_position) <= rite.radius)
	rite.call("_refresh_world_art")
	vault.call("_sync_presentation")
	_freeze(_stage)
	_aim(_origin)
	_quiet_tutorials()
	get_tree().paused = false
	RunEvents.objective_changed.emit("LAST CHANCE / BEFORE COMMITMENT", "Actual edge placement; all safeguard and healing costs visible before opening")
	await _capture_modes("last-chance-before", "Rite 85%% hold/durable thirds staged; production spawner placed vault at radius+32 opposite approach. Actual %d safeguards; configured no encounter requests" % safeguards)
	var before := _game.get_children()
	var director := get_tree().get_first_node_in_group(&"encounter_director")
	var counters: Dictionary = director.call("balance_snapshot") if director != null else {}
	vault._process(vault.open_time)
	await _frames(3)
	_adopt(before)
	await _frames(65)
	var paid := vault.reward() as ItemPickup
	var locked := float(_player.call("healing_locked_seconds"))
	var counters_after: Dictionary = director.call("balance_snapshot") if director != null else {}
	if not vault.is_opened() or rite.safeguard_count() != 0 or not vault.cost_beats.is_empty() or not _manifestation_reward(paid) or not is_equal_approx(locked, 45.0):
		_fail("actual Last Chance must spend all safeguards, pay Manifestation and lock healing without encounter requests")
	if counters.get("counters", {}) != counters_after.get("counters", {}):
		_fail("Last Chance unexpectedly changed encounter request counters")
	rite.call("_refresh_world_art")
	vault.call("_sync_presentation")
	_freeze(_stage)
	_quiet_tutorials()
	get_tree().paused = false
	RunEvents.objective_changed.emit("LAST CHANCE / ACTUAL SACRIFICE", "Production opening drained safeguards and paid Manifestation; 45 s healing sealed")
	await _capture_modes("last-chance-after", "Genuine production hold/open paid Manifestation, took all %d actual safeguards (now %d), billed %.0f s healing, and made no encounter request" % [safeguards, rite.safeguard_count(), locked])
	_notes.append({"kind": "last_chance", "rite_fraction_staged": 0.85, "actual_safeguards_before": safeguards, "actual_safeguards_after": rite.safeguard_count(), "actual_open": vault.is_opened(), "actual_manifestation_reward": _manifestation_reward(paid), "actual_healing_lock": locked, "cost_beats": vault.cost_beats, "encounter_counters_unchanged": counters.get("counters", {}) == counters_after.get("counters", {})})
	_stage.queue_free()
	await _frames(3)
	BattleText.call("_process", 20.0)

func _capture_ritual() -> void:
	_stage = _new_stage()
	var ritual := RITUAL_SCRIPT.new() as RitualInterference
	ritual.position = _origin
	_stage.add_child(ritual)
	ritual.set_process(false)
	_player.global_position = _origin + Vector2(-105, 100)
	_aim(_origin)
	var death_at := _origin + Vector2(145, 80)
	var spawner := _game.get_node("Spawner") as EnemySpawner
	ritual.setup(spawner, false)
	var actor := spawner.spawn_beat_member(GRUNT_SCENE, death_at, false) as Node2D
	await _frames(3)
	var actual_pending := false
	if is_instance_valid(actor):
		_freeze(actor)
		actor.call("take_damage", 1000000000.0, _player)
		actual_pending = ritual.pending() > 0
	if actual_pending:
		ritual._process(0.8)
	else:
		# Explicitly labelled fallback: inspect the renderer without inventing a kill.
		var pending_entries: Array = ritual.get("_pending")
		pending_entries.append({"scene": GRUNT_SCENE, "pos": death_at, "t": 0.8, "enemy_id": "enemy_grunt"})
	_freeze(_stage)
	ritual.queue_redraw()
	_quiet_tutorials()
	get_tree().paused = false
	RunEvents.objective_changed.emit("RITUAL INTERFERENCE / HAZARD", "Actual death queued return; frozen halfway" if actual_pending else "Controlled pending fixture; live death producer not verified in frozen staging")
	var note := "Actual production lethal damage queued a corpse; frozen at 0.8 / 1.6 s return delay" if actual_pending else "Controlled pending-entry fixture at 0.8 / 1.6 s; actual frozen producer did not queue a corpse. No genuine kill/revival claim"
	_notes.append({"kind": "ritual", "actual_death_pending": actual_pending, "pending": ritual.pending(), "note": note})
	await _capture_modes("ritual-pending", note)

func _capture_modes(panel: String, note: String) -> void:
	_panels += 1
	for mode: Dictionary in MODES:
		get_window().size = mode["size"]
		SettingsManager.set_value(&"accessibility", &"reduced_motion", mode["reduced"], false)
		SettingsManager.set_value(&"accessibility", &"combat_flash", "off" if mode["reduced"] else "full", false)
		for ritual: Node in get_tree().get_nodes_in_group(&"ritual_interference"):
			ritual.set("_reduced_motion", mode["reduced"])
			ritual.queue_redraw()
		_camera.force_update_scroll()
		await _frames(4)
		_publish_enemies()
		await RenderingServer.frame_post_draw
		var filename := "%s-%s.png" % [panel, mode["suffix"]]
		var pixels := get_viewport().get_texture().get_image()
		if pixels.get_size() != mode["size"] or pixels.save_png(_out.path_join(filename)) != OK:
			_fail("capture failed " + filename)
		_captures.append({"file": filename, "panel": panel, "window": str(mode["size"]), "reduced_motion": mode["reduced"], "combat_flash": "off" if mode["reduced"] else "full", "camera_center": str(_camera.global_position), "player_position": str(_player.global_position), "note": note})
		print("ObjectiveRiskReworkPreview -> ", filename)
	# Retain genuine current-panel reward notices in all three views, then age
	# only their cosmetic presentation before the unrelated next composition.
	FollowerFeedbackUI.call("_process", 10.0)

func _publish_enemies() -> void:
	var proxy := _game.get_node_or_null("EnemyProxyRoot")
	if proxy != null and proxy.get("renderer") != null:
		var drawn := int(proxy.get("renderer").call("publish"))
		if drawn < _minimum_visible_enemies:
			_fail("actual security must render: expected %d, published %d" % [_minimum_visible_enemies, drawn])

func _manifestation_reward(pickup: ItemPickup) -> bool:
	return is_instance_valid(pickup) and pickup.item_instance != null and pickup.item_instance.has_manifestation()

func _reset_healing_control() -> void:
	# Separate genuine cost controls start unlocked; this is explicit staging.
	_player.set("_healing_lock_left", 0.0)
	_player.call("_on_healing_lock_expired")

func _clear_risk_enemies() -> void:
	for enemy: Node in get_tree().get_nodes_in_group(&"enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()
	EnemyWorld.clear_world()

func _write_manifest(complete: bool) -> void:
	var manifest := {"complete": complete, "scene": "res://scenes/game.tscn", "segment": 2, "attempt_world_seed": WORLD_SEED, "presentation": "Controlled frozen actual Game; immortal player; original omissions preview preserved; no human-played fight claim", "scope": "Eight world risk panels, each normal/small/reduced+flashes-off", "captures": _captures, "notes": _notes, "panels": _panels, "save_writes": SaveManager.debug_save_writes - _save_writes_before, "failures": _failures, "independent_cost_controls": "Healing lock explicitly reset by staging before each actual production vault open; no natural-expiry claim"}
	var file := FileAccess.open(_out.path_join("manifest.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(manifest, "\t"))
	else:
		_fail("could not write capture manifest")

func _fail(message: String) -> void:
	_failures += 1
	push_error("ObjectiveRiskReworkPreview: " + message)
