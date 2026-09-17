extends Node
class_name BurnDot

var _target: Node = null
var _source: Node = null

var _stacks: int = 0
var _time_left: float = 0.0
var _tick: float = 0.5
var _tick_left: float = 0.0
var _dmg_per_tick_per_stack: float = 0.1

func setup(target: Node, source: Node, stacks: int, duration: float, tick_interval: float, dmg_per_tick_per_stack: float) -> void:
	_target = target
	_source = source
	_stacks = maxi(_stacks, stacks) # refresh can increase stacks
	_time_left = maxf(_time_left, duration)
	_tick = maxf(tick_interval, 0.05)
	_dmg_per_tick_per_stack = maxf(dmg_per_tick_per_stack, 0.01)
	_tick_left = minf(_tick_left, _tick) # make it feel responsive
	# When attached to an enemy that drives its own dots, the enemy's simulation
	# step ticks us at its scheduler cadence — no 60 Hz idle callback per dot.
	if get_parent() == target and target.has_method("register_dot"):
		target.call("register_dot", self)
		set_process(false)
	else:
		set_process(true)

func _process(dt: float) -> void:
	tick(dt)

func tick(dt: float) -> void:
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return

	_time_left -= dt
	if _time_left <= 0.0:
		queue_free()
		return

	_tick_left -= dt
	if _tick_left > 0.0:
		return
	_tick_left = _tick

	var dmg: float = float(_stacks) * _dmg_per_tick_per_stack

	# Prefer unblockable if enemies support it
	if _target.has_method("take_damage_unblockable"):
		_target.call("take_damage_unblockable", dmg, _source)
	elif _target.has_method("take_damage"):
		_target.call("take_damage", dmg, _source)
