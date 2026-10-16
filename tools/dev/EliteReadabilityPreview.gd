extends "res://tools/dev/EliteModifierPreview.gd"
## A bounded native-scale companion to the live crowd recording. This uses
## production EnemyActors, the shared body renderer, tells and combat text.
## The 1920×1080 game canvas is rendered into the same 1280×720 window.
## --out=<absolute folder>; --reduced-motion; --still-only; --interactive.

const GAME_VIEWPORT := Vector2i(1920, 1080)
const NATIVE_WINDOW := Vector2i(1280, 720)
const GRID_ORIGIN := Vector2(36.0, 124.0)
const GRID_STEP := Vector2(624.0, 440.0)
const TILE_SIZE := Vector2(600.0, 418.0)
const ACTOR_AT := Vector2(300.0, 238.0)
var _reduced := false


func _enter_tree() -> void:
	super._enter_tree()
	_preview_scale = 1.0
	_out = "user://dev_previews/elite_readability" if _out == "user://dev_previews/elite_modifiers" else _out
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--reduced-motion":
			_reduced = true
	_cards = [
		{"name": "ARMOURED + VAMPIRIC", "spec": "Brute", "palette": "STEEL", "ids": [EliteModifiers.ARMOURED, EliteModifiers.VAMPIRIC], "trait": "Steel body · Red blood ring"},
		{"name": "ARMOURED + SPLITTING", "spec": "Brute", "palette": "STEEL", "ids": [EliteModifiers.ARMOURED, EliteModifiers.SPLITTING], "trait": "Steel body · Green fractured seam"},
		{"name": "ARMOURED + SPLITTING + FAST", "spec": "Brute", "palette": "STEEL", "ids": [EliteModifiers.ARMOURED, EliteModifiers.SPLITTING, EliteModifiers.FAST], "trait": "Forced triple · All three tells retained"},
		{"name": "VAMPIRIC + SPLITTING", "spec": "Brute", "palette": "RED", "ids": [EliteModifiers.VAMPIRIC, EliteModifiers.SPLITTING], "trait": "Red body · Green fractured seam"},
		{"name": "SHIELDED + VAMPIRIC", "spec": "Brute", "palette": "CYAN", "ids": [EliteModifiers.SHIELDED, EliteModifiers.VAMPIRIC], "trait": "Real 180 px ward · Red blood ring"},
		{"name": "SHIELDED + SPLITTING", "spec": "Brute", "palette": "CYAN", "ids": [EliteModifiers.SHIELDED, EliteModifiers.SPLITTING], "trait": "Real 180 px ward · Green fractured seam"},
	]


func _prepare_runtime() -> void:
	super._prepare_runtime()
	SettingsManager.set_value(&"accessibility", &"reduced_motion", _reduced, false)
	SettingsManager.set_value(&"accessibility", &"ability_callouts", true, false)
	BattleText.visible = true
	BattleText.clear()
	get_window().title = "Synthetic Ascension — secondary elite readability"
	get_window().content_scale_size = GAME_VIEWPORT
	get_window().size = NATIVE_WINDOW


func _build_layout() -> void:
	_rect(Rect2(Vector2.ZERO, Vector2(GAME_VIEWPORT)), Color("0e1311"), -1000)
	_rect(Rect2(0, 0, GAME_VIEWPORT.x, 109), Color("131913"), -999)
	_label(Rect2(36, 21, 1848, 42), "SECONDARY ELITE TELLS", 32, GOLD, TITLE_FONT)
	_label(Rect2(37, 67, 1846, 31), "Actual game scale · Multi-modifier actors · Production body renderer, marks and promotion text", 23, MUTED)
	for index in range(_cards.size()):
		var origin := _card_origin(index)
		var card := _cards[index]
		var tint := EliteModifiers.tint(card["ids"][0])
		_panel(Rect2(origin, TILE_SIZE), tint, index < 3)
		_label(Rect2(origin + Vector2(20, 17), Vector2(560, 36)), card["name"], 24, IVORY, TITLE_FONT, true)
		_label(Rect2(origin + Vector2(20, 376), Vector2(560, 30)), card["trait"], 24, MUTED, BODY_FONT, true)
	_label(Rect2(36, 1030, 1848, 28), "Native 1280 × 720 output from the 1920 × 1080 game canvas · No enemy stats changed · No profile save writes", 22, MUTED)


func _card_origin(index: int) -> Vector2:
	return GRID_ORIGIN + Vector2(float(index % 3) * GRID_STEP.x, float(index / 3) * GRID_STEP.y)


func _build_actors() -> void:
	for index in range(_cards.size()):
		var card := _cards[index]
		var actor := ENEMY_SCENE.instantiate() as EnemyActor
		actor.spec = load("res://core/actors/enemy/EnemySpec_%s.tres" % card["spec"]) as EnemySpec
		actor.name = "Readability_%d" % index
		actor.position = _card_origin(index) + ACTOR_AT
		actor.set_physics_process(false)
		actor.collision_layer = 0
		actor.collision_mask = 0
		add_child(actor)
		actor.player = _dummy_player
		var hitbox := actor.get_node("Hitbox") as Area2D
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
		if actor.animator != null:
			actor.animator.set("_phase_ms", 0)
		var ids: Array[StringName] = []
		ids.assign(card["ids"])
		actor.apply_elite_modifiers(ids)
		actor.set_physics_process(false)
		actor.set_process(false)
		_actors.append(actor)


func _capture() -> void:
	var absolute_out := ProjectSettings.globalize_path(_out)
	var result := DirAccess.make_dir_recursive_absolute(absolute_out.path_join("frames"))
	if result != OK and result != ERR_ALREADY_EXISTS:
		_failures += 1
		push_error("EliteReadabilityPreview cannot create output")
		return
	var images: Array[Image] = []
	var times: Array[float] = []
	var started := Time.get_ticks_usec()
	var count := 1 if _still_only else 72
	for frame in range(count):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		times.append(float(Time.get_ticks_usec() - started) / 1000000.0)
		images.append(get_viewport().get_texture().get_image())
	_save_image(images[0], absolute_out.path_join("elite-readability-native.png"))
	if not _still_only:
		_save_image(images[36], absolute_out.path_join("elite-readability-settled.png"))
		for frame in range(images.size()):
			_save_image(images[frame], absolute_out.path_join("frames/readability-%03d.png" % frame))
	var writes := SaveManager.debug_save_writes - _save_writes_before
	if writes != 0:
		_failures += 1
		push_error("EliteReadabilityPreview unexpected save write")
	var examples: Array[Dictionary] = []
	for index in range(_actors.size()):
		var mark := _actors[index].get("_elite_mark") as Node2D
		examples.append({"name": _cards[index]["name"], "ids": _actors[index].elite_modifier_ids(), "world": str(_actors[index].position), "image": str(_actors[index].position * (2.0 / 3.0)), "drawn_bits": int(mark.get("last_drawn_bits"))})
	var info := {"scene": "res://tools/dev/EliteReadabilityPreview.tscn", "presentation": "Actual EnemyActors, real batching at z=10, world-sized wards, real promotion popups, frozen actor simulation only.", "viewport": [1920, 1080], "image_size": [1280, 720], "world_px_to_image_px": 2.0 / 3.0, "reduced_motion": _reduced, "frames": images.size(), "frame_timestamps_seconds": times, "actors": examples, "save_writes": writes, "failures": _failures}
	var file := FileAccess.open(absolute_out.path_join("capture-info.json"), FileAccess.WRITE)
	if file == null:
		_failures += 1
		push_error("EliteReadabilityPreview cannot write metadata")
	else:
		file.store_string(JSON.stringify(info, "\t") + "\n")
		file.close()
	print("EliteReadabilityPreview -> ", absolute_out, " frames=", images.size(), " writes=", writes, " failures=", _failures)
