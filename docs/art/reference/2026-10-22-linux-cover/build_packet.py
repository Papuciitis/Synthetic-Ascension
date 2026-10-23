#!/usr/bin/env python3
"""Populate this scratch packet from finished cover runs; never starts Godot.

Run only after the root agent releases the packet CPU-work hold. Re-running
adds newly completed cases, regenerates indexes, and leaves originals untouched.
"""
from pathlib import Path
import gzip
import hashlib
import json
import re
import runpy

PACKET = Path(__file__).resolve().parent
ROOT = Path('/home/user/Nauris/Synthetic-Ascension')
CONTROL = ROOT / '.superpowers/continuation-20261022'
RUNS = ROOT / '.superpowers/claude-city-20261021/runs'
NATIVE = Path('/var/tmp/sa-city22/cover')
THRESHOLD = 128 * 1024
VISUAL_TOOL_PATH = 'tools/dev/WorldCoverMovingVisualProbe.gd'
PRESERVED_SOURCE_DIRS = [PACKET / 'sources/blobs', CONTROL / 'cover-tree-r6-basis', CONTROL / 'cover-tree-r7-basis', CONTROL / 'cover-tree-r8-basis']
R6_TOOL_SHA = '00f7eba66cffef7961f211e21410ed315244d37280fd8a33bf451c57c196527f'
R7_TOOL_SHA = '8737b1c5ff967a3caa097d1101649c3ddb0d227a0899b884cc9612202c6deab3'
R6_REVIEW_SHA = '867f0101ea63b99c53ae2cc96559f16ec22c10dbe85a90086b6fd33fef96fb2d'
R8_TOOL_SHA = '4ab8a4100dbb99487f88f7965a812762dc29bae165eba96894adb17b23de1b1e'
R8_SHADER_SHA = 'a399f0e37d1cadf82712c9efb668eb8d62bb0866521ded5d415846332318e367'
R8_REVIEW_SHA = 'd66dbaf9f3259b4ef0d066baddbadeb50a38c1b974bc4a6fe395f60a8ca9123a'
R8_DRIVER_SHA = 'd7b543546dfb08163ef3c5a2e54ecc5a22b57387a8b286df5efbce29c716c48b'
R8_DECISION_SHA = '62a8fc6c40c9030691524d2b7d2f34e985542a8cb0866a1896a438ed16834619'
VISUAL_TOOL_VERSIONS = {
    'b1f7b9f364ba1cf67baf1a3ecdb710dac0774e11d16078cbbe8790d6512ceff5':
        'Accepted bounded home-r3 and failed/interrupted tree-r3 source; outcomes remain per run.',
    '51204c3cec2d83682b3cc636c8960c3e9e6d89dd67e8570294d4b02f17e67ad7':
        'Tree r4/r5 preparation; actual r5 failed logically with body-space diagnostics and no exposed controls.',
    '00f7eba66cffef7961f211e21410ed315244d37280fd8a33bf451c57c196527f':
        'Tree-r6 camera/body-space correction; clean functional capture, but actual locked-ring readability remains OPEN under review867f0101.',
    R7_TOOL_SHA:
        'Tree-r7 actual comparison failed only same-view after live knockback moved camera; originals remain qualitative, not a matched-view pass.',
    R8_TOOL_SHA:
        'Tree-r8 clean actual parser3/native33/moving controls plus fixed-camera ordinary comparison; small equipment discoverability remains OPEN in exact native review.',
}
SCOPED = [
    '.superpowers/claude-city-20261021/run_engine_slot.py',
    '/home/user/Nauris/Synthetic-Ascension/.superpowers/claude-city-20261021/run_engine_slot.py',
    'core/systems/world/visibility/WorldCover.gd',
    'core/systems/world/visibility/PickupCover.gd',
    'core/systems/world/visibility/pickup_cover.gdshader',
    'core/systems/world/visibility/world_cover.gdshaderinc',
    'tools/tests/WorldCoverWatchLifecycleTest.gd',
    'tools/tests/WorldCoverWatchLifecycleTest.tscn',
    'tools/tests/WorldCoverInvalidationTest.gd',
    'tools/tests/WorldCoverInvalidationTest.tscn',
    'tools/dev/WorldCoverCostProbe.gd',
    'tools/dev/WorldCoverCostProbe.tscn',
    'tools/dev/WorldCoverMovingVisualProbe.gd',
    'tools/dev/WorldCoverMovingVisualProbe.tscn',
    'tools/dev/WorldCoverMovingVisualProbe.md',
    'tools/dev/WorldCoverStreamingProfile.gd',
    'tools/dev/WorldCoverStreamingProfile.tscn',
    'tools/dev/CityMovingCoverPreview.gd',
    'tools/dev/CityEntityCoverPreview.gd',
    'tools/dev/CityBlockPlayablePreview.gd',
    'tools/dev/EliteCrowdFightPreview.gd',
    'tools/tests/EnemyCoverRenderTest.gd',
    'tools/tests/PickupCoverTest.gd',
    'tools/tests/WorldCueCoverRenderTest.gd',
    'tools/tests/PlayerForegroundCoverRenderTest.gd',
]
EXPECTED = [
    'city22-cover-watch-red', 'city22-cover-watch-red2',
    'city22-cover-watch-red3', 'city22-cover-watch-green',
    'city22-cover-invalidation', 'city22-cover-tools-parse',
    'city22-cover-cost-s2', 'city22-cover-cost-s10',
    'city22-cover-native-baseline', 'city22-cover-native-candidate',
    'city22-cover-core', 'city22-cover-reuse', 'city22-cover-faces',
    'city22-cover-enemy-native', 'city22-cover-pickup-native',
    'city22-cover-cue-native', 'city22-cover-player-native',
    'city22-cover-moving-final-parse', 'city22-cover-moving-visual',
    'city22-cover-moving-home', 'city22-cover-moving-tree',
    'city22-cover-tree-r6-parse', 'city22-cover-moving-tree-r6',
    'city22-cover-tree-r7-parse', 'city22-cover-moving-tree-r7',
    'city22-cover-tree-r8-parse', 'city22-cover-pickup-r8-native', 'city22-cover-moving-tree-r8',
]
files = {}
compression = []
blob_data = {}
source_cache = {}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def put(data, relative, origin, role, compress=True):
    raw_path = str(relative)
    packed = compress and len(data) > THRESHOLD
    relative = raw_path + '.gz' if packed else raw_path
    target = PACKET / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    payload = gzip.compress(data, compresslevel=6, mtime=0) if packed else data
    target.write_bytes(payload)
    record = {'path': relative, 'role': role, 'source_path': str(origin),
              'raw_sha256': sha(data), 'raw_bytes': len(data),
              'delivered_sha256': sha(payload), 'delivered_bytes': len(payload)}
    files[relative] = record
    if packed:
        compression.append({'original_path': raw_path, 'raw_sha256': sha(data),
                            'raw_bytes': len(data), 'gzip_path': relative,
                            'gzip_sha256': sha(payload), 'gzip_bytes': len(payload),
                            'round_trip_verified': gzip.decompress(payload) == data})
    return relative


def copy(source, relative, role, compress=True):
    return put(source.read_bytes(), relative, source, role, compress=compress)


def output(relative, obj, role='derived index'):
    return put((json.dumps(obj, indent=2, sort_keys=True) + '\n').encode(),
               relative, 'derived from recorded inputs; see references', role)


def source_bytes(project, path, expected, head):
    if expected in blob_data:
        return blob_data[expected], 'previously matched content'
    # Keep earlier launch snapshots usable after an authorized tool change.
    for directory in PRESERVED_SOURCE_DIRS:
        for snapshot in directory.glob(expected + '-*'):
            data = snapshot.read_bytes()
            if sha(data) == expected:
                blob_data[expected] = data
                return data, 'preserved source snapshot exactly matches launch SHA256: ' + str(snapshot)
    key = (str(project), path, expected, head)
    if key in source_cache:
        return source_cache[key]
    present = project / path
    if present.is_file():
        data = present.read_bytes()
        if sha(data) == expected:
            source_cache[key] = (data, 'current file exactly matches launch SHA256')
            return source_cache[key]
    # This scratch refresh invokes neither Git nor engines. Earlier matched
    # content-addressed blobs remain usable; unavailable history stays hash-only.
    source_cache[key] = (None, 'recorded hash only; exact draft bytes unavailable')
    return source_cache[key]


def classify(label, result, stdout):
    if label == 'city22-cover-watch-red2':
        return 'parser_failure_then_owned_engine_termination_not_behavioral_red'
    if label == 'city22-cover-watch-red3':
        footer = re.search(r'WorldCoverWatchLifecycleTest: (\d+) passed, (\d+) failed', stdout)
        if result['actual_exit'] == 1 and footer and int(footer[2]) > 0:
            return 'expected_behavioral_red'
        return 'unexpected_red_outcome'
    if (label == 'city22-cover-moving-tree-r5' and result.get('stop_reason') == 'completed'
            and result.get('actual_exit') == 1 and result.get('diagnostics')):
        return 'completed_logical_probe_and_harness_failures_not_thermal'
    if result.get('stop_reason') == 'completed' and result.get('actual_exit') == 0 and not result.get('diagnostics'):
        return 'completed_zero_diagnostics'
    if result.get('stop_reason') != 'completed':
        return 'interrupted_after_engine_start_not_clean_completion'
    return 'failed_or_diagnostic_run'


def visual_case_state(result, manifest, present, fixture=False, outer_reason='completed'):
    if result.get('stop_reason') != 'completed' or outer_reason != 'completed':
        return 'partial_interrupted_capture_not_acceptance'
    if result.get('actual_exit') != 0 or result.get('diagnostics'):
        return 'completed_with_failure_or_diagnostics_not_acceptance'
    if not present:
        return 'missing_final_manifest_not_acceptance'
    if not fixture and (manifest.get('failures') != 0 or manifest.get('save_writes') != 0):
        return 'final_manifest_failed_or_incomplete_not_acceptance'
    return 'completed_clean_native_fixture' if fixture else 'pending_visual_review'


def ordinary_equipment_gate(result, manifest, present, png_present, outer, expected_tool=R7_TOOL_SHA):
    """R7 functional comparison only; never converts pixel telemetry into readability acceptance."""
    if result.get('source_hashes', {}).get(VISUAL_TOOL_PATH) != expected_tool:
        return {'state': 'different_tool_source_not_reviewed_comparison', 'passed': False}
    if expected_tool == R8_TOOL_SHA and (result.get('source_hashes', {}).get('core/systems/world/visibility/pickup_cover.gdshader') != R8_SHADER_SHA
            or manifest.get('normal_equipment_comparison', {}).get('comparison_camera_only_held') is not True):
        return {'state':'r8_shader_or_fixed_camera_gate_failed','passed':False}
    if (result.get('runner_exit') != 0 or outer.get('wrapper_exit') != 0
            or outer.get('received_signal') is not None):
        return {'state': 'unclean_runner_or_guard_transport_not_acceptance', 'passed': False}
    state = visual_case_state(result, manifest, present, outer_reason=outer.get('reason'))
    if state != 'pending_visual_review':
        return {'state': state, 'passed': False}
    normal = manifest.get('normal_equipment_comparison', {})
    before, after = normal.get('before', []), normal.get('after', [])
    paired = (len(before) == len(after) == 2 and
              all(isinstance(row, dict) for row in before + after))
    if paired:
        paired = (len({row.get('instance_id') for row in before}) == 2 and
                  all(a.get('instance_id') == b.get('instance_id') and a.get('world') == b.get('world')
                      and a.get('same_owner_world_as_third_plate') is True
                      and a.get('pickup_ready') is False and a.get('monitoring') is False
                      and a.get('monitorable') is False
                      and b.get('same_position_material_texture_and_owner_state') is True
                      and b.get('pickup_ready') is True and b.get('monitoring') is True
                      and b.get('monitorable') is True and b.get('picked') is False
                      and b.get('vfx_locked') is False
                      and a.get('player_distance', 0) > normal.get('minimum_player_distance', 126)
                      and b.get('player_distance', 0) > normal.get('minimum_player_distance', 126)
                      for a, b in zip(before, after)))
    flags = all(normal.get(key) is True for key in
                ['passed', 'same_camera_and_view', 'health_stays_locked', 'original_locked_counts_preserved'])
    fragments = (paired and sum(row.get('opaque_tree_covered', 0) > 0 for row in after) == 1
                 and sum(row.get('opaque_shared_exposed', 0) > 0 for row in after) == 1)
    passed = (flags and paired and fragments and png_present and manifest.get('phase') == 'tree'
              and manifest.get('engine_max_fps') == 15 and manifest.get('physics_ticks_per_second') == 60
              and len(manifest.get('tree_plates', [])) == 3
              and normal.get('plate', {}).get('file') == 'tree-normal-equipment.png'
              and normal.get('minimum_player_distance') == 126
              and normal.get('ordinary_wait_simulation_seconds', 0) + 1e-9 >= 0.35
              and normal.get('ordinary_physics_frames', 0) > 0)
    return {'state': 'clean_native_comparison_requires_image_review' if passed else 'failed_or_incomplete_comparison_not_acceptance',
            'passed': passed, 'same_original_owners_and_world_points': bool(paired),
            'covered_and_exposed_opaque_controls': bool(fragments),
            'appearance_acceptance': 'OPEN; ordinary-versus-locked native images require actual review',
            'limits': 'The fourth plate cannot satisfy original locked controls. Same view is not whole-PNG identity, and source/material counts do not prove readable contrast.'}


def r6_appearance_review(data, result, delivered_plates):
    if sha(data) != R6_REVIEW_SHA:
        raise ValueError('R6 appearance review changed; independent review binding must be updated explicitly')
    review = json.loads(data)
    if (result.get('source_hashes', {}).get(VISUAL_TOOL_PATH) != R6_TOOL_SHA
            or result.get('stop_reason') != 'completed' or result.get('actual_exit') != 0
            or result.get('runner_exit') != 0
            or result.get('diagnostics')
            or review.get('tool_sha256') != R6_TOOL_SHA
            or review.get('status') != 'CLEAN_FUNCTIONAL_CAPTURE_VISUAL_LEGIBILITY_UNRESOLVED'
            or not review.get('all_three_original_plates_viewed')
            or len(review.get('plates', [])) != 3
            or any(result.get('source_hashes', {}).get(path) != expected
                   for path, expected in review.get('source_binding', {}).items())
            or any(delivered_plates.get(plate['file']) != plate['sha256'] for plate in review['plates'])):
        raise ValueError('R6 actual source/three original images do not match appearance review')
    return {'state': 'OPEN_locked_small_equipment_readability', 'review_sha256': R6_REVIEW_SHA,
            'functional_execution': 'clean; independent from visual readability',
            'finding': 'No source/material/sampler/z mismatch identified; low-alpha locked ring is difficult to identify against busy canopy at native zoom.',
            'acceptance': 'Withheld. R7 ordinary-ready comparison is a separate case, not a retroactive R6 pass.'}


def r8_receipt_gate(queue, driver, records):
    pins=driver['PINS']
    labels=['city22-cover-tree-r8-parse','city22-cover-pickup-r8-native','city22-cover-moving-tree-r8']
    arguments=[
        ['--headless','--audio-driver','Dummy',str(CONTROL/'external_source_parse_probe.tscn'),'--',
            'res://tools/dev/WorldCoverMovingVisualProbe.gd','res://tools/tests/PickupCoverTest.gd',str(CONTROL/'PickupCoverDensityNative.gd')],
        ['--rendering-driver','opengl3','--audio-driver','Dummy',str(CONTROL/'PickupCoverDensityNative.tscn')],
        ['--rendering-driver','opengl3','--audio-driver','Dummy','res://tools/dev/WorldCoverMovingVisualProbe.tscn','--',
            '--visible','--runtime-fps=15','--phase=tree','--world-seed=16102026','--target-building-id=944996572',
            '--target-chunk=0,3','--review=small','--out='+str(NATIVE/'moving-tree-r8')],
    ]
    cases=queue.get('cases',[])
    if (queue.get('state')!='clean_functional_capture_requires_actual_image_review'
            or queue.get('tool_sha256')!=R8_TOOL_SHA or queue.get('shader_sha256')!=R8_SHADER_SHA
            or queue.get('source_pins')!=pins or [case.get('label') for case in cases]!=labels):
        raise ValueError('R8 exact queue/source/three-case receipt differs')
    project=Path('/tmp/sa-wp2-cover')
    for index,case in enumerate(cases):
        canonical=driver['command'](labels[index],arguments[index],moving=index==2)
        if case.get('command')!=canonical: raise ValueError('R8 command is not the exact frozen parser/native/moving invocation')
        record=records[labels[index]];raw=record['result'];outer=record['outer'];stdout=record['stdout']
        if (case.get('wrapper_exit')!=0 or case.get('raw_run_record')!=record['raw_path']
                or raw.get('actual_exit')!=0 or raw.get('runner_exit')!=0 or raw.get('stop_reason')!='completed'
                or not raw.get('ended_utc') or raw.get('diagnostics')!=[] or outer.get('reason')!='completed'
                or outer.get('wrapper_exit')!=0 or outer.get('received_signal') is not None
                or Path(raw.get('project_root','')).resolve()!=project):
            raise ValueError('R8 actual runner/guard/source project differs')
        if any(raw.get('source_hashes',{}).get(str(Path(path).relative_to(project)))!=digest
                for path,digest in pins.items() if Path(path).is_relative_to(project)):
            raise ValueError('R8 actual launched source pins differ')
        engine_args=case['command'][case['command'].index('--')+1:]
        if raw.get('command',[])[-len(engine_args):]!=engine_args:
            raise ValueError('R8 actual command differs')
        protocol={'cpu_affinity':[0,1],'start_temperature_c':65,'runtime_temperature_stop_c':90,
            'sustained_temperature_stop_c':85,'sustained_temperature_samples':3,'duty_cycle':0.25,
            'duty_released':index==2,'release_marker':'[Game] ready' if index==2 else None}
        if any(outer.get(key)!=value for key,value in protocol.items()): raise ValueError('R8 actual guard protocol differs')
        if index==0 and ('--headless' not in raw['command'] or 'ExternalSourceParseProbe: checked=3 failures=0' not in stdout):
            raise ValueError('R8 scoped parser3 verdict missing')
        if index==1 and ('--headless' in raw['command'] or 'opengl3' not in raw['command']
                or 'PickupCoverTest passes=33 failures=0' not in stdout or 'native pixel cases skipped' in stdout
                or 'PickupCoverDensityNative: driver=opengl3 cap=15 physics=60 original_predicates=33' not in stdout):
            raise ValueError('R8 actual native33/cap/physics verdict missing')
    return {'state':'clean_parser3_native33_moving_capture','passed':True,
        'appearance':'Bounded density improvement only; small equipment discoverability OPEN'}


def r8_appearance_review(data, decision_data, result, manifest, hashes, delivered_images):
    if sha(data)!=R8_REVIEW_SHA or sha(decision_data)!=R8_DECISION_SHA:
        raise ValueError('R8 exact independent review/root decision changed')
    review=json.loads(data);decision=json.loads(decision_data)
    expected={'tools/dev/WorldCoverMovingVisualProbe.gd':R8_TOOL_SHA,
        'core/systems/world/visibility/pickup_cover.gdshader':R8_SHADER_SHA}
    if (review.get('verdict')!='BOUNDED_IMPROVEMENT_BUT_SMALL_EQUIPMENT_DISCOVERABILITY_REMAINS_OPEN'
            or result.get('actual_exit')!=0 or result.get('runner_exit')!=0 or result.get('stop_reason')!='completed'
            or result.get('diagnostics')!=[] or manifest.get('failures')!=0 or manifest.get('save_writes')!=0
            or review.get('launched_sources')!=expected
            or any(result.get('source_hashes',{}).get(path)!=digest for path,digest in expected.items())
            or any(review.get(key,{}).get('sha256')!=hashes.get(key) for key in ('raw','guard','visual_manifest'))
            or len(review.get('images',[]))!=6
            or any(image.get('reviewed_original') is not True or delivered_images.get(image['path'])!=image['sha256'] for image in review['images'])
            or any(manifest.get('normal_equipment_comparison',{}).get(key)!=value for key,value in review.get('normal_equipment_matched_reference',{}).items())
            or decision.get('tool_sha256')!=R8_TOOL_SHA or decision.get('shader_sha256')!=R8_SHADER_SHA
            or decision.get('independent_review_sha256')!=R8_REVIEW_SHA
            or set(decision.get('root_viewed_originals',[]))!={'tree-front.png','tree-behind.png','tree-front-restored.png','tree-normal-equipment.png'}
            or decision.get('decision')!='Integrate bounded pickup density improvement and native comparison tool; do not claim small-equipment discoverability resolved.'):
        raise ValueError('R8 actual original/source/reference or bounded root verdict differs')
    return {'state':'BOUNDED_IMPROVEMENT_APPROVED_DISCOVERABILITY_OPEN','review_sha256':R8_REVIEW_SHA,
        'root_decision_sha256':R8_DECISION_SHA,'decision':decision['decision'],
        'finding':'Normal ring is denser; locked and ordinary tiny ring still need foreknowledge against busy leaves. Potions and actors read more readily.',
        'limits':'R7 originals are qualitative references only. R8 same-view/19-covered/19-exposed gates do not prove practical icon recognition. No performance or all-item/all-background acceptance.'}


def reference_closure(label, result):
    hashes = result.get('source_hashes', {})
    project = Path(result['project_root'])
    roots = ['project.godot', 'scenes/game.tscn']
    roots += [part[6:] for part in result['command'] if part.startswith('res://')]
    pending = list(dict.fromkeys(roots))
    seen, unresolved, absent, unavailable = set(), set(), set(), set()
    edges = []
    textual = {'.godot', '.gd', '.tscn', '.tres', '.gdshader', '.gdshaderinc', '.import', '.json'}
    while pending:
        path = pending.pop()
        if path in seen:
            continue
        if path not in hashes:
            absent.add(path)
            continue
        seen.add(path)
        if path.startswith('assets/') and path + '.import' in hashes:
            pending.append(path + '.import')
        if Path(path).suffix not in textual:
            continue
        data, _ = source_bytes(project, path, hashes[path], result['git_head'])
        if data is None:
            unavailable.add(path)
            continue
        for match in re.findall(r'res://[^"\s\)\],;]+', data.decode(errors='replace')):
            dep = match[6:].rstrip("'}")
            if any(token in dep for token in ['%', '{', '+']):
                unresolved.add(match)
                continue
            edges.append([path, dep])
            pending.append(dep)
    return {'run': label, 'roots': roots,
            'interpretation': 'Static literal reference superset, not actual loaded-resource telemetry; dynamic paths are incomplete.',
            'recorded_inputs': {path: hashes[path] for path in sorted(seen)},
            'literal_edges': edges, 'unresolved_dynamic_patterns': sorted(unresolved),
            'references_without_launch_hash': sorted(absent),
            'source_bodies_unavailable_for_reference_scan': sorted(unavailable),
            'recorded_generated_import_hashes': {p: h for p, h in hashes.items() if p.startswith('.godot/imported/')},
            'generated_cache_limit': 'No later filesystem hash is substituted for a missing launch hash.'}


def main():
    (PACKET / '.gdignore').touch(exist_ok=True)
    index, bindings, completed, pending = [], [], {}, []
    completed_details = {}
    for name in ['legacy-WorldCover.gd', 'pending-WorldCover.gd']:
        path = CONTROL / 'variants' / name
        data = path.read_bytes()
        blob_data[sha(data)] = data
        copy(path, 'variants/' + name, 'exact provider comparison variant')
    labels = sorted(set(EXPECTED) | {p.name.removesuffix('-thermal.json')
                                    for p in CONTROL.glob('city22-cover-*-thermal.json')})
    for label in labels:
        thermal = CONTROL / (label + '-thermal.json')
        # The outer wrapper writes this only after exit/cleanup. Do not read
        # an active run folder merely to infer whether its JSON is finished.
        if not thermal.is_file():
            pending.append(label)
            continue
        folders = sorted(RUNS.glob(label + '-*'))
        results = [p / 'run-results.json' for p in folders if (p / 'run-results.json').is_file()]
        finished = []
        for path in results:
            result = json.loads(path.read_text())
            if result.get('ended_utc') and result.get('actual_exit') is not None:
                finished.append((path, result))
        if not finished:
            if thermal.is_file():
                outer = json.loads(thermal.read_text())
                if outer.get('owned_pids'):
                    pending.append(label)
                    continue
                index.append({'label': label, 'classification': 'preflight_without_owned_godot_no_behavioral_result',
                              'godot_started': False, 'owned_pids': outer.get('owned_pids'),
                              'thermal': copy(thermal, 'runs/' + label + '/thermal.json', 'original outer thermal record')})
                wrapper = CONTROL / (label + '-wrapper.log')
                if wrapper.is_file():
                    index[-1]['wrapper'] = copy(wrapper, 'runs/' + label + '/wrapper.log', 'original preflight wrapper outcome')
            else:
                pending.append(label)
            continue
        for path, result in finished:
            run_label = path.parent.name
            destination = 'runs/' + run_label + '/'
            stdout_path = path.parent / 'logs/stdout.log'
            stdout = stdout_path.read_text(errors='replace') if stdout_path.is_file() else ''
            record = {'label': label, 'run_folder': run_label,
                      'classification': classify(label, result, stdout),
                      'actual_exit': result['actual_exit'], 'stop_reason': result['stop_reason'],
                      'diagnostic_count': len(result.get('diagnostics', [])),
                      'git_head': result.get('git_head'),
                      'source_hash_count': len(result.get('source_hashes', {})),
                      'command': result['command'], 'command_shell': result['command_shell'],
                      'started_utc': result.get('started_utc'), 'ended_utc': result.get('ended_utc'),
                      'assertion_footer_lines': [line for line in stdout.splitlines()
                          if ('Test' in line or 'Probe' in line) and
                          re.search(r'\b(passed|passes|failed|failures)\b', line)],
                      'run_results': copy(path, destination + 'run-results.json', 'original launch/source/resource/diagnostic record')}
            for name in ['stdout.log', 'stderr.log', 'engine.log']:
                log = path.parent / 'logs' / name
                if log.is_file():
                    copy(log, destination + 'logs/' + name, 'original engine log')
            if thermal.is_file():
                record['thermal'] = copy(thermal, destination + 'thermal.json', 'original outer thermal record')
                t = json.loads(thermal.read_text())
                record['peak_package_c'] = max((s.get('package_c') or 0 for s in t.get('samples', [])), default=None)
                record['first_wrapper_sample_c'] = t.get('samples', [{}])[0].get('package_c')
                record['first_wrapper_sample_scope'] = 'Wrapper/preflight sample; not established as actual Godot-start temperature.'
                record['start_gate_environment'] = t.get('environment_overrides', {}).get('SA_ENGINE_THERMAL_LIMIT_C')
                record['actual_engine_start_temperature_c'] = None
                record['outer_stop_reason'] = t.get('reason')
            wrapper = CONTROL / (label + '-wrapper.log')
            if wrapper.is_file():
                copy(wrapper, destination + 'wrapper.log', 'original wrapper summary')
            index.append(record)
            completed[label] = result
            completed_details[label] = {'result':result, 'outer':json.loads(thermal.read_text()),
                'stdout':stdout, 'raw_path':str(path), 'raw_sha256':files[record['run_results']]['raw_sha256'],
                'guard_sha256':files[record['thermal']]['raw_sha256']}
            hashes = result.get('source_hashes', {})
            scoped = {}
            for source in SCOPED:
                expected = hashes.get(source)
                if expected is None:
                    continue
                data, status = source_bytes(Path(result['project_root']), source, expected, result['git_head'])
                detail = {'launch_sha256': expected, 'status': status}
                if data is not None:
                    blob_data[expected] = data
                    detail['snapshot'] = put(data, 'sources/blobs/' + expected + '-' + Path(source).name,
                                             str(Path(result['project_root']) / source), 'scoped bytes matching original launch SHA256')
                scoped[source] = detail
            binding = {'run': run_label, 'git_head': result['git_head'],
                       'tracked_git_status': result.get('git_status_porcelain'),
                       'source_untracked': result.get('source_untracked'), 'scoped': scoped,
                       'recorded_generated_import_count': sum(p.startswith('.godot/imported/') for p in hashes)}
            binding_path = output('sources/run-bindings/' + run_label + '.json', binding)
            bindings.append({'run': run_label, 'git_head': result['git_head'],
                             'binding': binding_path, 'scoped_count': len(scoped),
                             'unavailable_scoped_sources': [p for p, d in scoped.items() if 'snapshot' not in d],
                             'recorded_generated_import_count': binding['recorded_generated_import_count']})
    r8_status = {'state':'pending_clean_r8_parser_native33_moving_receipts','passed':False}
    r8_labels = ['city22-cover-tree-r8-parse','city22-cover-pickup-r8-native','city22-cover-moving-tree-r8']
    if all(label in completed_details for label in r8_labels):
        driver_path=CONTROL/'cover-tree-r8-queue.py'
        if sha(driver_path.read_bytes())!=R8_DRIVER_SHA: raise ValueError('Frozen R8 driver source differs')
        driver=runpy.run_path(str(driver_path)) # Read frozen PINS only; never invoke main/verify/engine calls.
        r8_status=r8_receipt_gate(json.loads((CONTROL/'cover-tree-r8-queue.json').read_text()),driver,completed_details)
    summaries = {'static': {}, 'native': {}, 'performance_claim': 'No watch-related speedup or isolated matched-workload throughput gain is established.'}
    for fixture in ['s2', 's10']:
        source = CONTROL / ('city22-cover-cost-' + fixture + '.json')
        if source.is_file() and 'city22-cover-cost-' + fixture in completed:
            copy(source, 'cost/static-' + fixture + '.json', 'original static CPU cost report')
            summaries['static'][fixture] = json.loads(source.read_text())
    for variant in ['baseline', 'candidate']:
        label = 'city22-cover-native-' + variant
        profile = NATIVE / ('profile-' + variant) / 'profile-info.json'
        if label not in completed or not profile.is_file():
            continue
        p = json.loads(profile.read_text())
        copy(profile, 'native/profile-' + variant + '/profile-info.json', 'original full no-readback native profile')
        summaries['native'][variant] = {k: v for k, v in p.items() if k not in ['samples', 'streaming', 'cover']}
        summaries['native'][variant]['sample_count'] = len(p['samples'])
        summaries['native'][variant]['streaming_summary'] = {k: v for k, v in p['streaming'].items() if k != 'samples'}
        summaries['native'][variant]['cover_summary'] = p['cover']
        r = completed[label]
        output('sources/' + variant + '-native-reference-closure.json', reference_closure(label, r))
        output('sources/' + variant + '-recorded-asset-import-inventory.json', {
            'run': label, 'scope': 'Recorded project-wide launch inventory; not a loaded-resource trace.',
            'entries': {path: value for path, value in r['source_hashes'].items()
                        if path.startswith('assets/') and (path.endswith('.import') or Path(path).suffix in ['.png', '.jpg', '.webp', '.res'])}})
    if all('city22-cover-native-' + v in completed for v in ['baseline', 'candidate']):
        a = completed['city22-cover-native-baseline']['source_hashes']
        b = completed['city22-cover-native-candidate']['source_hashes']
        output('sources/native-launch-map-comparison.json', {
            'baseline_count': len(a), 'candidate_count': len(b),
            'shared_count': len(a.keys() & b.keys()),
            'changed_shared': {k: {'baseline': a[k], 'candidate': b[k]} for k in sorted(a.keys() & b.keys()) if a[k] != b[k]},
            'baseline_only': sorted(a.keys() - b.keys()), 'candidate_only': sorted(b.keys() - a.keys())})
    for name in ['guarded_engine.py', 'guarded_engine-final.py', 'guarded_engine-descendants.py', 'guarded_engine-functional70.py', 'source_parse_probe.gd', 'source_parse_probe.tscn',
                 'cover-timing-queue.json', 'cover-native-queue.json', 'cover-checks-queue.json',
                 'cover-tree-r4-source.json', 'cover-tree-r4-tool.diff', 'cover-tree-r4-queue.py',
                 'cover-tree-r5-queue.py', 'cover-tree-r5-queue.json',
                 'cover-tree-r6-source.json', 'cover-tree-r6-tool.diff', 'cover-tree-r6-root-cause.json',
                 'cover-tree-r6-driver.diff', 'cover-tree-r6-queue.py', 'cover-tree-r6-queue.md',
                 'cover-tree-r6-queue.json',
                 'cover-tree-r6-native-appearance-review.md',
                 'cover-tree-r7-source.json', 'cover-tree-r7-tool.diff', 'cover-tree-r7-driver.diff',
                 'cover-tree-r7-queue.py', 'cover-tree-r7-queue.md', 'cover-tree-r7-queue.json',
                 'cover-tree-r7-readonly-review.md',
                 'cover-tree-r8-source.json','cover-tree-r8-tool.diff','cover-tree-r8-shader.diff','cover-tree-r8-offset-only.diff',
                 'cover-tree-r8-queue.py','cover-tree-r8-queue.md','cover-tree-r8-queue.json',
                 'PickupCoverDensityNative.gd','PickupCoverDensityNative.tscn','pickup-cover-density-r8.gdshader',
                 'cover-tree-r8-independent-review.json','cover-tree-r8-independent-visual-review.md']:
        source = CONTROL / name
        if source.is_file():
            copy(source, 'harness/' + name, 'packaging-time harness snapshot; original commands remain in run records')
    visual_status = {}
    artifact_cases = {
        'player-reference': 'city22-cover-player-native-g2',
        'moving-visual': 'city22-cover-moving-visual',
        'moving-home': 'city22-cover-moving-home',
        'moving-tree': 'city22-cover-moving-tree',
    }
    # Fresh retry labels/directories are preserved independently. Discover only
    # explicitly recorded direct-child outputs for this exact owned visual tool.
    for label, result in completed.items():
        if not any('WorldCoverMovingVisualProbe.tscn' in arg for arg in result.get('command', [])):
            continue
        for arg in result.get('command', []):
            if arg.startswith('--out='):
                directory = Path(arg.removeprefix('--out=')).resolve()
                if directory.parent == NATIVE.resolve() and directory.name.startswith('moving-'):
                    artifact_cases[directory.name] = label
    for folder, label in artifact_cases.items():
        if label not in completed:
            visual_status[folder] = {'state': 'pending_completed_run_record'}
            continue
        directory = NATIVE / folder
        result = completed[label]
        manifest_path = directory / ('result.json' if folder == 'player-reference' else 'visual-cover-info.json')
        manifest = json.loads(manifest_path.read_text()) if manifest_path.is_file() else {}
        outer_path = CONTROL / (label + '-thermal.json')
        outer = json.loads(outer_path.read_text()) if outer_path.is_file() else {}
        state = visual_case_state(result, manifest, manifest_path.is_file(),
                                  fixture=folder == 'player-reference', outer_reason=outer.get('reason'))
        entries = []
        for source in sorted(directory.rglob('*')):
            if source.is_file() and source.suffix in ['.png', '.json', '.md']:
                target = 'native/' + folder + '/' + str(source.relative_to(directory))
                entries.append(copy(source, target, 'original completed-run visual artifact; review state is separate', compress=source.suffix != '.png'))
        visual_status[folder] = {'run': label, 'state': state,
            'final_manifest_present': manifest_path.is_file(), 'artifacts': entries,
            'actual_exit': result.get('actual_exit'), 'diagnostics': result.get('diagnostics', []),
            'outer_stop_reason': outer.get('reason'),
            'tool_source_sha256': result.get('source_hashes', {}).get(VISUAL_TOOL_PATH)}
        if manifest_path.is_file() and folder != 'player-reference':
            visual_status[folder]['manifest_summary'] = {key: manifest.get(key) for key in
                ['phase', 'failures', 'save_writes', 'engine_max_fps', 'physics_ticks_per_second', 'moving_enemy_transitions']}
            visual_status[folder]['manifest_summary']['phase_summary'] = {key: manifest.get('phase_summary', {}).get(key) for key in
                ['simulation_seconds', 'wall_seconds', 'deadline_hit', 'projectile_covered', 'projectile_exposed', 'tell_covered', 'tell_exposed', 'producers_stayed_live']}
            if folder == 'moving-tree-r5':
                visual_status[folder]['interpretation'] = 'Actual five logical/fixture failures and body-space diagnostics; guard completed. Covered icons/projectiles/bodies succeeded, exposed equipment/health controls and exposed windup did not. No thermal excuse or visual acceptance.'
            if folder == 'moving-tree-r6':
                if (state != 'pending_visual_review' or outer.get('wrapper_exit') != 0
                        or outer.get('received_signal') is not None):
                    raise ValueError('R6 clean-transport review cannot bind an incomplete/unclean capture')
                review_path = CONTROL / 'cover-tree-r6-native-appearance-review.json'
                delivered_plates = {Path(entry).name: files[entry]['raw_sha256'] for entry in entries if entry.endswith('.png')}
                review = r6_appearance_review(review_path.read_bytes(), result, delivered_plates)
                review['record'] = copy(review_path, 'reviews/cover-tree-r6-native-appearance-review.json', 'exact source/image-bound review; locked-equipment readability remains open')
                visual_status[folder]['appearance_review'] = review
                visual_status[folder]['interpretation'] = 'R6 clean native transport and functional gates do not establish readable locked equipment. Exact review867f0101 keeps actual ring contrast OPEN; r5 failures remain separate.'
        if folder == 'moving-tree-r7':
            visual_status[folder]['ordinary_equipment_comparison'] = ordinary_equipment_gate(
                result, manifest, manifest_path.is_file(), (directory / 'tree-normal-equipment.png').is_file(), outer)
            visual_status[folder]['interpretation'] = 'Actual R7 failed its same-view comparison after live knockback moved player/camera. Same-owner ordinary fragments/readiness succeeded, but unmatched third/fourth images remain qualitative references. No thermal excuse or matched-view acceptance.'
        if folder == 'moving-tree-r8':
            comparison=ordinary_equipment_gate(result,manifest,manifest_path.is_file(),(directory/'tree-normal-equipment.png').is_file(),outer,R8_TOOL_SHA)
            if not comparison['passed'] or not r8_status.get('passed'): raise ValueError('R8 exact prerequisites/fixed-view ordinary comparison failed')
            detail=completed_details[label]
            manifest_hash=next(files[entry]['raw_sha256'] for entry in entries if files[entry]['source_path']==str(manifest_path))
            delivered_images={entry['source_path']:entry['raw_sha256'] for entry in files.values() if entry['path'].endswith('.png')}
            review_path=CONTROL/'cover-tree-r8-independent-visual-review.json';decision_path=CONTROL/'cover-tree-r8-root-decision.json'
            review=r8_appearance_review(review_path.read_bytes(),decision_path.read_bytes(),result,manifest,
                {'raw':detail['raw_sha256'],'guard':detail['guard_sha256'],'visual_manifest':manifest_hash},delivered_images)
            review['record']=copy(review_path,'reviews/cover-tree-r8-independent-visual-review.json','exact original/source-bound independent review; small-equipment discoverability OPEN')
            review['root_decision']=copy(decision_path,'reviews/cover-tree-r8-root-decision.json','exact root bounded-integration decision; readability remains OPEN')
            visual_status[folder].update(ordinary_equipment_comparison=comparison,prerequisites=r8_status,appearance_review=review,
                interpretation='Actual parser3/native33/moving capture clean at exact4ab/a399. Fixed camera-only comparison passes with same owners/world points/readiness; root approves bounded density improvement. Tiny ring discoverability remains OPEN; no all-item/background or performance claim.')
    import_samples = {}
    for source in sorted(NATIVE.glob('moving-*-imports-*.json')):
        # These finite explicit samples identify only their own recorded time.
        case = re.fullmatch(r'(moving-.+)-imports-(before|after)\.json', source.name)
        if case is None or 'city22-cover-' + case[1] not in completed:
            continue # Never harvest an active retry's before-sample as completion.
        sample = json.loads(source.read_text())
        copy(source, 'native/import-samples/' + source.name, 'original finite import/launcher sample; never retrofitted to older cost runs')
        import_samples[source.name] = {'started_utc': sample.get('started_utc'), 'ended_utc': sample.get('ended_utc'),
            'scope': sample.get('scope'), 'selected_seeds': sample.get('seeds', []),
            'binding_limit': 'Finite selected resources at this sample time, not full Game/import closure or loaded-resource telemetry.',
            'sampled_bytes': sample.get('sampled_bytes'), 'entry_count': len(sample.get('entries', [])),
            'sampled_generated_import_count': sum(e.get('status') == 'sampled' and e['path'].startswith('.godot/imported/') for e in sample.get('entries', [])),
            'launcher_records': [e for e in sample.get('entries', []) if e.get('reason') == 'explicit launcher sample']}
    output('native/visual-artifact-index.json', {'cases': visual_status, 'finite_import_samples': import_samples, 'r8_prerequisites':r8_status,
        'limits': 'Original images are unmodified. R6 readability remains OPEN; R7 failed matched view. R8 clean exact parser3/native33/moving controls support a bounded density improvement approved by root; small-equipment discoverability remains OPEN in actual reviewed originals. Material/source-alpha counts do not accept practical contrast.'})
    output('cost-summary.json', summaries)
    output('sources/source-bindings.json', {'schema': 1, 'runs': bindings,
           'limitation': 'Snapshots are included only when their exact bytes match a recorded launch hash; missing earlier drafts remain hash-only.'})
    versions = {}
    for expected, purpose in VISUAL_TOOL_VERSIONS.items():
        data, status = source_bytes(Path('/tmp/sa-wp2-cover'), VISUAL_TOOL_PATH, expected, None)
        version = {'purpose': purpose, 'byte_status': status,
            'matched_completed_runs': [name for name, record in completed.items()
                if record.get('source_hashes', {}).get(VISUAL_TOOL_PATH) == expected]}
        if data is not None:
            version['snapshot'] = put(data, 'sources/blobs/' + expected + '-WorldCoverMovingVisualProbe.gd',
                status, 'exact preserved visual-tool version; acceptance remains per actual completed run')
        versions[expected] = version
    output('sources/visual-tool-version-map.json', {'versions': versions,
        'limits': 'Byte availability is not native completion. Home acceptance belongs to b1f7 home-r3 only; r5 remains failed. R6 clean00f7 has readability OPEN; R7 camera comparison failed. ExactR8 parser3/native33/moving and bounded root approval do not close small-item discoverability. Original full route remains unaccepted.'})
    gate_status = {}
    for base in ['city22-cover-core', 'city22-cover-reuse', 'city22-cover-faces',
                 'city22-cover-enemy-native', 'city22-cover-pickup-native',
                 'city22-cover-cue-native', 'city22-cover-player-native']:
        successes = [r for r in index if re.fullmatch(re.escape(base) + r'(?:-(?:f|g)\d*)?', r['label'])
                     and r['classification'] == 'completed_zero_diagnostics']
        gate_status[base] = successes[-1]['run_folder'] if successes else 'pending_clean_completion'
        if successes:
            pending = [label for label in pending if label != base]
    output('evidence-index.json', {'schema': 1, 'runs': index, 'pending_cases': pending,
           'focused_gate_status': gate_status,
           'r8_prerequisite_status':r8_status,
           'moving_visual_artifacts': visual_status,
           'moving_visual_acceptance': 'Home-r3 bounded home scope accepted. Earlier tree failures remain failed: r3 interrupted, r5 logical/fixture, r7 camera mismatch. R6 clean capture retains readability-OPEN review867f. R8 exact4ab/a399 has clean parser3/native33/moving controls and reviewed four originals; root approves bounded density improvement under exact decision62a8/reviewd66d. Small-equipment discoverability remains OPEN. Original full route remains unaccepted.'})
    evidence = PACKET / 'EVIDENCE.md'
    text = evidence.read_text()
    marker = '\n## Completed-run refresh\n'
    text = text.split(marker)[0]
    if r8_status.get('passed'):
        text=re.sub(r'(?m)^\| Tree-r3 and source-only r4 correction \|.*$',
            '| Earlier tree attempts | r3 failed/interrupted; r5 fixture failure; r7 same-view failure | Historical originals remain failed/qualitative |\n'
            '| R6 actual tree capture | Clean functional transport; readability OPEN | Exact00f7/review867f |\n'
            '| R8 actual tree capture | Parser3/native33/moving clean; bounded density improvement approved | Tiny equipment discoverability OPEN; exact4ab/a399, reviewd66d/root62a8 |',text)
    table = '\n| Required gate | Latest clean completed run |\n| --- | --- |\n'
    table += '\n'.join('| ' + key + ' | ' + value + ' |' for key, value in gate_status.items()) + '\n'
    evidence.write_text(text + marker + '\nThis generated table uses completed run records only. Earlier preflight and failed attempts remain in the run index.\n' + table +
        '\nR6 clean transport retains readability-OPEN review867f. R7 failed matched camera/view and remains qualitative. R8 exact4ab/a399 clean parser3/native33/moving controls and four original plates support the root-approved bounded density improvement (decision62a8, reviewd66d). Small-equipment discoverability remains OPEN; source-opaque counts do not replace recognition at native zoom. Original full-route acceptance remains open.\n')
    (PACKET / 'compression-map.json').write_text(json.dumps({'schema': 1, 'threshold_bytes': THRESHOLD,
        'format': 'gzip level6, mtime0', 'scratch_originals_modified': False, 'entries': compression}, indent=2) + '\n')
    inventory = []
    for path in sorted(PACKET.rglob('*')):
        if path.is_file() and path.name != 'manifest.json':
            data = path.read_bytes()
            inventory.append({'path': str(path.relative_to(PACKET)), 'bytes': len(data), 'sha256': sha(data)})
    (PACKET / 'manifest.json').write_text(json.dumps({'schema': 1, 'files': inventory,
        'raw_record_map': list(files.values())}, indent=2) + '\n')
    print(json.dumps({'completed_run_records': len(index), 'pending': pending,
                      'delivered_files': len(inventory), 'bytes': sum(x['bytes'] for x in inventory)}))


if __name__ == '__main__':
    main()
