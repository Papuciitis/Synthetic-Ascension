extends PanelContainer
## A HUD plate with the register's small corner diamonds drawn over its own
## box: the objective stack, the tutorial tip. It draws only when it resizes,
## which a Control redraws for anyway.

const OverlayKit := preload("res://ui/widgets/overlays/OverlayKit.gd")

@export var mark_colour: Color = Color(0.62, 0.47, 0.3, 0.95)
@export var mark_size: float = 3.0


func _draw() -> void:
	OverlayKit.draw_corner_marks(self, Rect2(Vector2(1, 1), size - Vector2(2, 2)), mark_colour, mark_size)
