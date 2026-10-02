extends Control
class_name TradeConfirmPopup
## The last look before a trade is sealed: what goes, what comes, and the
## Followers before and after. A veil, an ornamented panel and two choices in
## the front-end register; Enter seals, Escape returns to the cart.

signal confirmed
signal cancelled

const ArcaneFrameScript := preload("res://ui/components/ArcaneFrame.gd")
const ArcaneMotion := preload("res://ui/widgets/ArcaneMotion.gd")
const ExchangeStyle := preload("res://ui/widgets/exchange/ExchangeStyle.gd")

@onready var panel: PanelContainer = $Blocker/Center/Panel
@onready var commitment: Label = $Blocker/Center/Panel/Margin/VBox/Commitment
@onready var sell_value: Label = $Blocker/Center/Panel/Margin/VBox/Summary/Margin/Rows/Sell/Value
@onready var buy_value: Label = $Blocker/Center/Panel/Margin/VBox/Summary/Margin/Rows/Buy/Value
@onready var net_value: Label = $Blocker/Center/Panel/Margin/VBox/Summary/Margin/Rows/Net/Value
@onready var followers_value: Label = $Blocker/Center/Panel/Margin/VBox/Summary/Margin/Rows/Followers/Value
@onready var btn_close: Button = $Blocker/Center/Panel/Margin/VBox/Header/Close
@onready var btn_cancel: Button = $Blocker/Center/Panel/Margin/VBox/Actions/Cancel
@onready var btn_confirm: Button = $Blocker/Center/Panel/Margin/VBox/Actions/Confirm

var _open: bool = false
var _tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	btn_close.pressed.connect(_cancel)
	btn_cancel.pressed.connect(_cancel)
	btn_confirm.pressed.connect(_confirm)
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size * 0.5)
	var frame := ArcaneFrameScript.new()
	frame.set("glow", 0.25)
	panel.add_child(frame)
	ExchangeStyle.style_button(btn_cancel, ExchangeStyle.Btn.SMALL, 15)
	ExchangeStyle.style_button(btn_confirm, ExchangeStyle.Btn.PRIMARY, 16)
	ExchangeStyle.style_button(btn_close, ExchangeStyle.Btn.SMALL, 16)
	btn_close.add_theme_constant_override(&"h_separation", 0)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var sb := btn_close.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		if sb != null:
			sb.content_margin_left = 0.0
			sb.content_margin_right = 0.0
			sb.content_margin_top = 0.0
			sb.content_margin_bottom = 2.0
			btn_close.add_theme_stylebox_override(state, sb)


func open_trade(
	sell_amount: int,
	buy_amount: int,
	net_cost: int,
	followers_before: int,
	followers_after: int,
	commitment_line: String
) -> void:
	commitment.text = commitment_line
	sell_value.text = ExchangeStyle.grouped(maxi(0, sell_amount))
	buy_value.text = ExchangeStyle.grouped(maxi(0, buy_amount))

	if net_cost > 0:
		net_value.text = "−%s Followers" % ExchangeStyle.grouped(net_cost)
		net_value.modulate = ExchangeStyle.EMBER
	elif net_cost < 0:
		net_value.text = "+%s Followers" % ExchangeStyle.grouped(-net_cost)
		net_value.modulate = ExchangeStyle.GOLD_BRIGHT
	else:
		net_value.text = "No change"
		net_value.modulate = ExchangeStyle.PARCHMENT

	followers_value.text = "%s  →  %s" % [ExchangeStyle.grouped(maxi(0, followers_before)), ExchangeStyle.grouped(maxi(0, followers_after))]
	_open = true
	visible = true
	move_to_front()
	_play_open()
	call_deferred("_focus_confirm")


## The veil fades up and the panel settles from a hair smaller (fade only
## under reduced motion).
func _play_open() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	panel.pivot_offset = panel.size * 0.5
	var still := ArcaneMotion.reduced()
	panel.scale = Vector2.ONE if still else Vector2(0.96, 0.96)
	_tween = create_tween().set_ignore_time_scale(true).set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.16)
	if not still:
		_tween.tween_property(panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _focus_confirm() -> void:
	if _open and btn_confirm.is_visible_in_tree():
		btn_confirm.grab_focus()


func close_popup() -> void:
	_open = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 1.0
	if panel != null:
		panel.scale = Vector2.ONE
	visible = false


func _cancel() -> void:
	if not _open:
		return
	close_popup()
	cancelled.emit()


func _confirm() -> void:
	if not _open:
		return
	close_popup()
	confirmed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_cancel"):
		_cancel()
		get_viewport().set_input_as_handled()
