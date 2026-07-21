extends CanvasLayer
class_name Segment1NarrativeOverlay

signal dismissed

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

func _present() -> void:
	root.visible = true
	await get_tree().process_frame
	continue_button.grab_focus()

func _dismiss() -> void:
	if not root.visible:
		return
	root.visible = false
	dismissed.emit()
