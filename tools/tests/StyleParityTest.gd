extends Node

## Nothing may be reachable by only one combat style.
##
## The whole project was built and tested with the default style, "ranged", and
## that quietly produced a game where melee got NO scripted attack behaviour at
## all (apply_to_melee_slash had a dispatcher, an implementer, and no caller)
## and magic's burn metadata was set and never read. Neither is visible in any
## other test, because every other test plays ranged.
##
## The checks below drive the real nodes: the player's own spawn paths are
## called with spy runners installed, and a real MeleeSlash / MagicImpact is
## fired at a data-only enemy handle. They used to be greps over player.gd,
## MeleeSlash.gd and MagicImpact.gd for the names of the calls, which a comment
## mentioning "apply_to_melee_slash" would have satisfied.

const STYLES: Array[StringName] = [&"melee", &"ranged", &"magic"]
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

## Geometry for the fired-attack fixtures, mirroring EnemyAreaCombatTest: a
## slash facing +X with a 62 px / 90 degree wedge, and an impact with a 60 px
## radius, both with the target well inside them.
const ATTACK_TARGET_OFFSET: Vector2 = Vector2(30.0, 0.0)
const SLASH_ARC_RADIUS: float = 62.0
const SLASH_ARC_DEGREES: float = 90.0
const SLASH_THICKNESS: float = 18.0
const IMPACT_RADIUS: float = 60.0
const TARGET_HEALTH: float = 40.0
## Burn rider values of the shape a real item or manifestation hook writes onto
## an attack node.
const BURN_DURATION: float = 3.0
const BURN_TICK: float = 0.5
const BURN_STACKS: int = 2
const BURN_TICK_MULT: float = 0.4


## Stands in for the two runners the player looks up by node name, so the test
## can see whether the spawn path actually dispatches to them.
class SpyItemRunner:
	extends ItemEffectRunner

	var melee_slashes: Array[Node] = []
	var magic_impacts: Array[Node] = []
	var managed_profiles: int = 0

	func apply_to_melee_slash(slash: Node) -> void:
		melee_slashes.append(slash)

	func apply_to_magic_impact(impact: Node) -> void:
		magic_impacts.append(impact)

	func apply_to_managed_hit_profile(_profile: HitProfileAdapter, _style_id: StringName) -> void:
		managed_profiles += 1


class SpyManifestationRunner:
	extends ManifestationRunner

	var melee_slashes: Array[Node] = []
	var magic_impacts: Array[Node] = []
	var managed_profiles: int = 0

	func apply_to_melee_slash(slash: Node) -> void:
		melee_slashes.append(slash)

	func apply_to_magic_impact(impact: Node) -> void:
		magic_impacts.append(impact)

	func apply_to_managed_hit_profile(_profile: HitProfileAdapter, _style_id: StringName) -> void:
		managed_profiles += 1


var _passes: int = 0
var _failures: int = 0
var _hit_crit_flags: Array[bool] = []


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
	_run.call_deferred()


func _run() -> void:
	await _test_attack_riders_reach_every_style()
	await _test_node_attacks_read_what_they_were_handed()
	_test_anchor_rite_pays_every_style()
	_test_style_tuning_is_a_triangle()
	print("StyleParityTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


## Each style's attack node must be able to receive scripted riders, and both
## runners must be able to dispatch them.
func _test_attack_riders_reach_every_style() -> void:
	var runner := ManifestationRunner.new()
	for hook in ["apply_to_melee_slash", "apply_to_magic_impact", "apply_to_managed_hit_profile"]:
		_check(runner.has_method(hook), "the manifestation runner dispatches %s" % hook)
	runner.free()

	var items := ItemEffectRunner.new()
	for hook in ["apply_to_melee_slash", "apply_to_magic_impact", "apply_to_managed_hit_profile"]:
		_check(items.has_method(hook), "the item runner dispatches %s" % hook)
	items.free()

	# A dispatcher nothing calls is the exact bug this suite exists for, so the
	# player's own spawn paths are driven with spy runners in place of the real
	# ones instead of grepping player.gd for the call sites.
	var player_scene := load("res://core/actors/player/player.tscn") as PackedScene
	var player: Node2D = player_scene.instantiate() as Node2D if player_scene != null else null
	_check(player != null, "the player scene loads for the rider check")
	if player == null:
		return
	add_child(player)
	await get_tree().process_frame

	var item_spy := SpyItemRunner.new()
	var rule_spy := SpyManifestationRunner.new()
	_swap_runner(player, "ItemEffectRunner", item_spy)
	_swap_runner(player, "ManifestationRunner", rule_spy)
	await get_tree().process_frame

	# The melee and magic spawn paths, driven directly. _fire_weapon is not used
	# on purpose: it rolls the crit itself, and the contract under test is what
	# the spawn path does with a slash or an impact once it has one.
	player.set("_lucky_crit_pending", true)
	player.call("_spawn_melee_slash", Vector2.ZERO, Vector2.RIGHT, 5.0)
	player.call("_spawn_magic_impact", Vector2.ZERO, 5.0)
	player.set("_lucky_crit_pending", false)
	await get_tree().process_frame

	_check(
		item_spy.melee_slashes.size() == 1 and rule_spy.melee_slashes.size() == 1,
		"the melee spawn path applies item and manifestation riders (%d, %d)"
			% [item_spy.melee_slashes.size(), rule_spy.melee_slashes.size()]
	)
	_check(
		item_spy.magic_impacts.size() == 1 and rule_spy.magic_impacts.size() == 1,
		"the magic spawn path applies item and manifestation riders (%d, %d)"
			% [item_spy.magic_impacts.size(), rule_spy.magic_impacts.size()]
	)
	# A Lucky Crit must be handed to melee and magic, not just to ranged: the
	# attack node turns that meta into the HitLedger that makes it report AS a
	# crit rather than merely deal crit damage.
	var spawned_attacks: Array[Node] = item_spy.melee_slashes + item_spy.magic_impacts
	for named: Array in [
		["melee slash", item_spy.melee_slashes],
		["magic impact", item_spy.magic_impacts],
	]:
		for spawned: Node in (named[1] as Array):
			_check(
				bool(spawned.get_meta("lucky_crit", false)),
				"the player tells the %s when an attack is a Lucky Crit" % String(named[0])
			)

	# The ranged path is managed (no per-shot node), so its riders arrive on the
	# shared hit profile the projectile manager is handed instead.
	item_spy.managed_profiles = 0
	rule_spy.managed_profiles = 0
	player.call("_spawn_ranged_bullet", Vector2.ZERO, Vector2.RIGHT, 5.0)
	_check(
		item_spy.managed_profiles >= 1 and rule_spy.managed_profiles >= 1,
		"the ranged spawn path applies item and manifestation riders (%d, %d)"
			% [item_spy.managed_profiles, rule_spy.managed_profiles]
	)

	for spawned: Node in spawned_attacks:
		if is_instance_valid(spawned):
			spawned.queue_free()
	player.queue_free()
	await get_tree().process_frame


## The two node attacks must READ the riders they were handed: burn metadata
## has to become a real status on the target, and the Lucky Crit meta has to
## reach EnemyCombatService as a HitLedger so the hit reports as critical.
##
## Both used to be greps for the names of private helpers ("_apply_burn_dot(",
## "_crit_payload()"). They are fired at a data-only enemy handle here, the
## same fixture shape EnemyAreaCombatTest uses.
##
## Limitation, named rather than papered over: this drives the handle path
## (_apply_burn_handle). The node path (_apply_burn_dot, for legacy Node-owned
## enemies) would need a legacy enemy actor fixture, which lives in
## EnemyLegacyCombatCompatibilityTest; it is still unpinned for burn.
func _test_node_attacks_read_what_they_were_handed() -> void:
	RunEvents.player_hit_landed.connect(_on_player_hit_landed)
	await _fire_attack_at_handle("melee slash", true)
	await _fire_attack_at_handle("magic impact", true)
	# The same attack without the meta must NOT report a crit, or "reports as a
	# crit" would be true of every hit and pin nothing.
	await _fire_attack_at_handle("melee slash", false)
	RunEvents.player_hit_landed.disconnect(_on_player_hit_landed)


func _on_player_hit_landed(
	_source: Node, _handle: int, _position: Vector2, _amount: float, is_crit: bool, _is_elite: bool
) -> void:
	_hit_crit_flags.append(is_crit)


func _make_attack(kind: String, source: Node2D) -> Node2D:
	if kind == "melee slash":
		var slash := (load("res://scenes/world/combat/MeleeSlash.tscn") as PackedScene).instantiate() as MeleeSlash
		slash.damage = 6.0
		slash.lifetime = 1.0
		slash.arc_radius = SLASH_ARC_RADIUS
		slash.arc_degrees = SLASH_ARC_DEGREES
		slash.thickness = SLASH_THICKNESS
		slash.source = source
		return slash
	var impact := (load("res://scenes/world/combat/MagicImpact.tscn") as PackedScene).instantiate() as MagicImpact
	impact.damage = 6.0
	impact.lifetime = 1.0
	impact.radius = IMPACT_RADIUS
	impact.source = source
	return impact


func _fire_attack_at_handle(kind: String, lucky_crit: bool) -> void:
	var handle := EnemyWorld.create_enemy(SpawnState.new(
		&"style_parity_target",
		"res://style_parity_target.tscn",
		ATTACK_TARGET_OFFSET,
		TARGET_HEALTH,
		0.0,
		4.0,
		0
	))
	var attack_source := Node2D.new()
	add_child(attack_source)
	var attack := _make_attack(kind, attack_source)
	attack.set_meta("burn_duration", BURN_DURATION)
	attack.set_meta("burn_tick", BURN_TICK)
	attack.set_meta("burn_stacks", BURN_STACKS)
	attack.set_meta("burn_tick_mult", BURN_TICK_MULT)
	if lucky_crit:
		attack.set_meta("lucky_crit", true)
	_hit_crit_flags.clear()
	add_child(attack)
	await get_tree().physics_frame
	await get_tree().process_frame

	_check(
		EnemyWorld.get_health(handle) < TARGET_HEALTH,
		"a %s reaches a data-only handle at all (fixture)" % kind
	)
	_check(
		EnemyStatus.has_status(handle, EnemyStatusService.BURN),
		"a %s applies the burn it was handed" % kind
	)
	_check(
		not _hit_crit_flags.is_empty(),
		"a %s reports its hit on RunEvents.player_hit_landed" % kind
	)
	if not _hit_crit_flags.is_empty():
		_check(
			_hit_crit_flags[0] == lucky_crit,
			"a %s reports a Lucky Crit through a HitLedger (expected is_crit=%s, got %s)"
				% [kind, str(lucky_crit), str(_hit_crit_flags[0])]
		)

	EnemyStatus.clear_handle(handle)
	EnemyWorld.remove_enemy(handle, &"style_parity")
	attack.queue_free()
	attack_source.queue_free()
	await get_tree().process_frame


func _swap_runner(player: Node, node_name: String, spy: Node) -> void:
	var existing := player.get_node_or_null(node_name)
	if existing != null:
		existing.name = "%sRetired" % node_name
		existing.queue_free()
	spy.name = node_name
	player.add_child(spy)


## The one rule that ever branched on style must pay all three.
func _test_anchor_rite_pays_every_style() -> void:
	var def := ManifestationCatalog.get_def(&"anchor_rite")
	_check(def != null, "anchor_rite is in the catalog")
	if def == null:
		return
	# Hard, not a silent skip: without logic the six assertions below simply
	# vanish, which is how a rule could lose its payout unnoticed.
	_check(def.logic != null, "anchor_rite still carries its logic script")
	if def.logic == null:
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
