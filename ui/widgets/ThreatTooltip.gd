extends PanelContainer

@onready var label: Label = $Margin/Label

func set_text(t: String) -> void:
	label.text = t
