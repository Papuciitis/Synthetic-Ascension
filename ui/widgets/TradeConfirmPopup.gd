extends Control
class_name TradeConfirmPopup

signal confirmed
signal cancelled

@onready var commitment: Label = $Blocker/Center/Panel/Margin/VBox/Commitment
@onready var sell_value: Label = $Blocker/Center/Panel/Margin/VBox/Summary/Margin/Rows/Sell/Value
@onready var buy_value: Label = $Blocker/Center/Panel/Margin/VBox/Summary/Margin/Rows/Buy/Value
@onready var net_value: Label = $Blocker/Center/Panel/Margin/VBox/Summary/Margin/Rows/Net/Value
@onready var followers_value: Label = $Blocker/Center/Panel/Margin/VBox/Summary/Margin/Rows/Followers/Value
@onready var btn_close: Button = $Blocker/Center/Panel/Margin/VBox/Header/Close
@onready var btn_cancel: Button = $Blocker/Center/Panel/Margin/VBox/Actions/Cancel
@onready var btn_confirm: Button = $Blocker/Center/Panel/Margin/VBox/Actions/Confirm

var _open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	btn_close.pressed.connect(_cancel)
	btn_cancel.pressed.connect(_cancel)
	btn_confirm.pressed.connect(_confirm)


func open_trade(
	sell_amount: int,
	buy_amount: int,
	net_cost: int,
	followers_before: int,
	followers_after: int,
	commitment_line: String
) -> void:
	commitment.text = commitment_line
	sell_value.text = str(maxi(0, sell_amount))
	buy_value.text = str(maxi(0, buy_amount))

	if net_cost > 0:
		net_value.text = "-%d Followers" % net_cost
		net_value.modulate = Color(1.0, 0.62, 0.32, 1.0)
	elif net_cost < 0:
		net_value.text = "+%d Followers" % (-net_cost)
		net_value.modulate = Color(0.42, 0.9, 0.62, 1.0)
	else:
		net_value.text = "No change"
		net_value.modulate = Color(0.9, 0.9, 0.92, 1.0)

	followers_value.text = "%d  →  %d" % [maxi(0, followers_before), maxi(0, followers_after)]
	_open = true
	visible = true
	move_to_front()
	call_deferred("_focus_confirm")


func _focus_confirm() -> void:
	if _open and btn_confirm.is_visible_in_tree():
		btn_confirm.grab_focus()


func close_popup() -> void:
	_open = false
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
