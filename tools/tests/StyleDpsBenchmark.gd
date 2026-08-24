extends Node

## Measures what each combat style actually does to a crowd.
##
## Every probe in this repo has been driven with the default style, which is
## "ranged" - so melee and magic have never been measured at all. This fires
## each style at a human-fast input rate into a live horde and reports damage
## dealt, attacks that actually left the weapon, and enemies hit per attack.
##
## Input rate is held IDENTICAL across styles on purpose. Melee has no cooldown
## (it fires on the press, so the player's click rate is the attack rate) while
## ranged and magic are cooldown-gated, and the whole question is what each
## style does with the same hands.

## Presses per second. Fast but human; firing every frame would give melee 60
## attacks a second and measure nothing.
## Melee has no cooldown, so its damage is literally proportional to how fast
## the player clicks - which the other two styles are not. Sweeping the rate is
## the only way to say whether melee is "strong" or "strong if you can spam".
const PRESS_RATES: Array[float] = [4.0, 8.0, 12.0]
const MEASURE_SECONDS: float = 6.0
const HORDE_TARGET: int = 45

const STYLES: Array[String] = ["ranged", "melee", "magic"]

var _is_worker: bool = false
var _damage: float = 0.0
var _hits: int = 0


func _ready() -> void:
	if _is_worker:
		get_tree().create_timer(280.0).timeout.connect(func() -> void:
			push_error("StyleDpsBenchmark timed out")
			get_tree().quit(1)
		)
		_run.call_deferred()
		return
	var worker := Node.new()
	worker.name = "StyleDpsWorker"
	worker.process_mode = Node.PROCESS_MODE_ALWAYS
	worker.set_script(get_script())
	worker.set("_is_worker", true)
	get_tree().root.add_child.call_deferred(worker)


func _run() -> void:
	Global.start_new_attempt()
	Global.attempt_segment = 2
	Global.attempt_opening_completed = true
	Global.attempt_opening_phase = 10
	Global.debug_dev_mode = true
	Global.debug_player_god_mode = true
	Global.goto_game()

	var player: Node2D = null
	for _wait in range(500):
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group(&"player") as Node2D
		if player != null:
			break
	if player == null:
		push_error("FAIL: no player")
		get_tree().quit(1)
		return
	_disable_modals(get_tree().root)
	get_tree().paused = false

	RunEvents.damage_dealt.connect(_on_damage)

	print("STYLE BENCH  window=%.0fs  horde=%d" % [MEASURE_SECONDS, HORDE_TARGET])
	for rate in PRESS_RATES:
		for style in STYLES:
			await _measure(player, style, rate)
	print("NOTE  measured with a target in contact every press. Ranged's real")
	print("NOTE  advantage is not needing one: 520 px reach vs melee's 62 px.")
	print("StyleDpsBenchmark: done")
	get_tree().quit(0)


func _on_damage(_who: Node, amount: float) -> void:
	_damage += amount
	_hits += 1


func _measure(player: Node2D, style: String, presses_per_sec: float) -> void:
	Global.selected_style_id = style
	if player.has_method("refresh_run_state"):
		player.call("refresh_run_state")
	var spawner := get_tree().get_first_node_in_group(&"enemy_spawner")

	# Let a crowd gather before the clock starts, so every style is measured
	# against the same wall of bodies rather than against whatever wandered in.
	for _warm in range(180):
		await get_tree().process_frame
		if spawner != null and spawner.has_method("spawn_burst"):
			spawner.call("spawn_burst", 6)
		if _alive() >= HORDE_TARGET:
			break

	_damage = 0.0
	_hits = 0
	var attacks: int = 0
	var elapsed: float = 0.0
	var since_press: float = 0.0
	var interval: float = 1.0 / maxf(0.5, presses_per_sec)
	var top_up: float = 0.0

	while elapsed < MEASURE_SECONDS:
		await get_tree().process_frame
		var delta: float = get_process_delta_time()
		elapsed += delta
		since_press += delta
		top_up += delta
		# Top up hard. Every style wiped the crowd part-way through the first
		# run, so the tail of the window was measuring an empty room.
		if top_up >= 0.25:
			top_up = 0.0
			var missing: int = HORDE_TARGET - _alive()
			if missing > 0 and spawner != null and spawner.has_method("spawn_burst"):
				spawner.call("spawn_burst", mini(missing, 12))
		if since_press < interval:
			continue
		since_press = 0.0
		attacks += 1
		# Stand ON the crowd before every press.
		#
		# Without this the measurement is dominated by whether the horde
		# happened to wander inside melee's 62 px reach, which swung its number
		# by 3x between runs while magic (which lands at the cursor) and ranged
		# (which travels) barely moved. Contact is the melee player's JOB - the
		# question here is what each style does once it has a target, not how
		# good the enemy AI is at walking into a slash.
		var contact := _aim_point(player)
		if contact != player.global_position:
			player.global_position = contact - Vector2(46, 0)
		# Aim at the nearest live enemy, which is what a player does. A fixed
		# offset made ranged look terrible for a reason that was the harness's
		# fault: melee and magic land on or near the player and hit regardless
		# of aim, while a bullet fired at empty ground hits nothing.
		player.call("_fire_weapon", _aim_point(player))

	var dps: float = _damage / maxf(0.001, elapsed)
	print("STYLE %-7s @%4.1f/s  dps=%7.1f  dmg/press=%6.1f  presses=%3d  hits/press=%4.2f  alive=%d" % [
		style,
		presses_per_sec,
		dps,
		_damage / maxf(1.0, float(attacks)),
		attacks,
		float(_hits) / maxf(1.0, float(attacks)),
		_alive()
	])


func _aim_point(player: Node2D) -> Vector2:
	var world := get_node_or_null("/root/EnemyWorld")
	if world != null and world.has_method("nearest_enemy") and world.has_method("get_position"):
		var handle: int = int(world.call("nearest_enemy", player.global_position, 900.0))
		if handle != -1:
			var at: Vector2 = world.call("get_position", handle)
			if at != Vector2.ZERO:
				return at
	var nearest: Node2D = null
	var best := INF
	for enemy in get_tree().get_nodes_in_group(&"enemy"):
		var node := enemy as Node2D
		if node == null or not is_instance_valid(node):
			continue
		var d := player.global_position.distance_squared_to(node.global_position)
		if d < best:
			best = d
			nearest = node
	if nearest != null:
		return nearest.global_position
	return player.global_position + Vector2(90, 0)


## EnemyWorld exposes active_count(), not alive_count() - the first version of
## this asked for the wrong name, got 0 every time, and therefore topped the
## horde up on every tick. That flooded the field and made the two area styles
## look far better than they are.
func _alive() -> int:
	var world := get_node_or_null("/root/EnemyWorld")
	if world != null and world.has_method("active_count"):
		return int(world.call("active_count"))
	var index := get_node_or_null("/root/EnemyIndex")
	if index != null and index.has_method("alive_count"):
		return int(index.call("alive_count"))
	return get_tree().get_nodes_in_group(&"enemies").size()


func _disable_modals(node: Node) -> void:
	var script: Variant = node.get_script()
	if script != null and String(script.resource_path).ends_with("TutorialModalController.gd"):
		node.queue_free()
		return
	for child in node.get_children():
		_disable_modals(child)
