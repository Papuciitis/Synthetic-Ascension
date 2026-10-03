extends RefCounted
class_name AugmentScaling

## Every number the augment layer is paid in, in one place
## (docs/design/2026-10-03-bindings-and-theses.md).
##
## Augments used to pay `12 x k x (1 + Power)`: no style multiplier, nothing
## from gear, dice that added +2 at 20% Power. The tree pays in D, the native
## hit, so by segment 6 a Lv.5 augment was a rounding error beside one node.
## Combat augments now pay in D as well, grow linearly with level (damage is
## not a capped stat) and stop clamping at Lv.5.

const MAX_LEVEL := 20
## The level an augment must reach before its Transcendence is offered.
const TRANSCEND_LEVEL := 5
## Damage per level above 1, as a fraction of the Lv.1 payload.
const POTENCY_PER_LEVEL := 0.35
## Counts (missiles, targets, spiders, dice) stop growing after this many
## levels; past it only potency and the cooldown floors move.
const COUNT_STEP_CAP := 8


static func clamp_level(level: int) -> int:
	return clampi(level, 1, MAX_LEVEL)


## Payload multiplier at `level`: Lv.1 = 1, Lv.5 = 2.4, Lv.10 = 4.15.
static func potency(level: int) -> float:
	return 1.0 + POTENCY_PER_LEVEL * float(clamp_level(level) - 1)


## Levels above 1 that count-type growth may use.
static func count_steps(level: int) -> int:
	return mini(clamp_level(level) - 1, COUNT_STEP_CAP)


## D for augments: the player's native hit before runner multipliers, the
## same reading AscensionRunner.native_damage makes (style multiplier and
## Power included), so an augment grows with exactly what the tree grows with.
static func native_d(player: Node) -> float:
	var base := 12.0
	var power := 0.0
	if player != null and is_instance_valid(player):
		var bwd: Variant = player.get("base_weapon_damage")
		if typeof(bwd) == TYPE_FLOAT or typeof(bwd) == TYPE_INT:
			base = float(bwd)
		var stats: Variant = player.get("stats")
		if stats is Object and stats != null:
			var p: Variant = (stats as Object).get("power")
			if typeof(p) == TYPE_FLOAT or typeof(p) == TYPE_INT:
				power = float(p)
	var style := StringName(str(Global.selected_style_id)) if Global != null else &"ranged"
	return base * CombatStyleTuning.damage_multiplier(style) * maxf(0.05, 1.0 + power)


## One augment payload: D x coefficient x potency(level) x the Doctrine's
## augment-damage multipliers.
static func damage(player: Node, coefficient: float, level: int) -> float:
	return native_d(player) * coefficient * potency(level) * damage_multiplier()


## Doctrine-side augment damage (Choir, Twin Seal, The Engine Prays and the
## Circuit Thesis / Canon). 1.0 outside a run.
static func damage_multiplier() -> float:
	if Global == null or not Global.has_method("augment_damage_multiplier"):
		return 1.0
	return float(Global.augment_damage_multiplier())


## The haste multiplier automatic augments tick at (Tesla used to ignore it).
static func haste_multiplier(player: Node) -> float:
	if player == null or not is_instance_valid(player):
		return 1.0
	var stats: Variant = player.get("stats")
	if stats is Object and stats != null:
		var h: Variant = (stats as Object).get("haste")
		if typeof(h) == TYPE_FLOAT or typeof(h) == TYPE_INT:
			return maxf(0.1, 1.0 + maxf(float(h), -0.9))
	return 1.0


## A dice expression normalised to its mean: 3d6 averages 1.0, so dice keep
## their swing without changing the expected payload.
static func dice_factor(count: int, sides: int, rng: RandomNumberGenerator = null) -> float:
	var n := maxi(1, count)
	var s := maxi(2, sides)
	var total := 0
	for i in range(n):
		total += rng.randi_range(1, s) if rng != null else randi_range(1, s)
	return float(total) / (float(n) * (float(s) + 1.0) * 0.5)


## Elites and bosses: what Storm Crown strikes twice.
static func is_heavy(handle: int) -> bool:
	if not EnemyWorld.is_valid_handle(handle):
		return false
	if EnemyWorldTypes.has_flag(EnemyWorld.get_flags(handle), EnemyWorldTypes.Flags.ELITE):
		return true
	var actor := EnemyWorld.actor_for_handle(handle)
	return actor != null and is_instance_valid(actor) and (actor.is_in_group(&"boss_like") or actor.is_in_group(&"boss") or actor.is_in_group(&"miniboss"))


## Velocity Engine: Power from move speed above the base 100, +30% per 100,
## at most +60%.
static func velocity_power(move_speed: float) -> float:
	return clampf(0.3 * (move_speed / 100.0 - 1.0), 0.0, 0.6)


## Fortune's Engine: lucky crit chance x2 and x2.5 damage (was x1.5).
static func lucky_crit_chance(luck: float, fortune: bool) -> float:
	var chance := LuckResolver.lucky_crit_chance(luck)
	return chance * 2.0 if fortune else chance


static func lucky_crit_multiplier(fortune: bool) -> float:
	return 2.5 if fortune else 1.5


# ---------------------------------------------------------------- grades

## Etched, Gilded, Sanctified, Apocryphal: how many levels a Binding card adds.
const GRADE_NAMES: PackedStringArray = ["ETCHED", "GILDED", "SANCTIFIED", "APOCRYPHAL"]
const GRADE_LEVELS: PackedInt32Array = [1, 2, 3, 4]
const GRADE_COUNT := 4


static func grade_name(grade: int) -> String:
	return GRADE_NAMES[clampi(grade, 0, GRADE_COUNT - 1)]


static func grade_levels(grade: int) -> int:
	return GRADE_LEVELS[clampi(grade, 0, GRADE_COUNT - 1)]


## The OverlayKit rarity index a grade borrows its colour from (green,
## arcane blue, violet, ember).
static func grade_rarity_index(grade: int) -> int:
	return clampi(grade, 0, GRADE_COUNT - 1) + 1


## Relative weights at completed segment `segment`. Everything above Etched
## is scaled by Luck (the unused LuckResolver.augment_quality_bonus, x0.52 to
## x1.48) and by the Doctrine's grade multiplier.
static func grade_weights(segment: int, luck: float, grade_mul: float = 1.0) -> PackedFloat32Array:
	var s := float(maxi(1, segment))
	var lucky := maxf(0.0, 1.0 + 4.0 * LuckResolver.augment_quality_bonus(luck)) * maxf(0.0, grade_mul)
	return PackedFloat32Array([
		100.0,
		(30.0 + 6.0 * s) * lucky,
		(6.0 + 3.0 * s) * lucky,
		(0.5 + maxf(0.0, s - 3.0)) * lucky,
	])


## One grade, never below `floor_grade` (the Archive Canon's Gilded floor).
static func roll_grade(rng: RandomNumberGenerator, segment: int, luck: float, grade_mul: float = 1.0, floor_grade: int = 0) -> int:
	var weights := grade_weights(segment, luck, grade_mul)
	var lo := clampi(floor_grade, 0, GRADE_COUNT - 1)
	var total := 0.0
	for i in range(lo, GRADE_COUNT):
		total += weights[i]
	if total <= 0.0:
		return lo
	var pick := rng.randf() * total
	for i in range(lo, GRADE_COUNT):
		pick -= weights[i]
		if pick <= 0.0:
			return i
	return GRADE_COUNT - 1


# ---------------------------------------------------------------- recast / abstain

const RECAST_PER_SEGMENT := 40
const ABSTAIN_PER_SEGMENT := 75


## Followers for the next Recast of this Binding (`done` already paid).
static func recast_cost(segment: int, done: int, multiplier: float = 1.0) -> int:
	return int(round(float(RECAST_PER_SEGMENT * maxi(1, segment) * (maxi(0, done) + 1)) * maxf(0.0, multiplier)))


static func abstain_reward(segment: int, multiplier: float = 1.0) -> int:
	return int(round(float(ABSTAIN_PER_SEGMENT * maxi(1, segment)) * maxf(0.0, multiplier)))


# ---------------------------------------------------------------- transcendence

## id -> {name, rule, catalyst_text, catalysts}. A catalyst is one of
## {augment: id}, {stat: name, at_least: value}, {discipline: [codes]},
## {family: id}, {curses: n} or {followers: n}; any one holds.
const TRANSCENDENCE := {
	&"augment_magic_missile": {
		"name": "Choir of Needles",
		"rule": "+1 missile. Every hit splits into 2 shards (60%) that seek other enemies.",
		"catalyst_text": "Lucky Charm, or +40% Haste, or a Precision or Invocation node",
		"catalysts": [{"augment": &"augment_lucky_charm"}, {"stat": "haste", "at_least": 0.4}, {"discipline": ["PR", "IN"]}],
	},
	&"augment_tesla_aura": {
		"name": "Storm Crown",
		"rule": "Radius x1.3. Each zap chains 2 hops (x0.7) and stuns 0.12 s; elites and bosses take double.",
		"catalyst_text": "Sprint Servos, or 180 move speed, or a Momentum or Distortion node",
		"catalysts": [{"augment": &"augment_sprint_servos"}, {"stat": "move_speed", "at_least": 180.0}, {"discipline": ["MO", "DT"]}],
	},
	&"augment_spirit_slash": {
		"name": "Thousand Cuts",
		"rule": "Casts itself when ready and strikes the 3 nearest (+1 per 4 levels). A kill re-casts at once, 3 times.",
		"catalyst_text": "Litany of Wounds, or Blink Hex, or an Execution node",
		"catalysts": [{"augment": &"augment_litany_of_wounds"}, {"augment": &"augment_blink_hex"}, {"discipline": ["EX"]}],
	},
	&"augment_blink_hex": {
		"name": "Hexgate",
		"rule": "Each blink tears rifts at both ends: 2.5 D in a wide circle and a 0.6 s stun. +1 marked attack.",
		"catalyst_text": "Sprint Servos, or Spirit Slash, or a Momentum or Dominion node",
		"catalysts": [{"augment": &"augment_sprint_servos"}, {"augment": &"augment_spirit_slash"}, {"discipline": ["MO", "DO"]}],
	},
	&"augment_summon_spiderlings": {
		"name": "Brood Mother",
		"rule": "30% of kills near you hatch a spiderling. Spiderlings detonate when their life ends.",
		"catalyst_text": "Cult of Personality, or Gambler's Rite, or an Invocation or Dominion node",
		"catalysts": [{"augment": &"augment_cult_of_personality"}, {"augment": &"augment_gamblers_rite"}, {"discipline": ["IN", "DO"]}],
	},
	&"augment_reflect_shield": {
		"name": "Mirror Aegis",
		"rule": "A ward opens itself every 1.6 s. Reflections fan into 3. The perfect zap strikes everything in range.",
		"catalyst_text": "Stamina Core, or 40 Armor, or a Bastion node",
		"catalysts": [{"augment": &"augment_stamina_core"}, {"stat": "armor", "at_least": 40.0}, {"discipline": ["BA"]}],
	},
	&"augment_stamina_core": {
		"name": "Undying Engine",
		"rule": "6% lifesteal always. Fires itself below 35% HP when ready.",
		"catalyst_text": "Doctrine of Burden, or Reflect Shield, or a Bastion or Execution node",
		"catalysts": [{"augment": &"augment_doctrine_of_burden"}, {"augment": &"augment_reflect_shield"}, {"discipline": ["BA", "EX"]}],
	},
	&"augment_lucky_charm": {
		"name": "Fortune's Engine",
		"rule": "Lucky crit chance x2. Lucky crits deal x2.5 instead of x1.5.",
		"catalyst_text": "Gambler's Rite, or Cult of Personality, or a Distortion node",
		"catalysts": [{"augment": &"augment_gamblers_rite"}, {"augment": &"augment_cult_of_personality"}, {"discipline": ["DT"]}],
	},
	&"augment_sprint_servos": {
		"name": "Velocity Engine",
		"rule": "Power + 30% per 100 move speed above 100 (at most +60%).",
		"catalyst_text": "Tesla Aura, or Blink Hex, or a Momentum node",
		"catalysts": [{"augment": &"augment_tesla_aura"}, {"augment": &"augment_blink_hex"}, {"discipline": ["MO"]}],
	},
	&"augment_corruption_engine": {
		"name": "Heart of Ruin",
		"rule": "The three heaviest curses feed it. Power cap 30% -> 75%.",
		"catalyst_text": "Litany of Wounds, or two curses worn, or a vessel Doctrine",
		"catalysts": [{"augment": &"augment_litany_of_wounds"}, {"curses": 2}, {"family": &"vessel"}],
	},
	&"augment_doctrine_of_burden": {
		"name": "Martyr's Frame",
		"rule": "+5% Power per qualifying curse (at most +40%).",
		"catalyst_text": "Stamina Core, or four curses worn, or a Bastion node",
		"catalysts": [{"augment": &"augment_stamina_core"}, {"curses": 4}, {"discipline": ["BA"]}],
	},
	&"augment_inversion_lens": {
		"name": "Twin Lens",
		"rule": "The suppressed curse returns 110% of its severity (was 55%). Luck kicker x2.",
		"catalyst_text": "Lucky Charm, or Equilibrium Sigil, or an archive Doctrine",
		"catalysts": [{"augment": &"augment_lucky_charm"}, {"augment": &"augment_equilibrium_sigil"}, {"family": &"archive"}],
	},
	&"augment_equilibrium_sigil": {
		"name": "Perfect Balance",
		"rule": "Power and Haste cap 20% -> 45%, rate x2.",
		"catalyst_text": "Inversion Lens, or Lucky Charm, or a Distortion node",
		"catalysts": [{"augment": &"augment_inversion_lens"}, {"augment": &"augment_lucky_charm"}, {"discipline": ["DT"]}],
	},
	&"augment_litany_of_wounds": {
		"name": "Requiem",
		"rule": "Starts at 85% HP (full at 35%). Cap 35% -> 70%, and it adds Power as well as Haste.",
		"catalyst_text": "Corruption Engine, or Spirit Slash, or an Execution node",
		"catalysts": [{"augment": &"augment_corruption_engine"}, {"augment": &"augment_spirit_slash"}, {"discipline": ["EX"]}],
	},
	&"augment_cult_of_personality": {
		"name": "Prophet",
		"rule": "Recruit chance x2 and +2 Followers per recruit. Belief Power cap 15% -> 30%.",
		"catalyst_text": "Summon Spiderlings, or Gambler's Rite, or 300 Followers held",
		"catalysts": [{"augment": &"augment_summon_spiderlings"}, {"augment": &"augment_gamblers_rite"}, {"followers": 300}],
	},
	&"augment_gamblers_rite": {
		"name": "House Edge",
		"rule": "Follower chance cap 35% -> 70%, +2 Followers per curse found.",
		"catalyst_text": "Lucky Charm, or Cult of Personality, or a Distortion node",
		"catalysts": [{"augment": &"augment_lucky_charm"}, {"augment": &"augment_cult_of_personality"}, {"discipline": ["DT"]}],
	},
}


static func can_transcend(id: StringName) -> bool:
	return TRANSCENDENCE.has(id)


static func transcended_name(id: StringName) -> String:
	var row: Dictionary = TRANSCENDENCE.get(id, {})
	return String(row.get("name", ""))


static func transcend_rule(id: StringName) -> String:
	var row: Dictionary = TRANSCENDENCE.get(id, {})
	return String(row.get("rule", ""))


static func catalyst_text(id: StringName) -> String:
	var row: Dictionary = TRANSCENDENCE.get(id, {})
	return String(row.get("catalyst_text", ""))


## Whether any catalyst of `id` holds in `context`:
## {equipped: Array[StringName], stats: {haste, move_speed, armor},
##  disciplines: {code: true}, families: {family: count}, curses: int,
##  followers: int, waive: bool}.
static func catalyst_holds(id: StringName, context: Dictionary) -> bool:
	if not TRANSCENDENCE.has(id):
		return false
	if bool(context.get("waive", false)):
		return true
	var equipped: Array = context.get("equipped", [])
	var stats: Dictionary = context.get("stats", {})
	var disciplines: Dictionary = context.get("disciplines", {})
	var families: Dictionary = context.get("families", {})
	for catalyst in (TRANSCENDENCE[id] as Dictionary)["catalysts"]:
		var c: Dictionary = catalyst
		if c.has("augment"):
			if equipped.has(StringName(c["augment"])) and StringName(c["augment"]) != id:
				return true
		elif c.has("stat"):
			if float(stats.get(String(c["stat"]), 0.0)) >= float(c["at_least"]):
				return true
		elif c.has("discipline"):
			for code in c["discipline"]:
				if disciplines.has(String(code)):
					return true
		elif c.has("family"):
			if int(families.get(StringName(c["family"]), 0)) > 0:
				return true
		elif c.has("curses"):
			if int(context.get("curses", 0)) >= int(c["curses"]):
				return true
		elif c.has("followers"):
			if int(context.get("followers", 0)) >= int(c["followers"]):
				return true
	return false
