extends AscensionEngine
class_name BastionEngine
## Bastion: Force from enemy pressure, prevention, caught projectiles, Guard,
## Full Tank, Meltdown and RUPTURE.
##
## Force 0-100 (150 with Overpressure; +3 sqrt(rank) capacity). Enemy hits
## grant 2 Force per 1% max HP of pre-mitigation damage, at most 25 per hit
## (shared rule); prevented hits count. No decay outside combat; in combat
## without pressure for 2 s, 10/s. Prevention (Guard, Plate, Anvil, Glass
## Armor) is applied through the per-source incoming-damage hook; Thorns
## reads what that hook prevented. Interpretations: Immovable's trigger
## (resisting a displacement) cannot occur because nothing displaces the
## player; Meltdown's third ring applies Thorns' virtual prevented hit to
## enemies within R since a virtual hit has no source.

const EFFECTS: Dictionary = {
	"BA01": &"stored_force", "BA02": &"return_to_sender", "BA03": &"plate", "BA04": &"full_tank",
	"BA05": &"razor_guard", "BA06": &"thorns", "BA07": &"surrounded", "BA08": &"vessel",
	"BA09": &"armor_break", "BA10": &"immovable", "BA11": &"slow_leak", "BA12": &"last_hit",
	"BAQ": &"guard", "BAQ1": &"bulwark", "BAQ2": &"counterweight", "BAQ3": &"mirror", "BAQ4": &"bunker",
	"BAQ5": &"martyr", "BAQ6": &"living_rampart", "BAF1": &"pressure_vessel", "BAF2": &"overpressure",
	"BAK1": &"anvil", "BAK2": &"glass_armor", "BAA": &"heavy_hands", "BAC": &"meltdown",
	"BAE1": &"gun_shield", "BAE2": &"bomb_bunker", "BAS1": &"force_capacity", "BAS2": &"armor",
	"BAV": &"rupture", "BAV1": &"aftershock", "BAV2": &"fallout", "BAV3": &"zero_armor",
}
const CLAIMERS: Array[String] = ["BA01", "BA02", "BA03", "BA04", "BA07", "BA08", "BA09", "BA10", "BA11", "BA12", "BAQ", "BAA"]
const FORCE_PER_PERCENT := 2.0
const FORCE_HIT_CAP := 25.0
const DECAY_AFTER := 2.0
const DECAY_RATE := 10.0

var force: float = 0.0
var plates: int = 0                     # Vessel plates (20 Force each)
var _clock: float = 0.0
var _last_hit_at: float = -INF
var _plate_ready: bool = false
var _plate_pending: bool = false
var _refill_pause: float = 0.0
var _volley: int = 0
var _strike_bonus: float = 0.0
var _bonus_volley: int = -1
var _spend_volley: int = -1
var _pending_spend: float = 0.0
var _surrounded_volley: int = -1
var _surrounded_force: float = 0.0
var _catch_times: Array[float] = []
var _razor_recovery: float = 0.0
var _scraps: Array = []                 # {pos, life}
var _leak_bank: float = 0.0
var _last_hit_recovery: float = 0.0
var _last_hit_fired: bool = false
var _last_prevention: float = 0.0
var _earned_bank: float = 0.0
var _discharged_bank: float = 0.0
var _armor_break_targets: Dictionary = {}
var _no_armor_left: float = 0.0
# Guard
var guarding: bool = false
var _guard_pool_stored: Array = []      # Mirror: caught projectiles {source}
var _gun_shield_tick: float = 0.0
var _bunker: Dictionary = {}            # {pos, life, force, dir, arc}
var _martyr_active: bool = false
# Meltdown / RUPTURE
var _rings: Array = []                  # {delay, radius, kind}
var _meltdown_recovery: float = 0.0
var _rupture_tell: float = -1.0
var _rupture_spent: float = 0.0
var _aftershock_delay: float = -1.0

var counters: Dictionary = {"force_earned": 0.0, "plates_formed": 0, "plate_hits": 0, "full_tanks": 0, "stored_spends": 0, "returns": 0, "catches": 0, "razor_rings": 0, "thorns": 0, "surrounded": 0, "vessel_plates": 0, "vessel_blades": 0, "armor_breaks": 0, "scraps": 0, "scrap_pickups": 0, "scrap_shocks": 0, "last_hits": 0, "guards": 0, "guard_waves": 0, "mirror_shots": 0, "bunkers": 0, "bunker_waves": 0, "meltdowns": 0, "ruptures": 0, "fallout_blades": 0, "gun_shield_shots": 0}


func discipline() -> String:
	return "BA"


func D() -> float:
	return runner.native_damage()


func claims_force() -> bool:
	for id in CLAIMERS:
		if has(id):
			return true
	return false


func capacity() -> float:
	var cap := 150.0 if has("BAF2") else 100.0
	if has("BAS1"):
		cap += 3.0 * sqrt(float(rank("BAS1")))
	return cap


# ---------------------------------------------------------------- Force

func add_force(points: float, from_pressure: bool = true) -> void:
	if not claims_force() or points <= 0.0 or _refill_pause > 0.0:
		return
	if from_pressure and has("BAK1") and _anvil_active():
		points *= 2.0
	var cap := capacity()
	var room := cap - force
	var stored := minf(points, room)
	force += stored
	if from_pressure:
		counters["force_earned"] = float(counters["force_earned"]) + stored
		_earned_bank += stored
		while _earned_bank >= 20.0:
			_earned_bank -= 20.0
			runner.add_action_charge(1.0)
	if points > room and has("BA08"):
		# Vessel: Force beyond capacity becomes orbiting plates of 20.
		var overflow := points - room
		while overflow >= 20.0 and plates < 3:
			overflow -= 20.0
			plates += 1
			counters["vessel_plates"] = int(counters["vessel_plates"]) + 1
	if has("BAF1") and has("BA04") and force >= 100.0:
		_discharge("pressure_vessel", runner.player_position(), Vector2.RIGHT)
		_refill_pause = 1.0


func spend_force(points: float) -> float:
	var spent := minf(points, force)
	force -= spent
	if spent >= 20.0 and has("MM9") and not _orbiters.is_empty():
		_throw_orbiters()
	if spent > 0.0:
		_discharged_bank += spent
		while _discharged_bank >= 50.0:
			_discharged_bank -= 50.0
			runner.add_action_charge(2.0)
		if has("BA09") and spent >= 20.0:
			_armor_break_pending = true
	return spent


var _armor_break_pending: bool = false
var _mine_bank: float = 0.0
var _orbiters: Dictionary = {}          # Gravity Armor: handle -> angle


func _grown_sigil_here() -> Dictionary:
	var invocation := runner.engine_of_discipline("IN") as InvocationEngine
	if invocation == null:
		return {}
	for sigil in invocation.player_inside():
		if float(sigil["growth"]) >= 1.0:
			return sigil
	return {}


## Gravity Armor (MM9): above 60 Force nearby normals orbit the player.
func _tick_gravity_armor(delta: float) -> void:
	if not has("MM9"):
		return
	if force <= 60.0:
		_orbiters.clear()
		return
	var centre := runner.player_position()
	for handle in runner.enemies_in_radius(centre, AscensionRunner.R):
		if not runner.is_normal(handle) or not runner.enemy_alive(handle):
			continue
		if not _orbiters.has(handle):
			_orbiters[handle] = (runner.enemy_position(handle) - centre).angle()
			EnemyCombat.apply_stun(handle, 0.5)
		var radius := maxf(30.0, minf(runner.enemy_position(handle).distance_to(centre), AscensionRunner.R))
		var angle := float(_orbiters[handle]) + 1.5 * delta
		_orbiters[handle] = angle
		runner.move_enemy_to(handle, centre + Vector2.from_angle(angle) * radius)
	for handle in _orbiters.keys():
		if not runner.enemy_alive(int(handle)) or runner.enemy_position(int(handle)).distance_to(centre) > 1.5 * AscensionRunner.R:
			_orbiters.erase(handle)


func _throw_orbiters() -> void:
	var thrown := 0
	var centre := runner.player_position()
	var dir := _facing()
	var out: Array[int] = []
	var ts := PackedFloat32Array()
	for handle in _orbiters.keys():
		if thrown >= 4:
			break
		if not runner.enemy_alive(int(handle)):
			continue
		_orbiters.erase(handle)
		thrown += 1
		var from := runner.enemy_position(int(handle))
		var to := centre + dir * 2.0 * AscensionRunner.R
		var count := EnemyCombat.enemies_on_segment(from, to, 10.0, int(handle), out, ts)
		var tags := AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "MM9", "throw", 1, 0.4)
		runner.damage_enemy(int(handle), 0.8 * D(), tags)
		for i in range(count):
			runner.damage_enemy(out[i], 0.8 * D(), tags)
		runner.move_enemy_to(int(handle), to)
		counters["orbiters_thrown"] = int(counters.get("orbiters_thrown", 0)) + 1


func _facing() -> Vector2:
	var dir := (runner.aim_target() - runner.player_position()).normalized()
	return dir if dir != Vector2.ZERO else Vector2.RIGHT


func _anvil_active() -> bool:
	return has("BAK1") and runner.still_seconds >= 0.5


func _in_combat() -> bool:
	return runner.nearest_enemy(runner.player_position(), 3.0 * AscensionRunner.L) != 0


# ---------------------------------------------------------------- tick

func tick(delta: float) -> void:
	_clock += delta
	if _refill_pause > 0.0:
		_refill_pause = maxf(0.0, _refill_pause - delta)
	if _razor_recovery > 0.0:
		_razor_recovery = maxf(0.0, _razor_recovery - delta)
	if _last_hit_recovery > 0.0:
		_last_hit_recovery = maxf(0.0, _last_hit_recovery - delta)
	if _meltdown_recovery > 0.0:
		_meltdown_recovery = maxf(0.0, _meltdown_recovery - delta)
	if _no_armor_left > 0.0:
		_no_armor_left = maxf(0.0, _no_armor_left - delta)
	while not _catch_times.is_empty() and _clock - _catch_times[0] > 1.0:
		_catch_times.remove_at(0)
	# Plate: two seconds without being hit forms one, below 50 Force (Ward: one).
	if has("BA03") and not _plate_ready and force < 50.0 and _clock - _last_hit_at >= (1.0 if (has("MM7") and not _grown_sigil_here().is_empty()) else 2.0):
		_plate_ready = true
		counters["plates_formed"] = int(counters["plates_formed"]) + 1
	# Decay: only in combat, only after two seconds without pressure.
	if claims_force() and force > 0.0 and _in_combat() and _clock - _last_hit_at >= DECAY_AFTER and not guarding:
		var rate := DECAY_RATE * (2.0 if has("BAK2") else 1.0)
		var lost := minf(force, rate * delta)
		force -= lost
		if has("BA11"):
			_leak_bank += lost
			while _leak_bank >= 20.0:
				_leak_bank -= 20.0
				_drop_scrap()
	_tick_scraps(delta)
	_tick_vessel()
	_tick_gravity_armor(delta)
	_tick_guard(delta)
	_tick_bunker(delta)
	_tick_rings(delta)
	_tick_rupture(delta)


func _drop_scrap() -> void:
	if _scraps.size() >= 5:
		_scraps.pop_front()
	# Dropped under the player and armed once they step off it.
	_scraps.append({"pos": runner.player_position(), "life": 4.0, "armed": false})
	counters["scraps"] = int(counters["scraps"]) + 1


func _tick_scraps(delta: float) -> void:
	if _scraps.is_empty():
		return
	var player_pos := runner.player_position()
	for i in range(_scraps.size() - 1, -1, -1):
		var scrap: Dictionary = _scraps[i]
		scrap["life"] = float(scrap["life"]) - delta
		var at: Vector2 = scrap["pos"]
		if float(scrap["life"]) <= 0.0:
			_scraps.remove_at(i)
		elif not bool(scrap["armed"]):
			if at.distance_to(player_pos) > 30.0:
				scrap["armed"] = true
		elif at.distance_to(player_pos) <= 24.0:
			add_force(10.0, false)
			counters["scrap_pickups"] = int(counters["scrap_pickups"]) + 1
			_scraps.remove_at(i)
		elif runner.nearest_enemy(at, 20.0) != 0:
			runner.spawn_impact(at, 0.8 * D(), AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "BA11", "impact", 1, 0.5), AscensionRunner.R * 0.6)
			counters["scrap_shocks"] = int(counters["scrap_shocks"]) + 1
			_scraps.remove_at(i)


func _tick_vessel() -> void:
	if plates <= 0:
		return
	var consumed: Array = []
	ProjectileManager.consume_enemy_projectiles_in_radius(runner.player_position(), 34.0, consumed)
	while not consumed.is_empty() and plates > 0:
		consumed.pop_back()
		plates -= 1


# ---------------------------------------------------------------- incoming damage

## Guard, Plate, Anvil, Glass Armor, Overpressure, Zero Armor and the Armor
## sink change what reaches the player; the prevented share is remembered
## for Thorns.
func damage_taken_multiplier_for(_source: Node, _kind: StringName) -> float:
	var mul := 1.0
	var tree_prevention := 1.0
	if guarding:
		var prevention := 0.75 if (force > 0.0 or _martyr_active) else 0.3
		tree_prevention *= 1.0 - prevention
	if _plate_ready:
		_plate_ready = false
		_plate_pending = true
		tree_prevention *= 0.5
	if _anvil_active():
		tree_prevention *= 1.0 - 0.2 * runner.keystone_bonus()
	if has("BAK2"):
		tree_prevention *= 1.0 - 0.6 * runner.keystone_bonus() * clampf(force / capacity(), 0.0, 1.0)
	mul *= tree_prevention
	_last_prevention = 1.0 - tree_prevention
	if has("BAF2") and force > 100.0:
		mul *= 1.2
	# Armor changes are expressed as a multiplier on the mitigated hit.
	var armor := runner.player_armor()
	var effective := armor
	if has("BAK2"):
		effective *= 0.5
	if has("BAS2"):
		var r := float(rank("BAS2"))
		effective *= 1.0 + 0.35 * r / (r + 70.0)
	if _no_armor_left > 0.0:
		effective = 0.0
	if effective != armor:
		mul *= (100.0 + maxf(armor, 0.0)) / (100.0 + maxf(effective, 0.0))
	return mul


func on_player_damage_resolved(source: Node, raw: float, _applied: float, _kind: StringName) -> void:
	_last_hit_at = _clock
	if _plate_pending:
		_plate_pending = false
		add_force(15.0, false)
		counters["plate_hits"] = int(counters["plate_hits"]) + 1
		if has("MM7"):
			# Ward: a Plate broken inside a grown Sigil stores a 1D Echo and adds two Growth.
			var sigil := _grown_sigil_here()
			var invocation := runner.engine_of_discipline("IN") as InvocationEngine
			if invocation != null and not sigil.is_empty():
				invocation._store_echo(sigil, invocation._new_echo("magic", runner.player_position(), runner.aim_target(), D(), 0.4, "MM7"))
				invocation.add_growth(sigil, 2.0, false)
				counters["wards"] = int(counters.get("wards", 0)) + 1
	if _last_hit_fired:
		# The intercepted blow emptied Force; it does not refill it.
		_last_hit_fired = false
	elif claims_force():
		var max_hp := runner.player_max_hp()
		if max_hp > 0.0 and not (has("BAQ6") and guarding and runner.still_seconds > 0.0 and raw < 0.02 * max_hp):
			add_force(minf(FORCE_HIT_CAP, FORCE_PER_PERCENT * 100.0 * raw / max_hp))
	if has("BA06") and _last_prevention > 0.0 and source != null and is_instance_valid(source):
		var handle := EnemyCombat.handle_for_actor(source)
		if handle != 0 and runner.enemy_alive(handle):
			var prevented := raw * _last_prevention
			var returned := clampf(0.35 * prevented, 0.2 * D(), 2.0 * D())
			runner.damage_enemy(handle, returned, AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "BA06", "thorns", 1, 0.25, PackedStringArray(["reflected"])))
			counters["thorns"] = int(counters["thorns"]) + 1
			if has("MM8"):
				# Backlash: half the dealt damage becomes Debt on the attacker.
				var distortion := runner.engine_of_discipline("DT") as DistortionEngine
				if distortion != null and runner.enemy_alive(handle):
					distortion.deposit(handle, 0.5 * returned, "backlash", false)
	if has("MR9") and _last_prevention > 0.0 and raw > 0.0:
		# Reactive Armor: a Mine per 10% max HP prevented, fractions banked, three per hit.
		var ordnance := runner.engine_of_discipline("OR") as OrdnanceEngine
		var max_hp_for_mines := runner.player_max_hp()
		if ordnance != null and max_hp_for_mines > 0.0:
			_mine_bank += raw * _last_prevention / (0.1 * max_hp_for_mines)
			var mines := mini(3, int(floor(_mine_bank)))
			_mine_bank -= float(mines)
			for _i in range(mines):
				ordnance.drop_mine(runner.player_position(), OrdnanceEngine.MINE_D, "MR9")
				counters["reactive_mines"] = int(counters.get("reactive_mines", 0)) + 1
	_last_prevention = 0.0


## Last Hit: at 50+ Force a killing blow empties Force and leaves 1 HP.
func intercept_lethal_hit(_damage: float) -> bool:
	if not has("BA12") or force < 50.0 or _last_hit_recovery > 0.0:
		return false
	force = 0.0
	_last_hit_recovery = 45.0
	_last_hit_fired = true
	counters["last_hits"] = int(counters["last_hits"]) + 1
	runner.player().call("grant_invulnerability", 0.5)
	if BattleText != null:
		BattleText.popup(runner.player_position(), "LAST HIT", Color(1.0, 0.9, 0.5, 1.0), 1.5)
	return true


# ---------------------------------------------------------------- strikes

func decorate_native_slash(slash: Node) -> void:
	if has("BA01") and force >= 20.0 and not (has("BA04") and force >= 100.0):
		slash.set("arc_radius", float(slash.get("arc_radius")) + AscensionRunner.R * 0.5)
	if has("BA07") and runner.enemies_in_radius(runner.player_position(), AscensionRunner.R).size() >= 4:
		slash.set("arc_degrees", 340.0)
		_surrounded_volley = _volley + 1
		_surrounded_force = 0.0
		counters["surrounded"] = int(counters["surrounded"]) + 1


func on_native_fire(style: String, origin: Vector2, target: Vector2, _power: float, _haste: float) -> void:
	_volley += 1
	_armor_break_pending = false
	var dir := (target - origin).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	if style == "melee":
		if has("BA02"):
			_return_to_sender(origin, dir)
		if has("BA04") and force >= 100.0:
			_discharge("full_tank", origin, dir)
		elif has("BA01"):
			var spent := spend_force(minf(20.0, force))
			if spent > 0.0:
				_strike_bonus = 0.05 * D() * spent
				_bonus_volley = _volley
				counters["stored_spends"] = int(counters["stored_spends"]) + 1
	elif has("BAA") and has("BA01"):
		# Heavy Hands: foreign Core strikes spend at half the coefficient.
		var spent := spend_force(minf(20.0, force))
		if spent > 0.0:
			_strike_bonus = 0.025 * D() * spent
			_bonus_volley = _volley
			counters["stored_spends"] = int(counters["stored_spends"]) + 1


func modify_outgoing_damage(preview: Dictionary, raw: float) -> float:
	var damage := raw
	if _bonus_volley == _volley and bool(preview["core_strike"]) and preview["family"] == AscensionTags.FAMILY_NATIVE:
		damage += _strike_bonus
	return damage


func on_hit(hit: Dictionary) -> void:
	var handle := int(hit["handle"])
	var core_strike := AscensionTags.has_flag(hit["tags"], "core_strike")
	if _armor_break_pending and core_strike and hit["family"] == AscensionTags.FAMILY_NATIVE:
		runner.status_of(handle)["cracked"] = 5
		counters["armor_breaks"] = int(counters["armor_breaks"]) + 1
		if bool(hit["is_boss"]):
			EnemyCombat.apply_stun(handle, 0.25)
	if _surrounded_volley == _volley and core_strike and _surrounded_force < 20.0:
		var to_enemy := (hit["position"] as Vector2) - runner.player_position()
		if to_enemy.dot(_facing()) < 0.0:
			_surrounded_force += 5.0
			add_force(5.0, false)
	if has("BAA") and _bonus_volley == _volley and core_strike and hit["core"] != "melee":
		if hit["core"] == "ranged":
			runner.spawn_impact(hit["position"], 0.5 * D(), AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "BAA", "impact", 1, 0.5), 0.5 * AscensionRunner.R)
		else:
			EnemyCombat.apply_stun(handle, 0.25)


func on_kill(_hit: Dictionary, _context: RefCounted) -> void:
	pass


func _return_to_sender(origin: Vector2, dir: Vector2) -> void:
	var caught: Array = []
	ProjectileManager.consume_enemy_projectiles_in_sector(origin, AscensionRunner.R, dir, deg_to_rad(60.0), caught, 3)
	for bullet in caught:
		add_force(10.0, false)
		_note_catch()
		counters["returns"] = int(counters["returns"]) + 1
		var source: Variant = bullet["source"]
		var toward := Vector2.ZERO
		if source != null and is_instance_valid(source) and source is Node2D:
			toward = ((source as Node2D).global_position - origin).normalized()
		if toward == Vector2.ZERO:
			toward = -(bullet["velocity"] as Vector2).normalized()
		runner.spawn_bullet(origin, toward, 0.6 * D(), AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "BA02", "return", 1, 0.4))


func _note_catch() -> void:
	_catch_times.append(_clock)
	if has("BA05") and _catch_times.size() >= 3 and _razor_recovery <= 0.0:
		_razor_recovery = 1.0
		_catch_times.clear()
		counters["razor_rings"] = int(counters["razor_rings"]) + 1
		_radial_blades(6, 0.7 * D(), 0.4, "BA05")


func _radial_blades(count: int, damage: float, pp: float, root: String, pierce: int = 0) -> void:
	var origin := runner.player_position()
	for i in range(count):
		runner.spawn_bullet(origin, Vector2.from_angle(TAU * float(i) / float(count)), damage, AscensionTags.make("melee", AscensionTags.FAMILY_TREE, root, "blade", 1, pp), {"pierce": pierce})


# ---------------------------------------------------------------- discharges

## Full Tank (and Q release with a full tank): 3D nova in 2R, plates fired,
## Meltdown on a 100-Force spend.
func _discharge(reason: String, origin: Vector2, dir: Vector2) -> void:
	var spent := spend_force(force)
	runner.note_union_trigger("discharge")
	counters["full_tanks"] = int(counters["full_tanks"]) + 1
	var damage := 3.0 * D()
	if has("BAF2") and spent > 100.0:
		damage += 0.03 * D() * (spent - 100.0)
	runner.spawn_impact(origin, damage, AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "BA04", "impact", 1, 0.5, PackedStringArray([reason])), 2.0 * AscensionRunner.R)
	if plates > 0:
		_radial_blades(plates, D(), 0.5, "BA08", 4)
		counters["vessel_blades"] = int(counters["vessel_blades"]) + plates
		plates = 0
	if has("BAE1") and guarding and not _guard_pool_stored.is_empty():
		_fire_mirror()
	if has("BAC") and spent >= 100.0 and _meltdown_recovery <= 0.0:
		_meltdown()
	if BattleText != null:
		BattleText.popup(origin, "FULL TANK", Color(0.6, 0.9, 1.0, 1.0), 1.3)


func _meltdown() -> void:
	counters["meltdowns"] = int(counters["meltdowns"]) + 1
	_meltdown_recovery = 8.0
	runner.note_catastrophe("BAC")
	_rings = [{"delay": 0.0, "radius": 2.0 * AscensionRunner.R, "kind": "first"}, {"delay": 0.4, "radius": 4.0 * AscensionRunner.R, "kind": "erase"}, {"delay": 0.8, "radius": runner.camera_rect().size.length() * 0.5, "kind": "block"}]
	if BattleText != null:
		BattleText.popup(runner.player_position(), "MELTDOWN", Color(1.0, 0.5, 0.3, 1.0), 1.6)


func _tick_rings(delta: float) -> void:
	if _rings.is_empty():
		return
	var due: Array = []
	for ring in _rings:
		ring["delay"] = float(ring["delay"]) - delta
		if float(ring["delay"]) <= 0.0:
			due.append(ring)
	for ring in due:
		_rings.erase(ring)
		var origin := runner.player_position()
		var radius := float(ring["radius"])
		runner.spawn_impact(origin, 2.0 * D(), AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "BAC", "impact", 1, 0.25), radius)
		match String(ring["kind"]):
			"erase":
				var gone: Array = []
				ProjectileManager.consume_enemy_projectiles_in_radius(origin, radius, gone)
			"block":
				# Each owned on-block payload once, from a virtual 20%-max-HP prevented hit.
				if has("BA06"):
					var returned := clampf(0.35 * 0.2 * runner.player_max_hp(), 0.2 * D(), 2.0 * D())
					for handle in runner.enemies_in_radius(origin, AscensionRunner.R):
						runner.damage_enemy(handle, returned, AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "BA06", "thorns", 2, 0.25, PackedStringArray(["reflected"])))
				if has("BA05"):
					counters["razor_rings"] = int(counters["razor_rings"]) + 1
					_radial_blades(6, 0.7 * D(), 0.4, "BA05")


# ---------------------------------------------------------------- Guard (Q)

func q_is_hold(id: String) -> bool:
	return id == "BAQ"


func activate_q(id: String) -> Dictionary:
	if id != "BAQ":
		return {"ok": false, "message": "NOT BASTION", "cooldown": 0.0}
	if not _bunker.is_empty() and has("BAE2") and not guarding:
		# Bomb Bunker: a tap while not guarding detonates it remotely.
		_resolve_bunker(true)
		return {"ok": true, "message": "DETONATE", "cooldown": 0.0}
	if runner.automatic_cast or runner.reaction_cast:
		# Automatic Guard holds toward the greatest threat for 0.75 s, then releases.
		guarding = true
		_auto_release = 0.75
	else:
		guarding = true
		_auto_release = -1.0
	_guard_pool_stored.clear()
	counters["guards"] = int(counters["guards"]) + 1
	return {"ok": true, "message": "GUARD", "cooldown": 0.0}


var _auto_release: float = -1.0


func hold_q(_id: String, delta: float) -> void:
	if not guarding:
		return
	var still := runner.still_seconds > 0.0 and not runner.is_player_moving()
	_martyr_active = false
	if force > 0.0:
		if not (has("BAQ6") and still):
			spend_force(12.0 * delta)
	elif has("BAQ5") and runner.player_hp() > 0.25 * runner.player_max_hp():
		_martyr_active = true
		runner.pay_health(0.02 * runner.player_max_hp() * delta, &"martyr")
	# Catch ordinary projectiles inside the guard.
	var caught: Array = []
	var facing := _facing()
	var half := PI if has("BAQ1") else deg_to_rad(80.0)
	ProjectileManager.consume_enemy_projectiles_in_sector(runner.player_position(), AscensionRunner.R, facing, half, caught)
	for bullet in caught:
		add_force(10.0, false)
		_note_catch()
		counters["catches"] = int(counters["catches"]) + 1
		if (has("BAQ3") or has("BAE1")) and _guard_pool_stored.size() < 12:
			_guard_pool_stored.append({"source": bullet["source"]})
	if has("BAE1") and not _guard_pool_stored.is_empty():
		_gun_shield_tick += delta
		if _gun_shield_tick >= 0.15:
			_gun_shield_tick = 0.0
			var stored: Dictionary = _guard_pool_stored.pop_front()
			_shoot_stored(stored, D(), "BAE1")
			counters["gun_shield_shots"] = int(counters["gun_shield_shots"]) + 1


func _tick_guard(delta: float) -> void:
	if guarding and _auto_release >= 0.0:
		hold_q("BAQ", delta)
		_auto_release -= delta
		if _auto_release <= 0.0:
			_auto_release = -1.0
			var released := release_q("BAQ")
			runner.q_cooldown_left = float(released.get("cooldown", 4.0))
			runner.q_cooldown_max = runner.q_cooldown_left


func release_q(id: String) -> Dictionary:
	if id != "BAQ" or not guarding:
		return {"ok": false, "message": "", "cooldown": 0.0}
	guarding = false
	_martyr_active = false
	var origin := runner.player_position()
	var facing := _facing()
	if has("BA04") and force >= 100.0:
		_discharge("guard_release", origin, facing)
	var damage := D() * runner.q_scale()
	if has("BAQ2"):
		var spent := spend_force(force * 0.5)
		damage += 0.06 * D() * spent
	runner.spawn_impact(origin, damage, AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "BAQ", "impact", 1, 1.0 * runner.q_proc_scale(), PackedStringArray(["core_strike"])), 2.0 * AscensionRunner.R * runner.q_area_scale())
	counters["guard_waves"] = int(counters["guard_waves"]) + 1
	if has("BAQ3"):
		_fire_mirror()
	if has("BAQ4") or has("BAE2"):
		if not _bunker.is_empty():
			_resolve_bunker(has("BAE2"))
		_bunker = {"pos": origin, "life": 8.0 if has("BAE2") else 3.0, "force": 30.0, "dir": facing, "half": PI if has("BAQ1") else deg_to_rad(80.0), "stored": 0.0}
		counters["bunkers"] = int(counters["bunkers"]) + 1
	return {"ok": true, "message": "RELEASE", "cooldown": 4.0}


func _fire_mirror() -> void:
	while not _guard_pool_stored.is_empty():
		var stored: Dictionary = _guard_pool_stored.pop_front()
		_shoot_stored(stored, 0.75 * D(), "BAQ3")
		counters["mirror_shots"] = int(counters["mirror_shots"]) + 1


func _shoot_stored(stored: Dictionary, damage: float, root: String) -> void:
	var origin := runner.player_position()
	var toward := Vector2.ZERO
	var source: Variant = stored.get("source")
	if source != null and is_instance_valid(source) and source is Node2D:
		toward = ((source as Node2D).global_position - origin).normalized()
	if toward == Vector2.ZERO:
		var nearest := runner.nearest_enemy(origin, 3.0 * AscensionRunner.L)
		toward = (runner.enemy_position(nearest) - origin).normalized() if nearest != 0 else Vector2.RIGHT
	runner.spawn_bullet(origin, toward, damage, AscensionTags.make("melee", AscensionTags.FAMILY_TREE, root, "return", 1, 0.4))


func _tick_bunker(delta: float) -> void:
	if _bunker.is_empty():
		return
	_bunker["life"] = float(_bunker["life"]) - delta
	var caught: Array = []
	ProjectileManager.consume_enemy_projectiles_in_sector(_bunker["pos"], AscensionRunner.R, _bunker["dir"], float(_bunker["half"]), caught)
	for _bullet in caught:
		if has("BAE2"):
			_bunker["stored"] = minf(150.0, float(_bunker["stored"]) + 10.0)
		else:
			_bunker["force"] = float(_bunker["force"]) - 10.0
	if float(_bunker["life"]) <= 0.0 or (not has("BAE2") and float(_bunker["force"]) <= 0.0):
		_resolve_bunker(false)


func _resolve_bunker(detonate: bool) -> void:
	if _bunker.is_empty():
		return
	var at: Vector2 = _bunker["pos"]
	var damage := 2.0 * D()
	if detonate and has("BAE2"):
		damage += 0.04 * D() * float(_bunker["stored"])
	runner.spawn_impact(at, damage, AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "BAQ4", "impact", 1, 0.5), 2.0 * AscensionRunner.R)
	counters["bunker_waves"] = int(counters["bunker_waves"]) + 1
	_bunker = {}


# ---------------------------------------------------------------- RUPTURE (V)

func activate_v(id: String) -> Dictionary:
	if id != "BAV":
		return {"ok": false, "message": "NOT BASTION", "cooldown": 0.0}
	_rupture_spent = spend_force(force)
	_rupture_tell = 0.5
	return {"ok": true, "message": "RUPTURE", "cooldown": 0.0}


func _tick_rupture(delta: float) -> void:
	if _rupture_tell >= 0.0:
		_rupture_tell -= delta
		if _rupture_tell <= 0.0:
			_rupture_tell = -1.0
			_rupture(1.0)
			if has("BAV1"):
				_aftershock_delay = 1.0
	if _aftershock_delay >= 0.0:
		_aftershock_delay -= delta
		if _aftershock_delay <= 0.0:
			_aftershock_delay = -1.0
			_rupture(0.5)


func _rupture(scale: float) -> void:
	counters["ruptures"] = int(counters["ruptures"]) + 1
	var damage := (5.0 * D() + 0.04 * D() * _rupture_spent) * scale
	if has("BAV3"):
		damage *= 2.0
		_no_armor_left = 3.0
	var rect := runner.camera_rect()
	var tags := AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "BAV", "sweep", 1, 0.0, PackedStringArray(["v"]))
	tags.append("cast:rupture:%d" % int(counters["ruptures"]))
	var survivors: Array[int] = []
	for handle in runner.enemies_in_radius(rect.get_center(), rect.size.length() * 0.5):
		if not rect.has_point(runner.enemy_position(handle)):
			continue
		EnemyCombat.apply_stun(handle, 0.5)
		runner.damage_enemy(handle, damage, tags)
		if runner.enemy_alive(handle):
			survivors.append(handle)
	var erased: Array = []
	ProjectileManager.consume_enemy_projectiles_in_radius(rect.get_center(), rect.size.length() * 0.5, erased)
	if has("BAV2") and not survivors.is_empty():
		for bullet in erased:
			var target: int = survivors[runner.rng().randi_range(0, survivors.size() - 1)]
			runner.spawn_impact(runner.enemy_position(target), 0.5 * D(), AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "BAV2", "impact", 2, 0.3, PackedStringArray(["v"])), AscensionRunner.R * 0.5)
			counters["fallout_blades"] = int(counters["fallout_blades"]) + 1
	if scale >= 1.0:
		runner.note_revelation_ended("BAV")
	if BattleText != null:
		BattleText.popup(runner.player_position(), "RUPTURE", Color(1.0, 0.8, 0.5, 1.0), 1.8)


# ---------------------------------------------------------------- multipliers and HUD

func move_speed_multiplier() -> float:
	var mul := 0.5 if guarding and has("BAQ1") else 1.0
	if has("MM9") and force > 100.0:
		mul *= 0.8
	return mul


func hud_state(slot: String) -> Dictionary:
	var state := {}
	if slot == "q":
		state["resource_value"] = force
		state["resource_max"] = capacity()
		if guarding:
			state["combat_text"] = "GUARD"
		elif _plate_ready:
			state["combat_text"] = "FORCE %d  PLATE" % int(force)
		else:
			state["combat_text"] = "FORCE %d" % int(force)
	elif slot == "v" and _rupture_tell >= 0.0:
		state["combat_text"] = "RUPTURE"
	return state


func collect_draw_points(out: Array) -> void:
	for scrap in _scraps:
		out.append([scrap["pos"], 5.0, Color(0.7, 0.8, 0.9, 0.8)])
	if guarding:
		out.append([runner.player_position(), AscensionRunner.R, Color(0.6, 0.9, 1.0, 0.15)])
	if not _bunker.is_empty():
		out.append([_bunker["pos"], AscensionRunner.R, Color(0.6, 0.8, 1.0, 0.2)])
	for i in range(plates):
		out.append([runner.player_position() + Vector2.from_angle(_clock * 2.0 + TAU * float(i) / 3.0) * 30.0, 4.0, Color(0.8, 0.9, 1.0, 0.9)])


func describe() -> Dictionary:
	var out := counters.duplicate()
	out["force"] = force
	out["plates"] = plates
	out["guarding"] = guarding
	out["plate_ready"] = _plate_ready
	return out
