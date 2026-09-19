extends CPUParticles2D
class_name VfxBurst

## A one-shot textured particle burst (the CC0 Kenney particle textures
## under assets/vfx/particles/kenney) that lives in the PoolManager through
## PooledVfx: play() places and restarts it, `finished` hands it back.
## Cheap by construction: a few sprites on one additive material, no nodes
## created or freed per burst after the first.

## Blend additively (light, sparks, magic); off for smoke and dust.
@export var additive := true

var _released := false


func _ready() -> void:
	if additive:
		material = PooledVfx.additive_material()
	if not finished.is_connected(_on_finished):
		finished.connect(_on_finished)


## Places the burst and fires it. `size` scales the whole burst, `tint`
## multiplies its colours, `dir` (when set) aims the emission.
func play(pos: Vector2, size: float = 1.0, tint: Color = Color.WHITE, dir: Vector2 = Vector2.ZERO) -> void:
	global_position = pos
	scale = Vector2.ONE * maxf(0.05, size)
	modulate = tint
	if dir != Vector2.ZERO:
		direction = dir.normalized()
	_released = false
	restart()


func _on_pool_obtain() -> void:
	_released = false


func _on_pool_recycle() -> void:
	emitting = false


func _on_finished() -> void:
	if _released:
		return
	_released = true
	PooledVfx.release(self)
