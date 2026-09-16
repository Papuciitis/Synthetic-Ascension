extends AscensionEngine
class_name DominionEngine
## Dominion: Wells that pull, Links that share, Compel and KNEEL.
##
## Well: radius 1.5R, life 1.5 s, four at most; pulls normals R over 0.5 s,
## elites R/3, bosses convert resisted travel to stagger (stun). Link: one
## group of up to twelve for 3 s. Weight stores resisted pull up to 3L.
## Forced movement is stepped by the engine through the runner's enemy
## move primitive, with terrain contact (Throw) and crossings (Collision)
## checked per step. Interpretations: "stagger" is a stun; a boss converts
## L of resisted travel into 0.5 s of stun.

const EFFECTS: Dictionary = {
	"DO01": &"gravity_well", "DO02": &"dead_weight", "DO03": &"lingering_weight", "DO04": &"collision",
	"DO05": &"bind", "DO06": &"dragnet", "DO07": &"collective_burden", "DO08": &"crushing",
	"DO09": &"anchor", "DO10": &"throw", "DO11": &"collapse", "DO12": &"crowded_well",
	"DOQ": &"compel", "DOQ1": &"ring", "DOQ2": &"chain", "DOQ3": &"repulse", "DOQ4": &"repeat",
	"DOQ5": &"throw_q", "DOQ6": &"crush", "DOF1": &"singularity", "DOF2": &"forced_orbit",
	"DOK1": &"sovereign_ground", "DOK2": &"event_horizon", "DOA": &"common_ground", "DOC": &"black_hole",
	"DOE1": &"mass_grave", "DOE2": &"crowd_pinball", "DOS1": &"pull", "DOS2": &"link_life",
	"DOV": &"kneel", "DOV1": &"pile", "DOV2": &"orbit", "DOV3": &"again",
}
const WELL_RADIUS_MUL := 1.5
const WELL_LIFE := 1.5
const WELL_CAP := 4
const PULL_SECONDS := 0.5
const LINK_LIFE := 3.0
const LINK_MAX := 12
const WEIGHT_MAX := 3.0 * AscensionRunner.L

var _clock: float = 0.0
var wells: Array = []                   # {id, at, life, radius, budget: {handle: remaining}, anchor, crush_hits, crush_tick, shrunk, inside, resisted, black, kind, orbit: {handle: angle}}
var links: Array = []                   # {id, members: Array[int], life}
var stains: Array = []                  # {at, life}
var territories: Array = []             # {at, life}
var weight: float = 0.0
var _serial: int = 0
var _hits: float = 0.0
var _placed_volley: int = -1
var _volley: int = 0
var _dash_armed: bool = false
var _bind_volley: int = -1
var _bind_members: Array[int] = []
var _bind_last_at: float = -INF
var _resisted_bank: float = 0.0
var _hole_recovery: float = 0.0
var _boss_resisted: Array = []          # [clock, distance]
var _throws: Dictionary = {}            # handle -> {dir}
var _collided: Dictionary = {}          # instruction key -> true
var _instruction: int = 0
var _repeat: Dictionary = {}            # {delay, at, dir, radius, cone}
var _q_hold: float = 0.0
var _q_pending: Dictionary = {}
var _graves: Array = []                 # {at, life, pulsed: {}}
var _pinballs: Array = []               # {a, b, life, bodies: {handle: legs}}
var _kneel: Dictionary = {}
var _corpses: Array = []                # Pile {at, life}
var _still_marked: bool = false

var counters: Dictionary = {"wells": 0, "placement_hits": 0, "pulls": 0, "resisted": 0.0, "weight_spent": 0.0, "stains": 0, "stain_pulls": 0, "collisions": 0, "links": 0, "linked": 0, "dragnets": 0, "burdens": 0, "anchors": 0, "crush_hits": 0, "crush_releases": 0, "throws": 0, "collapses": 0, "singularities": 0, "orbits": 0, "territories": 0, "horizons": 0, "compels": 0, "repeats": 0, "q_throws": 0, "crushes": 0, "black_holes": 0, "graves": 0, "grave_pulses": 0, "pinballs": 0, "kneels": 0, "slams": 0, "orbit_shots": 0, "second_slams": 0}


func discipline() -> String:
	return "DO"


func D() -> float:
	return runner.native_damage_for("magic")


func has_wells() -> bool:
	return has("DO01") or has("DO12") or has("DOQ")


# ---------------------------------------------------------------- multipliers

func pull_speed() -> float:
	var speed := AscensionRunner.R / PULL_SECONDS
	if has("DOS1"):
		var r := float(rank("DOS1"))
		speed *= 1.0 + 0.8 * r / (r + 100.0)
	if has("DOK1") and _in_territory(runner.player_position()):
		speed *= 1.5
	return speed


func link_life() -> float:
	var life := LINK_LIFE
	if has("DOS2"):
		var r := float(rank("DOS2"))
		life += 2.0 * r / (r + 70.0)
	return life


func _in_territory(point: Vector2) -> bool:
	for territory in territories:
		if (territory["at"] as Vector2).distance_to(point) <= 2.0 * AscensionRunner.R:
			return true
	return false


func modify_outgoing_damage(preview: Dictionary, raw: float) -> float:
	if has("DOK1") and not territories.is_empty() and AscensionTags.value_of(preview["tags"], "root").begins_with("DO") and not _in_territory(runner.player_position()):
		return raw * 0.75
	return raw


# ---------------------------------------------------------------- wells

func place_well(at: Vector2, kind: String = "well", placement_damage: bool = true) -> Dictionary:
	if wells.size() >= WELL_CAP:
		_expire_well(wells[0])
	_serial += 1
	var well := {"id": _serial, "at": at, "life": WELL_LIFE, "radius": WELL_RADIUS_MUL * AscensionRunner.R, "budget": {}, "anchor": 0, "crush_hits": 0, "crush_tick": 0.0, "shrunk": false, "inside": 0, "resisted": 0.0, "black": 0.0, "kind": kind, "orbit": {}, "caught": {}, "orbit_left": 2.0}
	wells.append(well)
	counters["wells"] = int(counters["wells"]) + 1
	if placement_damage and has("DO01"):
		var tags := AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DO01", "well", 1, 0.4)
		tags.append("cast:well:%d" % int(well["id"]))
		for handle in runner.enemies_in_radius(at, float(well["radius"])):
			runner.damage_enemy(handle, 0.5 * D(), tags)
			counters["placement_hits"] = int(counters["placement_hits"]) + 1
	if has("DO03"):
		_consume_stain(well)
	return well


func _consume_stain(well: Dictionary) -> void:
	var nearest: Dictionary = {}
	var best := 2.0 * AscensionRunner.R
	for stain in stains:
		var d := (stain["at"] as Vector2).distance_to(well["at"])
		if d <= best:
			best = d
			nearest = stain
	if nearest.is_empty():
		return
	stains.erase(nearest)
	counters["stain_pulls"] = int(counters["stain_pulls"]) + 1
	var from: Vector2 = nearest["at"]
	var to: Vector2 = well["at"]
	var out: Array[int] = []
	var ts := PackedFloat32Array()
	var count := EnemyCombat.enemies_on_segment(from, to, AscensionRunner.R * 0.5, 0, out, ts)
	var tags := AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DO03", "line", 1, 0.4)
	var victims: Array[int] = []
	for i in range(count):
		victims.append(out[i])
	_instruction += 1
	for handle in victims:
		runner.damage_enemy(handle, 0.5 * D(), tags)
		if runner.enemy_alive(handle) and runner.is_normal(handle):
			_forced_step(handle, to, AscensionRunner.R, _instruction)
	runner.note_line_fx(from, to, AscensionRunner.R * 0.5)


func _expire_well(well: Dictionary) -> void:
	wells.erase(well)
	if has("DO08") and int(well["crush_hits"]) > 0:
		_crush_release(well)
	if has("DOK2"):
		counters["horizons"] = int(counters["horizons"]) + 1
		runner.spawn_impact(well["at"], 2.0 * D(), AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DOK2", "impact", 1, 0.4), 2.0 * AscensionRunner.R)
	if has("DO03"):
		if stains.size() >= 6:
			stains.pop_front()
		stains.append({"at": well["at"], "life": 4.0})
		counters["stains"] = int(counters["stains"]) + 1
	if has("DOF2") and has("DO10"):
		for handle in (well["orbit"] as Dictionary).keys():
			if _throws.has(handle) and runner.enemy_alive(int(handle)):
				var tangent := Vector2.from_angle(float((well["orbit"] as Dictionary)[handle]) + PI / 2.0)
				_throw(int(handle), tangent)


func _well_radius(well: Dictionary) -> float:
	var radius := float(well["radius"])
	if has("DO12"):
		var bodies := int(well["inside"])
		if has("DOV1"):
			bodies += mini(20, _corpses.size())
		radius *= 1.0 + minf(0.6, 0.05 * float(bodies))
	if bool(well["shrunk"]):
		radius *= 0.8
	return radius


func _acquire_radius(well: Dictionary) -> float:
	if has("DOK2") or float(well["black"]) > 0.0:
		return runner.camera_rect().size.length() * 0.5
	return _well_radius(well)


func _tick_wells(delta: float) -> void:
	if wells.is_empty():
		return
	var speed := pull_speed()
	for i in range(wells.size() - 1, -1, -1):
		var well: Dictionary = wells[i]
		well["life"] = float(well["life"]) - delta
		var at: Vector2 = well["at"]
		var inside := runner.enemies_in_radius(at, _acquire_radius(well))
		well["inside"] = inside.size()
		var pull_scale := 1.0
		if has("DO12"):
			pull_scale = 1.0 - minf(0.24, 0.02 * float(inside.size()))
		# Anchor: the highest-max-HP enemy inside; the Well follows it.
		if has("DO09"):
			var anchor := 0
			var best := -1.0
			for handle in inside:
				var max_hp := runner.enemy_max_hp(handle)
				if max_hp > best:
					best = max_hp
					anchor = handle
			if anchor != 0 and anchor != int(well["anchor"]):
				well["anchor"] = anchor
				counters["anchors"] = int(counters["anchors"]) + 1
			if anchor != 0:
				well["at"] = at.move_toward(runner.enemy_position(anchor), AscensionRunner.L * delta)
				at = well["at"]
		var target := at if int(well["anchor"]) == 0 or not runner.enemy_alive(int(well["anchor"])) else runner.enemy_position(int(well["anchor"]))
		var budget: Dictionary = well["budget"]
		var normals := 0
		var bodies := 0
		for handle in inside:
			if not runner.enemy_alive(handle):
				continue
			(well["caught"] as Dictionary)[handle] = true
			var is_boss := runner.is_boss(handle)
			var is_elite := runner.is_elite(handle)
			bodies += 4 if is_boss else (2 if is_elite else 1)
			if not is_boss and not is_elite:
				normals += 1
			if handle == int(well["anchor"]):
				continue
			if not budget.has(handle):
				var allowance := AscensionRunner.R if (not is_elite and not is_boss) else (AscensionRunner.R / 3.0 if is_elite else 0.0)
				if has("DO02") and weight > 0.0 and not is_boss:
					var spent := minf(weight, AscensionRunner.L)
					weight -= spent
					allowance += spent
					counters["weight_spent"] = float(counters["weight_spent"]) + spent
				budget[handle] = allowance
			var step := speed * pull_scale * delta
			var remaining := float(budget[handle])
			if is_boss:
				_boss_resist(handle, step)
				continue
			if has("DOF2") and float(well["orbit_left"]) > 0.0 and not is_boss:
				_orbit_step(well, handle, delta, is_elite)
				continue
			if remaining <= 0.0:
				# Only durable bodies resist; a normal past its travel simply rests.
				if is_elite:
					_resist(step, true)
				continue
			var moved := minf(step, remaining)
			budget[handle] = remaining - moved
			_instruction_for(well, handle)
			_forced_step(handle, target, moved, int(well["id"]) * 100000)
			counters["pulls"] = int(counters["pulls"]) + 1
		if has("DOF2"):
			well["orbit_left"] = float(well["orbit_left"]) - delta
		_tick_crushing(well, inside, delta)
		if has("DOF1") and bodies >= 6 and float(well["black"]) <= 0.0 and not (has("DOC") and _hole_recovery <= 0.0 and _black_hole_ready(well, normals)):
			_singularity(well, inside)
			continue
		if has("DOC") and _hole_recovery <= 0.0 and float(well["black"]) <= 0.0 and _black_hole_ready(well, normals):
			well["black"] = 1.0
			well["life"] = 1.0
			counters["black_holes"] = int(counters["black_holes"]) + 1
			runner.note_catastrophe("DOC")
			if BattleText != null:
				BattleText.popup(at, "BLACK HOLE", Color(0.5, 0.3, 0.9, 1.0), 1.6)
		if float(well["black"]) > 0.0:
			var consumed: Array = []
			ProjectileManager.consume_enemy_projectiles_in_radius(at, 3.0 * AscensionRunner.R, consumed)
		if float(well["life"]) <= 0.0:
			if float(well["black"]) > 0.0:
				_collapse_black_hole(well)
			else:
				_expire_well(well)


func _instruction_for(well: Dictionary, handle: int) -> void:
	pass


func _black_hole_ready(well: Dictionary, normals: int) -> bool:
	var count := normals
	if has("DOV1"):
		count += mini(20, _corpses.size())
	if count >= 20:
		return true
	for link in links:
		var inside := 0
		for member in link["members"]:
			if (well["caught"] as Dictionary).has(member):
				inside += 1
		if inside >= 8:
			return true
	# A lone boss qualifies after absorbing 3L of resisted travel in 4 s.
	var recent := 0.0
	for entry in _boss_resisted:
		if _clock - float(entry[0]) <= 4.0:
			recent += float(entry[1])
	return recent >= 3.0 * AscensionRunner.L


func _collapse_black_hole(well: Dictionary) -> void:
	wells.erase(well)
	_hole_recovery = 8.0
	var caught := (well["caught"] as Dictionary).size()
	var damage := minf(8.0 * D(), 2.0 * D() + 0.3 * D() * float(caught))
	if has("DOV1"):
		damage += 0.1 * D() * float(mini(20, _corpses.size()))
		_corpses.clear()
	var tags := AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DOC", "impact", 1, 0.3)
	tags.append("cast:well:%d" % int(well["id"]))
	runner.spawn_impact(well["at"], damage, tags, 3.0 * AscensionRunner.R)


func _singularity(well: Dictionary, inside: Array[int]) -> void:
	counters["singularities"] = int(counters["singularities"]) + 1
	var at: Vector2 = well["at"]
	var tags := AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DOF1", "impact", 1, 0.4)
	tags.append("cast:well:%d" % int(well["id"]))
	for handle in inside:
		if runner.is_normal(handle):
			runner.move_enemy_to(handle, at + Vector2.from_angle(runner.rng().randf_range(0.0, TAU)) * 6.0)
		EnemyCombat.apply_stun(handle, 0.5)
		runner.damage_enemy(handle, 1.5 * D(), tags)
	runner.note_impact_fx(at, _well_radius(well))
	wells.erase(well)
	if has("DO03"):
		stains.append({"at": at, "life": 4.0})


func _orbit_step(well: Dictionary, handle: int, delta: float, is_elite: bool) -> void:
	var orbit: Dictionary = well["orbit"]
	var at: Vector2 = well["at"]
	var pos := runner.enemy_position(handle)
	if not orbit.has(handle):
		orbit[handle] = (pos - at).angle()
		EnemyCombat.apply_stun(handle, 0.25 if is_elite else 0.5)
		counters["orbits"] = int(counters["orbits"]) + 1
		if is_elite:
			(well["budget"] as Dictionary)[handle] = 0.0
	if is_elite and float(well["orbit_left"]) < 1.75:
		return
	var radius := maxf(20.0, pos.distance_to(at))
	var angle := float(orbit[handle]) + (pull_speed() / radius) * delta
	orbit[handle] = angle
	runner.move_enemy_to(handle, at + Vector2.from_angle(angle) * radius)


func _resist(step: float, _is_elite: bool) -> void:
	counters["resisted"] = float(counters["resisted"]) + step
	if has("DO02"):
		weight = minf(WEIGHT_MAX, weight + step)
	_resisted_bank += step
	while _resisted_bank >= AscensionRunner.L:
		_resisted_bank -= AscensionRunner.L
		runner.add_action_charge(1.0)


func _boss_resist(handle: int, step: float) -> void:
	_resist(step, false)
	_boss_resisted.append([_clock, step])
	while _boss_resisted.size() > 600:
		_boss_resisted.pop_front()
	# A boss converts L of resisted travel into 0.5 s of stagger.
	var bank := float(runner.status_of(handle).get("stagger_bank", 0.0)) + step
	if bank >= AscensionRunner.L:
		bank -= AscensionRunner.L
		EnemyCombat.apply_stun(handle, 0.5)
	runner.status_of(handle)["stagger_bank"] = bank


## One forced-movement step toward `target`, at most `distance`. Terrain
## contact stores a Throw; crossing another enemy triggers Collision.
func _forced_step(handle: int, target: Vector2, distance: float, instruction: int) -> void:
	var from := runner.enemy_position(handle)
	var dir := (target - from).normalized()
	if dir == Vector2.ZERO or distance <= 0.0:
		return
	var to := from + dir * minf(distance, from.distance_to(target))
	var t := runner.terrain_hit_t(from, to, 10.0)
	if t >= 0.0:
		to = from.lerp(to, maxf(0.0, t - 0.05))
		if has("DO10") and runner.is_normal(handle) and not _throws.has(handle):
			_throws[handle] = {"dir": dir, "instruction": instruction}
	if (has("DO04") or has("DO06")) and runner.is_normal(handle):
		var crossed := runner.nearest_enemy(to, 14.0, handle)
		if crossed != 0:
			var key := "%d:%d" % [instruction, handle]
			if has("DO04") and not _collided.has(key):
				_collided[key] = true
				counters["collisions"] = int(counters["collisions"]) + 1
				var tags := AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DO04", "impact", 2, 0.3)
				runner.damage_enemy(handle, 0.6 * D(), tags)
				runner.damage_enemy(crossed, 0.6 * D(), tags)
			if has("DO06"):
				_dragnet(handle, crossed)
	runner.move_enemy_to(handle, to)


func _throw(handle: int, dir: Vector2) -> void:
	_throws.erase(handle)
	counters["throws"] = int(counters["throws"]) + 1
	var from := runner.enemy_position(handle)
	var to := from + dir * AscensionRunner.R
	var out: Array[int] = []
	var ts := PackedFloat32Array()
	var count := EnemyCombat.enemies_on_segment(from, to, 10.0, handle, out, ts)
	var tags := AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DO10", "line", 2, 0.3)
	for i in range(count):
		runner.damage_enemy(out[i], 0.8 * D(), tags)
	runner.move_enemy_to(handle, to)


func _tick_crushing(well: Dictionary, inside: Array[int], delta: float) -> void:
	if not has("DO08"):
		return
	if inside.size() >= 4 and not bool(well["shrunk"]):
		well["shrunk"] = true
	if not bool(well["shrunk"]) or int(well["crush_hits"]) >= 4:
		return
	well["crush_tick"] = float(well["crush_tick"]) + delta
	if float(well["crush_tick"]) < 0.3:
		return
	well["crush_tick"] = 0.0
	var centre := runner.enemies_in_radius(well["at"], 20.0)
	if centre.is_empty():
		_crush_release(well)
		well["crush_hits"] = 0
		well["shrunk"] = false
		return
	well["crush_hits"] = int(well["crush_hits"]) + 1
	counters["crush_hits"] = int(counters["crush_hits"]) + 1
	var tags := AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DO08", "impact", 1, 0.3)
	for handle in centre:
		runner.damage_enemy(handle, 0.5 * D(), tags)


func _crush_release(well: Dictionary) -> void:
	var hits := int(well["crush_hits"])
	if hits <= 0:
		return
	counters["crush_releases"] = int(counters["crush_releases"]) + 1
	runner.spawn_impact(well["at"], 0.5 * D() * float(hits), AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DO08", "impact", 1, 0.3), 2.0 * AscensionRunner.R)
	well["crush_hits"] = 0


# ---------------------------------------------------------------- links

func link_of(handle: int) -> Dictionary:
	for link in links:
		if (link["members"] as Array).has(handle):
			return link
	return {}


func make_link(members: Array, life: float = -1.0) -> Dictionary:
	_serial += 1
	var link := {"id": _serial, "members": [], "life": link_life() if life < 0.0 else life}
	links.append(link)
	counters["links"] = int(counters["links"]) + 1
	for handle in members:
		join_link(link, int(handle))
	return link


func join_link(link: Dictionary, handle: int) -> bool:
	var members: Array = link["members"]
	if members.size() >= LINK_MAX or members.has(handle) or not link_of(handle).is_empty():
		return false
	members.append(handle)
	runner.status_of(handle)["link"] = int(link["id"])
	counters["linked"] = int(counters["linked"]) + 1
	runner.add_action_charge(1.0)
	return true


func _break_link(link: Dictionary) -> void:
	links.erase(link)
	for handle in link["members"]:
		runner.clear_status(int(handle), "link")


func _tick_links(delta: float) -> void:
	for i in range(links.size() - 1, -1, -1):
		var link: Dictionary = links[i]
		link["life"] = float(link["life"]) - delta
		var members: Array = link["members"]
		for j in range(members.size() - 1, -1, -1):
			if not runner.enemy_alive(int(members[j])):
				members.remove_at(j)
		if float(link["life"]) <= 0.0 or members.is_empty():
			_break_link(link)


func _dragnet(pulled: int, crossed: int) -> void:
	var group := link_of(crossed)
	if not group.is_empty():
		if link_of(pulled).is_empty() and join_link(group, pulled):
			counters["dragnets"] = int(counters["dragnets"]) + 1
		return
	var others := runner.enemies_in_radius(runner.enemy_position(pulled), 16.0, pulled)
	if others.size() >= 2 and link_of(pulled).is_empty():
		var members: Array = [pulled]
		for other in others:
			if members.size() >= 3:
				break
			members.append(other)
		make_link(members, 2.0)
		counters["dragnets"] = int(counters["dragnets"]) + 1


func _note_bind(hit: Dictionary) -> void:
	var handle := int(hit["handle"])
	var single := _bind_volley != _volley and _clock - _bind_last_at <= 0.75
	if _bind_volley != _volley and not single:
		_bind_members.clear()
	_bind_volley = _volley
	_bind_last_at = _clock
	if not _bind_members.has(handle):
		_bind_members.append(handle)
	if _bind_members.size() < 2:
		return
	var group := {}
	for member in _bind_members:
		group = link_of(member)
		if not group.is_empty():
			break
	if group.is_empty():
		make_link(_bind_members.duplicate())
	else:
		join_link(group, handle)


# ---------------------------------------------------------------- hits and kills

func on_native_fire(_style: String, _origin: Vector2, _target: Vector2, _power: float, _haste: float) -> void:
	_volley += 1


func decorate_native_impact(impact: Node) -> void:
	impact.set_meta(AscensionTags.META_KEY, AscensionTags.with_flag(impact.get_meta(AscensionTags.META_KEY, PackedStringArray()), "core_strike"))


func on_player_dashed(_from: Vector2, _direction: Vector2) -> void:
	if has("DO12"):
		_dash_armed = true


func on_hit(hit: Dictionary) -> void:
	var handle := int(hit["handle"])
	var tags: PackedStringArray = hit["tags"]
	var core_strike := AscensionTags.has_flag(tags, "core_strike")
	var is_burden := AscensionTags.has_flag(tags, "burden")
	if core_strike and (hit["core"] == "magic" or has("DOA")):
		if has("DO05") or has("DOA"):
			_note_bind(hit)
	if core_strike and hit["core"] == "magic":
		if has("DO01"):
			_hits += float(hit["pp"])
		var place := false
		if has("DO01") and _hits >= 3.0 - 0.0005 and _placed_volley != _volley:
			_hits -= 3.0
			place = true
		elif has("DO12") and _dash_armed and _placed_volley != _volley:
			_dash_armed = false
			place = true
		if place:
			_placed_volley = _volley
			place_well(hit["position"])
	# Collective Burden: 20% copied to every other member.
	if has("DO07") and not is_burden:
		var group := link_of(handle)
		if not group.is_empty():
			var fraction := 0.2 * (1.5 if (has("DOK1") and _in_territory(runner.player_position())) else 1.0)
			var copy_tags := AscensionTags.make(String(hit["core"]) if not String(hit["core"]).is_empty() else "magic", AscensionTags.FAMILY_TREE, "DO07", "burden", int(hit["gen"]) + 1, 0.25, PackedStringArray(["burden"]))
			for member in (group["members"] as Array).duplicate():
				if int(member) != handle and runner.enemy_alive(int(member)):
					runner.damage_enemy(int(member), fraction * float(hit["applied"]), copy_tags)
					counters["burdens"] = int(counters["burdens"]) + 1
	if has("DOE1") and (bool(hit["is_elite"]) or bool(hit["is_boss"])) and core_strike:
		for grave in _graves:
			if (grave["at"] as Vector2).distance_to(hit["position"]) <= 3.0 * AscensionRunner.R:
				grave["durable"] = float(grave.get("durable", 0.0)) + float(hit["applied"])
				if float(grave["durable"]) >= 3.0 * D() and _clock - float(grave.get("last", -INF)) >= 0.5:
					grave["durable"] = float(grave["durable"]) - 3.0 * D()
					grave["last"] = _clock
					_grave_pulse(grave, hit["position"])


func on_kill(hit: Dictionary, _context: RefCounted) -> void:
	var handle := int(hit["handle"])
	_throws.erase(handle)
	var group := link_of(handle)
	if not group.is_empty():
		(group["members"] as Array).erase(handle)
		if has("DO11") and not bool(group.get("collapsed", false)):
			group["collapsed"] = true
			counters["collapses"] = int(counters["collapses"]) + 1
			var corpse: Vector2 = hit["position"]
			var tags := AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DO11", "impact", int(hit["gen"]) + 1, 0.4)
			_instruction += 1
			for member in (group["members"] as Array).duplicate():
				if runner.enemy_alive(int(member)):
					_forced_step(int(member), corpse, AscensionRunner.R, _instruction)
					runner.damage_enemy(int(member), 0.8 * D(), tags)
			_break_link(group)
	for grave in _graves:
		if (grave["at"] as Vector2).distance_to(hit["position"]) <= 3.0 * AscensionRunner.R and not (grave["pulsed"] as Dictionary).has(handle):
			(grave["pulsed"] as Dictionary)[handle] = true
			_grave_pulse(grave, hit["position"])
	if has("DOV1") and AscensionTags.value_of(hit["tags"], "root") == "DOV":
		if _corpses.size() >= 20:
			_corpses.pop_front()
		_corpses.append({"at": hit["position"], "life": 5.0})


# ---------------------------------------------------------------- tick

func tick(delta: float) -> void:
	_clock += delta
	if _hole_recovery > 0.0:
		_hole_recovery = maxf(0.0, _hole_recovery - delta)
	_tick_wells(delta)
	_tick_links(delta)
	_tick_lists(delta)
	_tick_throw_releases()
	_tick_repeat(delta)
	_tick_pinballs(delta)
	_tick_kneel(delta)
	if has("DOK1"):
		if runner.still_seconds >= 0.75 and not _still_marked:
			_still_marked = true
			if territories.size() >= 2:
				territories.pop_front()
			territories.append({"at": runner.player_position(), "life": 5.0})
			counters["territories"] = int(counters["territories"]) + 1
		elif runner.still_seconds < 0.75:
			_still_marked = false
	if has("DOK2") and not wells.is_empty():
		var strongest: Dictionary = wells[0]
		for well in wells:
			if int(well["inside"]) > int(strongest["inside"]):
				strongest = well
		var player_pos := runner.player_position()
		if player_pos.distance_to(strongest["at"]) > 8.0:
			runner.teleport_player(player_pos.move_toward(strongest["at"], 0.5 * AscensionRunner.L * delta))
		if float(strongest["life"]) <= 0.5:
			var dash: Variant = runner.player().get("_dash")
			if dash != null and float(dash.get("cooldown_left")) < 0.1:
				dash.set("cooldown_left", 0.1)


func _tick_lists(delta: float) -> void:
	for list in [stains, territories, _corpses, _graves]:
		for i in range(list.size() - 1, -1, -1):
			list[i]["life"] = float(list[i]["life"]) - delta
			if float(list[i]["life"]) <= 0.0:
				list.remove_at(i)
	if _collided.size() > 2000:
		_collided.clear()


func _tick_throw_releases() -> void:
	if _throws.is_empty():
		return
	for handle in _throws.keys():
		if not runner.enemy_alive(int(handle)):
			_throws.erase(handle)
			continue
		var moving := false
		for well in wells:
			if (well["budget"] as Dictionary).has(handle) and float((well["budget"] as Dictionary)[handle]) > 0.0 and float(well["life"]) > 0.0:
				moving = true
		if not moving and not has("DOF2"):
			_throw(int(handle), (_throws[handle] as Dictionary)["dir"])


# ---------------------------------------------------------------- Compel (Q)

func q_is_hold(id: String) -> bool:
	return id == "DOQ" and has("DOQ3") and not runner.automatic_cast and not runner.reaction_cast


func activate_q(id: String) -> Dictionary:
	if id != "DOQ":
		return {"ok": false, "message": "NOT DOMINION", "cooldown": 0.0}
	var origin := runner.player_position()
	var aim := runner.auto_aim_for("DOQ") if runner.automatic_cast else runner.aim_target()
	if has("DOQ3") and not runner.automatic_cast and not runner.reaction_cast:
		_q_hold = 0.0
		_q_pending = {"origin": origin, "aim": aim}
		return {"ok": true, "message": "COMPEL", "cooldown": 0.0}
	var push := runner.automatic_cast and has("DOQ3") and String(runner.ledger.state.get("compel_default", "pull")) == "push"
	_compel(origin, aim, push, 1.0)
	return {"ok": true, "message": "COMPEL", "cooldown": 6.0}


func hold_q(_id: String, delta: float) -> void:
	_q_hold += delta


func release_q(id: String) -> Dictionary:
	if id != "DOQ" or _q_pending.is_empty():
		return {"ok": false, "message": "", "cooldown": 0.0}
	var pending := _q_pending
	_q_pending = {}
	_compel(pending["origin"], pending["aim"], _q_hold >= 0.3, 1.0)
	return {"ok": true, "message": "COMPEL", "cooldown": 6.0}


func auto_target(_id: String) -> Vector2:
	var origin := runner.player_position()
	var best := origin + Vector2(AscensionRunner.R, 0)
	var best_count := -1
	for handle in runner.enemies_in_radius(origin, 3.0 * AscensionRunner.L):
		var at := runner.enemy_position(handle)
		var count := runner.enemies_in_radius(at, AscensionRunner.R).size()
		if count > best_count:
			best_count = count
			best = at
	return best


## The pull (or shove): a 90-degree 3R cone toward the cursor, or Ring's
## 2.5R circle at the cursor; up to R of movement, 1D, interrupt.
func _compel(origin: Vector2, aim: Vector2, push: bool, scale: float, repeat: bool = false) -> void:
	counters["compels"] = int(counters["compels"]) + 1
	var centre := aim
	if has("DOQ1"):
		if centre.distance_to(origin) > 3.0 * AscensionRunner.L:
			centre = origin + (centre - origin).normalized() * 3.0 * AscensionRunner.L
	var dir := (aim - origin).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var affected: Array[int] = []
	if has("DOQ1"):
		affected = runner.enemies_in_radius(centre, 2.5 * AscensionRunner.R)
	else:
		for handle in runner.enemies_in_radius(origin, 3.0 * AscensionRunner.R):
			var to_enemy := (runner.enemy_position(handle) - origin).normalized()
			if to_enemy.dot(dir) >= cos(deg_to_rad(45.0)):
				affected.append(handle)
	if not repeat:
		if has("DOE1"):
			_graves.append({"at": centre, "life": 3.0, "pulsed": {}})
			counters["graves"] = int(counters["graves"]) + 1
		if has("DOE2"):
			var perp := Vector2(-dir.y, dir.x)
			var table := {"a": centre - perp * AscensionRunner.R, "b": centre + perp * AscensionRunner.R, "life": 3.0, "bodies": {}, "tick": 0.0}
			for handle in affected:
				(table["bodies"] as Dictionary)[handle] = 0
			_pinballs.append(table)
			counters["pinballs"] = int(counters["pinballs"]) + 1
	var damage := D() * runner.q_scale() * scale
	var pp := 1.0 * runner.q_proc_scale()
	var tags := AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DOQ", "pull", 1, pp, PackedStringArray(["core_strike"]))
	tags.append("cast:compel:%d" % int(counters["compels"]))
	_instruction += 1
	var moved := 0
	var reached: Array[int] = []
	for handle in affected:
		runner.damage_enemy(handle, damage, tags)
		if not runner.enemy_alive(handle):
			continue
		EnemyCombat.apply_stun(handle, 0.2)
		var pos := runner.enemy_position(handle)
		var travel := AscensionRunner.R * scale
		if runner.is_boss(handle):
			_boss_resist(handle, travel)
			reached.append(handle)
			continue
		if runner.is_elite(handle):
			_resist(travel * 2.0 / 3.0, true)
			travel /= 3.0
		var away_from := centre if has("DOQ1") else origin
		var target := pos + (pos - away_from).normalized() * (3.0 * AscensionRunner.R + 1.0) if push else centre
		_forced_step(handle, target, travel, _instruction)
		moved += 1
		if runner.enemy_position(handle).distance_to(centre) <= 24.0 or push:
			reached.append(handle)
		if has("DOQ5") and runner.is_normal(handle):
			var throw_dir := (pos - away_from).normalized() if push else dir
			_throws.erase(handle)
			counters["q_throws"] = int(counters["q_throws"]) + 1
			var from := runner.enemy_position(handle)
			var to := from + throw_dir * 1.5 * AscensionRunner.R
			var out: Array[int] = []
			var ts := PackedFloat32Array()
			var count := EnemyCombat.enemies_on_segment(from, to, 10.0, handle, out, ts)
			var throw_tags := AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DOQ5", "line", 2, 0.3)
			for i in range(count):
				runner.damage_enemy(out[i], 0.8 * D(), throw_tags)
			runner.move_enemy_to(handle, to)
	if has("DOQ6") and not reached.is_empty():
		var crush := minf(6.0 * D(), D() + 0.25 * D() * float(moved))
		var crush_tags := AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DOQ6", "impact", 2, 0.5)
		for handle in reached:
			if runner.enemy_alive(handle):
				runner.damage_enemy(handle, crush, crush_tags)
				counters["crushes"] = int(counters["crushes"]) + 1
	if has("DOQ2") and affected.size() >= 2:
		var ordered := affected.duplicate()
		ordered.sort_custom(func(a, b): return centre.distance_squared_to(runner.enemy_position(a)) < centre.distance_squared_to(runner.enemy_position(b)))
		var group: Array = []
		for handle in ordered:
			if not runner.enemy_alive(handle) or not link_of(handle).is_empty():
				continue
			group.append(handle)
			if group.size() >= LINK_MAX:
				make_link(group)
				group = []
		if group.size() >= 2:
			make_link(group)
	if not repeat:
		place_well(centre, "compel", has("DO01"))
		if has("DOQ4"):
			_repeat = {"delay": 1.0, "origin": origin, "aim": aim, "push": not push}
	runner.note_impact_fx(centre, 2.5 * AscensionRunner.R if has("DOQ1") else AscensionRunner.R)


func _tick_repeat(delta: float) -> void:
	if _repeat.is_empty():
		return
	_repeat["delay"] = float(_repeat["delay"]) - delta
	if float(_repeat["delay"]) <= 0.0:
		var entry := _repeat
		_repeat = {}
		counters["repeats"] = int(counters["repeats"]) + 1
		_compel(entry["origin"], entry["aim"], bool(entry["push"]), 0.6, true)


func _grave_pulse(grave: Dictionary, corpse: Vector2) -> void:
	counters["grave_pulses"] = int(counters["grave_pulses"]) + 1
	var at: Vector2 = grave["at"]
	_instruction += 1
	for handle in runner.enemies_in_radius(at, 3.0 * AscensionRunner.R):
		if runner.enemy_alive(handle) and not runner.is_boss(handle):
			_forced_step(handle, corpse, AscensionRunner.R, _instruction)
	runner.spawn_impact(at, D(), AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DOE1", "impact", 2, 0.4), AscensionRunner.R)


func _tick_pinballs(delta: float) -> void:
	if _pinballs.is_empty():
		return
	for i in range(_pinballs.size() - 1, -1, -1):
		var table: Dictionary = _pinballs[i]
		table["life"] = float(table["life"]) - delta
		table["tick"] = float(table["tick"]) + delta
		if float(table["tick"]) >= 0.25:
			table["tick"] = 0.0
			var bodies: Dictionary = table["bodies"]
			for handle in bodies.keys():
				if not runner.enemy_alive(int(handle)):
					bodies.erase(handle)
					continue
				var legs := int(bodies[handle])
				var max_legs := 1 if runner.is_elite(int(handle)) else 2
				if runner.is_boss(int(handle)):
					if legs < 2:
						runner.damage_enemy(int(handle), D(), AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DOE2", "impact", 2, 0.3))
						bodies[handle] = legs + 1
					continue
				if legs >= max_legs:
					var tangent := ((table["b"] as Vector2) - (table["a"] as Vector2)).normalized().rotated(PI / 2.0)
					_instruction += 1
					_forced_step(int(handle), runner.enemy_position(int(handle)) + tangent * AscensionRunner.R, AscensionRunner.R, _instruction)
					runner.damage_enemy(int(handle), D(), AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DOE2", "impact", 2, 0.3))
					bodies.erase(handle)
					continue
				var target: Vector2 = table["a"] if legs % 2 == 0 else table["b"]
				_instruction += 1
				_forced_step(int(handle), target, 2.0 * AscensionRunner.R, _instruction)
				bodies[handle] = legs + 1
		if float(table["life"]) <= 0.0 or (table["bodies"] as Dictionary).is_empty():
			_pinballs.remove_at(i)


# ---------------------------------------------------------------- KNEEL (V)

func activate_v(id: String) -> Dictionary:
	if id != "DOV":
		return {"ok": false, "message": "NOT DOMINION", "cooldown": 0.0}
	counters["kneels"] = int(counters["kneels"]) + 1
	var rect := runner.camera_rect()
	var cursor := runner.aim_target()
	var caught: Array[int] = []
	var elites: Array[int] = []
	var bosses: Array[int] = []
	for handle in runner.enemies_in_radius(rect.get_center(), rect.size.length() * 0.5):
		if not rect.has_point(runner.enemy_position(handle)) or not runner.enemy_alive(handle):
			continue
		if runner.is_boss(handle):
			bosses.append(handle)
		elif runner.is_elite(handle):
			elites.append(handle)
		else:
			caught.append(handle)
	_kneel = {"at": cursor, "phase": "pull", "left": 1.0, "caught": caught, "elites": elites, "bosses": bosses, "orbit": {}, "scale": 1.0, "count": caught.size(), "shots_done": false}
	_instruction += 1
	for handle in elites:
		_forced_step(handle, cursor, AscensionRunner.R, _instruction)
	if has("DO05") or has("DO06") or has("DOQ2"):
		var group: Array = []
		for handle in caught:
			if not link_of(handle).is_empty():
				continue
			group.append(handle)
			if group.size() >= LINK_MAX:
				make_link(group)
				group = []
		if group.size() >= 2:
			make_link(group)
	return {"ok": true, "message": "KNEEL", "cooldown": 0.0}


func _tick_kneel(delta: float) -> void:
	if _kneel.is_empty():
		return
	var at: Vector2 = _kneel["at"]
	var phase := String(_kneel["phase"])
	_kneel["left"] = float(_kneel["left"]) - delta
	match phase:
		"pull", "return":
			var step := 900.0 * delta
			var arrived := true
			_instruction += 1
			for handle in _kneel["caught"]:
				if not runner.enemy_alive(handle):
					continue
				_forced_step(handle, at, step, _instruction)
				if runner.enemy_position(handle).distance_to(at) > 24.0:
					arrived = false
			if arrived or float(_kneel["left"]) <= 0.0:
				_kneel["phase"] = "hold"
				_kneel["left"] = 1.5 if (has("DOV2") and phase == "pull") else 0.5
		"hold":
			if has("DOV2") and float(_kneel["left"]) > 0.5:
				for handle in _kneel["caught"]:
					if runner.enemy_alive(handle):
						_kneel_orbit(handle, at, delta)
				if float(_kneel["left"]) <= 0.75 and not bool(_kneel["shots_done"]):
					_kneel["shots_done"] = true
					for handle in _kneel["caught"]:
						if runner.enemy_alive(handle) and _is_ranged_normal(handle):
							var pos := runner.enemy_position(handle)
							ProjectileManager.spawn_enemy(pos, (pos - at).normalized() if pos != at else Vector2.RIGHT, 220.0, 5.0, 3.0, null)
							counters["orbit_shots"] = int(counters["orbit_shots"]) + 1
			if float(_kneel["left"]) <= 0.0:
				_slam()
		"again_wait":
			if float(_kneel["left"]) <= 0.0:
				_kneel["phase"] = "return"
				_kneel["left"] = 1.0


func _is_ranged_normal(handle: int) -> bool:
	var actor := EnemyWorld.actor_for_handle(handle) if EnemyWorld.has_method("actor_for_handle") else null
	return actor != null and (actor.is_in_group(&"ranged_enemy") or actor.has_method("fire_projectile"))


func _kneel_orbit(handle: int, at: Vector2, delta: float) -> void:
	var orbit: Dictionary = _kneel["orbit"]
	var pos := runner.enemy_position(handle)
	if not orbit.has(handle):
		orbit[handle] = (pos - at).angle()
	var radius := maxf(30.0, minf(pos.distance_to(at), AscensionRunner.R))
	var angle := float(orbit[handle]) + 4.0 * delta
	orbit[handle] = angle
	runner.move_enemy_to(handle, at + Vector2.from_angle(angle) * radius)


func _slam() -> void:
	var at: Vector2 = _kneel["at"]
	var scale := float(_kneel["scale"])
	var count := int(_kneel["count"])
	counters["slams"] = int(counters["slams"]) + 1
	var damage := minf(12.0 * D(), 4.0 * D() + 0.2 * D() * float(count)) * scale
	if has("DOV2"):
		damage *= 1.5
	var tags := AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DOV", "slam", 1, 0.2, PackedStringArray(["v"]))
	tags.append("cast:kneel:%d" % int(counters["kneels"]))
	var survivors: Array[int] = []
	for handle in _kneel["caught"]:
		if runner.enemy_alive(handle):
			runner.damage_enemy(handle, damage, tags)
			if runner.enemy_alive(handle):
				survivors.append(handle)
	for handle in _kneel["elites"]:
		if runner.enemy_alive(handle):
			runner.damage_enemy(handle, damage, tags)
			if runner.enemy_alive(handle):
				survivors.append(handle)
	for handle in _kneel["bosses"]:
		if runner.enemy_alive(handle):
			runner.damage_enemy(handle, damage, tags)
			EnemyCombat.apply_stun(handle, 0.4)
	runner.note_impact_fx(at, 1.5 * AscensionRunner.R)
	if has("DOV3") and scale >= 1.0 and not survivors.is_empty():
		counters["second_slams"] = int(counters["second_slams"]) + 1
		_instruction += 1
		for handle in survivors:
			var pos := runner.enemy_position(handle)
			var out := (pos - at).normalized()
			if out == Vector2.ZERO:
				out = Vector2.from_angle(runner.rng().randf_range(0.0, TAU))
			_forced_step(handle, pos + out * 3.0 * AscensionRunner.R, 3.0 * AscensionRunner.R, _instruction)
		_kneel["caught"] = survivors
		_kneel["elites"] = []
		_kneel["scale"] = 0.6
		_kneel["phase"] = "again_wait"
		_kneel["left"] = 1.0
		return
	_kneel = {}
	runner.note_revelation_ended("DOV")


# ---------------------------------------------------------------- HUD

func hud_state(slot: String) -> Dictionary:
	var state := {}
	if slot == "q":
		var linked := 0
		for link in links:
			linked += (link["members"] as Array).size()
		state["resource_value"] = weight
		state["resource_max"] = WEIGHT_MAX
		state["combat_text"] = "WELLS %d  LINKS %d" % [wells.size(), linked]
		if weight > 0.0:
			state["combat_text"] += "  WEIGHT %d" % int(weight)
	elif slot == "v" and not _kneel.is_empty():
		state["combat_text"] = "KNEEL"
	return state


func collect_draw_points(out: Array) -> void:
	for well in wells:
		out.append([well["at"], _well_radius(well), Color(0.4, 0.3, 0.8, 0.5 if float(well["black"]) > 0.0 else 0.25)])
	for stain in stains:
		out.append([stain["at"], 8.0, Color(0.4, 0.3, 0.6, 0.4)])
	for territory in territories:
		out.append([territory["at"], 2.0 * AscensionRunner.R, Color(0.6, 0.5, 0.9, 0.12)])
	for link in links:
		var members: Array = link["members"]
		for i in range(members.size() - 1):
			if runner.enemy_alive(int(members[i])) and runner.enemy_alive(int(members[i + 1])):
				out.append([runner.enemy_position(int(members[i])), 2.0, Color(0.8, 0.6, 1.0, 0.6), runner.enemy_position(int(members[i + 1]))])
	for grave in _graves:
		out.append([grave["at"], 3.0 * AscensionRunner.R, Color(0.3, 0.2, 0.4, 0.15)])


func describe() -> Dictionary:
	var out := counters.duplicate()
	out["wells_live"] = wells.size()
	out["links_live"] = links.size()
	out["weight"] = weight
	return out
