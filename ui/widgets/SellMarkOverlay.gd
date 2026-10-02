extends Control
class_name SellMarkOverlay
## The mark a slot carries while its item is part of the trade.
##
## In a source grid (gear, backpack, the Exchanger's stock) the item has moved
## onto a pan, so the slot shows its ghost, an ember (offered) or gold
## (requested) inner rule, a diamond and the price on a dark ribbon. On a pan
## it is only the price ribbon under the item. Drawn, and only redrawn when
## something it shows changes.

const ExchangeStyle := preload("res://ui/widgets/exchange/ExchangeStyle.gd")

enum Mode { SELL = 0, BUY = 1 }

var _selected: bool = false
var _mode: int = Mode.SELL
var _price: int = 0
var _pan: bool = false
var _ghost: Texture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_mode(m: int) -> void:
	if _mode == m:
		return
	_mode = m
	queue_redraw()


func set_price(v: int) -> void:
	v = maxi(0, int(v))
	if _price == v:
		return
	_price = v
	if _selected:
		queue_redraw()


func set_selected(v: bool) -> void:
	if _selected == v:
		return
	_selected = v
	queue_redraw()


## Pan marks are only the price ribbon (the item itself is showing).
func set_pan(v: bool) -> void:
	if _pan == v:
		return
	_pan = v
	queue_redraw()


## The icon of the reserved item, drawn faintly in its emptied slot.
func set_ghost(texture: Texture2D) -> void:
	if _ghost == texture:
		return
	_ghost = texture
	if _selected:
		queue_redraw()


func _draw() -> void:
	if not _selected:
		return
	var accent := ExchangeStyle.EMBER if _mode == Mode.SELL else ExchangeStyle.GOLD_BRIGHT
	var rect := Rect2(Vector2.ZERO, size)
	if not _pan:
		if _ghost != null:
			var inset := rect.grow(-maxf(6.0, size.x * 0.12))
			draw_texture_rect(_ghost, inset, false, Color(1.0, 0.9, 0.78, 0.3))
		draw_rect(rect.grow(-2.0), Color(accent, 0.07))
		draw_rect(rect.grow(-2.5), Color(accent, 0.75), false, 1.0)
		var c := Vector2(10.0, 10.0)
		draw_colored_polygon(ExchangeStyle.diamond(c, 4.5), accent)
		draw_colored_polygon(ExchangeStyle.diamond(c, 1.6), ExchangeStyle.INK)
	var band_h := clampf(size.y * 0.24, 15.0, 20.0)
	var band := Rect2(1.0, size.y - band_h - 1.0, size.x - 2.0, band_h)
	draw_rect(band, Color(0.02, 0.015, 0.01, 0.82))
	draw_line(band.position, Vector2(band.end.x, band.position.y), Color(accent, 0.45), 1.0)
	var font := ExchangeStyle.font(&"ArcaneHeading")
	var fsize := 13 if band_h >= 17.0 else 11
	var text := ExchangeStyle.grouped(_price)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var baseline := band.position.y + band_h * 0.5 + fsize * 0.36
	draw_string(font, Vector2(band.get_center().x - w * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, accent)
