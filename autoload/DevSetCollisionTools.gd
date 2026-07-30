extends CanvasLayer

const WALL_SCENE: PackedScene = preload("res://scenes/world/cover/CoverFull.tscn")
const WINDOW_SCENE: PackedScene = preload("res://scenes/world/cover/CoverWindow.tscn")
const FENCE_SCENE: PackedScene = preload("res://scenes/world/fence/FenceBlock.tscn")
const HALF_COVER_SCENE: PackedScene = preload("res://scenes/world/cover/CoverHalf.tscn")
const BULLET_SCENE: PackedScene = preload("res://scenes/world/combat/RangedBullet.tscn")

var _panel: PanelContainer = null
var _fixture: Node2D = null
var _item_id_edit: LineEdit = null

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
	Global.attempt_opening_phase = clampi(phase, 0, 8)
	Global.attempt_opening_completed = false
	Global.attempt_opening_officer_completed = phase >= 7
	Global.attempt_opening_bren_committed = phase >= 8
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
		Global.attempt_opening_phase = 9
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

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT, true)
	_panel.offset_left = -390.0
	_panel.offset_top = -650.0
	_panel.offset_right = -16.0
	_panel.offset_bottom = -16.0
	add_child(_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)
	var title := Label.new()
	title.text = "0.23 OPENING / SET / COLLISION TESTS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	_add_set_row(root, "Conduit", &"conduit")
	_add_set_row(root, "Gravemarch", &"gravemarch")
	_add_set_row(root, "Lattice", &"lattice")
	var clear_button := _button("Clear gear", clear_sets)
	root.add_child(clear_button)
	var combat := HBoxContainer.new()
	root.add_child(combat)
	combat.add_child(_button("Prime", prime_conduit))
	combat.add_child(_button("Fill bank", fill_gravemarch_bank))
	combat.add_child(_button("2 marks", place_lattice_marks))
	combat.add_child(_button("Clear state", clear_combat_state))
	var item_row := HBoxContainer.new()
	root.add_child(item_row)
	_item_id_edit = LineEdit.new()
	_item_id_edit.placeholder_text = "specific set item ID"
	_item_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_row.add_child(_item_id_edit)
	item_row.add_child(_button("Grant ID", func() -> void: grant_specific_set_item(StringName(_item_id_edit.text.strip_edges()))))
	var tests := HBoxContainer.new()
	root.add_child(tests)
	tests.add_child(_button("Force notice", force_breakpoint_notification))
	tests.add_child(_button("Collision fixture", spawn_collision_fixture))
	tests.add_child(_button("Toggle stress", func() -> void: Global.debug_projectile_stress_test = not Global.debug_projectile_stress_test))
	tests.add_child(_button("Performance", func() -> void:
		var overlay := get_tree().get_first_node_in_group(&"performance_overlay")
		if overlay != null and overlay.has_method("toggle_overlay"):
			overlay.call("toggle_overlay")
	))
	var opening_title := Label.new()
	opening_title.text = "OPENING SEQUENCE"
	opening_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(opening_title)
	var modes := HBoxContainer.new()
	root.add_child(modes)
	modes.add_child(_button("Full", func() -> void: restart_opening("full")))
	modes.add_child(_button("Short", func() -> void: restart_opening("short")))
	modes.add_child(_button("Skip", func() -> void: restart_opening("skip")))
	modes.add_child(_button("Replay next", set_next_run_full_replay))
	modes.add_child(_button("Reset history", reset_opening_history))
	modes.add_child(_button("Legacy save", simulate_legacy_opening_save))
	var phases := HBoxContainer.new()
	root.add_child(phases)
	phases.add_child(_button("Synthesis", func() -> void: restart_opening("full", 3)))
	phases.add_child(_button("Target", func() -> void: restart_opening("full", 4)))
	phases.add_child(_button("Construct", func() -> void: restart_opening("full", 5)))
	phases.add_child(_button("Officer", func() -> void: restart_opening("full", 6)))
	phases.add_child(_button("Death", func() -> void: restart_opening("full", 7)))
	phases.add_child(_button("Bren", func() -> void: restart_opening("full", 8)))
	var responses := HBoxContainer.new()
	root.add_child(responses)
	responses.add_child(_button("Analytical", func() -> void: restart_opening("full", 2, "analytical")))
	responses.add_child(_button("Decisive", func() -> void: restart_opening("full", 2, "decisive")))
	responses.add_child(_button("Protective", func() -> void: restart_opening("full", 2, "protective")))
	responses.add_child(_button("Withdrawn", func() -> void: restart_opening("full", 2, "withdrawn")))
	var segments := HBoxContainer.new()
	root.add_child(segments)
	segments.add_child(_button("Segment 2", func() -> void: jump_to_segment(2)))
	segments.add_child(_button("Segment 5", func() -> void: jump_to_segment(5)))
	segments.add_child(_button("Segment 10", func() -> void: jump_to_segment(10)))

func _add_set_row(parent: VBoxContainer, label_text: String, set_id: StringName) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.custom_minimum_size.x = 100.0
	label.text = label_text
	row.add_child(label)
	for count in [2, 4, 6]:
		row.add_child(_button("%dP" % count, func() -> void: grant_set(set_id, count)))

func _button(label_text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	return button
