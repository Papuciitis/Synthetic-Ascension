from pathlib import Path
import gzip, hashlib, json, re, shutil

ROOT = Path.cwd()
OUT = ROOT / '.superpowers/sdd/2026-11-04-trailer-yard-preview/real-candidate-verify-fix1'
if (OUT / 'source-pins.json').exists():
    raise SystemExit('Refusing to overwrite existing packet')
OUT.mkdir(exist_ok=True)
(OUT / '.gdignore').write_bytes(b'')  # FIRST file; exclude entire fresh project from main scans.
F = OUT / 'fixture'
F.mkdir(exist_ok=True)
(F / '.gdignore').write_bytes(b'')
S = OUT / 'source-payloads'
S.mkdir(exist_ok=True)
BASE = Path('docs/art/reference/2026-10-22-linux-streets')
sample = BASE / 'sources/blobs/43938c18fa45cbc8ca3248d4bdbcf3bf22922c23789e5bcd10ff5a193c60390b-city22-street-continuity-part-08-part08-v1.json'
binding = BASE / 'sources/run-bindings/city22-street-continuity-part-08-part08-v1-1.json'
run = BASE / 'runs/city22-street-continuity-part-08-part08-v1-1/run-results.json.gz'
sha = lambda b: hashlib.sha256(b).hexdigest()
data = json.loads(sample.read_bytes())
launch = json.loads(gzip.decompress(run.read_bytes()))
bind = json.loads(binding.read_bytes())
assert sha(sample.read_bytes()) == sample.name.split('-')[0]
assert launch['git_head'] == bind['git_head']
assert launch['actual_exit'] == 0 and launch['stop_reason'] == 'completed' and launch['runner_exit'] == 0 and not launch['diagnostics']
site = Path('core/systems/world/proc/SiteParcelsImpl.gd')
assert sha(site.read_bytes()) == bind['scoped'][site.as_posix()]['launch_sha256']
assert sha(site.read_bytes()) == launch['source_hashes'][site.as_posix()]
text = site.read_bytes().decode('utf8')
methods = re.findall(r'^func _mix_seed\(a: int, b: int, c: int, d: int\) -> int:\r?\n(?:\t[^\r\n]*\r?\n)+', text, re.M)
assert len(methods) == 1, f'extraction count {len(methods)}'
method = methods[0]
(S / 'extracted_mix_seed.gd.txt').write_bytes(method.encode('utf8'))
sources = [sample, binding, run, site, Path('core/systems/world/proc/RectFacilityCarver.gd'), Path('core/systems/world/proc/DonjonCarver.gd'), Path('core/systems/world/proc/ChunkGenImpl.gd'), Path('core/systems/world/proc/chunkgen/ChunkGenDistrict.gd'), Path('core/systems/world/proc/SegmentThemeData.gd'), Path('core/systems/world/proc/SegmentThemePicker.gd'), Path('core/systems/world/SegmentProcBuilder.gd'), Path('core/systems/world/ChunkManager.gd'), Path('tools/tests/CityStreetContinuityTest.gd'), Path('tools/tests/ProcChunkReachabilityTest.gd'), Path('scenes/world/buildings/CityBlockKit.gd'), Path('tools/capture/city_resource_guard.ps1')]
pins = []
for source_index, p in enumerate(sources):
    dest = S / f'{source_index:02d}-{p.suffix[1:]}'
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(p, dest)
    h = sha(p.read_bytes())
    pins.append(dict(original=p.as_posix(), packet=dest.relative_to(OUT).as_posix(), sha256=h, historical_launch_sha256=launch['source_hashes'].get(p.as_posix()), historical_launch_equal=h == launch['source_hashes'].get(p.as_posix())))
for p in sources[4:6]:
    dest = F / p
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(p, dest)
matches = [s for s in data['samples'] if s['coord'] == [-8,-4]]
assert len(matches) == 1
sample_row = matches[0]
assert sample_row['plan_seed'] == data['theme']['plan_seed'] == 1208827904
rects = [[21,7,8,7], [3,6,8,8], [21,20,8,8]]
rows = []
for rect, ident, variant in zip(rects, [1910440753,2052381668,1928485795], [1,0,3]):
    found = [b for b in sample_row['buildings'] if b['rect'] == rect]
    assert len(found) == 1
    b = found[0]
    assert b['usage'] == 'row_house' and not b['civic'] and not b['infill'] and not b['irregular']
    rows.append(dict(observed_historical=b, host_expected_id=ident, host_expected_variant=variant))
observed = dict(theme=data['theme'], sample=sample_row, candidates=rows)
(F / 'observed-inputs.json').write_text(json.dumps(observed, indent=2), encoding='utf8')
(F / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Recovered household derivation only"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding='utf8')
harness = '''extends SceneTree
# METHOD EXTRACTION ONLY: verbatim source-pinned _mix_seed, not a manager implementation.
const CARVER = preload("res://core/systems/world/proc/RectFacilityCarver.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool, label: String) -> void:
    if ok: passed += 1
    else:
        failed += 1
        print("FAIL: " + label)

func cells(values: Array) -> Array:
    var out: Array = []
    for v: Vector2i in values: out.append([v.x,v.y])
    out.sort_custom(func(a: Array,b: Array) -> bool: return a[1] < b[1] or (a[1] == b[1] and a[0] < b[0]))
    return out

func rect_array(r: Rect2i) -> Array:
    return [r.position.x,r.position.y,r.size.x,r.size.y]

func _initialize() -> void:
    var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://observed-inputs.json"))
    var output: Dictionary = {"observed_historical":input,"derived_verified":[],"missing_fields":{"garden_contact":"unknown; no kit created","care_spec":"unknown; no kit created","semantic_and_care_bytes":"unknown; no ground planner created","native_game":"pending; no Game, district regeneration or activated target"},"method":"verbatim _mix_seed extraction plus actual unchanged RectFacilityCarver/DonjonCarver"}
    var coord := Vector2i(-8,-4)
    var index: int = 0
    for c: Dictionary in input.candidates:
        var b: Dictionary = c.observed_historical
        var r := Rect2i(int(b.rect[0]),int(b.rect[1]),int(b.rect[2]),int(b.rect[3]))
        var tl: Vector2i = coord * 32 + r.grow(-1).position
        var mixed: int = _mix_seed(int(input.theme.plan_seed),tl.x,tl.y,77)
        var ident: int = int(mixed & 0x7fffffff) + 1
        var variant: int = absi(ident) % 4
        check(ident == int(c.host_expected_id),"signed64 id " + str(index))
        check(variant == int(c.host_expected_variant),"variant " + str(index))
        var row: Dictionary = {"rect":b.rect,"global_interior_tl_cells":[tl.x,tl.y],"signed64_mixed":str(mixed),"visual_seed":ident,"variant":variant,"care_eligibility_from_id_only":variant != 3,"footprint_before_roof_inset_px":[[r.position.x*64,r.position.y*64],[r.end.x*64,r.position.y*64],[r.end.x*64,r.end.y*64],[r.position.x*64,r.end.y*64]],"carve":"omitted for third candidate"}
        if index < 2:
            var d: Array = b.doors[0]
            var pos := Vector2i(int(d[0]),int(d[1]))
            var direction := Vector2i(int(d[2]),int(d[3]))
            var entrances: Array[Dictionary] = [{"pos":pos,"dir":direction,"width":2}]
            var rng := RandomNumberGenerator.new()
            var carve_seed: int = _mix_seed(int(input.theme.plan_seed),coord.x,coord.y,4027 + r.position.x*19 + r.position.y*23)
            rng.seed = carve_seed
            var max_room := Vector2i(maxi(5,mini(9,r.size.x-2)),maxi(5,mini(8,r.size.y-2)))
            var carve = CARVER.carve_room_first(r,rng,12,Vector2i(4,4),max_room,1,1,0.22,entrances,2,2)
            var door_cells: Dictionary = CARVER._collect_door_cells(r,entrances)
            check(door_cells.size() == 2,"derived door width " + str(index))
            var doors_open: bool = true
            for p: Vector2i in door_cells:
                if carve.wall_cells.has(p): doors_open = false
            check(doors_open,"source door cells open " + str(index))
            var walls_bounded: bool = true
            var partitions: Array = []
            for p: Vector2i in carve.wall_cells:
                if not r.has_point(p): walls_bounded = false
                if r.grow(-1).has_point(p): partitions.append(p)
            check(walls_bounded,"returned walls bounded " + str(index))
            var perimeter_closed: bool = true
            for y: int in range(r.position.y,r.end.y):
                for x: int in range(r.position.x,r.end.x):
                    var p := Vector2i(x,y)
                    if (x == r.position.x or x == r.end.x-1 or y == r.position.y or y == r.end.y-1) and not door_cells.has(p) and not carve.wall_cells.has(p): perimeter_closed = false
            check(perimeter_closed,"perimeter except doors " + str(index))
            var stamps: Array = []
            for stamp: Dictionary in carve.floor_stamps:
                stamps.append({"rect":rect_array(stamp.rect),"tex":stamp.tex,"alpha":stamp.alpha,"z":stamp.z})
            row.carve = {"classification":"current actual source geometry replay; normal width2 DERIVED, not historically observed","source_parameters":{"rng_seed_signed64":str(carve_seed),"room_attempts":12,"room_min":[4,4],"room_max":[max_room.x,max_room.y],"room_padding":1,"corridor_width":1,"window_chance":0.22,"door_width":2,"floor_room_tex":2,"floor_corr_tex":2},"door_cells":cells(door_cells.keys()),"wall_cells":cells(carve.wall_cells.keys()),"window_cells":cells(carve.window_cells.keys()),"partition_cells":cells(partitions),"floor_stamps":stamps,"half_cover_cells":cells(carve.half_cover_cells),"rng_state_after_signed64":str(rng.state)}
        output.derived_verified.append(row)
        index += 1
    output["passed"] = passed
    output["failed"] = failed
    var file := FileAccess.open("res://derived-results.json",FileAccess.WRITE)
    if file == null:
        print("FAIL: unable to write derived results")
        quit(1)
        return
    file.store_string(JSON.stringify(output,"  "))
    file.close()
    print("RealCandidateVerify: %d passed, %d failed" % [passed,failed])
    quit(0 if failed == 0 else 1)

'''
# Preserve method bytes exactly, including original line endings.
(F / 'verify.gd').write_bytes(re.sub(r'^(?:    )+', lambda m: '\t' * (len(m.group(0)) // 4), harness, flags=re.M).encode('utf8') + method.encode('utf8'))
pins.append(dict(original='method extraction',packet='source-payloads/extracted_mix_seed.gd.txt',sha256=sha(method.encode('utf8')),extraction_count=1,verbatim=True))
for p in sorted(F.rglob('*')):
    if p.is_file(): pins.append(dict(original='fixture',packet=p.relative_to(OUT).as_posix(),sha256=sha(p.read_bytes())))
(OUT / 'source-pins.json').write_text(json.dumps(pins,indent=2),encoding='utf8')
(OUT / 'input-derivation.json').write_text(json.dumps(dict(extraction_count=1,method_sha256=sha(method.encode('utf8')),notes=['No complete district regeneration. Actual historical generated lot records replayed.','Door width2 is derived through historical manager export2 -> generator copy -> district cfg -> parcel max2. Historical recorder omits width.','Window0.22 follows historical manager export -> generator copy -> district cfg. SegmentThemeData.apply_to_chunk_manager and test do not override these two fields.','Room attempts12/min4/max from lot dimensions/padding1/corridor1/floor2 are from SiteParcelsImpl._spawn_building_rect.','Carver scripts copied unchanged; source hash comparison with historical launch is recorded, not assumed.','Seed extraction never changes inputs or consumes RNG. Carve RNG newly seeded exactly by source formula; actual carver consumes it unchanged.'],source_bindings=dict(sample=sample.as_posix(),binding=binding.as_posix(),run=run.as_posix(),historical_git=launch['git_head'])),indent=2),encoding='utf8')
print(OUT)
