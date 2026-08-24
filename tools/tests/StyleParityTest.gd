extends Node

## Nothing may be reachable by only one combat style.
##
## The whole project was built and tested with the default style, "ranged", and
## that quietly produced a game where melee got NO scripted attack behaviour at
## all (apply_to_melee_slash had a dispatcher, an implementer, and no caller)
## and magic's burn metadata was set and never read. Neither is visible in any
## other test, because every other test plays ranged.

const STYLES: Array[StringName] = [&"melee", &"ranged", &"magic"]

var _passes: int = 0
var _failures: int = 0


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: %s" % message)


func _ready() -> void:
	get_tree().create_timer(45.0).timeout.connect(func() -> void:
		push_error("StyleParityTest timed out")
		get_tree().quit(1)
	)
	_test_attack_riders_reach_every_style()
	_test_anchor_rite_pays_every_style()
	_test_style_tuning_is_a_triangle()
	print("StyleParityTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


## Each style's attack node must be able to receive scripted riders, and both
## runners must be able to dispatch them.
func _test_attack_riders_reach_every_style() -> void:
	var player_source := FileAccess.get_file_as_string("res://core/actors/player/player.gd")
	_check(
		player_source.contains("apply_to_melee_slash"),
		"the melee spawn path applies attack riders"
	)
	_check(
		player_source.contains("apply_to_magic_impact"),
		"the magic spawn path applies attack riders"
	)
	_check(
		player_source.contains("apply_to_managed_hit_profile") or player_source.contains("apply_to_ranged_bullet"),
		"the ranged spawn path applies attack riders"
	)

	var runner := ManifestationRunner.new()
	for hook in ["apply_to_melee_slash", "apply_to_magic_impact", "apply_to_managed_hit_profile"]:
		_check(runner.has_method(hook), "the manifestation runner dispatches %s" % hook)
	runner.free()

	var items := ItemEffectRunner.new()
	for hook in ["apply_to_melee_slash", "apply_to_magic_impact", "apply_to_managed_hit_profile"]:
		_check(items.has_method(hook), "the item runner dispatches %s" % hook)
	items.free()

	# Burn metadata must actually be read by the node it is set on.
	var magic_source := FileAccess.get_file_as_string("res://scenes/world/combat/MagicImpact.gd")
	_check(
		magic_source.contains("_apply_burn_handle(") and magic_source.contains("_apply_burn_dot("),
		"a magic impact reads the burn it was handed"
	)
	var melee_source := FileAccess.get_file_as_string("res://scenes/world/combat/MeleeSlash.gd")
	_check(
		melee_source.contains("_apply_burn_handle(") and melee_source.contains("_apply_burn_dot("),
		"a melee slash reads the burn it was handed"
	)

	# A Lucky Crit must REPORT as a crit, not merely deal crit damage.
	# EnemyCombatService derives was_critical from a HitLedger payload, so a
	# damage call without one is a normal hit whatever the number was.
	_check(
		player_source.contains('set_meta("lucky_crit"'),
		"the player tells melee and magic when an attack is a Lucky Crit"
	)
	for source_path in [
		"res://scenes/world/combat/MeleeSlash.gd",
		"res://scenes/world/combat/MagicImpact.gd",
	]:
		var body := FileAccess.get_file_as_string(source_path)
		_check(
			body.contains("_crit_payload()"),
			"%s reports crits through a HitLedger" % source_path.get_file()
		)


## The one rule that ever branched on style must pay all three.
func _test_anchor_rite_pays_every_style() -> void:
	var def := ManifestationCatalog.get_def(&"anchor_rite")
	_check(def != null, "anchor_rite is in the catalog")
	if def == null or def.logic == null:
		return
	var rite: Node = def.logic.new()
	for hook in ["apply_to_hit_profile", "apply_to_melee_slash", "apply_to_magic_impact"]:
		_check(rite.has_method(hook), "Anchor Rite pays out through %s" % hook)

	# And it must not describe a payoff the current style cannot get.
	var previous: String = str(Global.selected_style_id)
	var seen: Dictionary = {}
	for style in STYLES:
		Global.selected_style_id = String(style)
		var text: String = rite.call("describe")
		_check(text.strip_edges() != "", "Anchor Rite describes itself on %s" % String(style))
		seen[text] = true
	Global.selected_style_id = previous
	_check(
		seen.size() == STYLES.size(),
		"Anchor Rite says something different to each style (%d of %d)" % [seen.size(), STYLES.size()]
	)
	rite.free()


## Slower styles must hit harder per attack, or the slow style is just worse.
func _test_style_tuning_is_a_triangle() -> void:
	var player_scene := load("res://core/actors/player/player.tscn") as PackedScene
	var player: Node = player_scene.instantiate() if player_scene != null else null
	_check(player != null, "the player scene loads")
	if player == null:
		return
	var melee_cd: float = float(player.get("melee_cooldown"))
	var ranged_cd: float = float(player.get("ranged_cooldown"))
	var magic_cd: float = float(player.get("magic_cooldown"))
	player.free()

	_check(melee_cd > 0.0, "no style is gated only by how fast a hand can click")
	_check(
		magic_cd > melee_cd and melee_cd > ranged_cd,
		"cooldowns order slowest-to-fastest magic > melee > ranged (%.2f, %.2f, %.2f)"
			% [magic_cd, melee_cd, ranged_cd]
	)
	_check(
		CombatStyleTuning.MAGIC_DAMAGE_MULT > CombatStyleTuning.MELEE_DAMAGE_MULT,
		"magic pays more per cast than melee per swing"
	)
	_check(
		CombatStyleTuning.MELEE_DAMAGE_MULT > CombatStyleTuning.RANGED_DAMAGE_MULT,
		"melee pays more per swing than ranged per shot"
	)

	# Ceiling DPS must land in the same order of magnitude for all three, or one
	# style is simply not a choice.
	var ceilings: Array[float] = [
		CombatStyleTuning.MELEE_DAMAGE_MULT / melee_cd,
		CombatStyleTuning.RANGED_DAMAGE_MULT / ranged_cd,
		CombatStyleTuning.MAGIC_DAMAGE_MULT / magic_cd,
	]
	var low: float = ceilings.min()
	var high: float = ceilings.max()
	_check(
		high / maxf(0.001, low) <= 1.6,
		"single-target ceilings stay within 60%% of each other (%.2f..%.2f)" % [low, high]
	)
