extends Resource
class_name CharacterFrameSet
## Output of tools/bake_character_atlases.gd: game-resolution frames cut from
## the source sheets, the pixel each frame hangs from, and (bodies only) where
## the collar sits in every frame so a separately drawn head can follow the
## stride. Generated; edit the RaceVisualDefinition / EnemyVisualDefinition
## and re-bake instead of editing this.

@export var frames: SpriteFrames
## animation name -> PackedVector2Array: the pixel inside each frame that sits
## on the node origin (the ground line under the collar for bodies, the scarf
## bottom for heads).
@export var anchors: Dictionary = {}
## body animation name -> PackedVector2Array: collar centre per frame,
## relative to the origin.
@export var collars: Dictionary = {}
## Animations produced by mirroring another facing because the sheet has no
## art for that facing.
@export var mirrored: PackedStringArray = PackedStringArray()


func has_animation(animation: StringName) -> bool:
	return frames != null and frames.has_animation(animation)


func frame_count(animation: StringName) -> int:
	return frames.get_frame_count(animation) if has_animation(animation) else 0


func anchor(animation: StringName, frame: int) -> Vector2:
	return _lookup(anchors, animation, frame)


func collar(animation: StringName, frame: int) -> Vector2:
	return _lookup(collars, animation, frame)


func _lookup(table: Dictionary, animation: StringName, frame: int) -> Vector2:
	var value: Variant = table.get(String(animation))
	if not (value is PackedVector2Array):
		return Vector2.ZERO
	var points := value as PackedVector2Array
	if points.is_empty():
		return Vector2.ZERO
	return points[clampi(frame, 0, points.size() - 1)]
