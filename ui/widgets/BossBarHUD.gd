extends Control
class_name BossBarHUD

## The boss's name and life across the top of the screen, in the register:
## a gold-ruled plate, the name in the sacred face, and a crimson bar that
## keeps the chunk a hit took lit for a moment (HudBarDecor).

@onready var panel: PanelContainer = $Panel
@onready var portrait: TextureRect = $Panel/HBox/Portrait
@onready var title_label: Label = $Panel/HBox/VBox/Title
@onready var hp_bar: ProgressBar = $Panel/HBox/VBox/HpBar
@onready var _track: Control = get_node_or_null("Panel/HBox/VBox/HpBar/HpTrack") as Control
@onready var _frame: Control = get_node_or_null("Panel/HBox/VBox/HpBar/HpFrame") as Control
## The trail marks a real loss only, never a change of the boss's maximum.
var _last_hp: float = -1.0

func _ready() -> void:
	visible = false

func show_boss(title_text: String, portrait_tex: Texture2D, hp: float, max_hp: float) -> void:
	visible = true
	if title_label != null:
		title_label.text = title_text
	if portrait != null:
		portrait.texture = portrait_tex
		portrait.visible = portrait_tex != null
	_set_hp(hp, max_hp, false)

func update_hp(hp: float, max_hp: float) -> void:
	if not visible:
		return
	_set_hp(hp, max_hp, true)

func hide_boss() -> void:
	visible = false

func _set_hp(hp: float, max_hp: float, animate: bool = true) -> void:
	if hp_bar == null:
		return
	hp_bar.max_value = maxf(1.0, max_hp)
	hp_bar.value = clampf(hp, 0.0, hp_bar.max_value)
	var ratio := float(hp_bar.value / hp_bar.max_value)
	var hurt := animate and hp < _last_hp - 0.001
	_last_hp = hp
	for decor: Control in [_track, _frame]:
		if decor != null:
			decor.call("set_ratio", ratio, hurt)
