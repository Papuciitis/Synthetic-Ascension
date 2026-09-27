extends Node2D
class_name BekaCompanionEffect
## Beka, the memorial companion (handoff 2026-09-25 §14.2, approved
## prototype). A rare Offhand: Comfortable Company — a real absorbable
## shield that regenerates after quiet — and What Have You Got There? —
## a 12-second pulse that pulls health pickups to a wounded player and
## highlights nearby equipment without touching them.
##
## She is safe: deals nothing, draws no attacks, blocks no navigation.
## Sleeping communicates shield regeneration; a small meow and restrained
## ring communicate a collection pulse that actually found something.

# ---- Comfortable Company (approved numbers) ----
const REGEN_DELAY := 4.0             # seconds after the last damaging hit
const REGEN_FRACTION_PER_SECOND := 0.04
const CAPACITY_BASE_FRACTION := 0.20
const CAPACITY_MAX_FRACTION := 0.30

# ---- What Have You Got There? (approved 12 s / 320 u; defaults documented) ----
const PULSE_PERIOD := 12.0
const PULSE_RADIUS := 320.0
const PULL_SECONDS := 2.0
const PULL_SPEED := 420.0            # the existing maximum magnet speed
const HIGHLIGHT_SECONDS := 3.0
const HIGHLIGHT_COLOR := Color(1.35, 1.2, 0.75, 1.0)

const CAT_OFFSET := Vector2(-24.0, -16.0)
const CAT_FOLLOW_SPEED := 6.0

var player: Node2D = null
var item: ItemInstance = null
var slot_index: int = -1

var shield: float = 0.0
var _delay_left: float = 0.0
var _pulse_left: float = PULSE_PERIOD
var _pulls: Dictionary = {}          # pickup node -> seconds of attraction left
var _highlights: Dictionary = {}     # pickup node -> {left, original modulate}
var _cat_pos: Vector2 = Vector2.ZERO
var _cat_face_left: bool = false
var _sit_texture: Texture2D = null
var _sleep_texture: Texture2D = null
var _meow_pulse: float = 0.0
var telemetry: Dictionary = {"absorbed": 0.0, "full_absorbs": 0, "pulses": 0, "health_pulled": 0, "highlighted": 0}


func get_effects_short(inst: ItemInstance) -> PackedStringArray:
	var fraction := capacity_fraction_for(inst)
	var out := PackedStringArray()
	out.append("Comfortable Company: after %.0f s without being hit, regenerates a shield at %.0f%% of max HP per second, up to %.0f%% of max HP." % [REGEN_DELAY, REGEN_FRACTION_PER_SECOND * 100.0, fraction * 100.0])
	out.append("What Have You Got There?: every %.0f s, pulls nearby health to you when wounded and points out nearby equipment." % PULSE_PERIOD)
	out.append("Beka keeps you company. She is in no danger.")
	return out


## The existing item-strength curve with baseline S = 1 (handoff formula:
## min(0.30, 0.20 x S)).
func capacity_fraction_for(inst: ItemInstance) -> float:
	var strength := inst.rarity_effect_multiplier() if inst != null else 1.0
	return minf(CAPACITY_MAX_FRACTION, CAPACITY_BASE_FRACTION * strength)


func setup_with_item(p: Node, inst: ItemInstance, slot: int) -> void:
	player = p as Node2D
	item = inst
	slot_index = slot


func set_item_instance(inst: ItemInstance) -> void:
	item = inst


func _ready() -> void:
	z_index = 4
	# Equipping (and re-equipping) starts empty with the full delay.
	shield = 0.0
	_delay_left = REGEN_DELAY
	if player != null:
		_cat_pos = player.global_position + CAT_OFFSET
	_sit_texture = _texture("res://assets/textures/companions/beka_sit.png")
	_sleep_texture = _texture("res://assets/textures/companions/beka_sleep.png")
	if RunEvents != null and not RunEvents.player_damage_taken.is_connected(_on_player_damage_taken):
		RunEvents.player_damage_taken.connect(_on_player_damage_taken)


func _exit_tree() -> void:
	# Unequipping clears the shield and progress; re-equipping starts empty
	# with the full delay. Highlights are restored, never left stuck.
	shield = 0.0
	for node in _highlights:
		if is_instance_valid(node):
			(node as CanvasItem).modulate = _highlights[node]["original"]
	_highlights.clear()
	_pulls.clear()
	if RunEvents != null and RunEvents.player_damage_taken.is_connected(_on_player_damage_taken):
		RunEvents.player_damage_taken.disconnect(_on_player_damage_taken)


static func _texture(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


func _max_hp() -> float:
	return float(player.get("max_hp")) if player != null else 100.0


func capacity() -> float:
	return capacity_fraction_for(item) * _max_hp()


## Player._take_damage offers the mitigated hit here before testing HP
## lethality. Every real absorbed hit restarts the delay; the return value
## is what the shield actually soaked.
func absorb_damage(amount: float) -> float:
	if amount <= 0.0 or shield <= 0.0:
		# A real hit still interrupts regeneration even at zero shield;
		# the HP-loss signal below handles that path.
		return 0.0
	var soaked := minf(shield, amount)
	shield -= soaked
	_delay_left = REGEN_DELAY
	telemetry["absorbed"] = float(telemetry["absorbed"]) + soaked
	if soaked >= amount:
		telemetry["full_absorbs"] = int(telemetry["full_absorbs"]) + 1
	return soaked


## HP damage that landed (never evasions, never pay_health, which uses its
## own signal) also restarts the delay.
func _on_player_damage_taken(who: Node, amount: float, _position: Vector2) -> void:
	if who == player and amount > 0.0:
		_delay_left = REGEN_DELAY


func is_regenerating() -> bool:
	return _delay_left <= 0.0 and shield < capacity() and player != null and not bool(player.get("is_dead"))


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	# Shield: capacity can shrink with max HP (clamp), never auto-fills up.
	var cap := capacity()
	shield = minf(shield, cap)
	if _delay_left > 0.0:
		_delay_left = maxf(0.0, _delay_left - delta)
	elif shield < cap and not bool(player.get("is_dead")):
		shield = minf(cap, shield + REGEN_FRACTION_PER_SECOND * _max_hp() * delta)
	# The pulse: fixed cadence, never banked, paused with the tree (Node
	# processing already pauses).
	_pulse_left -= delta
	if _pulse_left <= 0.0:
		_pulse_left = PULSE_PERIOD
		_fire_pulse()
	_tick_pulls(delta)
	_tick_highlights(delta)
	_tick_cat(delta)
	if _meow_pulse > 0.0:
		_meow_pulse = maxf(0.0, _meow_pulse - delta)
	queue_redraw()


## Selection happens once per pulse: armed health pickups toward a wounded
## player, equipment highlighted only. Line of sight at selection; nothing
## is pulled through solid walls.
func _fire_pulse() -> void:
	telemetry["pulses"] = int(telemetry["pulses"]) + 1
	var origin := player.global_position
	var wounded: bool = float(player.get("hp")) < _max_hp()
	var found := 0
	if wounded and get_tree() != null:
		for node in get_tree().get_nodes_in_group(GroundLootCap.HEALTH_GROUP):
			var pickup := node as Node2D
			if pickup == null or not is_instance_valid(pickup):
				continue
			if origin.distance_to(pickup.global_position) > PULSE_RADIUS:
				continue
			if _wall_between(origin, pickup.global_position):
				continue
			_pulls[pickup] = PULL_SECONDS
			found += 1
	if get_tree() != null:
		for node in get_tree().get_nodes_in_group(GroundLootCap.ITEM_GROUP):
			var pickup := node as Node2D
			if pickup == null or not is_instance_valid(pickup):
				continue
			if origin.distance_to(pickup.global_position) > PULSE_RADIUS:
				continue
			if _wall_between(origin, pickup.global_position):
				continue
			if not _highlights.has(pickup):
				_highlights[pickup] = {"left": HIGHLIGHT_SECONDS, "original": (pickup as CanvasItem).modulate}
				(pickup as CanvasItem).modulate = HIGHLIGHT_COLOR
				found += 1
			else:
				(_highlights[pickup] as Dictionary)["left"] = HIGHLIGHT_SECONDS
	# A quiet pulse stays quiet; a find gets one restrained meow.
	if found > 0:
		_meow_pulse = 0.8
		if BattleText != null and not _hub_beka_present():
			BattleText.popup(_cat_pos, "meow", Color(0.95, 0.8, 0.85, 0.9), 0.9)


func _wall_between(from: Vector2, to: Vector2) -> bool:
	if ProjectileManager == null:
		return false
	return ProjectileManager.world_hit_t(from, to, 4.0) >= 0.0


## Attraction: up to 2 s at up to the existing 420 u/s magnet ceiling; stops
## the moment HP is full. Pickups keep their own arming, collection and
## lifetime rules — this only carries them closer.
func _tick_pulls(delta: float) -> void:
	if _pulls.is_empty():
		return
	if float(player.get("hp")) >= _max_hp():
		_pulls.clear()
		return
	var origin := player.global_position
	for node in _pulls.keys():
		if not is_instance_valid(node):
			_pulls.erase(node)
			continue
		var left := float(_pulls[node]) - delta
		if left <= 0.0:
			_pulls.erase(node)
			continue
		_pulls[node] = left
		var pickup := node as Node2D
		pickup.global_position = pickup.global_position.move_toward(origin, PULL_SPEED * delta)
		if pickup.global_position.distance_to(origin) < 24.0:
			telemetry["health_pulled"] = int(telemetry["health_pulled"]) + 1
			_pulls.erase(node)


func _tick_highlights(delta: float) -> void:
	if _highlights.is_empty():
		return
	for node in _highlights.keys():
		if not is_instance_valid(node):
			_highlights.erase(node)
			continue
		var entry: Dictionary = _highlights[node]
		entry["left"] = float(entry["left"]) - delta
		var canvas := node as CanvasItem
		if float(entry["left"]) <= 0.0:
			canvas.modulate = entry["original"]
			_highlights.erase(node)
		else:
			var wave := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
			canvas.modulate = (entry["original"] as Color).lerp(HIGHLIGHT_COLOR, 0.4 + 0.4 * wave)


## In the hub Beka is at home as her own character (HubBeka), who follows
## the player there when equipped; this companion's cat stays out of sight.
func _hub_beka_present() -> bool:
	return is_inside_tree() and get_tree().get_first_node_in_group(&"hub_beka") != null


func _tick_cat(delta: float) -> void:
	var target := player.global_position + CAT_OFFSET
	var to_target := target - _cat_pos
	if to_target.length() > 2.0:
		_cat_pos = _cat_pos.lerp(target, clampf(delta * CAT_FOLLOW_SPEED, 0.0, 1.0))
		_cat_face_left = to_target.x < 0.0


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	draw_set_transform_matrix(get_global_transform().affine_inverse())
	# The cat: asleep while regenerating, sitting otherwise. She rides near
	# the player, behind the aim point, small enough to hide nothing.
	var sleeping := is_regenerating()
	var texture := _sleep_texture if sleeping else _sit_texture
	var hidden_in_hub := _hub_beka_present()
	if not hidden_in_hub and texture != null:
		# Fixed WORLD height regardless of the art's resolution (the
		# user-supplied sprites are 64 px masters; the cat stays cat-sized).
		var target_height := 24.0 if sleeping else 34.0
		var size := texture.get_size() * (target_height / maxf(texture.get_size().y, 1.0))
		var at := _cat_pos - size * 0.5
		if _cat_face_left:
			draw_set_transform_matrix(get_global_transform().affine_inverse() * Transform2D(0.0, Vector2(-1.0, 1.0), 0.0, _cat_pos))
			draw_texture_rect(texture, Rect2(-size * 0.5, size), false)
			draw_set_transform_matrix(get_global_transform().affine_inverse())
		else:
			draw_texture_rect(texture, Rect2(at, size), false)
	elif not hidden_in_hub:
		draw_circle(_cat_pos, 6.0, Color(0.15, 0.14, 0.15, 1.0))
	# Purring while asleep: two soft drifting z-dots.
	if sleeping and not hidden_in_hub:
		var t := Time.get_ticks_msec() / 1000.0
		var rise := fmod(t, 1.6) / 1.6
		draw_circle(_cat_pos + Vector2(8.0, -10.0 - rise * 8.0), 1.5, Color(0.9, 0.9, 1.0, 0.7 * (1.0 - rise)))
	# The shield: a thin arc around the player, honest about its fraction.
	var cap := capacity()
	if cap > 0.0 and shield > 0.0:
		var fraction := shield / cap
		var radius := 30.0
		draw_arc(player.global_position, radius, -PI * 0.5, -PI * 0.5 + TAU * fraction, 40, Color(0.75, 0.9, 1.0, 0.75), 2.5, true)
		if fraction >= 1.0:
			draw_arc(player.global_position, radius + 2.5, 0.0, TAU, 48, Color(0.75, 0.9, 1.0, 0.2), 1.0, true)
	# The collection pulse's restrained ring.
	if _meow_pulse > 0.0:
		var grow := 1.0 - _meow_pulse / 0.8
		draw_arc(player.global_position, PULSE_RADIUS * grow, 0.0, TAU, 64, Color(0.95, 0.85, 0.9, 0.35 * (1.0 - grow)), 2.0, true)


## HUD text for the shield (ItemEffectRunner surfaces nothing by default;
## the arc above is the primary readout).
func describe() -> Dictionary:
	return {"shield": shield, "capacity": capacity(), "delay_left": _delay_left, "pulse_in": _pulse_left, "telemetry": telemetry.duplicate()}
