@tool
extends Resource
class_name RaceVisualDefinition
## One playable race's character art, described as the sheets actually are:
## which source PNGs to cut, which row/column holds which facing, how large the
## baked frames should be on screen, and the runtime presentation numbers.
## `tools/bake_character_atlases.gd` reads this and writes the CharacterFrameSet
## the player draws from; edit here, then re-bake.
##
## Cells are Vector2i(row, column). Rows are detected from the art (alpha bands),
## so a sheet whose rows are unevenly spaced still maps correctly.

const DIRECTIONS: Array[StringName] = [&"down", &"left", &"up", &"right"]

@export var race_id: StringName = &"human"

@export_group("Idle sheet")
@export var idle_sheet: Texture2D
@export var idle_columns: int = 2
## direction -> Array of Vector2i(row, column) cells, in playback order.
@export var idle_cells: Dictionary = {}

@export_group("Run sheet")
@export var run_sheet: Texture2D
@export var run_columns: int = 8
## direction -> row index; every column of that row is one stride frame.
@export var run_rows: Dictionary = {}

@export_group("Head sheet")
@export var head_sheet: Texture2D
@export var head_columns: int = 2
## direction -> Vector2i(row, column). A direction with no cell is baked by
## mirroring its opposite; the bake records that in CharacterFrameSet.mirrored.
@export var head_cells: Dictionary = {}
## Optional direction -> Vector2i(row, column) shown instead while running.
@export var head_run_cells: Dictionary = {}

@export_group("Bake size (screen pixels)")
## On-screen height of the idle "down" row band: the standing, headless body.
@export var idle_height_px: float = 48.0
## On-screen height of the run "down" row band. 0 = scale the run sheet so its
## collar is as wide as the idle collar, which keeps the head fitting both.
@export var run_height_px: float = 0.0
## On-screen height of the "down" head cell (hair to scarf bottom).
@export var head_height_px: float = 42.0

@export_group("Runtime")
## Per-direction nudge (screen px) added to the measured collar point when the
## head is placed. Keys are direction names; missing = no nudge.
@export var head_offsets: Dictionary = {}
@export var run_fps: float = 10.0
## Seconds for one full idle pose cycle; matches the breathing loop length.
@export var idle_cycle_seconds: float = 2.4


func baked_frames_path() -> String:
	return "res://assets/textures/characters/baked/%s_frames.tres" % String(race_id)


func baked_atlas_path() -> String:
	return "res://assets/textures/characters/baked/%s_atlas.png" % String(race_id)


func head_offset(direction: StringName) -> Vector2:
	var value: Variant = head_offsets.get(String(direction), Vector2.ZERO)
	return value if value is Vector2 else Vector2.ZERO
