extends RefCounted
class_name RiteProgressLedger

const SEAL_FRACTIONS: Array[float] = [1.0 / 3.0, 2.0 / 3.0, 1.0]

var _sealed_count: int = 0
var _spent_waves: Dictionary = {}


func update_fraction(fraction: float) -> PackedInt32Array:
	var crossed := PackedInt32Array()
	var clamped := clampf(fraction, 0.0, 1.0)
	while _sealed_count < SEAL_FRACTIONS.size() and clamped >= SEAL_FRACTIONS[_sealed_count]:
		_sealed_count += 1
		crossed.append(_sealed_count)
	return crossed


func clamp_loss_fraction(proposed: float) -> float:
	return maxf(clampf(proposed, 0.0, 1.0), floor_fraction())


func sealed_count() -> int:
	return _sealed_count


func floor_fraction() -> float:
	return 0.0 if _sealed_count == 0 else float(SEAL_FRACTIONS[_sealed_count - 1])


func initialize_sealed(count: int) -> void:
	_sealed_count = clampi(count, 0, SEAL_FRACTIONS.size())


func mark_wave_spent(index: int) -> bool:
	if index < 0 or _spent_waves.has(index):
		return false
	_spent_waves[index] = true
	return true


func spent_wave_count() -> int:
	return _spent_waves.size()
