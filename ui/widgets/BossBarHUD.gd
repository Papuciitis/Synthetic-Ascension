extends Control
class_name BossBarHUD

@onready var panel: PanelContainer = $Panel
@onready var portrait: TextureRect = $Panel/HBox/Portrait
@onready var title_label: Label = $Panel/HBox/VBox/Title
@onready var hp_bar: ProgressBar = $Panel/HBox/VBox/HpBar

func _ready() -> void:
	visible = false

func show_boss(title_text: String, portrait_tex: Texture2D, hp: float, max_hp: float) -> void:
	visible = true
	if title_label != null:
		title_label.text = title_text
	if portrait != null:
		portrait.texture = portrait_tex
	_set_hp(hp, max_hp)

func update_hp(hp: float, max_hp: float) -> void:
	if not visible:
		return
	_set_hp(hp, max_hp)

func hide_boss() -> void:
	visible = false

func _set_hp(hp: float, max_hp: float) -> void:
	if hp_bar == null:
		return
	hp_bar.max_value = maxf(1.0, max_hp)
	hp_bar.value = clampf(hp, 0.0, hp_bar.max_value)
