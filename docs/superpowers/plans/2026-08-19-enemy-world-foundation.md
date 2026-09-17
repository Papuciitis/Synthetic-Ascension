# Enemy World Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the authoritative, generation-safe enemy storage and spatial-query foundation, shadow existing materialized enemies through a compatibility bridge, and expose diagnostics without changing gameplay behavior yet.

**Architecture:** A new `EnemyWorld` autoload owns stable handles, hot/cold enemy state, a handle-based spatial grid, and safe weak Node bindings. During this first vertical slice, `EnemyIndex` remains the active gameplay registry and mirrors its register/update/unregister lifecycle into `EnemyWorld`; later plans move lifecycle and combat authority behind the new APIs before any Node is dematerialized.

**Tech Stack:** Godot 4.7.1, typed GDScript, packed arrays, `WeakRef`, existing `.tscn` headless test convention, existing `PerformanceFlightRecorder`.

**Spec:** `docs/superpowers/specs/2026-08-19-authoritative-enemy-world-design.md`

## Global Constraints

- Keep the game behaviorally unchanged in this plan: every spawned enemy remains a materialized Node and existing combat still uses `EnemyIndex`.
- The new handle is a 64-bit integer containing a one-based slot token in the low 32 bits and a nonzero generation in the high 32 bits; `0` is always invalid.
- Removing a record invalidates its handle before the storage slot can be reused.
- New storage and query code must never retain a strong reference to an enemy Node.
- Existing uncommitted pool-safety, projectile-buffer publication, warning cleanup, and their tests must be preserved.
- Do not add a worker thread, C++ extension, dependency, save-format change, or gameplay-balance change.
- Every production change begins with a focused failing test and ends with the focused suite passing.
- Use the Godot console executable at `C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe`.
- Do not claim a gameplay FPS improvement from this foundation; runtime scaling is validated only after proxy simulation is enabled in later plans.

## Delivery sequence

This is the first of four dependent implementation plans:

1. **Foundation (this plan):** storage, handles, spatial grid, bindings, shadow bridge, diagnostics.
2. **Authoritative lifecycle and combat:** spawn/death/retirement/reward ownership, proxy-aware projectiles, melee, spells, AOE, DOT, and knockback.
3. **Proxy representation:** materialization budget, pooled actor bindings, data-only movement, interpolation, and batched rendering for basic chase enemies.
4. **Archetype and scale rollout:** activity brains and round-trip state for smart enemies, removal of scheduler exemptions, 180/300/500/600 runtime gates, and the new safety cap.

Each plan must leave the project runnable and independently testable. Proxy eligibility remains disabled until the relevant combat and lifecycle paths are handle-aware.

## File structure

### New production files

- `core/systems/enemy_world/EnemyWorldTypes.gd` — shared representation/flag enums and handle bit helpers only.
- `core/systems/enemy_world/EnemySpawnState.gd` — typed construction payload for one logical enemy record.
- `core/systems/enemy_world/EnemySpatialGrid.gd` — Node-free slot spatial hash with O(1) swap removal.
- `core/systems/enemy_world/EnemyWorld.gd` — authoritative storage, lifecycle primitives, state accessors, spatial filtering, weak bindings, and debug counters.

### New focused tests

- `tools/tests/EnemyWorldStorageTest.gd` and `.tscn` — allocation, state, removal, slot reuse, and stale handles.
- `tools/tests/EnemyWorldSpatialTest.gd` and `.tscn` — insert/move/remove, radius queries, nearest queries, and huge-radius behavior.
- `tools/tests/EnemyWorldBindingTest.gd` and `.tscn` — binding uniqueness, freed actors, legacy adoption/release, and state synchronization.
- `tools/tests/EnemyWorldBenchmark.gd` and `.tscn` — deterministic 600-record movement/query benchmark and storage invariants.

### Modified files

- `project.godot` — register `EnemyWorld` after `EnemyIndex` and before systems that sample it.
- `autoload/EnemyIndex.gd` — mirror existing Node lifecycle and position changes into `EnemyWorld`; preserve every public Node-returning API.
- `autoload/PerformanceFlightRecorder.gd` — sample Enemy World counters and read `last_revision` from flow diagnostics.
- `tools/tests/EnemyIndexTest.gd` — prove the compatibility mirror does not change existing queries or population counts.
- `tools/tests/PerformanceFlightRecorderTest.gd` — prove the new schema and corrected flow revision.

---

### Task 0: Preserve and checkpoint the existing verified fixes

**Files:**
- Modify: none
- Verify: `autoload/PoolManager.gd`
- Verify: `core/combat/projectile/ProjectileSimulationManager.gd`
- Verify: `core/actors/enemy/modules/BurnDot.gd`
- Verify: `core/actors/enemy/modules/BleedDot.gd`
- Verify: `core/settings/InputBindingCodec.gd`
- Verify: `ui/screens/settings/SettingsScreen.gd`
- Verify: `tools/tests/EnemyPoolTest.gd`
- Verify: `tools/tests/ProjectileSlotReuseTest.gd`

**Interfaces:**
- Consumes: the current dirty working tree containing the already-reviewed pool, projectile-buffer, and warning fixes.
- Produces: a clean prerequisite commit so later task commits cannot accidentally mix with or discard those fixes.

- [ ] **Step 1: Confirm only the expected prerequisite files are dirty**

Run:

```powershell
git status --short
git diff --check
git diff --stat
```

Expected: exactly the eight prerequisite files listed above are modified, no whitespace errors are printed, and the Enemy World files do not exist yet except for this plan/spec documentation.

- [ ] **Step 2: Re-run the focused prerequisite tests**

Run:

```powershell
$godot = 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe'
& $godot --headless --path . res://tools/tests/EnemyPoolTest.tscn
& $godot --headless --path . res://tools/tests/ProjectileSlotReuseTest.tscn
& $godot --headless --path . --editor --quit
```

Expected: both focused scenes exit `0`, report zero failures, and the editor parse gate exits `0` without the previously listed enum/shadow warnings.

- [ ] **Step 3: Commit only the prerequisite fixes**

Run:

```powershell
git add -- autoload/PoolManager.gd core/actors/enemy/modules/BleedDot.gd core/actors/enemy/modules/BurnDot.gd core/combat/projectile/ProjectileSimulationManager.gd core/settings/InputBindingCodec.gd tools/tests/EnemyPoolTest.gd tools/tests/ProjectileSlotReuseTest.gd ui/screens/settings/SettingsScreen.gd
git commit -m "fix: harden pooled actors and projectile rendering"
```

Expected: one commit containing only the eight files; the design commit `561e66d` remains its parent or earlier ancestor.

---

### Task 1: Define stable handle and spawn-state contracts

**Files:**
- Create: `core/systems/enemy_world/EnemyWorldTypes.gd`
- Create: `core/systems/enemy_world/EnemySpawnState.gd`
- Create: `tools/tests/EnemyWorldStorageTest.gd`
- Create: `tools/tests/EnemyWorldStorageTest.tscn`

**Interfaces:**
- Consumes: no production runtime state.
- Produces: `EnemyWorldTypes.INVALID_HANDLE`, `make_handle(slot: int, generation: int) -> int`, `slot_from_handle(handle: int) -> int`, `generation_from_handle(handle: int) -> int`, `EnemyWorldTypes.Representation`, `EnemyWorldTypes.Flags`, and `EnemySpawnState` fields used by every later task.

- [ ] **Step 1: Add the storage test scene and failing handle-contract tests**

Create `tools/tests/EnemyWorldStorageTest.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource path="res://tools/tests/EnemyWorldStorageTest.gd" type="Script" id="1"]

[node name="EnemyWorldStorageTest" type="Node"]
script = ExtResource("1")
```

Create the test harness with these exact initial assertions:

```gdscript
extends Node

const Types = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

var _passes := 0
var _failures := 0

func _ready() -> void:
	call_deferred(&"_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	var handle: int = Types.make_handle(17, 9)
	_check(handle != Types.INVALID_HANDLE, "constructed handle is valid")
	_check(Types.slot_from_handle(handle) == 17, "handle preserves slot")
	_check(Types.generation_from_handle(handle) == 9, "handle preserves generation")
	_check(Types.slot_from_handle(Types.INVALID_HANDLE) == -1, "zero handle has no slot")
	var state := SpawnState.new(&"grunt", "res://scenes/world/enemies/EnemyGrunt.tscn", Vector2(12.0, 34.0), 50.0, 150.0, 24.0, 0)
	_check(state.spec_id == &"grunt", "spawn state preserves spec id")
	_check(state.position == Vector2(12.0, 34.0), "spawn state preserves position")
	_check(state.health == 50.0 and state.max_health == 50.0, "spawn state starts at max health")
	print("EnemyWorldStorageTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)
```

- [ ] **Step 2: Run the test and verify the missing scripts fail**

Run:

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tools/tests/EnemyWorldStorageTest.tscn
```

Expected: nonzero exit because `EnemyWorldTypes.gd` and `EnemySpawnState.gd` do not exist.

- [ ] **Step 3: Implement the shared types**

Create `EnemyWorldTypes.gd` with no Node dependencies:

```gdscript
class_name EnemyWorldTypes
extends RefCounted

const INVALID_HANDLE: int = 0
const SLOT_MASK: int = 0xFFFFFFFF

enum Representation {
	DATA_ONLY = 0,
	MATERIALIZED = 1,
	DYING = 2,
}

enum Flags {
	NONE = 0,
	ELITE = 1 << 0,
	CRITICAL = 1 << 1,
	OBJECTIVE = 1 << 2,
	TUTORIAL = 1 << 3,
	NEVER_RETIRE = 1 << 4,
	SPECIAL = 1 << 5,
}

static func make_handle(slot: int, generation: int) -> int:
	if slot < 0 or generation <= 0:
		return INVALID_HANDLE
	return (generation << 32) | (slot + 1)

static func slot_from_handle(handle: int) -> int:
	if handle == INVALID_HANDLE:
		return -1
	return int(handle & SLOT_MASK) - 1

static func generation_from_handle(handle: int) -> int:
	if handle == INVALID_HANDLE:
		return 0
	return int(handle >> 32)

static func has_flag(flags: int, flag: int) -> bool:
	return (flags & flag) != 0
```

- [ ] **Step 4: Implement the typed construction payload**

Create `EnemySpawnState.gd`:

```gdscript
class_name EnemySpawnState
extends RefCounted

var spec_id: StringName
var scene_path: String
var position: Vector2
var velocity: Vector2 = Vector2.ZERO
var health: float
var max_health: float
var speed: float
var collision_radius: float
var ai_kind: int
var flags: int = 0
var cold_state: Dictionary = {}

func _init(
	p_spec_id: StringName,
	p_scene_path: String,
	p_position: Vector2,
	p_max_health: float,
	p_speed: float,
	p_collision_radius: float,
	p_ai_kind: int,
	p_flags: int = 0,
	p_cold_state: Dictionary = {},
) -> void:
	spec_id = p_spec_id
	scene_path = p_scene_path
	position = p_position
	health = maxf(p_max_health, 0.0)
	max_health = maxf(p_max_health, 0.0)
	speed = maxf(p_speed, 0.0)
	collision_radius = maxf(p_collision_radius, 0.0)
	ai_kind = p_ai_kind
	flags = p_flags
	cold_state = p_cold_state.duplicate(true)
```

- [ ] **Step 5: Run the focused test and parse gate**

Run the storage scene and `--headless --path . --editor --quit`.

Expected: the test reports `7` passing assertions and zero failures; the parse gate exits `0` without warnings from the new scripts.

- [ ] **Step 6: Commit the contract**

```powershell
git add -- core/systems/enemy_world/EnemyWorldTypes.gd core/systems/enemy_world/EnemySpawnState.gd tools/tests/EnemyWorldStorageTest.gd tools/tests/EnemyWorldStorageTest.tscn
git commit -m "feat: define stable enemy world handles"
```

---

### Task 2: Implement the Node-free spatial grid

**Files:**
- Create: `core/systems/enemy_world/EnemySpatialGrid.gd`
- Create: `tools/tests/EnemyWorldSpatialTest.gd`
- Create: `tools/tests/EnemyWorldSpatialTest.tscn`

**Interfaces:**
- Consumes: stable integer storage slots from Task 1.
- Produces: `insert(slot: int, position: Vector2)`, `move(slot: int, position: Vector2)`, `remove(slot: int)`, `gather_candidate_slots(origin: Vector2, radius: float, out: Array[int])`, `has_slot(slot: int) -> bool`, `active_cell_count() -> int`, `max_cell_occupancy() -> int`, and `clear()`.

- [ ] **Step 1: Write failing spatial-grid tests**

Create the `.tscn` using the same one-script Node structure as Task 1. The test script must instantiate `EnemySpatialGrid.new(64.0)` and assert:

```gdscript
grid.insert(3, Vector2(10.0, 10.0))
grid.insert(8, Vector2(70.0, 10.0))
grid.insert(13, Vector2(4000.0, 0.0))
var candidates: Array[int] = []
grid.gather_candidate_slots(Vector2.ZERO, 100.0, candidates)
_check(candidates.has(3) and candidates.has(8), "nearby cells are gathered")
_check(not candidates.has(13), "distant cells are excluded")
grid.move(8, Vector2(4100.0, 0.0))
grid.gather_candidate_slots(Vector2.ZERO, 100.0, candidates)
_check(candidates == [3], "moving a slot removes its old bucket entry")
grid.remove(3)
_check(not grid.has_slot(3), "removed slot leaves the grid")
grid.remove(3)
_check(not grid.has_slot(3), "repeated removal is idempotent")
grid.gather_candidate_slots(Vector2.ZERO, 50000.0, candidates)
_check(candidates.has(8) and candidates.has(13), "huge radius scans occupied buckets")
```

Also insert slots `20`, `21`, and `22` in one cell, remove the middle slot, and verify the other two remain exactly once. This catches swap-index corruption.

- [ ] **Step 2: Run the spatial test and verify it fails**

Expected: nonzero exit because `EnemySpatialGrid.gd` is absent.

- [ ] **Step 3: Implement cell membership and O(1) removal**

Create `EnemySpatialGrid.gd` with these fields and rules:

```gdscript
class_name EnemySpatialGrid
extends RefCounted

var cell_size: float
var _buckets: Dictionary = {}        # Vector2i -> Array[int]
var _slot_cells: Dictionary = {}      # int -> Vector2i
var _slot_bucket_indices: Dictionary = {} # int -> int

func _init(p_cell_size: float = 64.0) -> void:
	cell_size = maxf(p_cell_size, 1.0)

func _cell_for(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / cell_size), floori(position.y / cell_size))

func insert(slot: int, position: Vector2) -> void:
	if slot < 0:
		return
	if _slot_cells.has(slot):
		move(slot, position)
		return
	var cell := _cell_for(position)
	var bucket: Array = _buckets.get(cell, [])
	_slot_cells[slot] = cell
	_slot_bucket_indices[slot] = bucket.size()
	bucket.append(slot)
	_buckets[cell] = bucket

func remove(slot: int) -> void:
	if not _slot_cells.has(slot):
		return
	var cell: Vector2i = _slot_cells[slot]
	var bucket: Array = _buckets[cell]
	var index: int = int(_slot_bucket_indices[slot])
	var last_index := bucket.size() - 1
	if index != last_index:
		var moved_slot: int = int(bucket[last_index])
		bucket[index] = moved_slot
		_slot_bucket_indices[moved_slot] = index
	bucket.pop_back()
	if bucket.is_empty():
		_buckets.erase(cell)
	else:
		_buckets[cell] = bucket
	_slot_cells.erase(slot)
	_slot_bucket_indices.erase(slot)

func move(slot: int, position: Vector2) -> void:
	var next_cell := _cell_for(position)
	if _slot_cells.get(slot, next_cell) == next_cell and _slot_cells.has(slot):
		return
	remove(slot)
	insert(slot, position)
```

Implement `gather_candidate_slots` so it clears `out`, computes the cell window, scans `_buckets.values()` when the requested window contains more cells than there are occupied buckets, otherwise scans only the coordinate window. It appends candidate slots without distance-filtering; `EnemyWorld` performs exact position/radius filtering. Implement the four diagnostic methods from the Interfaces block.

- [ ] **Step 4: Run the focused spatial tests twice**

Expected: both consecutive runs exit `0` with zero failures; the swap-remove test proves iteration order is irrelevant but membership is exact.

- [ ] **Step 5: Commit the grid**

```powershell
git add -- core/systems/enemy_world/EnemySpatialGrid.gd tools/tests/EnemyWorldSpatialTest.gd tools/tests/EnemyWorldSpatialTest.tscn
git commit -m "feat: add enemy handle spatial grid"
```

---

### Task 3: Build generation-safe Enemy World storage

**Files:**
- Create: `core/systems/enemy_world/EnemyWorld.gd`
- Modify: `tools/tests/EnemyWorldStorageTest.gd`
- Modify: `tools/tests/EnemyWorldSpatialTest.gd`

**Interfaces:**
- Consumes: `EnemyWorldTypes`, `EnemySpawnState`, and `EnemySpatialGrid`.
- Produces: record creation/removal, typed state accessors, active-slot iteration, exact nearest/radius queries, and `get_debug_counters()`.

Required public signatures:

```gdscript
func create_enemy(state: EnemySpawnState) -> int
func remove_enemy(handle: int, reason: StringName = &"removed") -> bool
func is_valid_handle(handle: int) -> bool
func active_count() -> int
func active_handles(out: Array[int]) -> void
func get_position(handle: int) -> Vector2
func get_previous_position(handle: int) -> Vector2
func set_position(handle: int, value: Vector2) -> bool
func get_velocity(handle: int) -> Vector2
func set_velocity(handle: int, value: Vector2) -> bool
func get_health(handle: int) -> float
func get_max_health(handle: int) -> float
func set_health(handle: int, value: float) -> bool
func get_speed(handle: int) -> float
func get_collision_radius(handle: int) -> float
func get_spec_id(handle: int) -> StringName
func get_scene_path(handle: int) -> String
func get_ai_kind(handle: int) -> int
func get_flags(handle: int) -> int
func set_flags(handle: int, value: int) -> bool
func get_representation(handle: int) -> int
func set_representation(handle: int, value: int) -> bool
func get_cold_state(handle: int) -> Dictionary
func replace_cold_state(handle: int, value: Dictionary) -> bool
func gather_in_radius(origin: Vector2, radius: float, out: Array[int], excluded_handle: int = 0) -> void
func nearest_enemy(origin: Vector2, max_distance: float, excluded_handle: int = 0) -> int
func clear_world() -> void
func get_debug_counters() -> Dictionary
```

- [ ] **Step 1: Extend storage tests to fail on missing world behavior**

Instantiate `EnemyWorld.gd` directly, add it to the test tree, and create three records. Assert all of the following:

- handles are nonzero and distinct;
- state getters equal the supplied `EnemySpawnState`;
- `set_position` preserves the old position as `previous_position`;
- `set_health` clamps to `[0, max_health]`;
- `active_handles` contains every live handle exactly once;
- removing a handle returns `true` once and `false` thereafter;
- every accessor returns its documented neutral default for a stale handle;
- the next allocation may reuse the old slot but has a different generation;
- the stale handle cannot mutate the reused record;
- `clear_world` invalidates all outstanding handles and resets active count.

Use neutral defaults: `Vector2.ZERO`, `0.0`, `0`, `StringName()`, empty `String`, and empty `Dictionary`.

- [ ] **Step 2: Run the storage test and verify the world script is missing**

Expected: nonzero exit naming `EnemyWorld.gd`.

- [ ] **Step 3: Implement packed hot storage and dense active iteration**

Create `EnemyWorld.gd` beginning with:

```gdscript
class_name EnemyWorldService
extends Node

const Types = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")
const SpatialGrid = preload("res://core/systems/enemy_world/EnemySpatialGrid.gd")

@export var cell_size: float = 64.0

var _active := PackedByteArray()
var _generations := PackedInt64Array()
var _positions := PackedVector2Array()
var _previous_positions := PackedVector2Array()
var _velocities := PackedVector2Array()
var _health := PackedFloat32Array()
var _max_health := PackedFloat32Array()
var _speeds := PackedFloat32Array()
var _collision_radii := PackedFloat32Array()
var _ai_kinds := PackedInt32Array()
var _flags := PackedInt64Array()
var _representations := PackedInt32Array()
var _active_slots := PackedInt32Array()
var _active_slot_indices := PackedInt32Array()
var _free_slots := PackedInt32Array()
var _spec_ids: Array[StringName] = []
var _scene_paths := PackedStringArray()
var _cold_states: Array[Dictionary] = []
var _grid: EnemySpatialGrid
var _removed_by_reason: Dictionary = {}

func _ready() -> void:
	_grid = SpatialGrid.new(cell_size)
```

Add `_append_slot_storage()` that resizes every packed array and typed array to the same new capacity, initializes generation to `1`, active-slot index to `-1`, representation to `Types.Representation.DATA_ONLY`, and cold state to `{}`. Add `_slot_if_valid(handle)` that checks slot bounds, active byte, and exact generation before returning the slot or `-1`.

`create_enemy` must pop a slot from `_free_slots` or append storage, populate every field, append the slot to `_active_slots`, store its dense index, insert it in `_grid`, and return `Types.make_handle(slot, _generations[slot])`.

`remove_enemy` must validate first, remove the slot from the grid and dense active list using swap removal, mark inactive, clear cold/string fields, increment generation with a nonzero wrap rule, append the slot to `_free_slots`, and increment `_removed_by_reason[reason]`. It must not shrink arrays.

`clear_world` must remove the current active handles through the same invalidation path rather than clearing generations and resetting capacity. A handle issued before `clear_world` must stay stale even after new records are created.

- [ ] **Step 4: Implement typed accessors and exact spatial queries**

Every accessor calls `_slot_if_valid` once. Setters return `false` for invalid handles. `set_position` writes the current value to `_previous_positions`, writes the new value, and calls `_grid.move(slot, value)`.

`gather_in_radius` obtains candidate slots from the grid, reconstructs each current handle from its slot/generation, filters active status, exclusion, and exact squared distance, then appends handles to the caller-provided array. `nearest_enemy` uses `gather_in_radius`, compares squared distances, and returns `Types.INVALID_HANDLE` when no target qualifies.

`get_debug_counters()` returns exactly:

```gdscript
{
	"logical": _active_slots.size(),
	"capacity": _active.size(),
	"free_slots": _free_slots.size(),
	"materialized": _count_representation(Types.Representation.MATERIALIZED),
	"data_only": _count_representation(Types.Representation.DATA_ONLY),
	"dying": _count_representation(Types.Representation.DYING),
	"spatial_cells": _grid.active_cell_count(),
	"max_cell_occupancy": _grid.max_cell_occupancy(),
	"removed_by_reason": _removed_by_reason.duplicate(),
}
```

- [ ] **Step 5: Add exact world-query tests**

Extend `EnemyWorldSpatialTest.gd` to create records through `EnemyWorldService`, move one record across cell boundaries, and verify radius/nearest results use exact distances rather than returning every grid candidate. Include a `50000.0` radius query to prove the occupied-bucket path remains bounded.

- [ ] **Step 6: Run storage and spatial tests**

Run both scenes twice. Expected: every run exits `0`, storage reports zero stale-handle mutations, and spatial results remain exact after moves/removals.

- [ ] **Step 7: Commit world storage**

```powershell
git add -- core/systems/enemy_world/EnemyWorld.gd tools/tests/EnemyWorldStorageTest.gd tools/tests/EnemyWorldSpatialTest.gd
git commit -m "feat: add authoritative enemy world storage"
```

---

### Task 4: Add weak materialized-actor bindings

**Files:**
- Modify: `core/systems/enemy_world/EnemyWorld.gd`
- Create: `tools/tests/EnemyWorldBindingTest.gd`
- Create: `tools/tests/EnemyWorldBindingTest.tscn`

**Interfaces:**
- Consumes: live handles from Task 3.
- Produces: one-to-one weak bindings and legacy Node state adoption without allowing Node lifetime to own future logical identity.

Required public signatures:

```gdscript
func bind_actor(handle: int, actor: Node2D) -> bool
func unbind_actor(handle: int, actor: Node2D = null) -> bool
func actor_for_handle(handle: int) -> Node2D
func handle_for_actor(actor: Node) -> int
func prune_invalid_bindings() -> int
func adopt_legacy_actor(actor: Node2D) -> int
func sync_legacy_actor(actor: Node2D) -> bool
func release_legacy_actor(actor: Node2D, reason: StringName = &"legacy_unregistered") -> bool
```

- [ ] **Step 1: Write failing binding tests**

Use a local dummy:

```gdscript
class DummyEnemy:
	extends Node2D
	var hp := 40.0
	var max_hp := 50.0
	var speed := 120.0
	var velocity := Vector2(3.0, 4.0)
	var dead := false
	var is_elite := false
	var spec = null
```

Assert:

- a valid handle binds one actor and sets representation to `MATERIALIZED`;
- binding the same actor to another live handle fails;
- binding another actor to the occupied handle fails;
- `handle_for_actor` and `actor_for_handle` are inverse lookups;
- unbinding with the wrong actor fails without changing the binding;
- correct unbinding clears both maps and sets representation to `DATA_ONLY`;
- after a bound actor is freed, `actor_for_handle` returns `null`, representation becomes `DATA_ONLY`, and `prune_invalid_bindings` does not cast the freed object;
- legacy adoption copies position, velocity, health, speed, elite flag, scene path, and an AI fallback;
- legacy synchronization updates the record after the actor moves or takes damage;
- legacy release unbinds and removes its record exactly once.

- [ ] **Step 2: Run the binding test and verify missing APIs fail**

Expected: nonzero exit because the binding methods do not exist.

- [ ] **Step 3: Implement weak one-to-one bindings**

Add:

```gdscript
var _actor_refs: Dictionary = {}      # handle -> WeakRef
var _actor_handles: Dictionary = {}   # instance id -> handle
var _bound_instance_ids: Dictionary = {} # handle -> instance id
var _legacy_handles: Dictionary = {}  # handle -> true
```

`bind_actor` validates the handle, actor validity, absence of an existing live actor for the handle, and absence of an existing different handle for the actor. It stores `weakref(actor)`, stores the instance-ID reverse mapping, and sets representation to `MATERIALIZED`.

`actor_for_handle` must never use `as Node2D` before validating the weak reference's returned Variant. Retrieve `ref.get_ref()`, check `value != null`, `is_instance_valid(value)`, and `value is Node2D`, then cast. If invalid, erase the handle entry, erase any matching reverse entry by stored instance ID in cold binding metadata, set representation to `DATA_ONLY`, and return `null`.

Store the bound instance ID in a separate `_bound_instance_ids: Dictionary` so cleanup never needs to call a method on a freed object. `unbind_actor` validates an optional supplied actor by instance ID, erases both dictionaries, and transitions only `MATERIALIZED` records back to `DATA_ONLY`.

- [ ] **Step 4: Implement the temporary legacy adapter**

`adopt_legacy_actor` constructs an `EnemySpawnState` from safe property checks:

```gdscript
var state := EnemySpawnState.new(
	_spec_id_from_actor(actor),
	actor.scene_file_path,
	actor.global_position,
	float(actor.get("max_hp")) if "max_hp" in actor else 1.0,
	float(actor.get("speed")) if "speed" in actor else 0.0,
	_collision_radius_from_actor(actor),
	_ai_kind_from_actor(actor),
	Types.Flags.ELITE if ("is_elite" in actor and bool(actor.get("is_elite"))) else Types.Flags.NONE,
)
```

After creation, copy current health and velocity and bind the actor. `_spec_id_from_actor` uses scene filename without `Enemy`, converted to snake case, when no resource identifier is available. `_collision_radius_from_actor` reads the actor's `CollisionShape2D` circle radius when present and otherwise returns `24.0`. `_ai_kind_from_actor` calls `_get_active_ai` only if exposed; otherwise it returns `0`.

Mark every adopted handle in `_legacy_handles`. `sync_legacy_actor` resolves the handle through the reverse map, validates both sides, then updates position, velocity, health, elite flag, and dead/dying representation. `release_legacy_actor` resolves the handle, erases it from `_legacy_handles`, unbinds it, and calls `remove_enemy(handle, reason)`. Direct `remove_enemy` also erases the handle from `_legacy_handles` so the marker cannot outlive a record.

- [ ] **Step 5: Run binding, storage, and spatial tests**

Expected: all three scenes exit `0`; freeing a bound dummy produces no `Trying to cast a freed object` error.

- [ ] **Step 6: Commit bindings**

```powershell
git add -- core/systems/enemy_world/EnemyWorld.gd tools/tests/EnemyWorldBindingTest.gd tools/tests/EnemyWorldBindingTest.tscn
git commit -m "feat: bind enemy actors through weak handles"
```

---

### Task 5: Register the autoload and mirror EnemyIndex lifecycle

**Files:**
- Modify: `project.godot`
- Modify: `autoload/EnemyIndex.gd`
- Modify: `tools/tests/EnemyIndexTest.gd`

**Interfaces:**
- Consumes: `EnemyWorld.adopt_legacy_actor`, `sync_legacy_actor`, and `release_legacy_actor` from Task 4.
- Produces: a live shadow record for every valid EnemyIndex entry while preserving all existing Node-returning behavior, plus `EnemyWorld.rebuild_legacy_shadow(valid_enemies: Array) -> void` for maintenance repair.

- [ ] **Step 1: Extend EnemyIndexTest with failing mirror assertions**

At test startup obtain `/root/EnemyWorld` and record its baseline count. After spawning the existing `near`, `mid`, and `far` dummies, assert:

```gdscript
_check(world != null, "enemy world autoload exists")
_check(int(world.call("active_count")) == world_baseline + 3, "index registration mirrors logical records")
var near_handle := int(world.call("handle_for_actor", near))
_check(near_handle != 0, "registered enemy receives a stable handle")
near.global_position = Vector2(130.0, 15.0)
index.call("update_enemy", near)
_check(world.call("get_position", near_handle) == near.global_position, "index movement synchronizes logical position")
```

After unregistering/freeing fixtures, assert active count returns to baseline and stale handles are invalid.

- [ ] **Step 2: Run EnemyIndexTest and verify it fails**

Expected: failure because `/root/EnemyWorld` is absent and no mirror records exist.

- [ ] **Step 3: Register the EnemyWorld autoload**

Add to `[autoload]` in `project.godot`:

```ini
EnemyWorld="*res://core/systems/enemy_world/EnemyWorld.gd"
```

Keep the existing autoload names unchanged.

- [ ] **Step 4: Add the compatibility mirror to EnemyIndex**

In `register(enemy)`, after duplicate rejection and before telemetry, call `EnemyWorld.adopt_legacy_actor(enemy as Node2D)` when the Node is a `Node2D`. If adoption fails, leave existing EnemyIndex registration intact and increment a rate-limited diagnostic counter rather than crashing.

In `update_enemy(enemy)`, call `EnemyWorld.sync_legacy_actor(enemy as Node2D)` before the early return for unchanged EnemyIndex cell; world health/velocity changes must not depend on a cell crossing.

In `mark_dead(enemy)`, call `EnemyWorld.sync_legacy_actor(enemy as Node2D)` so the record changes to `DYING`, but do not remove it until normal unregister/despawn.

In `unregister(enemy)`, call `EnemyWorld.release_legacy_actor(enemy as Node2D, &"legacy_unregistered")` before any code path can free or pool the Node. The world adapter is idempotent, so the existing exit-tree unregister remains safe.

In `prune_invalid`, clear and rebuild the shadow world only through a dedicated `rebuild_legacy_shadow(valid_enemies: Array)` method on `EnemyWorld`. That method removes only legacy-adopted records, adopts each valid Node once, and suppresses gameplay spawn/death telemetry. Do not call `clear_world`, because later plans may contain non-legacy logical records.

Implement `rebuild_legacy_shadow` by copying `_legacy_handles.keys()` before removal, validating each copied handle, unbinding/removing those records with reason `&"legacy_rebuild"`, clearing the marker dictionary, and then adopting each valid `Node2D` in `valid_enemies`. It must not iterate a dictionary while mutating that same dictionary.

- [ ] **Step 5: Run compatibility tests**

Run:

```powershell
$godot = 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe'
& $godot --headless --path . res://tools/tests/EnemyIndexTest.tscn
& $godot --headless --path . res://tools/tests/EnemyPoolTest.tscn
& $godot --headless --path . res://tools/tests/EnemyLifecycleStressTest.tscn
```

Expected: all exit `0`; EnemyIndex's original assertions remain green; logical counts return to baseline after pooling, death, unregister, and pruning; no freed-object casts appear.

- [ ] **Step 6: Commit the compatibility bridge**

```powershell
git add -- project.godot autoload/EnemyIndex.gd tools/tests/EnemyIndexTest.gd
git commit -m "feat: mirror materialized enemies into enemy world"
```

---

### Task 6: Add recorder visibility and correct flow revision

**Files:**
- Modify: `autoload/PerformanceFlightRecorder.gd`
- Modify: `tools/tests/PerformanceFlightRecorderTest.gd`

**Interfaces:**
- Consumes: `EnemyWorld.get_debug_counters()` and `FlowFieldNav.get_debug_counters()["last_revision"]`.
- Produces: incident samples containing Enemy World counts and a truthful flow revision.

- [ ] **Step 1: Write failing recorder schema assertions**

Extend the synthetic recorder test so its stubbed Enemy World counters are:

```gdscript
{
	"logical": 500,
	"materialized": 64,
	"data_only": 436,
	"dying": 0,
	"spatial_cells": 91,
	"max_cell_occupancy": 14,
}
```

Stub flow counters with `{"last_revision": 37}` and assert the produced sample contains:

```gdscript
_check(int(sample.get("enemy_world_logical", -1)) == 500, "recorder samples logical enemies")
_check(int(sample.get("enemy_world_materialized", -1)) == 64, "recorder samples materialized enemies")
_check(int(sample.get("enemy_world_data_only", -1)) == 436, "recorder samples proxies")
_check(int(sample.get("enemy_world_spatial_cells", -1)) == 91, "recorder samples spatial cells")
_check(int(sample.get("flow_revision", -1)) == 37, "recorder reads the actual flow revision key")
```

- [ ] **Step 2: Run PerformanceFlightRecorderTest and verify it fails**

Expected: the new Enemy World fields are missing and `flow_revision` remains `0` because the recorder currently reads `revision` instead of `last_revision`.

- [ ] **Step 3: Sample the new counters without hot-loop scans**

During the recorder's existing low-frequency subsystem sample, call `EnemyWorld.get_debug_counters()` once and copy the six scalar values into the sample under the exact names asserted above plus `enemy_world_dying` and `enemy_world_max_cell_occupancy`.

Change the flow lookup from:

```gdscript
flow_data.get("revision", 0)
```

to:

```gdscript
flow_data.get("last_revision", 0)
```

Do not serialize the nested removal-reason dictionary into every frame sample; it belongs in incident summaries or explicit counter events.

- [ ] **Step 4: Run recorder regression and benchmark tests**

Run:

```powershell
$godot = 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe'
& $godot --headless --path . res://tools/tests/PerformanceFlightRecorderTest.tscn
& $godot --headless --path . res://tools/tests/PerformanceIncidentWriteQueueTest.tscn
& $godot --headless --path . res://tools/tests/PerformanceFlightRecorderBenchmark.tscn
```

Expected: all exit `0`; recorder overhead remains inside the benchmark's existing bound; flow revision is `37` in the synthetic sample.

- [ ] **Step 5: Commit diagnostics**

```powershell
git add -- autoload/PerformanceFlightRecorder.gd tools/tests/PerformanceFlightRecorderTest.gd
git commit -m "perf: record authoritative enemy world counters"
```

---

### Task 7: Add the 600-record foundation benchmark and run the phase gate

**Files:**
- Create: `tools/tests/EnemyWorldBenchmark.gd`
- Create: `tools/tests/EnemyWorldBenchmark.tscn`
- Modify: `docs/superpowers/plans/2026-08-19-enemy-world-foundation.md` only to check completed boxes during execution.

**Interfaces:**
- Consumes: all foundation interfaces from Tasks 1-6.
- Produces: deterministic evidence that 600 logical records remain valid under repeated movement, query, removal, and reuse; no gameplay FPS claim.

- [ ] **Step 1: Write the benchmark scene**

Create the standard one-script `.tscn`. In the script, instantiate an isolated `EnemyWorldService`, create 600 records on a deterministic 30-by-20 grid, then run 600 fixed steps. On each step:

```gdscript
for handle_variant in handles:
	var handle: int = int(handle_variant)
	var p: Vector2 = world.get_position(handle)
	var v: Vector2 = world.get_velocity(handle)
	world.set_position(handle, p + v * (1.0 / 10.0))
var gathered: Array[int] = []
world.gather_in_radius(Vector2.ZERO, 900.0, gathered)
```

Initialize velocities deterministically from the record index; do not use `Global._rng`. Every 60th step, remove 20 known handles and create 20 replacements. Retain the removed handles in `stale_handles` and assert none ever validate or mutate a replacement.

At completion assert:

- `active_count() == 600`;
- `active_handles` contains 600 unique valid handles;
- every active handle has a finite position and health;
- no stale handle validates;
- debug counters report 600 logical records, 600 materialized or data-only records in total, and a bounded capacity no greater than 620;
- total elapsed headless wall time is printed as evidence but is not compared to a brittle millisecond threshold.

- [ ] **Step 2: Run the benchmark three times**

Expected: each run exits `0`, prints zero failures, never reports a stale-handle mutation, and active/capacity counts remain deterministic.

- [ ] **Step 3: Run every focused Enemy World gate**

Run storage, spatial, binding, index, pool, lifecycle stress, recorder, recorder queue, and benchmark scenes in separate Godot processes. Require every exit code to be `0`; do not treat printed engine shutdown leak diagnostics as assertion failures unless a test or script error accompanies them.

- [ ] **Step 4: Run the project parse gate**

Run:

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --editor --quit
```

Expected: exit `0`, no parse errors, no new GDScript warnings, and no autoload naming conflict.

- [ ] **Step 5: Review the phase diff against the specification**

Run:

```powershell
git diff 561e66d..HEAD --check
git status --short
git log --oneline --decorate -10
```

Verify that this phase has not added proxy movement, disabled any enemy Node, changed the 220 default spawner cap, rerouted combat, altered rewards, or changed save data. Confirm all newly introduced Node references are weak.

- [ ] **Step 6: Commit the benchmark**

```powershell
git add -- tools/tests/EnemyWorldBenchmark.gd tools/tests/EnemyWorldBenchmark.tscn docs/superpowers/plans/2026-08-19-enemy-world-foundation.md
git commit -m "test: gate enemy world foundation at 600 records"
```

## Foundation completion gate

Do not begin the authoritative-lifecycle plan until:

- every focused scene and the editor parse gate exits `0`;
- the old `EnemyIndex` test behavior is unchanged;
- freeing or pooling actors produces no stale-object cast;
- logical shadow counts exactly match materialized indexed enemies after normal register, update, death, pool recycle, prune, and unregister paths;
- 600-record allocation/removal/reuse is deterministic across three runs;
- recorder samples contain truthful Enemy World counts and `flow_revision` reads `last_revision`;
- the worktree contains no unrelated modifications.
