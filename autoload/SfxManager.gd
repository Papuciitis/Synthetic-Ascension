extends Node
# SfxManager: lightweight ID-based SFX playback (UI + 2D spatial + simple loops)
# Reads: res://assets/audio/sfx/sfx_manifest.txt

const MANIFEST_PATH: String = "res://assets/audio/sfx/sfx_manifest.txt"
const BASE_DIR: String = "res://assets/audio/sfx/"

class SoundDef:
	var stream: AudioStream
	var vol_db: float = -8.0
	var pitch_jitter: float = 0.0 # +/- fraction, e.g. 0.05 = ±5%
	var loop: bool = false
	var bus: StringName = &"Master"

@export var pool_size: int = 24
@export var max_simul_per_id: int = 6

# Global gains (easy balancing vs music)
@export var ui_gain_db: float = 0.0
@export var sfx_gain_db: float = 0.0

var _defs: Dictionary = {} # StringName -> SoundDef
var _active_counts: Dictionary = {} # StringName -> int

var _ui: AudioStreamPlayer
var _ui_current_id: StringName = &""

var _pool: Array[AudioStreamPlayer2D] = []
var _headless := false
var _loops: Dictionary = {} # String -> AudioStreamPlayer2D (key = "<owner_id>:<tag>")

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	# Nothing is audible in headless runs (the real audio driver still mixes
	# silently), so skipping voice starts is lossless and saves mixer work in
	# CI. Note: this does NOT fix the intermittent engine exit crash — that
	# reproduces even with all playback suppressed and with --audio-driver
	# Dummy, and is a pre-existing Godot 4.7.1 teardown race.
	_headless = DisplayServer.get_name() == "headless"
	_rng.randomize()
	_load_manifest()

	_ui = AudioStreamPlayer.new()
	_ui.bus = _best_bus(&"UI")
	_ui.finished.connect(_on_ui_finished)
	add_child(_ui)

	for i in range(pool_size):
		var p := AudioStreamPlayer2D.new()
		p.bus = _best_bus(&"SFX")
		p.finished.connect(_on_pooled_finished.bind(p))
		p.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(p)
		_pool.append(p)

	# Hook RunEvents (keeps SFX wiring centralized). Do it deferred so autoload order is safe.
	call_deferred("_hook_run_events")

func _hook_run_events() -> void:
	var re := get_node_or_null("/root/RunEvents")
	if re == null or not is_instance_valid(re):
		return
	if re.has_signal("weapon_fired"):
		re.weapon_fired.connect(_on_weapon_fired)
	if re.has_signal("enemy_defeated"):
		re.enemy_defeated.connect(_on_enemy_defeated)
	if re.has_signal("boss_spawned"):
		re.boss_spawned.connect(_on_boss_spawned)

# ----------------------------
# Public API
# ----------------------------

func play_ui(id: StringName, vol_add_db: float = 0.0) -> void:
	if _headless:
		return
	var def := _defs.get(id) as SoundDef
	if def == null or def.stream == null:
		return
	if _too_many(id):
		return

	# If we interrupt a currently playing UI sound, decrement its bookkeeping first.
	if _ui.playing and _ui_current_id != &"":
		_dec(_ui_current_id)

	_ui.stop()
	_ui.stream = def.stream
	_ui.bus = _best_bus(def.bus)
	_ui.volume_db = def.vol_db + vol_add_db + ui_gain_db
	_ui.pitch_scale = _jittered_pitch(1.0, def.pitch_jitter)
	_ui.play()

	_ui_current_id = id
	_inc(id)

func play_2d(id: StringName, world_pos: Vector2, vol_add_db: float = 0.0) -> void:
	if _headless:
		return
	var def := _defs.get(id) as SoundDef
	if def == null or def.stream == null:
		return
	if _too_many(id):
		return

	var p := _obtain_player()
	if p == null:
		return

	p.stop()
	p.global_position = world_pos
	p.stream = def.stream
	p.bus = _best_bus(def.bus)
	p.volume_db = def.vol_db + vol_add_db + sfx_gain_db
	p.pitch_scale = _jittered_pitch(1.0, def.pitch_jitter)

	_apply_loop_flag(def.stream, def.loop)
	p.play()
	_inc(id)
	p.set_meta(&"sfx_id", id)

# Loop attached to an owner (stops automatically when owner is freed)
func ensure_loop_2d(owner_node: Node2D, tag: StringName, id: StringName, vol_add_db: float = 0.0) -> void:
	if owner_node == null or not is_instance_valid(owner_node):
		return
	var def := _defs.get(id) as SoundDef
	if def == null or def.stream == null:
		return

	var key := str(owner_node.get_instance_id()) + ":" + String(tag)
	var existing := _loops.get(key) as AudioStreamPlayer2D
	if existing != null and is_instance_valid(existing):
		existing.volume_db = def.vol_db + vol_add_db + sfx_gain_db
		if not existing.playing:
			existing.play()
		return

	var p := AudioStreamPlayer2D.new()
	p.bus = _best_bus(def.bus)
	p.stream = def.stream
	p.volume_db = def.vol_db + vol_add_db + sfx_gain_db
	p.pitch_scale = 1.0
	p.global_position = owner_node.global_position
	_apply_loop_flag(def.stream, true) # force loop for loop players

	owner_node.add_child(p)
	_loops[key] = p
	p.tree_exited.connect(_on_loop_exited.bind(key))
	p.play()

func stop_loop(owner_node: Node, tag: StringName) -> void:
	if owner_node == null:
		return
	var key := str(owner_node.get_instance_id()) + ":" + String(tag)
	var p := _loops.get(key) as AudioStreamPlayer2D
	if p != null and is_instance_valid(p):
		p.stop()
		p.queue_free()
	_loops.erase(key)

# ----------------------------
# RunEvents hooks
# ----------------------------

func _on_weapon_fired(_player: Node, style_id: StringName, origin: Vector2, _target: Vector2, _power_mul: float, _haste_mul: float) -> void:
	if style_id == &"melee":
		play_2d(&"player_melee_swing", origin)
	elif style_id == &"magic":
		play_2d(&"player_magic_cast", origin)
	else:
		play_2d(&"player_ranged_shot", origin)

func _on_enemy_defeated(context: RefCounted) -> void:
	if context != null:
		play_2d(&"enemy_death", context.get("position") as Vector2)

func _on_boss_spawned(boss: Node, _tier: int, _portrait: Texture2D, _title: String) -> void:
	if boss is Node2D:
		play_2d(&"boss_intro", (boss as Node2D).global_position)
	else:
		play_ui(&"boss_intro")

# ----------------------------
# Internals
# ----------------------------

func _load_manifest() -> void:
	_defs.clear()

	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("[SfxManager] Missing manifest: " + MANIFEST_PATH)
		return

	var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if f == null:
		push_warning("[SfxManager] Failed to open manifest.")
		return

	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue

		# id=path|vol=-10|pitch=0.04|loop=1|bus=UI
		var parts := line.split("|")
		var head := parts[0]
		var eq := head.find("=")
		if eq <= 0:
			continue

		var id := StringName(head.substr(0, eq).strip_edges())
		var path := head.substr(eq + 1).strip_edges()

		if not path.begins_with("res://"):
			path = BASE_DIR + path

		var stream := load(path) as AudioStream
		if stream == null:
			push_warning("[SfxManager] Could not load: " + path)
			continue

		var def := SoundDef.new()
		def.stream = stream

		for i in range(1, parts.size()):
			var kv := parts[i].split("=")
			if kv.size() != 2:
				continue
			var k := kv[0].strip_edges()
			var v := kv[1].strip_edges()
			match k:
				"vol":
					def.vol_db = float(v)
				"pitch":
					def.pitch_jitter = float(v)
				"loop":
					def.loop = (v == "1" or v.to_lower() == "true")
				"bus":
					def.bus = StringName(v)

		_defs[id] = def

func _best_bus(wanted: StringName) -> StringName:
	var idx := AudioServer.get_bus_index(String(wanted))
	return wanted if idx >= 0 else &"Master"

func _apply_loop_flag(stream: AudioStream, loop_on: bool) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop_on
	elif stream is AudioStreamWAV:
		var w: AudioStreamWAV = stream
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop_on else AudioStreamWAV.LOOP_DISABLED

func _obtain_player() -> AudioStreamPlayer2D:
	for p in _pool:
		if not p.playing:
			return p
	return _pool[0] if _pool.size() > 0 else null

func _too_many(id: StringName) -> bool:
	# Recount from actual playing nodes to avoid stale bookkeeping across pauses/scene transitions.
	var c: int = 0
	if _ui != null and _ui.playing and _ui_current_id == id:
		c += 1
	for p in _pool:
		if p == null or not is_instance_valid(p):
			continue
		if not p.playing:
			continue
		if p.has_meta(&"sfx_id"):
			var pid := p.get_meta(&"sfx_id") as StringName
			if pid != null and pid == id:
				c += 1
	for k in _loops.keys():
		var lp := _loops.get(k) as AudioStreamPlayer2D
		if lp == null or not is_instance_valid(lp) or not lp.playing:
			continue
		if lp.has_meta(&"sfx_id"):
			var lid := lp.get_meta(&"sfx_id") as StringName
			if lid != null and lid == id:
				c += 1
	_active_counts[id] = c
	return c >= max_simul_per_id

func _inc(id: StringName) -> void:
	_active_counts[id] = int(_active_counts.get(id, 0)) + 1

func _dec(id: StringName) -> void:
	var c := int(_active_counts.get(id, 0)) - 1
	if c <= 0:
		_active_counts.erase(id)
	else:
		_active_counts[id] = c

func _on_ui_finished() -> void:
	if _ui_current_id != &"":
		_dec(_ui_current_id)
		_ui_current_id = &""

func _exit_tree() -> void:
	# Shutdown hygiene: leave no active or stream-holding voices for
	# AudioServer finalization. This narrows the teardown surface but does not
	# eliminate the pre-existing engine exit race (see _ready note).
	if _ui != null and is_instance_valid(_ui):
		_ui.stop()
		_ui.stream = null
	for p in _pool:
		if p != null and is_instance_valid(p):
			p.stop()
			p.stream = null


func _on_pooled_finished(p: AudioStreamPlayer2D) -> void:
	# release per-id concurrency bookkeeping
	if p.has_meta(&"sfx_id"):
		var id := p.get_meta(&"sfx_id") as StringName
		if id != null and id != &"":
			_dec(id)
	p.set_meta(&"sfx_id", null)

func _on_loop_exited(key: String) -> void:
	_loops.erase(key)

func _jittered_pitch(base: float, jitter: float) -> float:
	if jitter <= 0.0:
		return base
	var r := _rng.randf_range(-jitter, jitter)
	return maxf(0.05, base * (1.0 + r))
