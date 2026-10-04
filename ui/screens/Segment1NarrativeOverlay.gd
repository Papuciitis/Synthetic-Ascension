extends CanvasLayer
class_name Segment1NarrativeOverlay
## Segment I's chapter cards (its opening and its completion) in the front
## end's register: a near-black veil, a card in a double gold rule, a Cinzel
## Decorative title over a starred rule, Garamond body. The card eases up as
## the veil comes down; Reduced Motion leaves only the fade.

signal dismissed

const OverlayKit := preload("res://ui/widgets/overlays/OverlayKit.gd")

@onready var root: Control = $Root
@onready var eyebrow: Label = $Root/Center/Panel/Margin/VBox/Eyebrow
@onready var title: Label = $Root/Center/Panel/Margin/VBox/Title
@onready var body: Label = $Root/Center/Panel/Margin/VBox/Body
@onready var continue_button: Button = $Root/Center/Panel/Margin/VBox/Continue

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.visible = false
	continue_button.pressed.connect(_dismiss)

func present_opening(mortal_name: String) -> void:
	eyebrow.text = Segment1Text.AREA_TITLE
	title.text = Segment1Text.SEGMENT_TITLE
	body.text = Segment1Text.opening_body(mortal_name)
	continue_button.text = "Begin the synthesis"
	_present()

func present_completion(mortal_name: String) -> void:
	eyebrow.text = "AREA I — SEGMENT I COMPLETE"
	title.text = "UNAUTHORISED"
	body.text = Segment1Text.completion_body(mortal_name)
	continue_button.text = "Continue"
	_present()

## Any chapter card in this frame (the story layer's segment-10 close uses it).
func present_card(eyebrow_text: String, title_text: String, body_text: String, button_text: String) -> void:
	eyebrow.text = eyebrow_text
	title.text = title_text
	body.text = body_text
	continue_button.text = button_text
	_present()

func _present() -> void:
	root.visible = true
	var veil := root.get_node_or_null("Black") as CanvasItem
	if veil != null:
		OverlayKit.fade_in(veil, 0.3)
	var center := root.get_node_or_null("Center") as Control
	if center != null:
		OverlayKit.arrive(center, 18.0, 0.5, 0.08)
	await get_tree().process_frame
	continue_button.grab_focus()

func _dismiss() -> void:
	if not root.visible:
		return
	root.visible = false
	dismissed.emit()
