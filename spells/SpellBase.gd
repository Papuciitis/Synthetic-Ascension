extends Node
class_name SpellBase

var caster: Node2D
var data: SpellData

var _cd := 0.0
var is_initialized := false

func setup(_caster: Node2D, _data: SpellData) -> void:
	caster = _caster
	data = _data
	_cd = 0.0
	is_initialized = true

func _process(delta: float) -> void:
	_cd = max(_cd - delta, 0.0)

func try_cast() -> void:
	if not is_initialized:
		return
	if _cd > 0.0:
		return

	if cast():
		_cd = _get_cooldown()

# Override in specific spells if needed (haste scaling, minimum cap, etc.)
func _get_cooldown() -> float:
	return data.cooldown if data != null else 1.0

# Override in child spells
func cast() -> bool:
	return false


func reset_cooldown() -> void:
	_cd = 0.0
