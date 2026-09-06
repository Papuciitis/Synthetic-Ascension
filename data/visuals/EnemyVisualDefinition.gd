@tool
extends Resource
class_name EnemyVisualDefinition
## One enemy archetype's sheet: stride rows per facing plus the helmet cells
## that get composited onto the headless bodies at bake time. The bake writes a
## CharacterFrameSet whose frames are already whole enemies, so the runtime
## needs one Sprite2D region per frame and nothing else.

@export var enemy_id: StringName = &"grunt"
@export var sheet: Texture2D
@export var columns: int = 8
## direction -> body row index; every column of that row is one stride frame.
@export var body_rows: Dictionary = {}
## direction -> Vector2i(row, column) of the helmet composited on that row.
@export var head_cells: Dictionary = {}
## Where the helmet's bottom edge sits, as a fraction of the neck hole's
## height measured from the hole's top edge (1.0 = hole bottom).
@export var head_seat: float = 0.85
## Stride column used as the standing frame; -1 picks the narrowest one.
@export var idle_column: int = -1

@export_group("Bake size (screen pixels)")
## On-screen height of the "down" body row band, helmet excluded.
@export var body_height_px: float = 50.0

@export_group("Runtime")
@export var fps: float = 10.0


func baked_frames_path() -> String:
	return "res://assets/textures/characters/baked/%s_frames.tres" % String(enemy_id)


func baked_atlas_path() -> String:
	return "res://assets/textures/characters/baked/%s_atlas.png" % String(enemy_id)
