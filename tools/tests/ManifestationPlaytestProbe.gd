extends Node

# Rendered playtest probe for the Manifestation layer. Runs the REAL game,
# forces a deliberately interacting eight-rule loadout onto real equipment,
# then physically plays the behaviours the rules ask for - travel, plant,
# shoot, get hit - and asserts the SHARED STATE actually moved.
#
# The design question this exists to answer is not "did DPS go up?" but
# "did the rules change what the player has to do?". So every assertion here
# is about a behaviour producing a resource, never about a damage number.
#
# Screenshots land in MANIFEST_SHOT_DIR (env) or user://manifestation_shots.
# Run: <godot> --path . res://tools/tests/ManifestationPlaytestProbe.tscn
# (needs a display; use the headless ManifestationSystemTest for CI)

class Driver:
	extends Node

	# slot -> rule. Chosen to interlock: travel builds Momentum, being hit
	# spends it, crits forge shards, a full halo launches them, and the Mark
	# detonates into whatever is in orbit.
	const LOADOUT: Array = [
		[0, &"overtime_gospel"],
		[1, &"impact_scripture"],
		[2, &"pilgrims_momentum"],
		[3, &"predestination_sigil"],
		[4, &"third_litany"],
		[5, &"broken_providence"],
		[6, &"vector_halo"],
		[7, &"orbiting_testament"],
	]

	var _phase := 0
	var _elapsed := 0.0
	var _wall := 0.0
	var _busy := false
	var _passes := 0
	var _failures := 0
	var _shot_dir := ""
	var _player: Node2D = null
	var _runner: Node = null
	var _state: Node = null

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_shot_dir = OS.get_environment("MANIFEST_SHOT_DIR")
		if _shot_dir.is_empty():
			_shot_dir = ProjectSettings.globalize_path("user://manifestation_shots")
		DirAccess.make_dir_recursive_absolute(_shot_dir)
		Global.start_new_attempt()
		Global.attempt_segment = 2
		Global.attempt_opening_completed = true
		Global.attempt_opening_phase = 10
		Global.debug_dev_segment = false
		Global.debug_dev_mode = true
		Global.debug_player_god_mode = true
		_phase = 1
		Global.goto_game()

	## A heal must never be able to REMOVE health.
	##
	## heal() used to announce the requested amount rather than the applied one,
	## so at 95/100 a 30-point pickup landed 5 and reported 30 - and any rule
	## that takes a cut of a heal billed the player for the overflow. Walking
	## over a health pickup at full HP cost you a chunk of your life bar. This is
	## a whole CLASS of bug (anything reacting to player_healed), so it is pinned
	## on the real player, not on a stub.
	func _probe_overheal_is_never_damage() -> void:
		if _player == null or not is_instance_valid(_player):
			return
		var max_hp: float = float(_player.get("max_hp"))
		_player.set("hp", max_hp)
		var reported: Array[float] = []
		var sink := func(_who: Variant, amount: float) -> void: reported.append(amount)
		RunEvents.player_healed.connect(sink)
		_player.call("heal", max_hp * 0.5)
		RunEvents.player_healed.disconnect(sink)
		_check(
			float(_player.get("hp")) >= max_hp - 0.01,
			"healing at full HP never lowers it (%.1f / %.1f)" % [float(_player.get("hp")), max_hp]
		)
		_check(
			reported.is_empty(),
			"a heal that lands nothing announces nothing (announced %s)" % str(reported)
		)
		_player.set("hp", max_hp * 0.5)
		reported.clear()
		RunEvents.player_healed.connect(sink)
		_player.call("heal", max_hp)
		RunEvents.player_healed.disconnect(sink)
		var announced: float = reported[0] if not reported.is_empty() else -1.0
		_check(
			absf(announced - max_hp * 0.5) < 0.01,
			"an overheal announces what LANDED, not what was asked (%.1f)" % announced
		)


	## Haste has to be worth something on every weapon style.
	##
	## Melee fires on the press with no cooldown, so the click rate IS the attack
	## rate and Haste bought nothing - every Haste item, every set granting it,
	## and the rules built on it were dead text on a third of the game's builds.
	func _probe_haste_reaches_melee() -> void:
		if _player == null or not is_instance_valid(_player):
			return
		_check(
			int(_player.call("_melee_followups", 1.0)) == 0,
			"no Haste, no follow-through"
		)
		_check(
			int(_player.call("_melee_followups", 2.0)) == 1,
			"+100% Haste is one guaranteed follow-through"
		)
		var partial: int = 0
		for _i in range(400):
			partial += int(_player.call("_melee_followups", 1.5))
		_check(
			partial > 120 and partial < 280,
			"a fractional Haste is a chance at one (%d over 400 swings)" % partial
		)
		_check(
			int(_player.call("_melee_followups", 99.0)) <= 3,
			"and it is capped, so Haste cannot become a screen of slashes"
		)


	func _check(condition: bool, message: String) -> void:
		if condition:
			_passes += 1
			print("PASS: ", message)
		else:
			_failures += 1
			push_error("FAIL: " + message)

	func _process(delta: float) -> void:
		if _phase < 1:
			return
		# Dismissal has to keep running while the scripted play is in flight.
		# A card or an augment card pauses the tree, which stops every effect's
		# _process - and this probe's timers ignore pause, so a paused tree
		# reads as "the rule did nothing" instead of "the rule never ticked".
		_dismiss_tutorial_cards()
		if _busy:
			if get_tree().paused:
				_dismiss_blocking_ui()
			return
		_wall += delta
		if get_tree().paused:
			if _wall >= 2.0:
				_dismiss_blocking_ui()
			return
		_elapsed += delta
		if _phase == 1 and _elapsed >= 5.0:
			_phase = 2
			_busy = true
			_run()

	# -----------------------------------------------------------------------

	func _run() -> void:
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
		if _player == null:
			push_error("FAIL: no player node")
			_finish()
			return

		_equip_loadout()
		_runner = _player.get_node_or_null("ManifestationRunner")
		_check(_runner != null, "the player carries a ManifestationRunner")
		_probe_overheal_is_never_damage()
		_probe_haste_reaches_melee()
		if _runner == null:
			_finish()
			return
		_state = _runner.get("state")
		_check(_state != null, "the runner owns a shared ManifestationState")

		await _settle(0.6)
		_check(
			int(_runner.call("active_count")) == LOADOUT.size(),
			"all %d equipped rules came online (%d active)" % [LOADOUT.size(), int(_runner.call("active_count"))]
		)

		var summaries: Array = _runner.call("get_active_summaries")
		var described := true
		for entry_value in summaries:
			var entry: Dictionary = entry_value
			if String(entry.get("rule", "")).strip_edges() == "":
				described = false
			print("  RULE %s: %s" % [String(entry.get("name", "")), String(entry.get("rule", ""))])
		_check(described, "every active rule reports a readable line for the Run Sheet")

		await _shot("00_loadout")

		await _test_travel_builds_momentum()
		await _test_standing_still_is_a_different_verb()
		await _test_crits_forge_shards()
		await _test_being_hit_spends_momentum()
		await _test_dash_launches_the_halo()
		await _test_attacking_under_pressure()
		await _test_run_sheet_reads_the_chain()

		print("ManifestationPlaytestProbe: %d passed, %d failed" % [_passes, _failures])
		_finish()

	# -----------------------------------------------------------------------
	# Behaviours
	# -----------------------------------------------------------------------

	func _test_travel_builds_momentum() -> void:
		_state.set("momentum", 0.0)
		var before: float = float(_state.get("distance_travelled_total"))
		await _walk(Vector2.RIGHT, 3.2)
		var travelled: float = float(_state.get("distance_travelled_total")) - before
		_check(travelled > 300.0, "sustained travel is tracked (%.0f px)" % travelled)
		_check(
			float(_state.get("momentum")) > 0.6,
			"moving without stopping builds Momentum (%.2f)" % float(_state.get("momentum"))
		)
		await _shot("01_momentum_from_travel")

	func _test_standing_still_is_a_different_verb() -> void:
		# The conflict is the content: whatever Momentum the last phase built
		# has to bleed away the moment the player plants.
		var peak: float = float(_state.get("momentum"))
		# _walk drops world collision, so the run can end up standing inside
		# geometry; move_and_slide then depenetrates over several frames and
		# the state correctly reads that as movement. Let the body settle first
		# or this measures the push-out, not the player standing still.
		await _wait_until_still(2.0)

		# Sample the PEAK rather than the final value. This is a horde game and
		# the probe is standing in a live world: a wandering enemy shoving the
		# player is real movement and correctly resets the clock. What is being
		# asserted is that stopping accumulates stillness at all.
		var best_still := 0.0
		var left := 2.2
		while left > 0.0:
			await get_tree().process_frame
			left -= get_process_delta_time()
			best_still = maxf(best_still, float(_state.get("still_time")))
		_check(
			float(_state.get("momentum")) < peak,
			"standing still drains Momentum (%.2f -> %.2f)" % [peak, float(_state.get("momentum"))]
		)
		_check(
			best_still > 0.8,
			"stillness accumulates as its own resource (peaked %.2fs)" % best_still
		)
		await _shot("02_planted")

	func _test_crits_forge_shards() -> void:
		# The Luck roll itself is 8% at best, so drive the HOOK directly - the
		# roll is covered by the headless suite, this is about the engine.
		var cap: int = int(_state.call("shard_cap"))
		_check(cap > 4, "Vector Halo widened the shared orbit (cap %d, base 4)" % cap)

		# Drive a REALISTIC mix. Lucky Crit chance is capped at 8%, so failures
		# outnumber successes about twelve to one - and with the Bad Fortune
		# Engine pair live, a success SPENDS the orbit while a failure forges
		# into it. Emitting only successes tests the one input that drains.
		var peak_forge := 0
		for _f in range(6):
			RunEvents.player_lucky_crit.emit(_player, _player.global_position, false)
			peak_forge = maxi(peak_forge, int(_state.call("shard_count")))
			await _settle(0.03)
		print("  ORBIT  forge peak=%d  live=%d  pairs live=%d" % [
			peak_forge, int(_state.call("shard_count")), int(_runner.call("active_pair_count")),
		])
		_check(peak_forge >= 1, "Lucky Crit rolls forge shards into orbit (peak %d)" % peak_forge)
		await _shot("03a_first_shard")

		# Fill the orbit. The halo no longer fires itself - it WAITS for a dash,
		# which is the whole point of the rewiring: two triggers on one resource
		# meant the player controlled neither.
		# Paced, not spammed. Bad Fortune Engine rate-limits its forge so a
		# consumer can out-drink it, so a tight loop of failed rolls no longer
		# fills the orbit - and should not. Drive it over real time instead,
		# which is also what a player firing a weapon actually does.
		var peak := 0
		for _i in range((cap + 2) * 3):
			RunEvents.player_lucky_crit.emit(_player, _player.global_position, false)
			await _settle(0.24)
			peak = maxi(peak, int(_state.call("shard_count")))
		_check(peak >= cap - 2, "the orbit fills toward the widened cap (peak %d / %d)" % [peak, cap])

		# NOT "a full orbit sits there waiting". This loadout lights all ten
		# authored pairs, which puts four independent consumers on the orbit -
		# Bad Fortune Engine spends it on a lucky crit, Slipstream Foundry
		# strings it out while running, Reliquary Guard shatters it to absorb a
		# hit, the Loom fires it on the beat. A busy shared resource is the
		# intended tail behaviour, not a bug. That the orbit HOLDS for the dash
		# in isolation is pinned headlessly in ManifestationSystemTest instead,
		# against a bare state with no pairs.
		await _shot("03b_shard_halo")

	func _test_being_hit_spends_momentum() -> void:
		await _walk(Vector2.LEFT, 3.0)
		var stored: float = float(_state.get("momentum"))
		_check(stored > 0.3, "Momentum is banked before the hit (%.2f)" % stored)
		Global.debug_player_god_mode = false
		_player.call("_take_damage", 4.0)
		await _settle(0.4)
		Global.debug_player_god_mode = true
		_check(
			float(_state.get("momentum")) < stored,
			"taking a hit detonates banked Momentum (%.2f -> %.2f)" % [stored, float(_state.get("momentum"))]
		)
		await _shot("04_impact_scripture")

	func _test_dash_launches_the_halo() -> void:
		# The verb the design kept assuming. Vector Halo used to fire itself the
		# instant the orbit filled because there was nothing to dash with.
		_check(InputMap.has_action(&"dash"), "the dash action exists")

		var before: Vector2 = _player.global_position
		_player.call("_start_dash")
		await _settle(0.05)
		_check(bool(_player.get("invulnerable_time") > 0.0), "dashing grants i-frames")
		await _settle(0.35)
		var travelled: float = before.distance_to(_player.global_position)
		_check(travelled > 40.0, "the dash actually moves the player (%.0f px)" % travelled)

		# Phasing must end with the dash, and must not leave the player faster.
		var base_mask: int = int(_player.get("_base_collision_mask"))
		_check(
			int(_player.get("collision_mask")) == base_mask,
			"body phasing is restored when the dash ends"
		)

		# Refill and dash again: the halo should leave along the dash vector.
		for _i in range(6):
			RunEvents.player_lucky_crit.emit(_player, _player.global_position, false)
			await _settle(0.06)
		var orbiting: int = int(_state.call("shard_count"))
		if orbiting > 0:
			await _settle(1.4)
			_player.call("_start_dash")
			await _settle(0.3)
			_check(
				int(_state.call("shard_count")) < orbiting,
				"dashing launches the orbit (%d -> %d)" % [orbiting, int(_state.call("shard_count"))]
			)
		await _shot("05a_dash")


	func _test_attacking_under_pressure() -> void:
		var spawner := get_tree().get_first_node_in_group(&"enemy_spawner")
		if spawner != null and spawner.has_method("debug_force_spawn"):
			spawner.call("debug_force_spawn", 24)
			await _settle(2.0)
		var alive := 0
		var index := get_node_or_null("/root/EnemyIndex")
		if index != null and index.has_method("alive_count"):
			alive = int(index.call("alive_count"))
		_check(alive > 0, "the probe has something to shoot at (%d alive)" % alive)

		# Rhythm rules only mean anything against a real firing loop.
		for i in range(18):
			_player.call("_fire_weapon", _player.global_position + Vector2(220.0, 0.0).rotated(float(i) * 0.35))
			await _settle(0.18)
		_check(not _player.get("is_dead"), "the player survived the firing loop")
		await _shot("05_engine_running")

	func _test_run_sheet_reads_the_chain() -> void:
		# Eight interacting rules are only a payoff if the player can still
		# trace what they built, so the Run Sheet has to render the chain.
		var controller: Node = null
		for node in get_tree().root.find_children("*", "", true, false):
			if node.has_method("toggle_bag_open") and node.has_method("get_bag_ui"):
				controller = node
				break
		if controller == null:
			_check(false, "the HUD bag controller is reachable")
			return
		controller.call("toggle_bag_open")

		var sheet: Node = get_tree().root.find_children("RunSheetHUD", "", true, false).pop_front()
		_check(sheet != null, "the Run Sheet exists")
		if sheet == null:
			return

		# The HUD repopulates the panel on its own 10 Hz tick, so poll for the
		# section rather than betting on one settle window landing after a tick.
		var listed := 0
		var lines: PackedStringArray = PackedStringArray()
		for _attempt in range(30):
			await _settle(0.1)
			listed = 0
			lines = PackedStringArray()
			for child in sheet.find_children("*", "Label", true, false):
				var text: String = String(child.get("text"))
				if text.strip_edges() != "":
					lines.append(text)
				if text.begins_with("MANIFESTATIONS"):
					listed += 1
			if listed > 0:
				break
		_check(
			listed > 0,
			"the Run Sheet has a MANIFESTATIONS section (visible=%s)" % str(sheet.get("visible"))
		)
		_check(lines.size() > LOADOUT.size(), "and lists the rules with their text (%d lines)" % lines.size())
		await _shot("06_run_sheet")
		controller.call("toggle_bag_open")
		await _settle(0.4)


	# -----------------------------------------------------------------------
	# Driving helpers
	# -----------------------------------------------------------------------

	func _walk(direction: Vector2, seconds: float) -> void:
		# Player movement reads Input, which nothing is feeding, so step the
		# body directly. Small per-frame steps keep the state's "is the player
		# actually moving?" test honest - a teleport would not.
		#
		# World collision is dropped for the duration: move_and_slide runs every
		# physics frame with zero velocity, so a stepped body that ends up
		# inside geometry gets depenetrated back and the run stalls against the
		# first wall. This probe measures the Momentum tracker, not navigation.
		var speed := 240.0
		var left := seconds
		var heading := direction.normalized()
		var saved_mask: int = int(_player.get("collision_mask"))
		_player.set("collision_mask", 0)
		while left > 0.0:
			await get_tree().process_frame
			if get_tree().paused:
				_dismiss_tutorial_cards()
				_dismiss_blocking_ui()
				continue
			var dt := get_process_delta_time()
			left -= dt
			_player.global_position += heading * speed * dt
		_player.set("collision_mask", saved_mask)

	func _wait_until_still(timeout: float) -> void:
		var left := timeout
		while left > 0.0:
			await get_tree().process_frame
			left -= get_process_delta_time()
			if not bool(_state.get("is_moving")):
				return


	func _settle(seconds: float) -> void:
		if get_tree().paused:
			_dismiss_tutorial_cards()
			_dismiss_blocking_ui()
		await get_tree().create_timer(seconds, true, false, true).timeout

	func _equip_loadout() -> void:
		for entry_value in LOADOUT:
			var entry: Array = entry_value
			var slot: int = int(entry[0])
			var rule: StringName = entry[1]
			var data := _first_item_for_slot(slot)
			if data == null:
				push_warning("no item definition for slot %d" % slot)
				continue
			var inst := ItemInstance.from_roll(data, 6, ItemInstance.Polarity.POS, 0.5, false)
			inst.manifestation_id = rule
			Global.run_inventory.set_item(slot, inst, null)
		if _player.has_method("refresh_run_state"):
			_player.call("refresh_run_state")

	func _first_item_for_slot(slot: int) -> ItemData:
		for value: Variant in Global.item_db.values():
			var data: ItemData = value as ItemData
			if data != null and int(data.equip_slot) == slot:
				return data
		return null

	func _shot(shot_name: String) -> void:
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := _shot_dir.path_join("%s.png" % shot_name)
		var err := image.save_png(path)
		print("SHOT %s -> %s (err=%d)" % [shot_name, path, err])

	func _dismiss_tutorial_cards() -> void:
		for node in get_tree().root.find_children("*", "", true, false):
			var script: Script = node.get_script() as Script
			if script != null and script.resource_path.ends_with("TutorialCardOverlay.gd"):
				node.call("_dismiss")

	func _dismiss_blocking_ui() -> void:
		var scene := get_tree().current_scene
		var ui := scene.get_node_or_null("UI") if scene != null else null
		if ui != null:
			for child in ui.get_children():
				if child.has_method("open_choose_3"):
					child.queue_free()
		get_tree().paused = false

	func _finish() -> void:
		get_tree().quit(1 if _failures > 0 else 0)


func _ready() -> void:
	var driver := Driver.new()
	get_tree().root.add_child.call_deferred(driver)
