extends PanelContainer
## The Threat row's explanation on hover, in the item dossier's register: a
## square gold-ruled panel with Garamond lines. Looks are set once in _ready.

const OverlayKit := preload("res://ui/widgets/overlays/OverlayKit.gd")

@onready var label: Label = $Margin/Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override(&"panel", OverlayKit.shared(&"tip"))
	OverlayKit.style_label(label, &"body", 16, OverlayKit.BODY)
	label.add_theme_constant_override(&"line_spacing", 1)


func set_text(t: String) -> void:
	if label.text == t:
		return
	label.text = t
	# Fit the panel to the new lines; a panel only grows on its own.
	reset_size()


## Four small diamonds on the panel's corners (redrawn only on resize).
func _draw() -> void:
	OverlayKit.draw_corner_marks(self, Rect2(Vector2(1, 1), size - Vector2(2, 2)), Color(OverlayKit.GOLD_DIM, 0.95), 3.0)
