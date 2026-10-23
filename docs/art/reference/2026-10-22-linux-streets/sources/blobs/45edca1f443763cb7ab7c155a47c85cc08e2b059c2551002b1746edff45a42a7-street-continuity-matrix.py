#!/usr/bin/env python3
"""Run one dressed theme, resume a matrix, or strictly aggregate all14 parts.

No engine starts without --execute and a single --theme-index. The original
suite/runtime remain untouched. Aggregation rechecks every raw run and the
exact original five final assertions; partial matrices never satisfy the gate.
"""
from __future__ import annotations

import argparse
import ast
from collections import Counter
from datetime import datetime, timezone
import difflib
import fcntl
import hashlib
import json
from pathlib import Path
import re
import signal
import subprocess
import sys
import time

ROOT = Path('/home/user/Nauris/Synthetic-Ascension')
BASE = ROOT / '.superpowers/continuation-20261022'
PROJECT = Path('/tmp/sa-wp2-streets')
RUNS = ROOT / '.superpowers/claude-city-20261021/runs'
META = BASE / 'street-continuity-matrix-source/meta.json'
ORIGINAL_REL = 'tools/tests/CityStreetContinuityTest.gd'
PARENT_REL = 'tools/tests/ProcChunkReachabilityTest.gd'
COPY = BASE / 'CityStreetContinuityThemePart.gd'
SCENE = BASE / 'CityStreetContinuityThemePart.tscn'
ORIGINAL_SHA = '4e696d66596cb63514281254db820b3ea5ec7322796995027d10f1e9b3be8209'
PARENT_SHA = 'ddb5960e600bb6afc184d8e0df306fdb1b89026601f943aac8e5fdcf6d491258'
COPY_SHA = 'db2aa1113a8d1372c3032c3bd62d4a6c138d43743d89d333913b1bf28dd3973c'
SCENE_SHA = 'ca96e9db3db4d234811d98964cac805759bbf3db065488fa1046df5637fc8557'
DEFAULT_MATRIX = Path('/var/tmp/sa-city22/streets/continuity-matrix/matrix.json')
EMPTY_THEME_IDS = {0: 'service_courtyards', 1: 'checkpoint_lanes', 4: 'inner_district_gate', 13: 'gate_district'}
CANCELLED = False


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def digest(value: object) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def read(path: Path) -> dict:
    return json.loads(path.read_text())


def write(path: Path, value: dict) -> None:
    temporary = path.with_name(path.name + '.pending')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.replace(path)


def original_manifest() -> dict:
    source = (PROJECT / ORIGINAL_REL).read_text()
    themes = ast.literal_eval(re.search(r'(?s)const THEMES := (\[\[.*?\]\])\n', source).group(1))
    roles = ast.literal_eval(re.search(r'(?s)const ROLES := (\[.*?\])\n', source).group(1).replace('&"', '"'))
    constants = {name: int(re.search(r'(?m)^const ' + name + r' := (\d+)$', source).group(1)) for name in ('PER_ROLE', 'BASE_SEED', 'WALL_LIMIT', 'WALL_NEVER', 'DOOR_APRON')}
    return {'themes': themes, 'roles': roles, **constants}


def verify_harness() -> dict:
    metadata = read(META)
    bindings = {
        PROJECT / ORIGINAL_REL: ORIGINAL_SHA, PROJECT / PARENT_REL: PARENT_SHA,
        COPY: COPY_SHA, SCENE: SCENE_SHA,
        Path(metadata['original_snapshot']): ORIGINAL_SHA,
        Path(metadata['diff_path']): metadata['diff_sha256'],
    }
    for path, expected in bindings.items():
        if not path.is_file() or sha(path) != expected:
            raise RuntimeError('Original/helper/snapshot bytes changed: ' + str(path))
    original = Path(metadata['original_snapshot']).read_text()
    copied = COPY.read_text()
    actual_diff = ''.join(difflib.unified_diff(original.splitlines(keepends=True), copied.splitlines(keepends=True), fromfile='original/CityStreetContinuityTest.gd', tofile='external/CityStreetContinuityThemePart.gd'))
    if actual_diff != Path(metadata['diff_path']).read_text():
        raise RuntimeError('Explicit copy diff no longer matches bound sources')
    # All original methods except the dispatch/output method stay exact. The
    # one append in _check_plan only observes a completed original plan visit.
    def functions(text: str) -> dict:
        positions = list(re.finditer(r'(?m)^func (\w+)\(', text))
        return {match.group(1): text[match.start():positions[index+1].start() if index+1 < len(positions) else len(text)] for index, match in enumerate(positions)}
    before, after = functions(original), functions(copied)
    if before.keys() != after.keys():
        raise RuntimeError('The external copy added/removed original methods')
    observation = '\t\t\t_matrix_plan_visits.append({"coord": [coord.x, coord.y], "enabled": enabled})\n'
    for name in before:
        if name != '_run' and before[name] != after[name].replace(observation, ''):
            raise RuntimeError('Original per-chunk/plan helper changed: ' + name)
    manifest = original_manifest()
    if len(manifest['themes']) != 14 or metadata['deferred_assertions_count'] != 5:
        raise RuntimeError('Original theme set/global assertion contract changed')
    return {'metadata_path': str(META), 'metadata_sha256': sha(META), 'original_sha256': ORIGINAL_SHA, 'parent_sha256': PARENT_SHA, 'copy_sha256': COPY_SHA, 'scene_sha256': SCENE_SHA, 'diff_sha256': metadata['diff_sha256'], 'driver_sha256': sha(Path(__file__).resolve()), 'manifest': manifest}


def clean_run(label: str) -> tuple[dict, dict, Path, Path]:
    paths = sorted(RUNS.glob(label + '-*/run-results.json'))
    if len(paths) != 1:
        raise RuntimeError(label + ': missing/ambiguous actual run result')
    path = paths[0]
    data = read(path)
    thermal_path = BASE / (label + '-thermal.json')
    thermal = read(thermal_path)
    if data.get('actual_exit') != 0 or data.get('runner_exit') != 0 or data.get('stop_reason') != 'completed' or not data.get('ended_utc') or data.get('diagnostics') or not data.get('source_hashes'):
        raise RuntimeError(label + ': incomplete/failing run, not a checked part')
    if thermal.get('wrapper_exit') != 0 or thermal.get('reason') != 'completed' or thermal.get('duty_released') is not False or thermal.get('release_marker') is not None:
        raise RuntimeError(label + ': incomplete/released guard, inspect raw record')
    if thermal.get('start_temperature_c') not in (65, 70) or thermal.get('runtime_temperature_stop_c') != 90 or thermal.get('sustained_temperature_stop_c') != 85 or thermal.get('sustained_temperature_samples') != 3 or not 0 < thermal.get('duty_cycle', 0) <= 0.25:
        raise RuntimeError(label + ': functional guard protocol differs from retained limits')
    return data, thermal, path, thermal_path


def sample_key(item: dict) -> dict:
    return {key: item[key] for key in ('segment', 'theme', 'plan_seed', 'coord', 'role')}


def validate_part(part: dict, harness: dict) -> dict:
    index = part['theme_index']
    data_path = Path(part['data_path'])
    data = read(data_path)
    run, thermal, run_path, thermal_path = clean_run(part['label'])
    manifest = harness['manifest']
    expected_entry = manifest['themes'][index]
    actual_theme = data.get('theme', {})
    counts = data.get('counts', {})
    plan_paths = data.get('expected_plan_paths', [])
    coords = [tuple(item['coord']) for item in plan_paths]
    wanted_samples = []
    for role in manifest['roles']:
        for item in sorted((item for item in plan_paths if item['role'] == role), key=lambda item: item['coord'])[:manifest['PER_ROLE']]:
            wanted_samples.append({'segment': expected_entry[0], 'theme': actual_theme.get('id'), 'plan_seed': actual_theme.get('plan_seed'), 'coord': item['coord'], 'role': role})
    visits = [{'coord': list(coord), 'enabled': enabled} for enabled in (False, True) for coord in coords]
    steps = counts.get('steps', {})
    checks = {
        'index_and_original_theme_set': data.get('theme_index') == index and data.get('theme_entry') == expected_entry and data.get('themes') == manifest['themes'] and data.get('roles') == manifest['roles'] and data.get('base_seed') == manifest['BASE_SEED'] and data.get('per_role') == manifest['PER_ROLE'],
        'selected_actual_theme': actual_theme.get('segment') == expected_entry[0] and actual_theme.get('id') == (expected_entry[1] or EMPTY_THEME_IDS[index]) and manifest['BASE_SEED'] <= actual_theme.get('seed', -1) < manifest['BASE_SEED'] + 400,
        'dressed_no_local_failure': data.get('deco') is True and data.get('failures') == [],
        'original_parent_copy_binding': data.get('original_suite_sha256') == ORIGINAL_SHA and data.get('parent_suite_sha256') == PARENT_SHA and data.get('external_copy_sha256') == COPY_SHA and data.get('deferred_global_assertions') == 5,
        'same_strict_constants': data.get('wall_limit') == manifest['WALL_LIMIT'] and data.get('wall_never') == manifest['WALL_NEVER'] and data.get('door_apron') == manifest['DOOR_APRON'],
        'nonempty_exact_plan_set': bool(coords) and len(coords) == len(set(coords)) and coords == sorted(coords),
        'every_plan_chunk_off_and_on': data.get('actual_plan_visits') == visits and counts.get('plan_chunks') == len(visits),
        'every_original_role_sample': bool(wanted_samples) and data.get('expected_sample_paths') == wanted_samples and [sample_key(item) for item in data.get('samples', [])] == wanted_samples and counts.get('sample_chunks') == len(wanted_samples),
        'counter_shapes': all(isinstance(counts.get(name), int) and counts[name] >= 0 for name in ('sample_chunks', 'originals', 'infill', 'checks_local', 'preexisting_unreachable', 'plan_chunks', 'plan_doors', 'cross_seam_aprons', 'court_doors', 'framed', 'framed_open_sides')) and counts.get('checks_local', 0) > 0 and set(steps) == {'-1', '0', '1'} and all(isinstance(value, int) and value >= 0 for value in steps.values()) and 0 <= counts.get('framed_open_sides', -1) <= counts.get('framed', -1),
        'strict_wall_observations': all(value < manifest['WALL_NEVER'] for value in data.get('walls', [])) and all(value <= manifest['WALL_LIMIT'] for value in data.get('infill_walls', [])),
        'raw_source_original_binding': run.get('source_hashes', {}).get(ORIGINAL_REL) == ORIGINAL_SHA and run.get('source_hashes', {}).get(PARENT_REL) == PARENT_SHA,
        'actual_guarded_arguments': '--deco=1' in run.get('command', []) and '--theme-index=' + str(index) in run.get('command', []) and '--out=' + str(data_path) in run.get('command', []) and str(SCENE) in run.get('command', []),
    }
    if not all(checks.values()):
        raise RuntimeError(f'Theme {index}: part validation failed: {[name for name, good in checks.items() if not good]}')
    if part.get('data_sha256') and part['data_sha256'] != sha(data_path):
        raise RuntimeError('Part JSON changed after it was selected in the matrix')
    if part.get('run_sha256') and part['run_sha256'] != sha(run_path):
        raise RuntimeError('Raw engine result changed after it was selected in the matrix')
    external = part.get('external_bindings', {})
    if external.get(str(COPY)) != COPY_SHA or external.get(str(SCENE)) != SCENE_SHA or external.get(str(META)) != harness['metadata_sha256'] or external.get(str(Path(__file__).resolve())) != harness['driver_sha256']:
        raise RuntimeError('Actual part lacked exact external source/metadata bindings')
    return {'theme_index': index, 'theme': actual_theme, 'data_path': str(data_path), 'data_sha256': sha(data_path), 'label': part['label'], 'run_path': str(run_path), 'run_sha256': sha(run_path), 'thermal_path': str(thermal_path), 'thermal_sha256': sha(thermal_path), 'checks': checks, 'counts': counts, 'walls': data['walls'], 'infill_walls': data['infill_walls'], 'source_hashes': run['source_hashes'], 'source_map_sha256': digest(run['source_hashes']), 'source_pathset_sha256': digest(sorted(run['source_hashes'])), 'coverage_paths_sha256': digest({'samples': wanted_samples, 'plan_paths': plan_paths, 'visits': visits}), 'guard_duty_cycle': thermal['duty_cycle'], 'guard_peak_c': max((row.get('package_c') or 0 for row in thermal.get('samples', [])), default=None), 'external_bindings': external}


def aggregate_checks(totals: dict) -> list[dict]:
    # Exactly the original five _check invocations, unchanged thresholds.
    return [
        {'expression': '_infill_total > 0', 'message': 'The pass built no infill at all', 'passed': totals['infill'] > 0},
        *[{'expression': f'int(_steps[{step}]) > 0', 'message': f'No infill segment stands on setback step {step}', 'passed': totals['steps'][str(step)] > 0} for step in (-1, 0, 1)],
        {'expression': '_framed > 0 and _framed_open_sides > 0 and _framed_open_sides < _framed', 'message': 'framed squares: %d, with open sides %d (want some of each)' % (totals['framed'], totals['framed_open_sides']), 'passed': totals['framed'] > 0 and totals['framed_open_sides'] > 0 and totals['framed_open_sides'] < totals['framed']},
    ]


def build_aggregate(matrix_path: Path, check_current: bool = True) -> dict:
    harness = verify_harness()
    matrix = read(matrix_path)
    if matrix.get('harness') != harness or set(matrix.get('parts', {})) != {str(index) for index in range(14)}:
        raise RuntimeError('Matrix needs exactly14 selected successful original indices0..13 with the same source/harness binding')
    raw_parts = [matrix['parts'][str(index)] for index in range(14)]
    if Counter(item['theme_index'] for item in raw_parts) != Counter(range(14)):
        raise RuntimeError('Duplicate/missing selected theme index')
    parts = [validate_part(part, harness) for part in raw_parts]
    if len({part['run_path'] for part in parts}) != 14 or len({part['data_path'] for part in parts}) != 14:
        raise RuntimeError('Each theme needs a distinct actual raw run and JSON')
    first_map = parts[0]['source_hashes']
    if any(part['source_hashes'] != first_map for part in parts):
        raise RuntimeError('Source paths/bytes differ between selected theme parts; a mixed-source matrix is not accepted')
    if check_current:
        for relative, expected in first_map.items():
            path = Path(relative) if Path(relative).is_absolute() else PROJECT / relative
            if not path.is_file() or sha(path) != expected:
                raise RuntimeError('Current source no longer matches checked matrix: ' + relative)
    totals = {key: sum(part['counts'][key] for part in parts) for key in parts[0]['counts'] if key != 'steps'}
    totals['steps'] = {str(step): sum(part['counts']['steps'][str(step)] for part in parts) for step in (-1, 0, 1)}
    checks = aggregate_checks(totals)
    totals['checks_including_original_five'] = totals['checks_local'] + 5
    walls = [value for part in parts for value in part['walls']]
    infill_walls = [value for part in parts for value in part['infill_walls']]
    for part in parts:
        part.pop('source_hashes')
        part.pop('walls')
        part.pop('infill_walls')
    return {'kind': 'street-continuity-dressed-fourteen-theme-aggregate', 'created_utc': now(), 'status': 'passed' if all(item['passed'] for item in checks) else 'failed', 'matrix_path': str(matrix_path), 'matrix_sha256': sha(matrix_path), 'harness': harness, 'selected_indices': list(range(14)), 'parts': parts, 'runtime_source_map_sha256': digest(first_map), 'source_pathset_sha256': digest(sorted(first_map)), 'totals': totals, 'walls': {'count': len(walls), 'longest': max(walls, default=0)}, 'infill_walls': {'count': len(infill_walls), 'longest': max(infill_walls, default=0)}, 'original_five_aggregate_assertions': checks, 'global_assertions_evaluated': 5, 'limits': 'All original sampled-chunk and whole-plan assertions execute in14 separate cold engines with decoration enabled. Counts are combined only after14 clean distinct source-identical runs and the exact original five final assertions. Cold per-theme execution does not test cross-theme residency in one engine; dedicated resource-transition tests cover that separately. Functional correctness only, no timing/performance claim.'}


def validate_aggregate_file(path: Path) -> dict:
    saved = read(path)
    if saved.get('kind') != 'street-continuity-dressed-fourteen-theme-aggregate' or saved.get('status') != 'passed' or saved.get('selected_indices') != list(range(14)) or saved.get('global_assertions_evaluated') != 5 or len(saved.get('original_five_aggregate_assertions', [])) != 5:
        raise RuntimeError('No complete passing14-theme/five-assertion matrix gate: ' + str(path))
    rebuilt = build_aggregate(Path(saved['matrix_path']))
    for key in ('status', 'matrix_sha256', 'harness', 'selected_indices', 'parts', 'runtime_source_map_sha256', 'source_pathset_sha256', 'totals', 'walls', 'infill_walls', 'original_five_aggregate_assertions', 'global_assertions_evaluated'):
        if saved.get(key) != rebuilt.get(key):
            raise RuntimeError('Aggregate no longer revalidates against all raw parts: ' + key)
    return {'path': str(path), 'sha256': sha(path), 'status': 'passed', 'checked_themes': 14, 'original_global_assertions': 5, 'runtime_source_map_sha256': saved['runtime_source_map_sha256'], 'source_pathset_sha256': saved['source_pathset_sha256'], 'totals': saved['totals'], 'harness': saved['harness']}


def cancel(signum: int, _frame: object) -> None:
    global CANCELLED
    CANCELLED = True
    print(f'Cancellation requested ({signum}); waiting for current guarded cleanup.', flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--theme-index', type=int, choices=range(14))
    parser.add_argument('--matrix', type=Path, default=DEFAULT_MATRIX)
    parser.add_argument('--aggregate', action='store_true')
    parser.add_argument('--aggregate-out', type=Path)
    parser.add_argument('--verify-aggregate', type=Path)
    parser.add_argument('--suffix', default='v1')
    parser.add_argument('--guard', type=Path, default=BASE / 'guarded_engine.py')
    parser.add_argument('--guard-arg', action='append', default=[], help='Root-supplied actual guard options, e.g. its supported duty option; no guard is edited here.')
    parser.add_argument('--timeout', type=int, default=600)
    args = parser.parse_args()
    if args.verify_aggregate:
        print(json.dumps(validate_aggregate_file(args.verify_aggregate.resolve()), indent=2))
        return 0
    if not args.matrix.is_absolute() or not re.fullmatch('[a-z0-9-]+', args.suffix):
        parser.error('Use an absolute matrix path and lowercase alphanumeric/hyphen suffix')
    harness = verify_harness()
    indices = [args.theme_index] if args.theme_index is not None else list(range(14))
    planned = []
    for index in indices:
        label = f'city22-street-continuity-part-{index:02d}-{args.suffix}'
        data_path = args.matrix.parent / 'parts' / (label + '.json')
        command = [sys.executable, str(args.guard.resolve()), '--label', label, '--project', str(PROJECT), '--start-temperature', '70', '--max-wait', '900', '--timeout', str(args.timeout), *args.guard_arg, '--', '--headless', str(SCENE), '--', '--deco=1', '--theme-index=' + str(index), '--out=' + str(data_path)]
        planned.append({'theme_index': index, 'original_theme_entry': harness['manifest']['themes'][index], 'label': label, 'data_path': str(data_path), 'command': command})
    if not args.execute:
        print(json.dumps({'harness': harness, 'matrix': str(args.matrix), 'planned': planned, 'aggregate_requested': args.aggregate, 'limits': 'Dry run only. Each theme runs unchanged local/full-plan checks; no global counts or suite pass until all14 raw runs plus original5aggregate assertions validate.'}, indent=2))
        return 0
    if args.aggregate:
        if args.theme_index is not None:
            parser.error('--aggregate is separate from executing a theme index')
        aggregate = build_aggregate(args.matrix)
        target = args.aggregate_out or args.matrix.with_name('aggregate.json')
        if target.exists():
            raise RuntimeError('Preserve prior aggregate; choose fresh --aggregate-out')
        write(target, aggregate)
        print(json.dumps({'status': aggregate['status'], 'aggregate': str(target), 'totals': aggregate['totals'], 'original_five_aggregate_assertions': aggregate['original_five_aggregate_assertions']}, indent=2))
        return 0 if aggregate['status'] == 'passed' else 1
    if args.theme_index is None:
        parser.error('Execution requires one --theme-index=0..13; resume indices individually')
    part = planned[0]
    args.matrix.parent.mkdir(parents=True, exist_ok=True)
    (args.matrix.parent / '.gdignore').touch()
    (args.matrix.parent / 'parts').mkdir(exist_ok=True)
    lock_file = args.matrix.with_suffix(args.matrix.suffix + '.lock').open('a+')
    fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    matrix = read(args.matrix) if args.matrix.exists() else {'kind': 'street-continuity-theme-matrix', 'created_utc': now(), 'harness': harness, 'project': str(PROJECT), 'parts': {}, 'attempts': []}
    if matrix.get('harness') != harness or str(args.theme_index) in matrix['parts']:
        raise RuntimeError('Matrix harness changed or index already selected; do not count a theme twice')
    if Path(part['data_path']).exists() or list(RUNS.glob(part['label'] + '-*')) or (BASE / (part['label'] + '-thermal.json')).exists():
        raise RuntimeError('Preserve previous attempt/label; choose a fresh suffix')
    bound = [COPY, SCENE, META, Path(__file__).resolve(), args.guard.resolve()]
    part.update({'started_utc': now(), 'status': 'running', 'external_bindings': {str(path): sha(path) for path in bound}})
    matrix['attempts'].append(part)
    write(args.matrix, matrix)
    signal.signal(signal.SIGINT, cancel)
    signal.signal(signal.SIGTERM, cancel)
    try:
        print('START', part['label'], flush=True)
        child = subprocess.Popen(part['command'], cwd=ROOT)
        while child.poll() is None:
            time.sleep(0.25)
        part.update({'wrapper_exit': child.returncode, 'ended_utc': now()})
        if child.returncode != 0:
            raise RuntimeError('Guard stopped/failed; this index is incomplete, inspect raw attempt before resuming with a fresh suffix')
        if {str(path): sha(path) for path in bound} != part['external_bindings']:
            raise RuntimeError('External harness/runner changed during this part')
        verified = validate_part(part, harness)
        part.update({'status': 'part_checked', 'data_sha256': verified['data_sha256'], 'run_path': verified['run_path'], 'run_sha256': verified['run_sha256'], 'thermal_path': verified['thermal_path'], 'thermal_sha256': verified['thermal_sha256'], 'source_map_sha256': verified['source_map_sha256'], 'coverage_paths_sha256': verified['coverage_paths_sha256']})
        matrix['parts'][str(args.theme_index)] = part.copy()
        print('PART_CHECKED', args.theme_index, 'selected themes', len(matrix['parts']), 'of14; original global assertions not evaluated yet', flush=True)
    except BaseException as error:
        part.update({'status': 'incomplete', 'error': repr(error), 'ended_utc': now()})
        raise
    finally:
        write(args.matrix, matrix)
        lock_file.close()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
