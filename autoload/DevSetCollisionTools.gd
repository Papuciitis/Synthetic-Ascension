extends CanvasLayer

## Developer ACTION SERVICE. It owns no UI of its own.
##
## It used to also build an 860 px panel of about forty-five buttons - which was
## never shown, because nothing ever called _build_panel(). Every real dev
## control lives in the developer console (PerformanceOverlay), which calls into
## this script; the panel was a second, invisible copy of the same buttons that
## still had to be kept in sync by hand.

const WALL_SCENE: PackedScene = preload("res://scenes/world/cover/CoverFull.tscn")
const WINDOW_SCENE: PackedScene = preload("res://scenes/world/cover/CoverWindow.tscn")
const FENCE_SCENE: PackedScene = preload("res://scenes/world/fence/FenceBlock.tscn")
const HALF_COVER_SCENE: PackedScene = preload("res://scenes/world/cover/CoverHalf.tscn")
const BULLET_SCENE: PackedScene = preload("res://scenes/world/combat/RangedBullet.tscn")

var _fixture: Node2D = null

func _ready() -> void:
	layer = 120
	set_process(false)

func _process(_delta: float) -> void:
	pass

func grant_set(set_id: StringName, pieces: int) -> void:
	if Global == null or Global.run_inventory == null:
		return
	for slot in range(Inventory.STAT_SLOT_COUNT):
		Global.run_inventory.set_item(slot, null, null)
	var definitions: Array[ItemData] = []
	for value: Variant in Global.item_db.values():
		var data: ItemData = value as ItemData
		if data != null and StringName(data.set_id) == set_id and int(data.equip_slot) >= 0 and int(data.equip_slot) < Inventory.STAT_SLOT_COUNT:
			definitions.append(data)
	definitions.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		return int(a.equip_slot) < int(b.equip_slot)
	)
	for index in range(mini(pieces, definitions.size())):
		var item: ItemInstance = ItemInstance.from_roll(definitions[index], 0, 1, 0.45)
		Global.run_inventory.set_item(int(definitions[index].equip_slot), item, null)

func clear_sets() -> void:
	if Global == null or Global.run_inventory == null:
		return
	for slot in range(Inventory.STAT_SLOT_COUNT):
		Global.run_inventory.set_item(slot, null, null)

func grant_specific_set_item(item_id: StringName) -> void:
	if Global == null or Global.run_inventory == null:
		return
	var data: ItemData = Global.item_db.get(String(item_id), null) as ItemData
	if data == null or String(data.set_id) == "":
		push_warning("[0.22 set tools] Unknown or non-set item ID: %s" % String(item_id))
		return
	var target_slot: int = int(data.equip_slot)
	if target_slot < 0 or target_slot >= Inventory.STAT_SLOT_COUNT:
		push_warning("[0.22 set tools] Set item has no fixed equipment slot: %s" % String(item_id))
		return
	Global.run_inventory.set_item(target_slot, ItemInstance.from_roll(data, 0, 1, 0.45), null)

func force_breakpoint_notification() -> void:
	var notifier: Node = get_tree().get_first_node_in_group(&"set_breakpoint_notifier")
	if notifier != null and notifier.has_method("debug_force_notification"):
		notifier.call("debug_force_notification", &"conduit", 4, true)

func prime_conduit() -> void:
	_call_effect(&"debug_prime_discharge", [true])

func fill_gravemarch_bank() -> void:
	_call_effect(&"debug_fill_active_bank")

func place_lattice_marks() -> void:
	var player: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	_call_effect(&"debug_place_mark", [player.global_position + Vector2(100, -40), false])
	_call_effect(&"debug_place_mark", [player.global_position + Vector2(150, 50), true])

func clear_combat_state() -> void:
	_call_effect(&"debug_prime_discharge", [false])
	_call_effect(&"debug_clear_bank")
	_call_effect(&"debug_clear_marks")

func spawn_collision_fixture() -> void:
	if _fixture != null and is_instance_valid(_fixture):
		_fixture.queue_free()
	_fixture = Node2D.new()
	_fixture.name = "DevCollisionFixture"
	var scene: Node = get_tree().current_scene
	var player: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	var manager: ChunkManager = get_tree().get_first_node_in_group(&"chunk_manager") as ChunkManager
	if scene == null or player == null or manager == null:
		return
	scene.add_child(_fixture)
	var base_cell: Vector2i = manager.world_to_cell(player.global_position + Vector2(320, 0))
	var base: Vector2 = manager.cell_to_world_center(base_cell)
	var straight: Vector2 = base
	var corner: Vector2 = base + Vector2(0, 64)
	var wall_end: Vector2 = base + Vector2(0, 128)
	var window: Vector2 = base + Vector2(0, 192)
	var fence: Vector2 = base + Vector2(0, 256)
	var half_cover: Vector2 = base + Vector2(0, 320)
	_spawn_fixture_block(WALL_SCENE, straight, WorldBlockerGeometry.N | WorldBlockerGeometry.S)
	_spawn_fixture_block(WALL_SCENE, corner, WorldBlockerGeometry.N | WorldBlockerGeometry.E)
	_spawn_fixture_block(WALL_SCENE, wall_end, WorldBlockerGeometry.E)
	_spawn_fixture_block(WINDOW_SCENE, window, WorldBlockerGeometry.N | WorldBlockerGeometry.S)
	_spawn_fixture_block(FENCE_SCENE, fence, WorldBlockerGeometry.N | WorldBlockerGeometry.S)
	_spawn_fixture_half_cover(half_cover)
	_fire_fixture_pair(straight + Vector2(-150, 0))
	_fire_fixture_pair(corner + Vector2(-150, 20))
	_fire_fixture_pair(wall_end + Vector2(-150, 20))
	_fire_fixture_pair(window + Vector2(-150, 0))
	_fire_fixture_pair(fence + Vector2(-150, 0))
	_fire_fixture_pair(half_cover + Vector2(-150, 24))
	print("[0.22 collision fixture] hit t straight/corner-open/end-open/window/fence/half-open = ", manager.projectile_hit_t(straight + Vector2(-150, 0), straight + Vector2(150, 0), 3.0), ", ", manager.projectile_hit_t(corner + Vector2(-150, 20), corner + Vector2(150, 20), 3.0), ", ", manager.projectile_hit_t(wall_end + Vector2(-150, 20), wall_end + Vector2(150, 20), 3.0), ", ", manager.projectile_hit_t(window + Vector2(-150, 0), window + Vector2(150, 0), 3.0), ", ", manager.projectile_hit_t(fence + Vector2(-150, 0), fence + Vector2(150, 0), 3.0), ", ", manager.projectile_hit_t(half_cover + Vector2(-150, 24), half_cover + Vector2(150, 24), 3.0))

func _spawn_fixture_block(packed: PackedScene, world_position: Vector2, mask: int) -> void:
	var block: Node2D = packed.instantiate() as Node2D
	if block == null:
		return
	block.position = world_position
	block.set("connections_mask", mask)
	_fixture.add_child(block)

func _spawn_fixture_half_cover(world_position: Vector2) -> void:
	var block: Node2D = HALF_COVER_SCENE.instantiate() as Node2D
	if block == null:
		return
	block.position = world_position
	_fixture.add_child(block)

func _fire_fixture_pair(world_position: Vector2) -> void:
	_spawn_test_bullet(world_position + Vector2(0, -3), 180.0)
	_spawn_test_bullet(world_position + Vector2(0, 3), 4200.0)

func _spawn_test_bullet(world_position: Vector2, speed: float) -> void:
	var bullet: RangedBullet = BULLET_SCENE.instantiate() as RangedBullet
	if bullet == null:
		return
	bullet.position = world_position
	bullet.velocity = Vector2.RIGHT * speed
	bullet.max_range = 340.0
	bullet.damage = 0.0
	_fixture.add_child(bullet)

func _call_effect(method: StringName, args: Array = []) -> void:
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player == null:
		return
	var runner: Node = player.get_node_or_null("SetRunner")
	if runner == null:
		return
	for child: Node in runner.get_children():
		if child.has_method(method):
			child.callv(method, args)

func restart_opening(mode: String, phase: int = 0, response: String = "") -> void:
	if Global == null:
		return
	Global.attempt_active = true
	Global.attempt_segment = 1
	Global.attempt_deaths_this_segment = 0
	Global.attempt_checkpoint_pos = Vector2.INF
	Global.attempt_segment1_resonance = 0.0
	Global.attempt_segment1_milestones.clear()
	Global.attempt_opening_version = Global.OPENING_SEQUENCE_VERSION
	Global.attempt_opening_mode = StringName(mode)
	Global.attempt_opening_phase = clampi(phase, 0, 9)
	Global.attempt_opening_completed = false
	Global.attempt_opening_officer_completed = phase >= 8
	Global.attempt_opening_bren_committed = phase >= 9
	Global.debug_opening_mode_override = mode
	Global.debug_opening_force_phase = phase
	Global.debug_opening_response_override = response
	Global.set_followers(0)
	Global.save_current_profile()
	Global.call_deferred("goto_game")

func reset_opening_history() -> void:
	if Global == null:
		return
	Global.opening_full_intro_seen = false
	Global.opening_response_id = &""
	Global.opening_follower_explanation_seen = false
	Global.opening_replay_full_next_run = false
	Global.debug_opening_mode_override = ""
	Global.debug_opening_force_phase = -1
	Global.debug_opening_response_override = ""
	Global.save_current_profile()
	restart_opening("full")

func set_next_run_full_replay() -> void:
	if Global == null:
		return
	Global.opening_replay_full_next_run = true
	Global.debug_opening_mode_override = ""
	Global.debug_opening_force_phase = -1
	Global.save_current_profile()

func jump_to_segment(segment: int) -> void:
	if Global == null:
		return
	Global.attempt_active = true
	Global.attempt_segment = maxi(1, segment)
	if segment > 1:
		Global.attempt_opening_completed = true
		Global.attempt_opening_phase = 10
	Global.save_current_profile()
	Global.call_deferred("goto_game")

func simulate_legacy_opening_save() -> void:
	if Global == null or SaveManager == null or SaveManager.current_save == null:
		return
	Global.attempt_active = true
	Global.attempt_segment = 2
	Global.attempt_segment1_milestones = [&"synthesis", &"first_confrontation", &"assistant_commitment"]
	Global.attempt_opening_version = 0
	Global.attempt_opening_mode = &""
	Global.attempt_opening_phase = 0
	Global.attempt_opening_completed = false
	Global.attempt_opening_officer_completed = false
	Global.attempt_opening_bren_committed = false
	Global.save_current_profile()
	# Reapply the serialized resource so the same migration path used at boot is
	# exercised without requiring a developer to edit a .tres by hand.
	Global.apply_save(SaveManager.current_save)
	Global.call_deferred("goto_game")

# ============================================================
# Manifestations
#
# The layer is deliberately low-roll-rate, so playtesting it by farming drops
# is hopeless. These force a specific rule onto real equipped gear.
# ============================================================

func grant_manifestation(id: StringName) -> void:
	if Global == null or Global.run_inventory == null:
		return
	var def := ManifestationCatalog.get_def(id)
	if def == null:
		push_warning("[manifestations] unknown rule: %s" % String(id))
		return

	# Prefer stamping it onto gear that is already worn - that keeps the rest of
	# the loadout (and any set bonus being tested) intact.
	for slot in def.slots:
		var worn: ItemInstance = Global.run_inventory.get_at(int(slot))
		if worn != null and worn.data != null:
			worn.manifestation_id = id
			Global.run_inventory.emit_changed()
			_refresh_player_loadout()
			return

	for slot in def.slots:
		var data := _first_item_data_for_slot(int(slot))
		if data == null:
			continue
		var granted := ItemInstance.from_roll(data, 3, ItemInstance.Polarity.POS, 0.45, false)
		granted.manifestation_id = id
		Global.run_inventory.set_item(int(slot), granted, null)
		_refresh_player_loadout()
		return

	push_warning("[manifestations] no item definition exists for any slot %s allows" % String(id))


func roll_all_manifestations() -> void:
	# Every worn item gets a legal rule for its slot. This is the "what does
	# eight of them at once actually feel like?" button.
	if Global == null or Global.run_inventory == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for slot in range(Inventory.SLOT_COUNT):
		var worn: ItemInstance = Global.run_inventory.get_at(slot)
		if worn == null or worn.data == null:
			continue
		var pool := ManifestationCatalog.pool_for_slot(slot)
		if pool.is_empty():
			continue
		worn.manifestation_id = pool[rng.randi_range(0, pool.size() - 1)].id
	Global.run_inventory.emit_changed()
	_refresh_player_loadout()


func clear_manifestations() -> void:
	if Global == null or Global.run_inventory == null:
		return
	for slot in range(Inventory.SLOT_COUNT):
		var worn: ItemInstance = Global.run_inventory.get_at(slot)
		if worn != null:
			worn.manifestation_id = &""
	Global.run_inventory.emit_changed()
	_refresh_player_loadout()


func _first_item_data_for_slot(slot: int) -> ItemData:
	if Global == null or Global.item_db == null:
		return null
	for value: Variant in Global.item_db.values():
		var data: ItemData = value as ItemData
		if data != null and int(data.equip_slot) == slot:
			return data
	return null


func _refresh_player_loadout() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if player != null and player.has_method("refresh_run_state"):
		player.call("refresh_run_state")


# ============================================================
# Curses / burden
#
# The NEG slice is deliberately low-roll-rate, so hand-testing the three
# archetypes by farming drops is hopeless.
# ============================================================

func grant_deep_curses() -> void:
	if Global == null or Global.run_inventory == null:
		return
	for id in Global.item_db.keys():
		var data: ItemData = Global.item_db[id] as ItemData
		if data == null or not String(data.id).begins_with("curse_"):
			continue
		var slot: int = int(data.equip_slot)
		if slot < 0 or slot >= Inventory.SLOT_COUNT:
			continue
		# Rolled at its own floor, so every archetype sees the real thing.
		var cursed := ItemInstance.from_roll(data, 4, ItemInstance.Polarity.NEG, data.pct_min, false)
		Global.run_inventory.set_item(slot, cursed, null)
	_refresh_player_loadout()


func grant_mild_curses() -> void:
	# The Doctrine's wardrobe: many small real curses rather than two horrors.
	if Global == null or Global.run_inventory == null:
		return
	for slot in range(Inventory.SLOT_COUNT):
		var data := _first_item_data_for_slot(slot)
		if data == null:
			continue
		Global.run_inventory.set_item(
			slot, ItemInstance.from_roll(data, 3, ItemInstance.Polarity.NEG, -0.18, false), null
		)
	_refresh_player_loadout()


func grant_neg_augment(id: StringName) -> void:
	if Global == null:
		return
	Global.set_permanent_augment(0, id)
	_refresh_player_loadout()


## Light a pair on demand: grant two distinct rules of each of its two nouns.
##
## A pair needs two DISTINCT rules of noun A and two of noun B, which through
## the ordinary roll is a specific and uncommon loadout - so the ten authored
## payoffs were, in practice, untestable without fishing for them. Returns how
## many rules it managed to place; 0 means there were not enough free slots.
func grant_pair(pair_id: StringName) -> int:
	var def := ManifestationPairCatalog.get_def(pair_id)
	if def == null or def.nouns.size() < 2:
		return 0
	if Global == null or Global.run_inventory == null:
		return 0

	# Two DISTINCT rules per noun is the activation contract. Rules carrying
	# BOTH of the pair's nouns are taken first: one of those satisfies two
	# requirements at once, which matters because a slot a rule may legally live
	# on is the scarce resource here, not the rules themselves.
	var need: Dictionary = {}
	for noun in def.nouns:
		need[noun] = 2
	var chosen: Array[StringName] = []
	for pass_index in range(2):
		for id_value in ManifestationCatalog.all_ids():
			if chosen.has(id_value):
				continue
			var tags := ManifestationCatalog.tags_of(id_value)
			var serves: Array[StringName] = []
			for noun in def.nouns:
				if int(need.get(noun, 0)) > 0 and tags.has(noun):
					serves.append(noun)
			# First pass: only rules that cover both nouns at once.
			if serves.is_empty() or (pass_index == 0 and serves.size() < 2):
				continue
			chosen.append(id_value)
			for noun in serves:
				need[noun] = int(need[noun]) - 1

	# Each rule may only live on certain slots, so first-come-first-served loses
	# pairs it could have satisfied: a rule legal on three slots takes the one
	# that a later, pickier rule needed. Assign properly instead.
	var assignment := _assign_rules_to_slots(chosen)
	if assignment.is_empty():
		return 0

	var placed: int = 0
	for slot_key in assignment:
		var slot := int(slot_key)
		var rule_id: StringName = assignment[slot_key]
		var worn: ItemInstance = Global.run_inventory.get_at(slot)
		if worn == null or worn.data == null:
			var data := _first_item_data_for_slot(slot)
			if data == null:
				continue
			worn = ItemInstance.from_roll(data, 3, ItemInstance.Polarity.POS, 0.45, false)
			Global.run_inventory.set_item(slot, worn, null)
		worn.manifestation_id = rule_id
		placed += 1
	Global.run_inventory.emit_changed()
	_refresh_player_loadout()
	return placed


## slot -> rule id, or {} if every rule could not be placed at once.
##
## Pickiest rule first, then backtrack. Four rules over eight slots with
## per-rule slot restrictions is small enough that exhaustive search is instant
## and greedy is simply wrong.
func _assign_rules_to_slots(rules: Array[StringName]) -> Dictionary:
	var options: Array = []
	for rule_id in rules:
		var rule_def := ManifestationCatalog.get_def(rule_id)
		if rule_def == null:
			return {}
		var slots: Array[int] = []
		for slot_value in rule_def.slots:
			var slot := int(slot_value)
			# A slot with no item definition can never carry a rule.
			if _first_item_data_for_slot(slot) != null or Global.run_inventory.get_at(slot) != null:
				slots.append(slot)
		if slots.is_empty():
			return {}
		options.append({"id": rule_id, "slots": slots})
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["slots"] as Array).size() < (b["slots"] as Array).size())

	var result: Dictionary = {}
	if _place_from(options, 0, result):
		return result
	return {}


func _place_from(options: Array, index: int, result: Dictionary) -> bool:
	if index >= options.size():
		return true
	var entry: Dictionary = options[index]
	for slot_value in (entry["slots"] as Array):
		var slot := int(slot_value)
		if result.has(slot):
			continue
		result[slot] = entry["id"]
		if _place_from(options, index + 1, result):
			return true
		result.erase(slot)
	return false
