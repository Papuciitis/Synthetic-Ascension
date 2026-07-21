extends Node
class_name EnemySummoned

var _summoner_id: int = 0
var _time_left: float = 0.0

func setup(summoner_id: int, lifetime: float) -> void:
	_summoner_id = summoner_id
	_time_left = lifetime

func _process(delta: float) -> void:
	# If summoner is gone, despawn immediately
	if _summoner_id != 0:
		var summoner := instance_from_id(_summoner_id)
		if summoner == null or not is_instance_valid(summoner):
			_despawn()
			return

	_time_left -= delta
	if _time_left <= 0.0:
		_despawn()

func _despawn() -> void:
	var p := get_parent()
	if p != null and is_instance_valid(p):
		p.queue_free()
	else:
		queue_free()
