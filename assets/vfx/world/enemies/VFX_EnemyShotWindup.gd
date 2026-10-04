extends Node2D
class_name VFX_EnemyShotWindup

## The wind-up tell before an enemy shooter fires (audit 2026-10-04,
## change 7): Spitters fired the instant cooldown and line of sight allowed,
## with a same-frame muzzle flash as the only cue. EnemyShooter now holds
## each shot for a quarter second and drives this tell through it: a ring
## closing onto the muzzle while a core swells there, in the shooter's
## palette, brightest just before release. One persistent child per shooter,
## shown and hidden, never instanced per shot.
##
## Not scaled by the Combat Flashes setting: it is the warning, not a flash.

const MUZZLE_OFFSET := 14.0
const RING_FROM := 26.0
const RING_TO := 7.0
const CORE_FROM := 2.0
const CORE_TO := 6.5

var _progress := 0.0
var _dir := Vector2.RIGHT
var _core := Color(0.95, 0.98, 1.0, 0.95)
var _ring := Color(0.25, 0.65, 1.0, 0.8)


func _ready() -> void:
	z_index = 6
	material = null  # pixel-art kit: the sprites blend normally
	visible = false


## Shooter palettes match VFX_EnemyMuzzleFlash, so the tell and the flash
## read as one action.
func configure(style_id: StringName) -> void:
	match style_id:
		&"enemy_spitter":
			_core = Color(0.75, 1.0, 0.25, 0.95)
			_ring = Color(0.2, 0.9, 0.3, 0.85)
		&"enemy_herald":
			_core = Color(1.0, 0.7, 0.35, 0.95)
			_ring = Color(1.0, 0.45, 0.15, 0.85)
		_:
			_core = Color(0.95, 0.98, 1.0, 0.95)
			_ring = Color(1.0, 0.35, 0.25, 0.85)


## `progress` runs 0 -> 1 across the wind-up; `dir` points at the target.
func show_progress(progress: float, dir: Vector2) -> void:
	_progress = clampf(progress, 0.0, 1.0)
	if dir.length_squared() > 0.0001:
		_dir = dir.normalized()
	# The parent body may rotate; the tell is placed in world terms.
	rotation = -get_parent().global_rotation if get_parent() is Node2D else 0.0
	visible = true
	queue_redraw()


func hide_tell() -> void:
	visible = false


func progress() -> float:
	return _progress if visible else 0.0


func _draw() -> void:
	var at := _dir * MUZZLE_OFFSET
	var p := _progress
	VfxKit.draw_ring(self, at, lerpf(RING_FROM, RING_TO, p), Color(_ring.r, _ring.g, _ring.b, _ring.a * (0.35 + 0.65 * p)))
	VfxKit.draw_disc(self, at, lerpf(CORE_FROM, CORE_TO, p), Color(_core.r, _core.g, _core.b, _core.a * (0.4 + 0.6 * p)))
