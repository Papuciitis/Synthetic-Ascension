extends Node
class_name SpellCaster

const SLOT_COUNT := 3

@export var auto_tick: float = 0.05 # reduce per-frame work

var caster: Node2D
var slots: Array[SpellData] = [null, null, null]
var spell_nodes: Array[SpellBase] = []

var _tick := 0.0

func setup(_caster: Node2D) -> void:
	caster = _caster
	_reload_spells()

func set_slot(index: int, spell: SpellData) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	slots[index] = spell
	_reload_spells()

func _process(delta: float) -> void:
	# Auto-cast driver
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = auto_tick

	for s in spell_nodes:
		if not is_instance_valid(s):
			continue
		if s.data == null:
			continue
		if s.data.auto_cast:
			s.try_cast()

func _reload_spells() -> void:
	for s in spell_nodes:
		if is_instance_valid(s):
			s.queue_free()
	spell_nodes.clear()

	for spell_data in slots:
		if spell_data == null:
			continue
		if spell_data.spell_scene == null:
			push_warning("SpellData has no spell_scene: " + spell_data.id)
			continue

		var node := spell_data.spell_scene.instantiate()
		add_child(node)

		var spell_node := node as SpellBase
		if spell_node == null:
			push_error("Spell scene root must extend SpellBase: " + spell_data.id)
			node.queue_free()
			continue

		spell_node.setup(caster, spell_data)
		spell_nodes.append(spell_node)

func cast_all_manual() -> void:
	# Only manual spells cast here
	for s in spell_nodes:
		if not is_instance_valid(s):
			continue
		if s.data == null:
			continue
		if not s.data.auto_cast:
			s.try_cast()


func reset_all_cooldowns() -> void:
	for s in spell_nodes:
		if not is_instance_valid(s):
			continue
		if s.has_method("reset_cooldown"):
			s.call("reset_cooldown")
		else:
			s.set("_cd", 0.0)
