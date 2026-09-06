extends Node2D
## Dev tool: walk each race around, watch the idle breathe, check head/body
## alignment and the enemy stride frames. Not part of the game.
##
##   1-4      switch race            Tab    cycle a held facing (idle)
##   Space    toggle held run        P      release the hold (movement drives again)
##   F5       write a screenshot set to user://character_shots/
##
## Headless-ish capture:  godot --path . res://tools/dev/CharacterAnimationTest.tscn -- --shots=/abs/dir

const RACES: Array[StringName] = [&"human", &"elf", &"dragonborn", &"warforged"]
const FACINGS: Array[StringName] = [&"down", &"left", &"up", &"right"]
const ENEMY_FRAMES: Dictionary = {
	"grunt": "res://assets/textures/characters/baked/grunt_frames.tres",
	"spitter": "res://assets/textures/characters/baked/spitter_frames.tres",
}
const ENEMY_WALK_SPEED := 60.0
const ENEMY_TURN_SECONDS := 2.0

@export var camera_zoom := 3.0

@onready var player: CharacterBody2D = $Player
@onready var label: Label = $HUD/Label

var _visual: PlayerVisualController = null
var _enemies: Array[Dictionary] = []
var _held_facing := -1
var _held_run := false
var _enemy_clock := 0.0


func _ready() -> void:
	_visual = player.get_node("Visual") as PlayerVisualController
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.zoom = Vector2(camera_zoom, camera_zoom)
		camera.position_smoothing_enabled = false
	var x := -150.0
	for id in ENEMY_FRAMES:
		var frame_set := load(ENEMY_FRAMES[id]) as CharacterFrameSet
		var sprite := Sprite2D.new()
		sprite.position = Vector2(x, 0.0)
		add_child(sprite)
		var animator := EnemyAnimator.new()
		if frame_set == null or not animator.setup(sprite, sprite, frame_set, 10.0):
			push_warning("CharacterAnimationTest: no baked frames for " + String(id))
		_enemies.append({"sprite": sprite, "animator": animator})
		x += 300.0
	var shots_dir := _shots_argument()
	if not shots_dir.is_empty():
		_capture_set(shots_dir, true)


func _process(delta: float) -> void:
	_enemy_clock += delta
	var phase := fmod(_enemy_clock, ENEMY_TURN_SECONDS * 3.0)
	var velocity := Vector2.ZERO
	if phase < ENEMY_TURN_SECONDS:
		velocity = Vector2(0.0, ENEMY_WALK_SPEED)
	elif phase < ENEMY_TURN_SECONDS * 2.0:
		velocity = Vector2(0.0, -ENEMY_WALK_SPEED)
	for enemy in _enemies:
		(enemy["animator"] as EnemyAnimator).tick(velocity)
	queue_redraw()
	if _visual != null:
		label.text = "race %s   body %s   head %s   facing %s   %s" % [
			_visual.race_id, _visual.body_animation, _visual.head_animation, _visual.facing,
			"held (P releases)" if _held_facing >= 0 else "1-4 race, Tab hold facing, Space run, F5 shots",
		]


func _draw() -> void:
	# Ground line through the player's origin: the feet must sit on it.
	var origin := player.position + Vector2(0.0, PlayerVisualController.FEET_BELOW_ORIGIN)
	draw_line(origin + Vector2(-400.0, 0.5), origin + Vector2(400.0, 0.5), Color(0.2, 0.9, 0.4, 0.5), 1.0)
	draw_line(origin + Vector2(0.5, -80.0), origin + Vector2(0.5, 20.0), Color(0.9, 0.4, 0.2, 0.35), 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).keycode
	if key >= KEY_1 and key <= KEY_4:
		_visual.set_race(RACES[key - KEY_1])
	elif key == KEY_TAB:
		_held_facing = (_held_facing + 1) % FACINGS.size()
		_hold()
	elif key == KEY_SPACE:
		_held_run = not _held_run
		if _held_facing < 0:
			_held_facing = 0
		_hold()
	elif key == KEY_P:
		_held_facing = -1
		_visual.clear_preview()
	elif key == KEY_F5:
		_capture_set(ProjectSettings.globalize_path("user://character_shots"), false)


func _hold() -> void:
	var state := PlayerVisualController.State.RUN if _held_run else PlayerVisualController.State.IDLE
	_visual.set_preview(state, FACINGS[_held_facing])


func _shots_argument() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shots="):
			return argument.trim_prefix("--shots=")
	return ""


## Every race x state x facing, plus two beats of the idle so the breathing
## shows, then the current view of the enemies.
func _capture_set(directory: String, quit_after: bool) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var viewport := get_viewport()
	for race in RACES:
		_visual.set_race(race)
		for state_name in ["idle", "run"]:
			var state := PlayerVisualController.State.IDLE if state_name == "idle" else PlayerVisualController.State.RUN
			for facing in FACINGS:
				_visual.set_preview(state, facing)
				for _i in range(4):
					await get_tree().process_frame
				_save(viewport, "%s/%s_%s_%s.png" % [directory, race, state_name, facing])
				if state == PlayerVisualController.State.RUN:
					for _i in range(9):
						await get_tree().process_frame
					_save(viewport, "%s/%s_%s_%s_b.png" % [directory, race, state_name, facing])
		_visual.set_preview(PlayerVisualController.State.IDLE, &"down")
		await get_tree().create_timer(1.1).timeout
		_save(viewport, "%s/%s_idle_down_breath.png" % [directory, race])
	_visual.clear_preview()
	print("CharacterAnimationTest: screenshots written to ", directory)
	if quit_after:
		get_tree().quit()


func _save(viewport: Viewport, path: String) -> void:
	var image := viewport.get_texture().get_image()
	if image != null:
		image.save_png(path)
