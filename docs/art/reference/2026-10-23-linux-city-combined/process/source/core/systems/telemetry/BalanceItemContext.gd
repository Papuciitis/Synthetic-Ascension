class_name BalanceItemContext
extends RefCounted

## Telemetry only: the operation a container mutation belongs to, so the
## balance recorder can group "remove from bag, place in equipment, merge"
## under one operation id with its source (pickup, trade, player, reward,
## undo, debug). Callers open a scope around the operation; containers and
## ItemInstance.merge_from read the current scope when they report. Nothing
## reads the scope for gameplay, and without a recorder listening the scope
## is never pushed.

static var _stack: Array[Dictionary] = []
static var _serial := 0
## A hint the container sets right before a merge it drives (which
## container and slot the destination lives in); merge_from consumes it.
static var container: Dictionary = {}


static func listening() -> bool:
	return RunEvents != null and RunEvents.item_operation.has_connections()


## Opens an operation scope. Returns its id (0 when nothing listens).
static func begin(source: StringName, extra: Dictionary = {}) -> int:
	if not listening():
		return 0
	_serial += 1
	var scope := {"op": _serial, "source": String(source)}
	scope.merge(extra)
	_stack.append(scope)
	return _serial


static func end(op: int) -> void:
	if op <= 0:
		return
	for index in range(_stack.size() - 1, -1, -1):
		if int(_stack[index].get("op", 0)) == op:
			_stack.resize(index)
			return


static func current() -> Dictionary:
	return _stack[-1] if not _stack.is_empty() else {}


static func take_container() -> Dictionary:
	var hint := container
	container = {}
	return hint


## Containers and merge_from report through this; `data` gains the scope.
static func report(kind: StringName, inst: ItemInstance, data: Dictionary) -> void:
	if not listening():
		return
	var scope := current()
	if not scope.is_empty():
		data["op"] = int(scope.get("op", 0))
		data["source"] = String(scope.get("source", ""))
		for key in scope:
			if key != "op" and key != "source" and not data.has(key):
				data[key] = scope[key]
	RunEvents.item_operation.emit(kind, inst, data)


static func reset() -> void:
	_stack.clear()
	container = {}
