extends "res://tools/dev/S10BossTelegraphPreview.gd"
## Current-delivery integration capture in the actual S10 Game. Staged,
## immortal and frozen; it verifies rendered integration, not playability.
const Acting := preload("res://scenes/world/bosses/BossActing.gd")

func _freeze(node: Node) -> void:
	# The parent arranges accepted real casts before freezing their clocks.
	# Let their visual follower observe the arranged phase and pose once.
	if node.get_script() == Acting:
		node.call("_physics_process", 0.16)
	super._freeze(node)
