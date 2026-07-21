extends Control
class_name SellMarkOverlay

enum Mode { SELL = 0, BUY = 1 }

@onready var bg: ColorRect = $BG
@onready var check: Label = $Check
@onready var price: Label = $Price

var _selected: bool = false
var _mode: int = Mode.SELL

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_selected(false)
	set_price(0)
	_apply_mode()

func set_mode(m: int) -> void:
	_mode = m
	_apply_mode()

func set_price(v: int) -> void:
	if price != null:
		price.text = str(maxi(0, int(v)))

func set_selected(v: bool) -> void:
	_set_selected(v)

func _set_selected(v: bool) -> void:
	_selected = v
	if bg != null:
		bg.visible = v
	if check != null:
		check.visible = v
	if price != null:
		price.visible = v

func _apply_mode() -> void:
	# SELL = warm/orange, BUY = teal
	if bg != null:
		bg.color = Color(1.0, 0.55, 0.20, 0.18) if _mode == Mode.SELL else Color(0.25, 1.0, 0.75, 0.16)
	if check != null:
		check.text = "−" if _mode == Mode.SELL else "+"
