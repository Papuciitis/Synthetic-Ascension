extends Resource
class_name AugmentData

@export var id: StringName

@export var display_name: String = "Augment"
@export_multiline var description: String = ""

# Short text used on the selection card (the gray box).
# Keep it ~1–2 lines. Full explanation + numbers go in `description` + `details`.
@export_multiline var card_blurb: String = ""
@export_multiline var details: String = ""
@export var icon: Texture2D

# Optional stat changes (uses your existing StatDelta)
@export var mods: StatDelta = null

# If > 0, the StatDelta `mods` scales by stat_level_factor: the full rate
# per level up to Lv.5, half the rate per level after it (levels no longer
# stop at 5, and a linear +20% per level would make Sprint Servos alone a
# five-times move speed by Lv.20).
@export var mods_scale_per_level: float = 0.0

# Optional: grants a spell into a spell slot
@export var grant_spell_id: StringName = &""

@export var effect_scenes: Array[PackedScene] = []

func apply_to_stats(s: Stats) -> void:
	if mods != null:
		mods.apply_to(s)

func apply_to_stats_at_level(s: Stats, level: int) -> void:
	if mods == null:
		return
	var lvl: int = maxi(1, level)
	if mods_scale_per_level <= 0.0 or lvl <= 1:
		mods.apply_to(s)
		return

	var mul: float = stat_level_factor(mods_scale_per_level, lvl)
	var m: StatDelta = mods.copy()
	m.max_hp *= mul
	m.armor *= mul
	m.move_speed *= mul
	m.power *= mul
	m.haste *= mul
	m.luck *= mul
	m.apply_to(s)


static func stat_level_factor(scale: float, level: int) -> float:
	var lvl := maxi(1, level)
	var early := mini(lvl, 5) - 1
	var late := maxi(0, lvl - 5)
	return 1.0 + scale * (float(early) + 0.5 * float(late))
