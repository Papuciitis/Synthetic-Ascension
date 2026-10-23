#!/usr/bin/env python3
"""Refresh a scratch-only completed-run evidence packet; never runs Godot.

Run with nice -n 19. Only final outer thermal files admit runs. Optional
--native LABEL=/absolute/output/path binds later exact images/records to a
completed run; the binding persists in native-inputs.json for future refreshes.
No active project, original evidence, Git state, or documentation is modified.
"""
from pathlib import Path
import argparse
import datetime
import gzip
import hashlib
import importlib.util
import json
import re
import subprocess

PACKET = Path(__file__).resolve().parent
KIND = json.loads((PACKET / 'packet-config.json').read_text())['kind']
ROOT = Path('/home/user/Nauris/Synthetic-Ascension')
CONTROL = ROOT / '.superpowers/continuation-20261022'
RUNS = ROOT / '.superpowers/claude-city-20261021/runs'
THRESHOLD = 128 * 1024
PROJECT = Path('/tmp/sa-wp2-' + KIND)
SCOPED = {
    'streets': [
        'core/systems/world/proc/SiteParcelsImpl.gd',
        'core/systems/world/proc/chunkgen/ChunkGenDistrict.gd',
        'scenes/world/buildings/CityBlockKit.gd',
        'scenes/world/buildings/RoofOverlay.gd',
        'scenes/world/volumes/IndoorVolume.gd',
        'tools/dev/CityStreetTraversalProbe.gd', 'tools/dev/CityStreetTraversalProbe.tscn',
        'tools/dev/CityBlockPlayablePreview.gd', 'tools/dev/EliteCrowdFightPreview.gd',
        'tools/tests/ProcChunkReachabilityTest.gd', 'core/systems/world/ChunkManager.gd',
        'core/systems/world/ground/GroundSplatRenderer.gd',
        'core/systems/world/ground/DistrictGroundPolicy.gd', 'project.godot',
        *[f'tools/tests/{name}.{suffix}' for name in [
            'CityGroundCareTest', 'CityDoorApproachGroundTest',
            'CityStreetGroundAllocationTest', 'CityStreetTraversalCorridorTest',
            'CityStreetTraversalDiscoveryTest', 'CityStreetFrontageTest',
            'CityStreetContinuityTest'] for suffix in ['gd', 'tscn']],
    ],
    'plazas': [
        'core/systems/world/ChunkManager.gd',
        'core/systems/world/chunks/PlazaEdgeKit.gd',
        'core/systems/world/proc/chunkgen/PlazaPresentation.gd',
        'scenes/world/plazas/PlazaDressing.gd',
        'tools/design/build_plaza_wear_kit.py', 'tools/design/build_plaza_kit.py',
        *[f'tools/tests/{name}.{suffix}' for name in [
            'ChunkBuildDataTest', 'ChunkBlockRendererTest', 'PlazaPresentationTest',
            'TransitionResourceWarmupTest', 'PlazaResourceResidencyTest',
            'ScriptParseAuditTest'] for suffix in ['gd', 'tscn']],
        'tools/dev/CitySegmentSurvey.gd', 'tools/dev/CitySegmentSurvey.tscn',
    ]}[KIND]
PREFIX = {'streets': 'city22-street-', 'plazas': 'city22-plaza-'}[KIND]
GATES = {
    'streets': {
        'discovery': ['discovery-green'], 'corridor-contract': ['corridor-green'],
        'door-apron-core': ['apron-green'], 'reward-ground-allocation': ['ground-green', 'allocation-green'],
        'household-care': ['care-green'], 'frontage': ['frontage'], 'continuity': ['continuity'],
        'scoped-parser': ['ground-parse'],
        'native-S2-physical-route': ['native-s2', 'traversal-s2'],
        'native-S7-physical-route': ['native-s7', 'traversal-s7'],
        'native-S6-physical-route': ['native-s6', 'traversal-s6'],
        'reward-paving-views': ['reward-after'],
    },
    'plazas': {
        'residency': ['residency-green-native'], 'transition-preparation': ['transition-green'],
        'chunk-build-data': ['build-data'], 'batch-renderer': ['renderer'],
        'presentation': ['presentation'], 'parse-audit': ['parse'],
        'native-S2': ['native-s2', 'survey-s2'], 'native-S6': ['native-s6', 'survey-s6'],
        'native-S7': ['native-s7', 'survey-s7'], 'native-S8': ['native-s8', 'survey-s8'],
    }}[KIND]
EXPECTED_REDS = {
    'city22-street-discovery-red': 1, 'city22-street-ground-red2': 2,
    'city22-street-corridor-red2': 3, 'city22-street-apron-red': 12,
    'city22-plaza-transition-red': 6,
}
MATRIX = Path('/var/tmp/sa-city22/streets/continuity-matrix/matrix.json')
AGGREGATE = MATRIX.with_name('aggregate.json')
MATRIX_DRIVER = CONTROL / 'street-continuity-matrix.py'
NATIVE_DRIVER = CONTROL / 'street-native-queue.py'
SITE_REL = 'core/systems/world/proc/SiteParcelsImpl.gd'
OLD_SITE_SHA = '689545138ea4ffd47eac1f1a74475be4372ebcaee75f453106741d155825afee'
CURRENT_SITE_SHA = 'fa31541044a4da8d11d6e3d57cea654bc0ea0cc0911de880f04ac3828b3e7503'
PROTOCOL_PINS = {
    'street-continuity-matrix.py': '45edca1f443763cb7ab7c155a47c85cc08e2b059c2551002b1746edff45a42a7',
    'CityStreetContinuityThemePart.gd': 'db2aa1113a8d1372c3032c3bd62d4a6c138d43743d89d333913b1bf28dd3973c',
    'CityStreetContinuityThemePart.tscn': 'ca96e9db3db4d234811d98964cac805759bbf3db065488fa1046df5637fc8557',
    'street-continuity-matrix-source/meta.json': '066c93a2142d69422ff430b73ea91206bd4ef2e26af499b7f40811055ab766c5',
    'street-native-source-parse.gd': '1f3db53fa1cf888464670c9dea0cdfcf2a7c875919483e83ef513e14d5f77eca',
    'street-native-source-parse.tscn': 'aecf19481458932f80a5da177f719db32782003b932e8b407eb521a21d79c126',
    'guarded_engine.py': '9f8219f0a9b4ee81e9b797c58f48aa347f16c53cf788dbe5969bf3e2767f7eba',
    'street-native-queue.py': '568b217ecc4eebe69a2b036fca6cb457457be8d364565b06d07c6104837ef591',
    'StreetNativeAcceptanceProbe.gd': '30958eb61ab45a45d24fcb3f591d9716563756a2341fe911f34ff07459baa6b8',
    'StreetNativeAcceptanceProbe.tscn': 'ee443c8fef526dab2247bbe7952e462775d14f460f2d4d1c84abc934f248a76d',
    'StreetRewardCameraProbe.gd': 'cdb18f3cb96c08a2d1934ffcbba855872debed0882fe971275e88f8c9f59d993',
    'StreetRewardCameraProbe.tscn': '0a0ddadfe880c090d9e36e59f4eaf37b0845dc891fe656ec0fc5849fa60d9bad',
}
MASTER_DRIVER_PIN = 'cceba211982c8ec7782cce2ff65f8512fbed55a467bd1fb5470656781a658d87'
ROUTES = {'s2': (2, 16102026, (0, 2)), 's7': (7, 16102028, (-4, 3)), 's6': (6, 16102028, (1, -1))}
files, compression, source_cache, blob_data = {}, [], {}, {}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def put(data, relative, origin, role, allow_compression=True):
    raw_path = str(relative)
    packed = allow_compression and len(data) > THRESHOLD and Path(raw_path).suffix != '.png'
    relative = raw_path + '.gz' if packed else raw_path
    destination = PACKET / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    payload = gzip.compress(data, compresslevel=6, mtime=0) if packed else data
    destination.write_bytes(payload)
    files[relative] = {'path': relative, 'role': role, 'source_path': str(origin),
                      'raw_sha256': sha(data), 'raw_bytes': len(data),
                      'delivered_sha256': sha(payload), 'delivered_bytes': len(payload)}
    if packed:
        compression.append({'original_path': raw_path, 'raw_sha256': sha(data),
                            'raw_bytes': len(data), 'gzip_path': relative,
                            'gzip_sha256': sha(payload), 'gzip_bytes': len(payload),
                            'round_trip_verified': gzip.decompress(payload) == data})
    return relative


def copy(path, relative, role):
    return put(path.read_bytes(), relative, path, role)


def output(relative, obj):
    return put((json.dumps(obj, indent=2, sort_keys=True) + '\n').encode(), relative,
               'derived from original recorded inputs; see references', 'derived index')


def snapshot(data, basename, origin, role):
    digest = sha(data)
    blob_data[digest] = data
    return put(data, 'sources/blobs/' + digest + '-' + basename, origin, role, False)


def matched_bytes(project, path, expected, head):
    if expected in blob_data:
        return blob_data[expected], 'preserved exact content'
    for p in (PACKET / 'sources/blobs').glob(expected + '-*'):
        data = p.read_bytes()
        if sha(data) == expected:
            blob_data[expected] = data
            return data, 'preserved packet snapshot exactly matches launch SHA256'
    key = (str(project), path, expected, head)
    if key in source_cache:
        return source_cache[key]
    candidate = project / path
    if candidate.is_file():
        data = candidate.read_bytes()
        if sha(data) == expected:
            source_cache[key] = (data, 'current scoped bytes exactly match launch SHA256')
            return source_cache[key]
    result = subprocess.run(['git', 'show', f'{head}:{path}'], cwd=project,
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    if result.returncode == 0 and sha(result.stdout) == expected:
        source_cache[key] = (result.stdout, 'historical Git bytes exactly match launch SHA256')
    else:
        source_cache[key] = (None, 'recorded hash only; exact dirty draft bytes unavailable')
    return source_cache[key]


def classify(label, record, stdout):
    if label == 'city22-plaza-residency-red':
        return 'incomplete_import_failure_and_owned_cleanup_not_clean_behavioral_red'
    if label == 'city22-street-care-measure':
        return 'measured_changed_histogram_requires_review_not_green'
    if label in EXPECTED_REDS:
        footer = any(re.search(r'(\d+ failed|failures=\d+)', line) for line in stdout.splitlines() if 'Test:' in line)
        bad_source = bool(re.search(r'(Parse Error:|Failed to load|Could not resolve|No loader found|Cannot open file)', stdout + json.dumps(record.get('diagnostics', []))))
        if record.get('actual_exit') == 1 and footer and not bad_source and len(record.get('diagnostics', [])) == EXPECTED_REDS[label]:
            return 'expected_targeted_behavioral_red'
        return 'unexpected_red_outcome_review_original_diagnostics'
    if record.get('actual_exit') == 0 and record.get('stop_reason') == 'completed' and not record.get('diagnostics'):
        if label.startswith('city22-street-continuity-part-'):
            return 'completed_theme_part_raw_zero_diagnostics_not_full_suite'
        return 'completed_zero_diagnostics'
    return 'failed_or_diagnostic_run'


def protocol_module(path, name):
    expected = PROTOCOL_PINS[path.name]
    if sha(path.read_bytes()) != expected:
        raise ValueError('Reviewed street protocol driver changed: ' + str(path))
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)  # Both drivers have guarded main entrypoints.
    return module


def continuity_evidence(matrix_path=MATRIX, aggregate_path=AGGREGATE, module=None):
    """Parts never grant the gate; only the driver's fresh fourteen-run rebuild can."""
    result = {'accepted': False, 'checked_part_indices': [], 'required_indices': list(range(14)),
              'original_global_assertions_required': 5, 'matrix_path': str(matrix_path),
              'aggregate_path': str(aggregate_path), 'parts': [], 'errors': [],
              'limits': 'Partial counts are local observations only. No full-suite count or original-five verdict is inferred from passing parts.'}
    try:
        module = module or protocol_module(MATRIX_DRIVER, 'street_packet_matrix')
        result['harness'] = module.verify_harness()
        if not matrix_path.is_file():
            result['errors'].append('matrix ledger not available')
            return result
        data = matrix_path.read_bytes()
        ledger = json.loads(data)
        result['matrix_sha256'] = sha(data)
        result['attempts'] = ledger.get('attempts', [])
        for key, part in sorted(ledger.get('parts', {}).items(), key=lambda item: int(item[0])):
            try:
                if not str(key).isdigit() or int(key) not in range(14) or part.get('theme_index') != int(key):
                    raise ValueError('invalid/duplicate theme index')
                checked = module.validate_part(part, result['harness'])
                result['parts'].append({k: v for k, v in checked.items() if k not in ('source_hashes', 'walls', 'infill_walls')})
                result['checked_part_indices'].append(int(key))
            except (ValueError, RuntimeError, KeyError, OSError, TypeError) as error:
                result['errors'].append('part ' + str(key) + ': ' + str(error))
        if result['checked_part_indices'] != list(range(14)) or result['errors']:
            result['errors'].append('all fourteen distinct clean source-bound parts are required')
            return result
        # This rechecks all14 raw runs, exact source/path sets, current bytes,
        # original thresholds and exactly five original aggregate assertions.
        if Path(json.loads(aggregate_path.read_text())['matrix_path']).resolve() != matrix_path.resolve():
            raise ValueError('aggregate is bound to a different matrix ledger')
        result['aggregate'] = module.validate_aggregate_file(aggregate_path)
        checked = result['aggregate']
        if checked.get('status') != 'passed' or checked.get('checked_themes') != 14 or checked.get('original_global_assertions') != 5:
            raise ValueError('aggregate validator returned an incomplete contract')
        if matrix_path.read_bytes() != data:
            raise ValueError('matrix ledger changed during packet validation')
        result['accepted'] = True
    except (ValueError, RuntimeError, KeyError, OSError, TypeError) as error:
        result['errors'].append(str(error))
    return result


def completed_guard(raw, outer):
    return (raw.get('ended_utc') and raw.get('actual_exit') == 0 and raw.get('runner_exit') == 0
            and raw.get('stop_reason') == 'completed' and raw.get('diagnostics') == []
            and outer.get('reason') == 'completed' and outer.get('wrapper_exit') == 0
            and outer.get('received_signal') is None)


def native_case_binding(case, report, native):
    """Re-read raw launch and actual manifests; never trust a saved valid flag."""
    kind, label = case['id'], case['label']
    if not re.fullmatch(r'city22-street-native-[a-z0-9-]+-' + re.escape(kind), label):
        raise ValueError('native suffix/case label differs')
    checked = native.run_record(label)
    raw_path = Path(checked['path'])
    raw = json.loads(raw_path.read_text())
    outer = json.loads(Path(checked['thermal_path']).read_text())
    if not completed_guard(raw, outer) or Path(raw['project_root']).resolve() != PROJECT:
        raise ValueError('native raw/guard/project not clean')
    if (outer.get('start_temperature_c') != 70 or outer.get('runtime_temperature_stop_c') != 90
            or outer.get('sustained_temperature_stop_c') != 85 or outer.get('sustained_temperature_samples') != 3):
        raise ValueError('native functional guard protocol differs')
    before = case.get('sources_before', {})
    expected_site = OLD_SITE_SHA if kind == 'reward-before' else CURRENT_SITE_SHA
    for relative in native.SOURCE_RELS:
        path = PROJECT / relative
        expected = expected_site if relative == SITE_REL else sha(path.read_bytes())
        if raw.get('source_hashes', {}).get(relative) != expected or before.get(str(path), {}).get('sha256') != expected:
            raise ValueError('native launch/source binding differs: ' + relative)
    for name, expected in PROTOCOL_PINS.items():
        if name.startswith(('street-continuity', 'CityStreetContinuity')):
            continue
        path = CONTROL / name
        if before.get(str(path), {}).get('sha256') != expected or sha(path.read_bytes()) != expected:
            raise ValueError('external native helper/queue changed: ' + name)
    for path in native.EXTERNAL:
        if before.get(str(path), {}).get('sha256') != sha(path.read_bytes()):
            raise ValueError('native guard/parser/external source changed: ' + str(path))
    fps = report.get('runtime_render_fps_cap')
    if fps not in (20, 30, 60) or case.get('wrapper_exit') != 0 or case.get('run') != {key: value for key, value in checked.items() if key != 'source_hashes'}:
        raise ValueError('native cap or recorded raw binding differs')
    command = raw['command']
    if kind == 'parse':
        if str(CONTROL / 'street-native-source-parse.tscn') not in command or '--headless' not in command:
            raise ValueError('native helper parser command differs')
        return {'label': label, 'raw': str(raw_path), 'raw_sha256': checked['sha256'], 'kind': kind}
    if outer.get('release_marker') != '[Game] ready' or outer.get('duty_released') is not True:
        raise ValueError('native setup duty was not released normally')
    directory = Path(case['out'])
    if '--out=' + str(directory) not in command or '--runtime-fps=' + str(fps) not in command:
        raise ValueError('native manifest/output command differs')
    if kind in ROUTES:
        segment, seed, coord = ROUTES[kind]
        scene = CONTROL / 'StreetNativeAcceptanceProbe.tscn'
        if str(scene) not in command or '--segment=' + str(segment) not in command or '--world-seed=' + str(seed) not in command or '--passage-chunk=' + ','.join(map(str, coord)) not in command:
            raise ValueError('native dressed route command differs')
        manifest = native.validate_route(directory, segment, seed, coord, fps)
    else:
        if kind not in ('reward-before', 'reward-after') or str(CONTROL / 'StreetRewardCameraProbe.tscn') not in command:
            raise ValueError('unknown native case/reward scene')
        manifest = native.validate_reward(directory, fps)
    if not manifest.get('valid') or manifest != case.get('manifest'):
        raise ValueError('native actual manifest no longer matches every strict check')
    if case.get('images') != native.image_records(directory):
        raise ValueError('native complete PNG inventory/bindings differ')
    for image in case.get('images', []):
        path = Path(image['path'])
        if path.stat().st_size != image['bytes'] or sha(path.read_bytes()) != image['sha256']:
            raise ValueError('native image changed: ' + str(path))
    if not case.get('images'):
        raise ValueError('native image bindings absent')
    return {'label': label, 'kind': kind, 'raw': str(raw_path), 'raw_sha256': checked['sha256'],
            'manifest': manifest, 'out': str(directory), 'site_source_sha256': expected_site,
            'runtime_render_fps_cap': fps, 'physics_ticks_per_second': 60}


def native_queue_prefix(path, report):
    if Path(report.get('output', '')).resolve() != path.parent.resolve() or not re.fullmatch(r'native-[a-z0-9-]+', path.parent.name):
        raise ValueError('native queue output suffix/path differs')
    return 'city22-street-' + path.parent.name + '-'


def street_native_evidence(continuity, reports=None, native=None, matrix=None, case_validator=native_case_binding):
    result = {'route_gates': {}, 'reward_pair_accepted': False, 'queues': [], 'errors': [],
              'limits': 'Exact native suffix labels, raw/project/external source hashes, actual physics/collection/director/save manifests and image hashes are required; visual review remains separate.'}
    try:
        native = native or protocol_module(NATIVE_DRIVER, 'street_packet_native')
        matrix = matrix or protocol_module(MATRIX_DRIVER, 'street_packet_native_matrix')
        reports = reports if reports is not None else sorted(Path('/var/tmp/sa-city22/streets').glob('native-*/queue.json'))
        for path in reports:
            item = {'path': str(path), 'accepted': False, 'cases': []}
            result['queues'].append(item)
            try:
                report_bytes = path.read_bytes()
                report = json.loads(report_bytes)
                item['sha256'] = sha(report_bytes)
                if not continuity['accepted'] or report.get('status') != 'checked' or report.get('restored_source_sha256') != CURRENT_SITE_SHA:
                    raise ValueError('queue awaits full continuity or clean completion/source restoration')
                expected_prefix = native_queue_prefix(path, report)
                if any(case.get('label') != expected_prefix + case.get('id', '') for case in report.get('cases', [])):
                    raise ValueError('case label does not belong to this exact output suffix')
                after = report.get('sources_after', {})
                expected_after = native.sources()
                if after != expected_after or report.get('sources_before') != expected_after:
                    raise ValueError('queue initial/restored project or external source maps changed')
                substitution = report.get('source_substitution', {})
                if substitution.get('before_sha256') != OLD_SITE_SHA or substitution.get('after_sha256') != CURRENT_SITE_SHA:
                    raise ValueError('reward source substitution protocol differs')
                prerequisite = report.get('prerequisites', {}).get('complete_dressed_continuity_matrix', {})
                current = matrix.validate_aggregate_file(Path(prerequisite['path']))
                if current != prerequisite or current.get('sha256') != continuity['aggregate']['sha256']:
                    raise ValueError('native did not use the current exact full matrix gate')
                cases = {case['id']: case_validator(case, report, native) for case in report.get('cases', [])}
                mode = report.get('mode')
                required = {'all': {'parse', 's2', 's7', 's6', 'reward-before', 'reward-after'},
                            'routes': {'parse', 's2', 's7', 's6'}, 'reward': {'parse', 'reward-before', 'reward-after'},
                            **{key: {'parse', key} for key in ROUTES}}.get(mode)
                if required is None or set(cases) != required or len(cases) != len(report.get('cases', [])):
                    raise ValueError('native queue case set/uniqueness differs')
                item['cases'] = list(cases.values())
                if {'reward-before', 'reward-after'} <= cases.keys():
                    a, b = [cases[key]['manifest']['reward_camera_binding'] for key in ('reward-before', 'reward-after')]
                    keys = ('building_id', 'chunk', 'entry_world', 'outward', 'width_px', 'world_footprint', 'entry_viewport_pixel', 'entry_visible', 'runtime_render_fps_cap', 'physics_ticks_per_second')
                    if any(a.get(key) != b.get(key) for key in keys):
                        raise ValueError('reward before/after camera/building/door geometry differs')
                    if [(tap['world'], tap['cell'], tap['walkable']) for tap in a['ground_taps']] != [(tap['world'], tap['cell'], tap['walkable']) for tap in b['ground_taps']]:
                        raise ValueError('reward before/after tap geometry/walkability differs')
                    before_raw, after_raw = [json.loads(Path(cases[key]['raw']).read_text())['source_hashes'] for key in ('reward-before', 'reward-after')]
                    if set(before_raw) != set(after_raw) or {key for key in before_raw if before_raw[key] != after_raw[key]} != {SITE_REL}:
                        raise ValueError('reward raw source maps differ outside the one apron implementation')
                    reward_pair = {'queue': str(path), 'before': cases['reward-before'], 'after': cases['reward-after'],
                        'shared_ground_protocol': 'Candidate shared-ground runtime remains identical in both; only old/current apron source differs. This pair does not isolate the separate shared-ground config correction.'}
                if path.read_bytes() != report_bytes:
                    raise ValueError('queue receipt changed during validation')
                if {'reward-before', 'reward-after'} <= cases.keys():
                    result['reward_pair_accepted'] = True
                    result['reward_pair'] = reward_pair
                for key in ROUTES.keys() & cases.keys():
                    result['route_gates'][key] = {'queue': str(path), 'case': cases[key]}
                item['accepted'] = True
            except (ValueError, RuntimeError, KeyError, OSError, TypeError) as error:
                item['error'] = str(error)
    except (ValueError, RuntimeError, KeyError, OSError, TypeError) as error:
        result['errors'].append(str(error))
    return result


def gate_results(index, continuity, native):
    result = {}
    reserved = {'continuity', 'native-S2-physical-route', 'native-S7-physical-route', 'native-S6-physical-route', 'reward-paving-views'} if KIND == 'streets' else set()
    for gate, suffixes in GATES.items():
        if gate in reserved:
            continue
        successes = [row for row in index if row['classification'] == 'completed_zero_diagnostics'
                     and any(row['label'] == PREFIX + suffix or row['label'].startswith(PREFIX + suffix + '-') for suffix in suffixes)]
        result[gate] = successes[-1]['run_folder'] if successes else 'pending_clean_completion'
    if KIND == 'streets':
        result['continuity'] = continuity['aggregate']['path'] if continuity['accepted'] else 'pending_complete_14_theme_matrix_and_original_5_assertions'
        for key in ROUTES:
            result['native-' + key.upper() + '-physical-route'] = native['route_gates'][key]['case']['label'] if key in native['route_gates'] else 'pending_source_bound_native_queue'
        result['reward-paving-views'] = native['reward_pair']['queue'] if native['reward_pair_accepted'] else 'pending_bound_old_current_apron_pair_same_shared_ground'
    return result


def include_street_protocol(continuity, native):
    paths = [CONTROL / name for name in PROTOCOL_PINS]
    paths += [CONTROL / 'street-matrix-remaining-r1.py', CONTROL / 'guarded_engine.py',
              CONTROL / 'street-native-source-parse.gd', CONTROL / 'street-native-source-parse.tscn',
              CONTROL / 'street-before-approach-SiteParcels.gd.data', MATRIX, AGGREGATE]
    if continuity.get('harness'):
        metadata = json.loads((CONTROL / 'street-continuity-matrix-source/meta.json').read_text())
        paths += [Path(metadata[key]) for key in ('original_snapshot', 'diff_path', 'original_path', 'parent_path')]
    for part in continuity.get('parts', []):
        paths.append(Path(part['data_path']))
    paths += [Path(item['path']) for item in native.get('queues', [])]
    for path in dict.fromkeys(paths):
        if path.is_file():
            snapshot(path.read_bytes(), path.name, path, 'street matrix/native protocol or exact selected part source; see strict validation index')
    master = CONTROL / 'street-matrix-remaining-r1.py'
    output('street-protocol-validation.json', {'continuity': continuity, 'native': native,
        'matrix_master_driver': {'path': str(master), 'reviewed_sha256': MASTER_DRIVER_PIN, 'current_sha256': sha(master.read_bytes()) if master.is_file() else None, 'role': 'Frozen serial remaining-parts scheduler; actual acceptance is independently rebuilt from all fourteen raw parts'},
        'full_continuity_gate': continuity['accepted'], 'original_global_assertions': 5 if continuity['accepted'] else 'not_evaluated_as_full_suite',
        'required_harness_pins': PROTOCOL_PINS, 'old_apron_sha256': OLD_SITE_SHA, 'current_apron_sha256': CURRENT_SITE_SHA})


def include_variants():
    if KIND == 'streets':
        p = CONTROL / 'street-before-approach-SiteParcels.gd.data'
        if p.is_file():
            snapshot(p.read_bytes(), 'SiteParcelsImpl.gd', p, 'preserved pre-apron-fix source; launch binding still requires exact hash equality')
    else:
        p = CONTROL / 'plaza-transition-red-mutation.json'
        if p.is_file():
            meta = json.loads(p.read_text())
            copy(p, 'variants/plaza-transition-red-mutation.json', 'original targeted mutation and restoration record')
            backup = Path(meta['backup'])
            data = backup.read_bytes()
            if sha(data) != meta['original_sha256']:
                raise ValueError('plaza original backup SHA256 mismatch')
            snapshot(data, 'ChunkManager.gd', backup, 'exact restored GREEN source backup')
            hook = (b'\tif Global.attempt_segment >= 2:\n'
                    b'\t\t_transition_resource_stage = &"plaza"\n'
                    b'\t\tvar theme := SegmentThemePicker.get_theme(Global.attempt_segment, Global.attempt_world_seed)\n'
                    b'\t\tawait _PLAZA_EDGE_KIT.prepare_state_for_transition(tree, _PLAZA_EDGE_KIT.state_for_family(theme.district_family))\n')
            red = data.replace(hook, b'', 1)
            if sha(red) == meta['red_sha256']:
                snapshot(red, 'ChunkManager.gd', 'exact backup minus documented four-line hook, verified against recorded RED SHA256',
                         'reconstructed bytes exactly match original RED launch/mutation SHA256')



def self_test():
    """Small protocol decisions only; no engine, Git, project writes or packet build."""
    import copy as copy_module
    import tempfile
    from types import SimpleNamespace

    checks = []
    def expect(condition, name):
        if not condition:
            raise AssertionError(name)
        checks.append(name)

    clean = {'ended_utc': 'done', 'actual_exit': 0, 'runner_exit': 0,
             'stop_reason': 'completed', 'diagnostics': []}
    outer = {'reason': 'completed', 'wrapper_exit': 0, 'received_signal': None}
    expect(completed_guard(clean, outer), 'clean owned raw and guard accepted')
    expect(not completed_guard(clean, {**outer, 'reason': 'thermal_limit'}), 'thermal guard rejected despite zero raw exit')
    expect(not completed_guard({**clean, 'runner_exit': 1}, outer), 'runner failure rejected')
    expect(classify('city22-street-continuity-part-00-v1', clean, '') != 'completed_zero_diagnostics', 'clean part is not a full suite class')
    expect(classify('city22-street-continuity-dressed-r2', {**clean, 'actual_exit': -15, 'stop_reason': 'signal'}, '') == 'failed_or_diagnostic_run', 'failed full dressed attempt retained as failure')

    with tempfile.TemporaryDirectory(prefix='street-packet-tiny-') as temporary:
        root = Path(temporary)
        ledger_path, aggregate_path = root / 'matrix.json', root / 'aggregate.json'
        aggregate_path.write_text(json.dumps({'matrix_path': str(ledger_path)}))
        calls = []
        def validate_part(part, _harness):
            if part.get('bad'):
                raise RuntimeError('raw part failed')
            return {'theme_index': part['theme_index'], 'data_path': 'tiny-data.json'}
        def validate_aggregate(path):
            calls.append(str(path))
            return {'status': 'passed', 'checked_themes': 14, 'original_global_assertions': 5,
                    'path': str(path), 'sha256': 'tiny-sha'}
        module = SimpleNamespace(verify_harness=lambda: {'tiny': True}, validate_part=validate_part,
                                 validate_aggregate_file=validate_aggregate)
        def ledger(count=14, bad=None):
            ledger_path.write_text(json.dumps({'parts': {str(index): {'theme_index': index, 'bad': index == bad} for index in range(count)}}))
        ledger(5)
        partial = continuity_evidence(ledger_path, aggregate_path, module)
        expect(not partial['accepted'] and partial['checked_part_indices'] == list(range(5)) and not calls, 'five partials cannot call or satisfy full aggregate')
        ledger()
        full = continuity_evidence(ledger_path, aggregate_path, module)
        expect(full['accepted'] and len(calls) == 1, 'all fourteen require original aggregate validator')
        ledger(bad=8)
        expect(not continuity_evidence(ledger_path, aggregate_path, module)['accepted'] and len(calls) == 1, 'one failing raw part prevents aggregate')
        ledger()
        def stale(_path):
            raise RuntimeError('stale full aggregate')
        module.validate_aggregate_file = stale
        expect(not continuity_evidence(ledger_path, aggregate_path, module)['accepted'], 'stale aggregate never grants gate')
        module.validate_aggregate_file = lambda path: {**validate_aggregate(path), 'original_global_assertions': 4}
        expect(not continuity_evidence(ledger_path, aggregate_path, module)['accepted'], 'four assertions cannot substitute for original five')
        def moved(path):
            answer = validate_aggregate(path)
            ledger_path.write_text(ledger_path.read_text() + ' ')
            return answer
        module.validate_aggregate_file = moved
        expect(not continuity_evidence(ledger_path, aggregate_path, module)['accepted'], 'ledger mutation during validation rejected')
        module.validate_aggregate_file = validate_aggregate
        aggregate_path.write_text(json.dumps({'matrix_path': str(root / 'different.json')}))
        expect(not continuity_evidence(ledger_path, aggregate_path, module)['accepted'], 'another aggregate ledger cannot grant this matrix gate')

        no_native = {'route_gates': {}, 'reward_pair_accepted': False}
        fabricated = [{'classification': 'completed_zero_diagnostics', 'label': 'city22-street-continuity-part-00-v1', 'run_folder': 'part-1'},
                      {'classification': 'completed_zero_diagnostics', 'label': 'city22-street-native-any-s2', 'run_folder': 's2-1'}]
        gates = gate_results(fabricated, partial, no_native)
        expect(gates['continuity'].startswith('pending_') and gates['native-S2-physical-route'].startswith('pending_'), 'generic substrings cannot grant full or native gates')
        expect(gate_results([], full, no_native)['continuity'] == str(aggregate_path), 'validated aggregate path alone grants continuity gate')

        directory = root / 'native-test-r1'
        directory.mkdir()
        report_path = directory / 'queue.json'
        prerequisite = {'path': str(aggregate_path), 'sha256': 'tiny-sha'}
        report = {'status': 'checked', 'output': str(directory), 'mode': 'all',
                  'restored_source_sha256': CURRENT_SITE_SHA, 'sources_before': {}, 'sources_after': {},
                  'source_substitution': {'before_sha256': OLD_SITE_SHA, 'after_sha256': CURRENT_SITE_SHA},
                  'prerequisites': {'complete_dressed_continuity_matrix': prerequisite}, 'cases': []}
        camera = {'building_id': 1, 'chunk': '(0,9)', 'entry_world': '(1,2)', 'outward': '(0,1)',
                  'width_px': 2, 'world_footprint': [], 'ground_taps': [{'world': '(1,2)', 'cell': '(1,2)', 'walkable': True}]}
        for key in ('parse', 's2', 's7', 's6', 'reward-before', 'reward-after'):
            raw_path = directory / (key + '.json')
            raw_path.write_text(json.dumps({'source_hashes': {SITE_REL: OLD_SITE_SHA if key == 'reward-before' else CURRENT_SITE_SHA, 'control': 'identical'}}))
            report['cases'].append({'id': key, 'label': 'city22-street-native-test-r1-' + key,
                                    'raw': str(raw_path), 'manifest': {'reward_camera_binding': copy_module.deepcopy(camera)}})
        fake_native = SimpleNamespace(sources=lambda: {})
        fake_matrix = SimpleNamespace(validate_aggregate_file=lambda path: prerequisite)
        fake_case = lambda case, _report, _native: case
        full_native = {'accepted': True, 'aggregate': {'sha256': 'tiny-sha'}}
        def run_native():
            report_path.write_text(json.dumps(report))
            return street_native_evidence(full_native, [report_path], fake_native, fake_matrix, fake_case)
        accepted = run_native()
        expect(set(accepted['route_gates']) == set(ROUTES) and accepted['reward_pair_accepted'], 'matching suffix pair and routes accepted through their independent receipts')
        report['cases'][-1]['manifest']['reward_camera_binding']['width_px'] = 3
        rejected = run_native()
        expect(not rejected['route_gates'] and not rejected['reward_pair_accepted'], 'failed reward geometry cannot leak route gate acceptance from all-mode queue')
        report['cases'][-1]['manifest']['reward_camera_binding']['width_px'] = 2
        report['cases'][1]['label'] = 'city22-street-native-another-suffix-s2'
        expect(not run_native()['route_gates'], 'another native suffix cannot reuse this queue')
        report['cases'][1]['label'] = 'city22-street-native-test-r1-s2'
        after_path = Path(report['cases'][-1]['raw'])
        altered = json.loads(after_path.read_text())
        altered['source_hashes']['control'] = 'changed'
        after_path.write_text(json.dumps(altered))
        expect(not run_native()['reward_pair_accepted'], 'before-after source difference beyond apron rejected')
        report['sources_after'] = {'changed': {}}
        expect(not run_native()['route_gates'], 'restored source receipt mismatch rejected')
    print(json.dumps({'self_test': 'passed', 'checks': len(checks), 'cases': checks,
                      'scope': 'tiny temporary JSON/byte fixtures only; physical validators mocked only for aggregation tests; no engine/Git/project/packet rebuild'}))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--native', action='append', default=[], metavar='LABEL=/absolute/output')
    parser.add_argument('--self-test', action='store_true', help='Only tiny temporary-byte acceptance fixtures; never rebuilds a packet.')
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    (PACKET / '.gdignore').touch(exist_ok=True)
    include_variants()
    native_cfg_path = PACKET / 'native-inputs.json'
    native_cfg = json.loads(native_cfg_path.read_text()) if native_cfg_path.is_file() else {}
    for assignment in args.native:
        label, path = assignment.split('=', 1)
        if not label.startswith(PREFIX) or not Path(path).is_absolute():
            raise ValueError('native binding requires this stage label and an absolute path')
        native_cfg[label] = path
    native_cfg_path.write_text(json.dumps(native_cfg, indent=2, sort_keys=True) + '\n')
    labels = sorted({p.name.removesuffix('-thermal.json') for p in CONTROL.glob(PREFIX + '*-thermal.json')})
    index, bindings, completed, pending = [], [], {}, []
    for label in labels:
        thermal = CONTROL / (label + '-thermal.json')
        outer = json.loads(thermal.read_text())
        matching = [p for p in RUNS.glob(label + '-*') if re.fullmatch(re.escape(label) + r'-\d+', p.name)]
        finished = []
        for folder in sorted(matching):
            p = folder / 'run-results.json'
            if p.is_file():
                record = json.loads(p.read_text())
                if record.get('ended_utc') and record.get('actual_exit') is not None:
                    finished.append((p, record))
        if not finished:
            if outer.get('owned_pids'):
                pending.append({'label': label, 'reason': 'outer record exists but no final engine result; review ownership'})
                continue
            row = {'label': label, 'classification': 'preflight_without_owned_godot_no_behavioral_result',
                   'godot_started': False, 'owned_pids': outer.get('owned_pids'),
                   'thermal': copy(thermal, 'runs/' + label + '/thermal.json', 'original completed preflight record')}
            wrapper = CONTROL / (label + '-wrapper.log')
            if wrapper.is_file():
                row['wrapper'] = copy(wrapper, 'runs/' + label + '/wrapper.log', 'original wrapper record')
            index.append(row)
            continue
        for path, record in finished:
            folder = path.parent
            dest = 'runs/' + folder.name + '/'
            stdout_path = folder / 'logs/stdout.log'
            stdout = stdout_path.read_text(errors='replace') if stdout_path.is_file() else ''
            row = {'label': label, 'run_folder': folder.name, 'classification': classify(label, record, stdout),
                   'actual_exit': record['actual_exit'], 'stop_reason': record.get('stop_reason'),
                   'diagnostic_count': len(record.get('diagnostics', [])), 'git_head': record.get('git_head'),
                   'started_utc': record.get('started_utc'), 'ended_utc': record.get('ended_utc'),
                   'command': record['command'], 'command_shell': record.get('command_shell'),
                   'source_hash_count': len(record.get('source_hashes', {})),
                   'assertion_footer_lines': [line for line in stdout.splitlines()
                       if re.search(r'(Test:|SourceParseProbe:|fixture.*histogram)', line, re.I)],
                   'run_results': copy(path, dest + 'run-results.json', 'original launch/source/resource/diagnostic record'),
                   'thermal': copy(thermal, dest + 'thermal.json', 'original final outer thermal record'),
                   'peak_package_c': max((s.get('package_c') or 0 for s in outer.get('samples', [])), default=None),
                   'start_gate_environment': outer.get('environment_overrides', {}).get('SA_ENGINE_THERMAL_LIMIT_C'),
                   'first_wrapper_sample_c': outer.get('samples', [{}])[0].get('package_c'),
                   'actual_engine_start_temperature_c': None,
                   'temperature_scope': 'First wrapper sample may precede engine launch; not actual Godot-start temperature.'}
            row['outer_guard_reason'] = outer.get('reason')
            row['outer_wrapper_exit'] = outer.get('wrapper_exit')
            row['outer_owned_pids'] = outer.get('owned_pids')
            if row['classification'] in ('completed_zero_diagnostics', 'completed_theme_part_raw_zero_diagnostics_not_full_suite') and not completed_guard(record, outer):
                row['classification'] = 'unclean_outer_guard_no_acceptance'
            for name in ['stdout.log', 'stderr.log', 'engine.log']:
                p = folder / 'logs' / name
                if p.is_file():
                    copy(p, dest + 'logs/' + name, 'original engine log')
            wrapper = CONTROL / (label + '-wrapper.log')
            if wrapper.is_file():
                copy(wrapper, dest + 'wrapper.log', 'original wrapper summary')
            index.append(row)
            completed[label] = (row, record)
            hashes = record.get('source_hashes', {})
            scoped = {}
            for source in SCOPED:
                expected = hashes.get(source)
                if expected is None:
                    continue
                data, status = matched_bytes(Path(record['project_root']), source, expected, record['git_head'])
                detail = {'launch_sha256': expected, 'status': status}
                if data is not None:
                    detail['snapshot'] = snapshot(data, Path(source).name, Path(record['project_root']) / source,
                                                  'scoped bytes exactly matching original launch SHA256')
                scoped[source] = detail
            asset_imports = {p: h for p, h in hashes.items() if p.startswith('assets/') or p.startswith('.godot/imported/')}
            raw_map = (json.dumps(asset_imports, indent=2, sort_keys=True) + '\n').encode()
            asset_map_path = put(raw_map, 'sources/recorded-maps/' + sha(raw_map) + '.json',
                                 str(path) + '#source_hashes', 'recorded project launch asset/import inventory; not loaded-resource telemetry')
            bind = {'run': folder.name, 'git_head': record['git_head'],
                    'tracked_git_status': record.get('git_status_porcelain'),
                    'source_untracked': record.get('source_untracked'), 'scoped': scoped,
                    'recorded_asset_import_inventory': asset_map_path,
                    'recorded_generated_import_count': sum(p.startswith('.godot/imported/') for p in hashes),
                    'closure_limit': 'No complete historical Game or generated cache byte closure is supplied. Dynamic resources and absent launch cache hashes stay missing.'}
            binding_path = output('sources/run-bindings/' + folder.name + '.json', bind)
            bindings.append({'run': folder.name, 'binding': binding_path,
                             'unavailable_scoped_sources': [p for p, d in scoped.items() if 'snapshot' not in d]})
            # Auto-discover explicit output path only after this run is final.
            for part in record['command']:
                if part.startswith('--out=') and Path(part[6:]).is_absolute() and (KIND != 'streets' or label.startswith('city22-street-native-')):
                    native_cfg.setdefault(label, part[6:])
    native_index = []
    for label, source_text in sorted(native_cfg.items()):
        if KIND == 'streets' and label.startswith('city22-street-continuity-part-'):
            continue  # A theme part's --out is a JSON observation, not a native directory.
        if label not in completed:
            pending.append({'label': label, 'reason': 'native binding awaits completed outer+run records'})
            continue
        source = Path(source_text)
        if not source.is_dir():
            native_index.append({'label': label, 'source': source_text, 'status': 'output directory missing'})
            continue
        delivered = []
        for path in sorted(source.rglob('*')):
            if path.is_file() and path.suffix in ['.png', '.json', '.log', '.txt', '.md', '.csv', '.gz']:
                delivered.append(copy(path, 'native/' + label + '/' + str(path.relative_to(source)),
                                      'original completed native output; PNG bytes unchanged'))
        native_index.append({'label': label, 'run_folder': completed[label][0]['run_folder'],
                             'source': source_text, 'files': delivered, 'visual_review': 'pending explicit root review; capture success alone is not acceptance'})
    native_cfg_path.write_text(json.dumps(native_cfg, indent=2, sort_keys=True) + '\n')
    continuity = continuity_evidence() if KIND == 'streets' else {}
    native = street_native_evidence(continuity) if KIND == 'streets' else {}
    gate_status = gate_results(index, continuity, native)
    if KIND == 'streets':
        include_street_protocol(continuity, native)
    for name in ['guarded_engine-final.py', 'source_parse_probe.gd', 'source_parse_probe.tscn',
                 'street-ground-checks-queue.json' if KIND == 'streets' else 'plaza-focused-queue.json']:
        p = CONTROL / name
        if p.is_file():
            copy(p, 'harness/' + name, 'packaging-time harness/queue copy; historical launch bytes not established by this later copy')
    output('sources/source-bindings.json', {'schema': 1, 'runs': bindings,
           'limitation': 'Only exact SHA256-equal scoped snapshots bind to launch records. Earlier dirty draft bodies can remain unavailable.'})
    output('evidence-index.json', {'schema': 1, 'kind': KIND, 'runs': index,
           'focused_gate_status': gate_status, 'pending_cases': pending, 'native_outputs': native_index,
           **({'street_protocol': 'street-protocol-validation.json',
               'full_continuity_gate': continuity['accepted'],
               'checked_continuity_part_indices': continuity['checked_part_indices'],
               'original_global_assertions': 5 if continuity['accepted'] else 'not_evaluated_as_full_suite'} if KIND == 'streets' else {}),
           'visual_acceptance': 'Pending explicit image/route review. A clean native scene exit alone supplies no acceptance decision.',
           'performance_claim': 'Functional tests/captures under external duty limiting establish no comparative FPS/GPU/whole-Game budget claim.'})
    evidence = PACKET / 'EVIDENCE.md'
    text = evidence.read_text().split('\n## Completed-run refresh\n')[0]
    table = '\n| Gate | Latest clean completed run |\n| --- | --- |\n'
    table += '\n'.join('| ' + gate + ' | ' + value + ' |' for gate, value in gate_status.items()) + '\n'
    qualifier = (' Full continuity requires all fourteen exact-source raw theme runs and the frozen validator rebuilding the original five aggregate assertions; clean parts grant no full-suite gate or aggregate count. Native route and old/current apron reward gates require separate exact queue/manifest/image bindings; both reward sides retain the candidate shared-ground runtime.' if KIND == 'streets' else '')
    evidence.write_text(text + '\n## Completed-run refresh\n\nGenerated from final outer thermal and launch records only. Unsuccessful attempts, including thermal stops, remain in the machine index. Native rows require separate root review.' + qualifier + '\n' + table)
    (PACKET / 'compression-map.json').write_text(json.dumps({'schema': 1, 'threshold_bytes': THRESHOLD,
        'format': 'gzip level6 mtime0; native PNGs unchanged', 'scratch_originals_modified': False,
        'entries': list({e['gzip_path']: e for e in compression}.values())}, indent=2) + '\n')
    inventory = []
    for path in sorted(PACKET.rglob('*')):
        if path.is_file() and path.name != 'manifest.json':
            data = path.read_bytes()
            inventory.append({'path': str(path.relative_to(PACKET)), 'bytes': len(data), 'sha256': sha(data)})
    (PACKET / 'manifest.json').write_text(json.dumps({'schema': 1,
        'generated_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'files': inventory, 'raw_record_map': list(files.values())}, indent=2) + '\n')
    print(json.dumps({'kind': KIND, 'run_records': len(index), 'gate_status': gate_status,
                      'delivered_files': len(inventory), 'bytes': sum(p['bytes'] for p in inventory)}))


if __name__ == '__main__':
    main()
