class_name PlayerVisualController
extends Node2D
## The player's directional idle/run presentation: a body sprite and a head
## sprite on its own anchor, both fed from the selected race's baked
## CharacterFrameSet and driven by the gameplay body's velocity. Purely visual:
## it never moves the player, and it cancels the body's rotation so the art
## stays upright while the CharacterBody2D keeps turning for the dash and
## slash logic that read `rotation`.
##
## Adding a state later (attack, cast, hit, death, ...) is a new State value,
## its name in STATE_NAMES and baked `body_<state>_<facing>` /
## `head_<state>_<facing>` frames; anything missing falls back to idle for the
## same facing, so a partially drawn state still shows something sane.

signal visual_changed(body_animation: StringName, head_animation: StringName, facing: StringName)

enum State { IDLE, RUN }

const STATE_NAMES: Dictionary = {
	State.IDLE: "idle",
	State.RUN: "run",
}
const FACING_DOWN := &"down"
const FACING_LEFT := &"left"
const FACING_UP := &"up"
const FACING_RIGHT := &"right"
## Race id (Global.selected_race_id / RaceData.id) -> visual definition.
const RACE_DEFINITIONS: Dictionary = {
	&"human": "res://data/visuals/races/human.tres",
	&"elf": "res://data/visuals/races/elf.tres",
	&"dragonborn": "res://data/visuals/races/dragonborn.tres",
	&"warforged": "res://data/visuals/races/warforged.tres",
}
const DEFAULT_RACE := &"human"
## A movement axis must beat the other by this factor before the facing
## changes axis, so a near-diagonal path does not flicker between facings.
const AXIS_BIAS := 1.25
const MOVING_SPEED_SQ := 1.0
const BREATHE := &"breathe"

@onready var body: AnimatedSprite2D = $Body
@onready var head_anchor: Node2D = $HeadAnchor
@onready var head: AnimatedSprite2D = $HeadAnchor/Head
@onready var breath: AnimationPlayer = $AnimationPlayer

var race_id: StringName = &""
var definition: RaceVisualDefinition = null
var frame_set: CharacterFrameSet = null
var state: State = State.IDLE
var facing: StringName = FACING_DOWN
var body_animation: StringName = &""
var head_animation: StringName = &""

var _horizontal := false
var _preview := false
var _preview_state: State = State.IDLE
var _preview_facing: StringName = FACING_DOWN


func _ready() -> void:
	var selected := DEFAULT_RACE
	if Global != null and not String(Global.selected_race_id).is_empty():
		selected = StringName(Global.selected_race_id)
	set_race(selected)


func _process(_delta: float) -> void:
	var parent := get_parent() as Node2D
	if parent != null:
		rotation = -parent.rotation
	if _preview:
		facing = _preview_facing
		state = _preview_state
	else:
		var velocity := Vector2.ZERO
		if parent is CharacterBody2D:
			velocity = (parent as CharacterBody2D).velocity
		_update_facing(velocity)
		state = State.RUN if velocity.length_squared() > MOVING_SPEED_SQ else State.IDLE
	_apply()


## Swaps every sprite to another race's art. The current state and facing
## carry over, so a race change mid-pose keeps the pose.
func set_race(id: StringName) -> bool:
	var path: String = RACE_DEFINITIONS.get(id, "")
	if path.is_empty():
		push_warning("PlayerVisualController: no visual definition for race '%s'; showing %s" % [id, DEFAULT_RACE])
		id = DEFAULT_RACE
		path = RACE_DEFINITIONS[DEFAULT_RACE]
	var next_definition := load(path) as RaceVisualDefinition
	if next_definition == null:
		push_error("PlayerVisualController: cannot load " + path)
		return false
	var frames_path := next_definition.baked_frames_path()
	if not ResourceLoader.exists(frames_path):
		push_error("PlayerVisualController: %s is not baked; run tools/bake_character_atlases.gd then --import" % frames_path)
		return false
	var next_frames := load(frames_path) as CharacterFrameSet
	if next_frames == null or next_frames.frames == null:
		push_error("PlayerVisualController: %s holds no frames" % frames_path)
		return false
	race_id = id
	definition = next_definition
	frame_set = next_frames
	body.sprite_frames = frame_set.frames
	head.sprite_frames = frame_set.frames
	body_animation = &""
	head_animation = &""
	if is_node_ready():
		_apply()
	return true


## Dev tooling: show a state and facing regardless of movement.
func set_preview(preview_state: State, preview_facing: StringName) -> void:
	_preview = true
	_preview_state = preview_state
	_preview_facing = preview_facing


func clear_preview() -> void:
	_preview = false


func _update_facing(velocity: Vector2) -> void:
	if velocity.length_squared() <= MOVING_SPEED_SQ:
		return
	var ax := absf(velocity.x)
	var ay := absf(velocity.y)
	if _horizontal:
		if ay > ax * AXIS_BIAS:
			_horizontal = false
	elif ax > ay * AXIS_BIAS:
		_horizontal = true
	if _horizontal:
		facing = FACING_LEFT if velocity.x < 0.0 else FACING_RIGHT
	else:
		facing = FACING_UP if velocity.y < 0.0 else FACING_DOWN


func _apply() -> void:
	if frame_set == null or body == null:
		return
	var state_name: String = STATE_NAMES[state]
	var next_body := _resolve(&"body", state_name)
	var next_head := _resolve(&"head", state_name)
	if next_body == &"" or next_head == &"":
		return
	var changed := false
	if next_body != body_animation:
		body_animation = next_body
		body.play(next_body)
		# Standing still breathes; the loop restarts with the pose so the head
		# lift lands on the same beat as the pose change.
		breath.stop()
		head.position = Vector2.ZERO
		if state == State.IDLE:
			breath.play(BREATHE)
		changed = true
	if next_head != head_animation:
		head_animation = next_head
		head.play(next_head)
		head.offset = -frame_set.anchor(next_head, 0)
		changed = true
	# Feet stay on the origin; the head rides the collar of the current frame.
	body.offset = -frame_set.anchor(body_animation, body.frame)
	head_anchor.position = frame_set.collar(body_animation, body.frame) + definition.head_offset(facing)
	if changed:
		visual_changed.emit(body_animation, head_animation, facing)


func _resolve(layer: StringName, state_name: String) -> StringName:
	var candidates: Array[StringName] = [
		StringName("%s_%s_%s" % [layer, state_name, facing]),
		StringName("%s_idle_%s" % [layer, facing]),
		StringName("%s_idle_%s" % [layer, FACING_DOWN]),
	]
	for candidate in candidates:
		if frame_set.has_animation(candidate):
			return candidate
	return &""
