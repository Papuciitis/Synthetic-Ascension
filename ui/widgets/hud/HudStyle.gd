extends RefCounted
## The combat HUD's share of the front-end register (docs/design/
## 2026-10-02-front-end-arcane-register.md): the palette, the rarity colours
## and the slot states the HUD paints. Each slot owns one box that
## paint_slot() rewrites only when its state changes; the panels and tracks
## live in HUD.tscn / BagUI.tscn and the typography in SyntheticHudTheme's
## type variations.
##
## Preload by path; no class_name.

const PARCHMENT := Color(0.91, 0.86, 0.77)
const BODY := Color(0.82, 0.77, 0.68)
const MUTED := Color(0.62, 0.56, 0.47)
const GOLD := Color(0.86, 0.64, 0.36)
const GOLD_DIM := Color(0.62, 0.47, 0.30)
const GOLD_BRIGHT := Color(0.99, 0.84, 0.58)
const CAPTION := Color(0.72, 0.58, 0.40)
const INK := Color(0.13, 0.08, 0.045)
const PANEL := Color(0.032, 0.028, 0.025)
const EMBER := Color(1.0, 0.62, 0.30)
const ARCANE := Color(0.42, 0.62, 1.0)
const DANGER := Color(0.86, 0.32, 0.24)
## The health fill: a deep blood-crimson that leans toward the embers.
const VITAL := Color(0.66, 0.16, 0.12)
const VITAL_LIGHT := Color(0.93, 0.42, 0.30)
const VITAL_DARK := Color(0.30, 0.06, 0.05)

enum Slot { EMPTY, FILLED, HOVER, HOVER_EMPTY, LOCKED }

## Rarity colours, muted toward the panel so they sit in the register; the
## same hues the old slots used, so r1..r4 keep their meaning.
static func rarity_colour(r: int) -> Color:
	if r <= -2:
		return Color(0.55, 0.12, 0.10)
	if r == -1:
		return Color(0.80, 0.26, 0.20)
	if r == 0:
		return Color(0, 0, 0, 0)
	if r == 1:
		return Color(0.42, 0.74, 0.42)
	if r == 2:
		return Color(0.42, 0.62, 1.0)
	if r == 3:
		return Color(0.70, 0.46, 0.92)
	return Color(1.0, 0.70, 0.30)


## A fresh slot box in one of the Exchange's socket states. Callers that tint
## a slot in place (InventoryBar, BagSlot) own their copy; paint_slot()
## writes a state into it.
static func make_slot(state: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(1)
	sb.set_border_width_all(1)
	paint_slot(sb, state)
	return sb


static func paint_slot(sb: StyleBoxFlat, state: int) -> void:
	if sb == null:
		return
	var bg := Color(0.018, 0.016, 0.014, 0.78)
	var border := Color(GOLD_DIM, 0.26)
	var width := 1
	var glow := Color(0, 0, 0, 0)
	var glow_size := 0
	match state:
		Slot.FILLED:
			bg = Color(0.07, 0.056, 0.043, 0.94)
			border = Color(GOLD_DIM, 0.66)
		Slot.HOVER:
			bg = Color(0.13, 0.086, 0.05, 0.98)
			border = GOLD_BRIGHT
			glow = Color(1.0, 0.66, 0.3, 0.22)
			glow_size = 9
		Slot.HOVER_EMPTY:
			bg = Color(0.05, 0.038, 0.028, 0.86)
			border = Color(GOLD, 0.6)
		Slot.LOCKED:
			bg = Color(0.07, 0.056, 0.043, 0.94)
			border = Color(1.0, 0.76, 0.34, 0.9)
			width = 2
	if sb.bg_color != bg:
		sb.bg_color = bg
	if sb.border_color != border:
		sb.border_color = border
	if sb.border_width_left != width:
		sb.set_border_width_all(width)
	if sb.shadow_color != glow:
		sb.shadow_color = glow
	if sb.shadow_size != glow_size:
		sb.shadow_size = glow_size


static func diamond(center: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)])


## 6000 -> "6,000". Negative values keep their sign.
static func grouped(value: int) -> String:
	var negative := value < 0
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if negative else "") + digits + out
