extends PanelContainer
class_name RunSheetHUD

@onready var hpv: Label = $Margin/VBox/StatsGrid/HPV
@onready var armv: Label = $Margin/VBox/StatsGrid/ARMV
@onready var spdv: Label = $Margin/VBox/StatsGrid/SPDV
@onready var powv: Label = $Margin/VBox/StatsGrid/POWV
@onready var hstv: Label = $Margin/VBox/StatsGrid/HSTV
@onready var lckv: Label = $Margin/VBox/StatsGrid/LCKV

@onready var hpd: Label = $Margin/VBox/StatsGrid/HPD
@onready var armd: Label = $Margin/VBox/StatsGrid/ARMD
@onready var spdd: Label = $Margin/VBox/StatsGrid/SPDD
@onready var powd: Label = $Margin/VBox/StatsGrid/POWD
@onready var hstd: Label = $Margin/VBox/StatsGrid/HSTD
@onready var lckd: Label = $Margin/VBox/StatsGrid/LCKD

@onready var sets_vbox: VBoxContainer = $Margin/VBox/SetsVBox

const ACCENT := Color(1.0, 0.55, 0.20, 1.0)

func refresh(player: Node, inv: Inventory) -> void:
	# Player.stats is already the complete final snapshot: race, style, permanent
	# augments, attempt modifiers, equipped item deltas, set tiers, item effects
	# and active percentage rolls. Inventory deltas must not be added a second time.
	var max_hp_total: float = _get_num(player, "max_hp", _get_stats_num(player, "max_hp", 0.0))
	var armor_total: float = _get_stats_num(player, "armor", _get_num(player, "armor", 0.0))
	var stored_spd: float = _get_stats_num(player, "move_speed", _get_num(player, "speed", 0.0))
	var spd_total: float = _get_effective_move_speed(player, stored_spd)
	var pow_total: float = _get_stats_num(player, "power", _get_num(player, "power", 0.0))
	var hst_total: float = _get_stats_num(player, "haste", _get_num(player, "haste", 0.0))
	var lck_total: float = _get_stats_num(player, "luck", _get_num(player, "luck", 0.0))

	# Parenthesised values remain the equipped flat deltas for quick attribution;
	# they are informational only and are not added to the final totals again.
	var d := StatDelta.new()
	if inv != null and inv.has_method("sum_mods"):
		d = inv.sum_mods()

	# --- totals ---
	var cur_hp: float = _get_num(player, "hp", -1.0)
	if cur_hp >= 0.0:
		hpv.text = "%d / %d" % [int(round(cur_hp)), int(round(maxf(1.0, max_hp_total)))]
	else:
		hpv.text = str(int(round(maxf(1.0, max_hp_total))))

	armv.text = str(int(round(armor_total)))
	spdv.text = str(int(round(spd_total)))
	powv.text = _fmt_pct_fraction(pow_total)
	hstv.text = _fmt_pct_fraction(hst_total)
	lckv.text = _fmt_pct_fraction(lck_total)

	# --- deltas (from items) ---
	hpd.text = _fmt_int_delta(d.max_hp)      # show max hp delta
	armd.text = _fmt_int_delta(d.armor)
	spdd.text = _fmt_int_delta(d.move_speed)
	powd.text = _fmt_pct_delta(d.power)
	hstd.text = _fmt_pct_delta(d.haste)
	lckd.text = _fmt_pct_delta(d.luck)

	# --- sets ---
	for c in sets_vbox.get_children():
		c.queue_free()

	if inv == null:
		return

	var counts: Dictionary = {}
	if inv.has_method("get_set_counts"):
		counts = inv.get_set_counts()
	else:
		for it in inv.items:
			var inst := it as ItemInstance
			if inst == null or inst.data == null:
				continue
			var sid := String(inst.data.set_id)
			if sid == "":
				continue
			counts[sid] = int(counts.get(sid, 0)) + 1

	for sid in counts.keys():
		var n: int = int(counts[sid])
		var line := Label.new()
		line.add_theme_font_size_override("font_size", 12)
		line.text = "%s %d/6" % [String(sid).to_upper(), n]
		line.modulate = (ACCENT if n >= 6 else Color(1, 1, 1, 0.85))
		sets_vbox.add_child(line)

# ---------------------------d
# ---------------------------

func _fmt_int_delta(x: float) -> String:
	var v: int = int(round(x))
	if v == 0:
		return ""
	return "(%+d)" % v

func _fmt_pct_delta(x: float) -> String:
	# x is fraction: 0.20 => +20%
	var p: float = x * 100.0
	if is_equal_approx(p, 0.0):
		return ""
	if absf(p) < 0.01:
		return "(+<0.01%)" if p > 0.0 else "(−<0.01%)"
	if is_equal_approx(p, float(int(p))):
		return "(%+.0f%%)" % p
	return "(%+.2f%%)" % p

func _fmt_pct_fraction(x: float) -> String:
	# x is fraction: 0.20 => +20%
	var p: float = x * 100.0
	if is_equal_approx(p, 0.0):
		return "0%"
	if absf(p) < 0.01:
		return "+<0.01%" if p > 0.0 else "−<0.01%"
	if is_equal_approx(p, float(int(p))):
		return "%+.0f%%" % p
	return "%+.2f%%" % p

# ---------------------------
# Safe getters
# ---------------------------

func _get_num(obj: Object, prop: String, fallback: float) -> float:
	if obj == null:
		return fallback
	var v: Variant = obj.get(prop)
	if v is float or v is int:
		return float(v)
	return fallback

func _get_effective_move_speed(player: Object, fallback: float) -> float:
	if player == null:
		return fallback
	if player.has_method("get_effective_move_speed"):
		var value: Variant = player.call("get_effective_move_speed")
		if value is float or value is int:
			return float(value)
	return fallback


func _get_stats_num(player: Object, prop: String, fallback: float) -> float:
	if player == null:
		return fallback
	var stats: Variant = player.get("stats")
	if stats == null:
		return fallback
	if stats is Object:
		var v: Variant = (stats as Object).get(prop)
		if v is float or v is int:
			return float(v)
	return fallback
