#!/usr/bin/env python3
"""Build one finite paving evidence packet after actual runs and original review.

Preparation only until root invokes this script. --check-only validates all gates
and lists payloads without creating directories or compressing anything.

Usage:
  python3 build_paving_packet.py --root-review ROOT.json \
    --independent-review INDEPENDENT.json [--check-only]

Each review JSON requires accepted:true, reviewer_role:"root"|"independent",
source_head:the full HEAD below, and originals:[{path,sha256},...]. The originals
must bind exactly six original files: the committed before-s9-r2 PNG/JSON and
both /var/tmp after PNG/JSON pairs. Paths can be absolute or repo-relative.
Additional prose/evidence fields are retained without interpretation. Acceptance
is a human/reviewer decision; this program never manufactures it.

No Git, engine, image decoding/resizing, external commands or host changes.
All raw run-results bytes are retained unfiltered, gzip mtime=0, with a verified
round trip and raw hashes. manifest.json indexes every other delivered file;
its own hash is printed separately to avoid self-reference. Existing destination
is refused. All read/check gates complete before the first write (.gdignore).
"""
import argparse
from datetime import datetime, timezone
import gzip
import hashlib
import json
from pathlib import Path
import re
import struct

ROOT = Path('/home/user/Nauris/Synthetic-Ascension')
HERE = ROOT / '.superpowers/continuation-20261023-ground'
GUARDS = ROOT / '.superpowers/continuation-20261022'
LAUNCH = ROOT / '.superpowers/claude-city-20261021'
PROJECT = Path('/tmp/sa-c23-ground')
HEAD = '6905e7ea5a768f4edd2c279f0b5add4aa6283ccd'
STARTUP_GUARD_HASH = '205badf2274e8ba83a89dc35cfe0174cbe0f5604cda984a48306b958fe2146c5'
GUARD_HASH = '4c07431955288522aadb7e89669d16d3b50f571310d1bc44259f7dc0bc4503d0'
FAILED_SMALL = 'city23-ground-after-s9-small-r1'
OLD = ROOT / 'docs/art/reference/2026-10-23-ground-care-edges'
DEST = ROOT / 'docs/art/reference/2026-10-23-outer-wall-paving'
CASES = (
    ('city23-ground-after-s9-r3', 'after-s9-r3', 'normal', (1280, 720)),
    ('city23-ground-after-s9-small-r2', 'after-s9-small-r2', 'small', (960, 540)),
    ('city23-ground-owner-care-r4', None, 'CityGroundCareTest', None),
    ('city23-ground-owner-splat-r1', None, 'WorldGroundSplatTest', None),
)
PROJECT_FILES = (
    'project.godot', 'core/systems/world/WorldArt.gd',
    'core/systems/world/ground/DistrictGroundPolicy.gd',
    'core/systems/world/ground/ground_splat.gdshader',
    'core/systems/world/ground/GroundSplatRenderer.gd',
    'core/systems/world/ground/CityGroundCare.gd',
    'tools/tests/CityGroundCareTest.gd', 'tools/tests/CityGroundCareTest.tscn',
    'tools/tests/WorldGroundSplatTest.gd', 'tools/tests/WorldGroundSplatTest.tscn',
    'tools/tests/DistrictGroundPolicyTest.gd', 'tools/tests/DistrictGroundPolicyTest.tscn',
    'tools/tests/CityGroundCareRenderTest.gd', 'tools/tests/CityGroundCareRenderTest.tscn',
    'tools/dev/CityBlockPlayablePreview.gd', 'tools/dev/CityBlockPlayablePreview.tscn',
    'tools/dev/EliteCrowdFightPreview.gd', 'tools/dev/EliteCrowdFightPreview.tscn',
)
EXTERNAL = (
    (HERE/'GroundPavingPreview.gd', 'process/capture/GroundPavingPreview.gd'),
    (HERE/'GroundPavingPreview.tscn', 'process/capture/GroundPavingPreview.tscn'),
    (HERE/'GroundCarePreview.gd', 'process/capture/GroundCarePreview.gd'),
    (HERE/'GroundCarePreview.tscn', 'process/capture/GroundCarePreview.tscn'),
    (GUARDS/'final-combined-r4/FinalCombinedCityPreview.gd', 'process/capture/final-combined-r4/FinalCombinedCityPreview.gd'),
    (GUARDS/'final-combined-r4/FinalCombinedCityPreview.tscn', 'process/capture/final-combined-r4/FinalCombinedCityPreview.tscn'),
    (GUARDS/'stage4-cost-r3/FinalCombinedCityPreview.gd', 'process/capture/stage4-cost-r3/FinalCombinedCityPreview.gd'),
    (GUARDS/'stage4-cost-r3/FinalCombinedCityPreview.tscn', 'process/capture/stage4-cost-r3/FinalCombinedCityPreview.tscn'),
)
PROCESS = (
    (GUARDS/'guarded_engine.py', 'process/guard/guarded_engine.py'),
    (HERE/'guard-before-startup-discovery.py', 'process/guard/guard-before-startup-discovery.py'),
    (HERE/'guard-before-burst-option.py', 'process/guard/guard-before-burst-option.py'),
    *((HERE/name, 'process/guard/'+name) for name in (
        'test_guard_startup_discovery.py', 'guard-startup-old-red.json',
        'guard-startup-old-failure.json', 'guard-startup-new-green.json',
        'guard-before-cpu-option.py', 'test_guard_cpu_count.py',
        'test_guard_cpu_count_original.py', 'guard-affinity-rechecks.json',
        'guard-affinity-current-recheck.stdout', 'guard-affinity-current-recheck.stderr',
        'guard-affinity-original-recheck.stdout', 'guard-affinity-original-recheck.stderr',
        'test_guard_burst_temperature.py', 'guard-burst-old-red.json', 'guard-startup-burst-default-green.json',
        'guard-burst-new-green.json', 'guard-burst-decision.json')),
    (LAUNCH/'sa_engine.py', 'process/launcher/sa_engine.py'),
    (LAUNCH/'run_engine_slot.py', 'process/launcher/run_engine_slot.py'),
    (HERE/'paving-capture-source.json', 'process/paving-capture-source.json'),
    (HERE/'paving-queue.json', 'process/paving-queue.json'),
    (HERE/'paving-queue-r2.json', 'process/paving-queue-r2.json'),
    (HERE/'continue_paving_checks.py', 'process/continue_paving_checks.py'),
    (HERE/'paving-queue-r3.json', 'process/paving-queue-r3.json'),
    (HERE/'build_paving_packet.py', 'process/build_paving_packet.py'),
)


def need(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def js(path):
    return json.loads(path.read_bytes())


def json_bytes(value):
    return (json.dumps(value, indent=2, ensure_ascii=False)+'\n').encode()


def close(actual, expected):
    return len(actual) == len(expected) and all(abs(a-b) <= 2e-6 for a, b in zip(actual, expected))


def original_files():
    result = [OLD/'native/before-s9-r2'/name for name in ('ground-before.png', 'capture-info.json')]
    for _, directory, _, _ in CASES[:2]:
        result.extend(Path('/var/tmp/sa-city23-ground')/directory/name for name in ('ground-before.png', 'capture-info.json'))
    return result


def check_review(path, role, originals):
    record = js(path)
    need(record.get('accepted') is True and record.get('reviewer_role') == role,
         f'{role} original review is not explicitly accepted: {path}')
    need(record.get('source_head') == HEAD, f'{role} review source HEAD differs')
    bindings = record.get('originals', [])
    need(isinstance(bindings, list) and len(bindings) == len(originals), f'{role} must bind all six originals')
    actual = {}
    for item in bindings:
        p = Path(item['path'])
        p = p if p.is_absolute() else ROOT/p
        key = str(p.resolve())
        need(key not in actual, f'{role} review duplicates an original')
        actual[key] = item['sha256']
    need(actual == originals, f'{role} review original paths/hashes differ from actual files')
    return record


def check_capture(info, png, baseline, mode, size):
    need(png[:8] == b'\x89PNG\r\n\x1a\n' and png[12:16] == b'IHDR', 'Invalid original PNG header')
    need(struct.unpack('>II', png[16:24]) == size, f'{mode} actual PNG dimensions differ')
    need(info['review'] == mode and info['image_size'] == f'({size[0]}, {size[1]})', f'{mode} manifest dimensions/review differ')
    need(info['capture_scene'] == str(HERE/'GroundPavingPreview.tscn'), f'{mode} actual capture helper differs')
    for key in ('seed', 'attempt_seed', 'segment', 'theme', 'district_family', 'ground_context_world_px',
                'ground', 'visible_care_attribution', 'fixture', 'coord', 'plan_seed', 'role',
                'ground_review', 'occupied_comparison', 'player_god_mode', 'scripted_input',
                'ambient_spawner', 'controlled_enemies', 'local_security', 'fixed_camera',
                'normal_hud', 'optional_details_hidden', 'reduced_motion', 'requested_simulation_seconds',
                'initial_fight_population', 'weapon_fires', 'hits', 'deaths', 'save_writes', 'failures'):
        need(info[key] == baseline[key], f'{mode} baseline control/data mismatch: {key}')
    need(info['seed'] == 16102026 and info['segment'] == 9 and info['theme'] == 'outer_wall', 'Wrong S9 world')
    need(info['failures'] == 0 and info['save_writes'] == 0, f'{mode} capture failure/save write')
    for key in ('position', 'rotation', 'zoom', 'viewport'):
        need(info['camera'][key] == baseline['camera'][key], f'{mode} camera mismatch: {key}')
    combined = info['final_combined']
    for key in ('final_exterior', 'loaded_profile_counts', 'render_fps_cap',
                'physics_ticks_per_second', 'reduced_motion_setting', 'combat_flash_setting'):
        need(combined[key] == baseline['final_combined'][key], f'{mode} final control mismatch: {key}')
    need(combined['final_exterior']['all_opaque_outside'] is True, f'{mode} exterior opacity lost')
    need(combined['render_fps_cap'] == 20 and combined['physics_ticks_per_second'] == 60, 'Render/physics cap differs')
    dims = combined['render_dimensions']
    need(dims['window_size'] == list(size) and dims['display_server_size'] == list(size), 'Native window dimensions differ')
    need(dims['logical_visible_size'] == [1920, 1080] and dims['content_scale_size'] == [1920, 1080], 'Logical view differs')
    for key in ('content_scale_aspect', 'content_scale_factor', 'content_scale_mode',
                'content_scale_stretch', 'canvas_items_mode', 'nonembedded', 'window_is_viewport', 'engine_hash'):
        need(dims[key] == baseline['final_combined']['render_dimensions'][key], f'{mode} native contract differs: {key}')
    for key in ('profile', 'ground_receiver_enabled', 'frozen_phase', 'weather_frozen', 'reduced_motion'):
        need(combined['atmosphere'][key] == baseline['final_combined']['atmosphere'][key], f'{mode} atmosphere control differs: {key}')
    rows = info['ground_role_uniforms']
    need(len(rows) == 8 and sorted(row['role'] for row in rows) == list(range(8)), 'Role rows are not exactly 0..7')
    yard = next(row for row in rows if row['role'] == 4)  # ROLE_YARD=4; SOURCE_LAYER=3.
    need(close(yard['sample'], [3, 9, 192, 1]), f'{mode} actual yard sample differs')
    need(close(yard['mid'], [.573, .586, .543, .52]), f'{mode} actual yard mid/weight differs')
    need(close(yard['tint'], [1.34, 1.37, 1.43, 1]), f'{mode} actual yard tint differs')
    need(info['round_cobble_source']['layer'] == 9, 'Round-cobble layer differs')
    stills = combined['capture_stills']
    need(len(stills) == 1 and stills[0]['file'] == 'ground-before.png', 'Unexpected native still inventory')
    need(stills[0]['exterior']['all_opaque_outside'] is True and stills[0]['render_fps_cap_before_still'] == 20
         and stills[0]['physics_ticks_per_second_before_still'] == 60, 'Still exterior/cap gate failed')
    return {'mode':mode, 'native_dimensions':list(size), 'baseline_data_controls_equal':True,
            'yard_role':4, 'yard_uniforms':yard, 'original_png_sha256':sha(png)}


def prepare(args):
    payload = {}
    def add(path, destination, role, compress=False):
        need(destination not in payload, 'Duplicate packet destination: '+destination)
        raw = path.read_bytes()
        payload[destination] = {'raw':raw, 'source_path':str(path.resolve()), 'role':role, 'compress':compress}
        return raw
    originals = {str(p.resolve()):sha(p.read_bytes()) for p in original_files()}
    for path, role in ((args.root_review, 'root'), (args.independent_review, 'independent')):
        check_review(path, role, originals)
        add(path, 'reviews/'+role+'.json', role+' accepted original review')
    baseline = js(OLD/'native/before-s9-r2/capture-info.json')
    baseline_run = json.loads(gzip.decompress((OLD/'runs/city23-ground-before-s9-r2/run-results.json.gz').read_bytes()))
    preparation = js(HERE/'paving-capture-source.json')
    need(preparation['head'] == HEAD, 'Capture preparation HEAD differs')
    need(sha((GUARDS/'guarded_engine.py').read_bytes()) == GUARD_HASH, 'Current optional-burst guard source differs')
    need(sha((HERE/'guard-before-burst-option.py').read_bytes()) == STARTUP_GUARD_HASH,
         'Frozen normal/default90 guard source differs')
    green = js(HERE/'guard-startup-new-green.json')
    need(green['source_sha256'] == STARTUP_GUARD_HASH and green['guard_exit'] == 0
         and green['assertion_failures'] == [] and green['real_godot_started'] is False,
         'Startup regression GREEN receipt differs')
    burst = js(HERE/'guard-burst-new-green.json')
    need(burst['source_sha256'] == GUARD_HASH and burst['real_godot_started'] is False
         and burst['temperature_is_simulated'] is True and burst['failed_cases'] == 0,
         'Burst regression GREEN receipt/source differs')
    expected_cases = {'default90', 'brief95-one', 'brief95-two', 'sustained85',
                      'sustained95', 'immediate98', 'reject97'}
    need(len(burst['cases']) == 7 and {c['case'] for c in burst['cases']} == expected_cases
         and all(c['assertion_failures'] == [] and c['foreign_canary_live_and_unstopped'] is True
                 for c in burst['cases']), 'Exact seven-case burst regression is not GREEN')
    default_green = js(HERE/'guard-startup-burst-default-green.json')
    need(default_green['source_sha256'] == GUARD_HASH and default_green['guard_exit'] == 0
         and default_green['assertion_failures'] == [] and default_green['real_godot_started'] is False
         and default_green['thermal']['runtime_temperature_stop_c'] == 90,
         'New guard default90 startup recheck differs')
    decision = js(HERE/'guard-burst-decision.json')
    need(decision['guard_before_sha256'] == STARTUP_GUARD_HASH
         and decision['preserved_failed_small_run'] == FAILED_SMALL,
         'Recorded optional-burst decision/source differs')
    queue = js(HERE/'paving-queue-r3.json')
    need(queue['status'] == 'ALL_COMPLETED' and queue['source_head'] == HEAD
         and queue['reused_normal'] == CASES[0][0]
         and queue['preserved_interrupted_small'] == FAILED_SMALL,
         'Final queue is not complete at the expected source/protocol')
    need([c['label'] for c in queue['cases']] == [c[0] for c in CASES[1:]]
         and all(c['status'] == 'PASSED' and c['guard_exit'] == 0 for c in queue['cases']),
         'Final queue lacks exact three completed remaining cases')
    for item in queue['cases']:
        command = item['command']
        need(command[command.index('--burst-temperature')+1] == '98',
             'Remaining case did not request optional98 protocol')
    for path, digest in preparation['helpers'].items():
        need(sha(Path(path).read_bytes()) == digest, 'Prepared capture source changed: '+path)
    accepted_shader = OLD/'sources/production/core/systems/world/ground/ground_splat.gdshader'
    need((PROJECT/'core/systems/world/ground/ground_splat.gdshader').read_bytes() == accepted_shader.read_bytes(),
         'Paving packet shader differs from already accepted care-edge source')
    runs = []
    capture_checks = []
    capture_records = []
    for label, directory, mode, size in CASES:
        burst_stop = 90 if mode == 'normal' else 98
        guard_source = STARTUP_GUARD_HASH if mode == 'normal' else GUARD_HASH
        matches = sorted((LAUNCH/'runs').glob(label+'-[0-9]*/run-results.json'))
        need(len(matches) == 1, f'{label} needs one unambiguous actual result, found {len(matches)}')
        actual = matches[0]
        run = json.loads(add(actual, f'runs/{label}/run-results.json.gz', 'Complete unfiltered actual run result', compress=True))
        thermal = json.loads(add(GUARDS/(label+'-thermal.json'), f'runs/{label}/thermal.json', 'Actual outer guard receipt'))
        add(GUARDS/(label+'-wrapper.log'), f'runs/{label}/wrapper.log', 'Actual guard-owned launcher output')
        logs = {}
        for name in ('engine.log', 'stderr.log', 'stdout.log'):
            logs[name] = add(actual.parent/'logs'/name, f'runs/{label}/logs/{name}', 'Unfiltered actual engine log')
        need(run['actual_exit'] == 0 and run['runner_exit'] == 0 and run['stop_reason'] == 'completed'
             and run['diagnostics'] == [] and run['other_godot_pids'] == [], f'{label} is not a clean completed actual run')
        need(run['git_head'] == HEAD and run['git_status_porcelain'].strip() == '', f'{label} source HEAD/tree differs')
        need(run['project_root'] == str(PROJECT), f'{label} source project differs')
        need(thermal['reason'] == 'completed' and thermal['wrapper_exit'] == 0 and thermal['received_signal'] is None,
             f'{label} guard did not complete normally')
        for key, value in {'start_temperature_c':65, 'runtime_temperature_stop_c':burst_stop,
                           'sustained_temperature_stop_c':85, 'sustained_temperature_samples':3,
                           'duty_cycle':.1, 'duty_run_seconds':.05, 'duty_pause_seconds':.45,
                           'cpu_affinity':[0], 'release_marker':None, 'duty_released':False}.items():
            need(thermal[key] == value, f'{label} guard bound differs: {key}')
        need(thermal['throttle_cycles'] > 0 and thermal['owned_pids'] == [run['pid']], f'{label} owned duty identity differs')
        need(all(not sample['duty_released'] for sample in thermal['samples']), f'{label} duty released during run')
        active = [s for s in thermal['samples'] if s['owned_engine_live']]
        need(active and all(s['package_c'] is not None and s['package_c'] < burst_stop for s in active), f'{label} active instantaneous limit reached')
        need(not any(all(s['package_c'] >= 85 for s in active[i:i+3]) for i in range(len(active)-2)), f'{label} sustained thermal limit reached')
        expected_args = thermal['command'][thermal['command'].index('--')+1:]
        need(run['command'][6:] == expected_args, f'{label} outer/inner actual arguments differ')
        for relative in PROJECT_FILES:
            need(run['source_hashes'].get(relative) == sha((PROJECT/relative).read_bytes()), f'{label} source snapshot differs: {relative}')
        for relative in ('core/systems/world/ground/GroundSplatRenderer.gd', 'core/systems/world/ground/CityGroundCare.gd',
                         'core/systems/world/WorldArt.gd', 'tools/dev/CityBlockPlayablePreview.gd', 'tools/dev/EliteCrowdFightPreview.gd'):
            need(run['source_hashes'][relative] == baseline_run['source_hashes'][relative], f'{label} baseline owner/helper changed: {relative}')
        if directory:
            source = Path('/var/tmp/sa-city23-ground')/directory
            info = json.loads(add(source/'capture-info.json', f'native/{directory}/capture-info.json', 'Original actual native capture manifest'))
            png = add(source/'ground-before.png', f'native/{directory}/ground-before.png', 'Unmodified original native PNG')
            capture_checks.append(check_capture(info, png, baseline, mode, size))
            capture_records.append(info)
            need(f'--review={mode}' in expected_args and '--segment=9' in expected_args
                 and '--world-seed=16102026' in expected_args and '--ground-context=-3104,-1384' in expected_args
                 and '--out='+str(source) in expected_args and str(HERE/'GroundPavingPreview.tscn') in expected_args,
                 f'{label} actual capture invocation differs')
            need(re.search(rb'CityGroundReview: segment=9 seed=16102026 context=true frames=0 fires=0 hits=0 failures=0', logs['stdout.log']),
                 f'{label} native terminal footer missing')
        else:
            footer = re.search((re.escape(mode)+r': (\d+) passed, (\d+) failed').encode(), logs['stdout.log'])
            need(footer is not None and int(footer[1]) > 0 and int(footer[2]) == 0, f'{label} owner terminal result missing/failed')
            need('res://tools/tests/'+mode+'.tscn' in expected_args, f'{label} owner scene differs')
        runs.append({'label':label, 'actual_exit':0, 'diagnostics':0, 'head':run['git_head'],
                     'pid':run['pid'], 'guard_completed':True, 'throttle_cycles':thermal['throttle_cycles'],
                     'instantaneous_stop_c':burst_stop, 'sustained_stop_c':85, 'sustained_samples':3,
                     'guard_source_sha256':guard_source,
                     'owned_peak_c':max(s['package_c'] for s in active), 'elapsed_seconds':run['elapsed_seconds']})
    # This interrupted attempt is historical evidence, never an accepted case.
    failed_matches = sorted((LAUNCH/'runs').glob(FAILED_SMALL+'-[0-9]*/run-results.json'))
    need(len(failed_matches) == 1, 'Interrupted small attempt needs one unambiguous actual result')
    failed_path = failed_matches[0]
    failed = json.loads(add(failed_path, f'runs/incomplete/{FAILED_SMALL}/run-results.json.gz',
                            'Complete unfiltered interrupted attempt; not an accepted result', compress=True))
    failed_thermal = json.loads(add(GUARDS/(FAILED_SMALL+'-thermal.json'),
        f'runs/incomplete/{FAILED_SMALL}/thermal.json', 'Actual thermal interruption receipt'))
    add(GUARDS/(FAILED_SMALL+'-wrapper.log'), f'runs/incomplete/{FAILED_SMALL}/wrapper.log', 'Actual interrupted wrapper output')
    for name in ('engine.log', 'stderr.log', 'stdout.log'):
        add(failed_path.parent/'logs'/name, f'runs/incomplete/{FAILED_SMALL}/logs/{name}', 'Unfiltered interrupted-attempt log')
    need(failed['actual_exit'] != 0 and failed['stop_reason'] == 'interrupted'
         and failed['git_head'] == HEAD and failed['project_root'] == str(PROJECT)
         and failed_thermal['reason'] == 'thermal_limit'
         and failed_thermal['runtime_temperature_stop_c'] == 90
         and failed_thermal['sustained_temperature_stop_c'] == 85
         and failed_thermal['sustained_temperature_samples'] == 3,
         'Preserved small attempt is not the expected incomplete default90 run')
    incomplete = {'label':FAILED_SMALL, 'status':'INCOMPLETE_THERMAL_INTERRUPTION_NOT_ACCEPTED',
        'actual_exit':failed['actual_exit'], 'diagnostics':len(failed['diagnostics']),
        'instantaneous_stop_c':90, 'guard_source_sha256':STARTUP_GUARD_HASH,
        'throttle_cycles':failed_thermal['throttle_cycles']}
    need(capture_records[0]['ground_role_uniforms'] == capture_records[1]['ground_role_uniforms'], 'Normal/small actual role uniforms differ')
    manifest = js(PROJECT/'assets/world/ground/baked/ground_materials.json')
    cache_hash = sha((PROJECT/'assets/world/ground/baked/ground_materials.res').read_bytes())
    manifest_hash = sha((PROJECT/'assets/world/ground/baked/ground_materials.json').read_bytes())
    for info in capture_records:
        need(info['round_cobble_source']['record'] == manifest['sources'][9], 'Actual round-cobble record differs from source manifest')
        need(info['ground']['cache_sha256'] == cache_hash and info['ground']['manifest_sha256'] == manifest_hash,
             'Actual bound cache/manifest hashes differ from current finite files')
    for relative in PROJECT_FILES:
        add(PROJECT/relative, 'sources/project/'+relative, 'Bound current source/test owner body')
    for path, destination in EXTERNAL+PROCESS:
        add(path, destination, 'Finite capture/guard/launcher source or actual supporting receipt')
    references = {'baseline_packet':'../2026-10-23-ground-care-edges/',
        'baseline_originals':[{ 'path':str(p.relative_to(ROOT)), 'bytes':p.stat().st_size, 'sha256':originals[str(p.resolve())]}
                              for p in original_files()[:2]],
        'baseline_actual_result':'../2026-10-23-ground-care-edges/runs/city23-ground-before-s9-r2/run-results.json.gz',
        'accepted_care_shader':str(accepted_shader.relative_to(ROOT)),
        'limits':'Prior packet is referenced, not copied. Baseline precedes accepted care-edge shader; care/material/cache metadata remain exact.'}
    summary = {'schema':1, 'status':'ACCEPTED_BOUNDED_OUTER_WALL_PAVING', 'source_head':HEAD,
        'runs':runs, 'incomplete_attempts':[incomplete], 'capture_checks':capture_checks,
        'reviews':['reviews/root.json','reviews/independent.json'],
        'thermal_protocol':'Mixed functional profiles: normal default90; later small/owner runs optional98 instantaneous stop. Both retain65 launch,85x3 sustained,10% duty and exact owned identity. Mechanical evidence only;1Hz readings do not bound unsampled peaks or establish hardware safety.',
        'scope':'Outer-wall yard round cobbles: 192 px repeat, .52 source weight and local tint only. No care/generator/door/cache changes.',
        'limits':'Static appearance and focused functional correctness only; no motion-shimmer, performance, full playtest or whole-city completion claim.'}
    for destination, body, role in (
        ('.gdignore', b'', 'Godot exclusion; first delivered write'),
        ('baseline-reference.json', json_bytes(references), 'Earlier committed baseline reference; no duplicate images'),
        ('verification.json', json_bytes(summary), 'Checked actual outcome/control inventory'),
        ('README.md', ('# Outer-wall paving\n\nBounded S9 yard scale/grade correction at source '+HEAD+'.\n\n'
            'Original normal 1280x720 and small 960x540 PNGs and manifests are under `native/`. '
            'Both reviews bind these originals and the earlier committed baseline. '
            'The baseline remains in `../2026-10-23-ground-care-edges/native/before-s9-r2/`.\n\n'
            'Four clean actual run results are complete, unfiltered deterministic gzip bodies under `runs/`; '
            'guard thermal receipts, wrapper output and all three raw logs accompany each. '
            'The interrupted default90 small-r1 attempt is fully preserved under `runs/incomplete/` and is not accepted. '
            '`compression-map.json` records raw and compressed hashes and verified round trips. '
            '`manifest.json` indexes every other payload; its own receipt is printed by the builder.\n\n'
            'Three queue JSONs retain wrapper history: the first misread a summary-only field after the clean normal run; '
            'the second stopped after a thermal interruption; the third completes the remaining cases. '
            'Source, capture helper chain, per-case thermal profiles and safe non-Godot regressions are included. '
            'Normal used the frozen default90 guard; subsequent accepted small/owner runs use optional98 instantaneous stop. '
            'Both retain65 launch and85x3 sustained stops,10% duty and exact ownership. '
            'This mechanical protocol evidence and1Hz samples establish no hardware-safety result or bound on unsampled peaks. '
            'Care-edge shader was accepted in the preceding packet; it is bound again here. '
            'Existing broader ground/property geometry and motion-shimmer questions remain outside this static acceptance. '
            'These duty-controlled captures establish no performance result.\n').encode(), 'Review index'),
    ):
        need(destination not in payload, 'Duplicate generated payload')
        payload[destination] = {'raw':body, 'source_path':None, 'role':role, 'compress':False}
    return payload, summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root-review', required=True, type=Path)
    parser.add_argument('--independent-review', required=True, type=Path)
    parser.add_argument('--check-only', action='store_true')
    args = parser.parse_args()
    payload, summary = prepare(args)
    if args.check_only:
        print(json.dumps({'status':'ALL_INPUT_GATES_PASSED_NO_WRITES_NO_COMPRESSION',
            'source_head':HEAD, 'destination':str(DEST), 'planned_payload_files':len(payload)+1,
            'planned_files':sorted([*payload, 'compression-map.json']), 'runs':summary['runs']}, indent=2))
        return
    need(not DEST.exists(), 'Refusing existing packet destination: '+str(DEST))
    DEST.mkdir(parents=True)
    (DEST/'.gdignore').write_bytes(b'')  # First write, before any evidence/source body.
    entries = []
    compression = []
    for destination, item in sorted(payload.items()):
        raw = item['raw']
        output = gzip.compress(raw, mtime=0) if item['compress'] else raw
        if item['compress']:
            roundtrip = gzip.decompress(output)
            need(roundtrip == raw, 'Raw gzip round trip failed: '+destination)
            compression.append({'path':destination, 'gzip_mtime':0, 'raw_bytes':len(raw), 'raw_sha256':sha(raw),
                                'gzip_bytes':len(output), 'gzip_sha256':sha(output), 'roundtrip_sha256':sha(roundtrip)})
        target = DEST/destination
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(output)
        entries.append({'path':destination, 'bytes':len(output), 'sha256':sha(output),
            'source_path':item['source_path'], 'source_bytes':len(raw), 'source_sha256':sha(raw),
            'role':item['role'], 'encoding':'gzip' if item['compress'] else 'identity'})
    mapping = json_bytes({'schema':1, 'files':compression})
    (DEST/'compression-map.json').write_bytes(mapping)
    entries.append({'path':'compression-map.json', 'bytes':len(mapping), 'sha256':sha(mapping),
                    'role':'Raw gzip round-trip inventory', 'encoding':'identity'})
    manifest = json_bytes({'schema':1, 'generated_utc':datetime.now(timezone.utc).isoformat(),
        'source_head':HEAD, 'scope':'Every delivered payload except this manifest itself',
        'files':sorted(entries, key=lambda x:x['path'])})
    (DEST/'manifest.json').write_bytes(manifest)
    need(sorted(str(p.relative_to(DEST)) for p in DEST.rglob('*') if p.is_file()) ==
         sorted([*(entry['path'] for entry in entries), 'manifest.json']), 'Final finite packet inventory differs')
    print(json.dumps({'status':'BUILT', 'destination':str(DEST), 'payload_files':len(entries),
        'delivered_files_including_manifest':len(entries)+1, 'raw_gzip_results':len(compression),
        'manifest_sha256':sha(manifest), 'manifest_bytes':len(manifest)}, indent=2))


if __name__ == '__main__':
    main()
