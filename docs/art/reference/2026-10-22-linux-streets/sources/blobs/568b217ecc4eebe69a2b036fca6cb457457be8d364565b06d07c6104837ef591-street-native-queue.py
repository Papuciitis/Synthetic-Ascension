#!/usr/bin/env python3
"""Prepare/run source-bound street visuals. Dry run unless --execute is supplied.

Root only: wait for its existing street queue to finish first. This helper never
starts outside guarded_engine.py, and never launches two cases concurrently.
The reward pair changes ONLY SiteParcelsImpl.gd to the preserved old apron and
restores its exact current bytes before any after-image or dressed route.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import fcntl
import hashlib
import importlib.util
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
GUARD = BASE / 'guarded_engine.py'
SITE_REL = 'core/systems/world/proc/SiteParcelsImpl.gd'
SITE = PROJECT / SITE_REL
OLD_SITE = BASE / 'street-before-approach-SiteParcels.gd.data'
OLD_SHA = '689545138ea4ffd47eac1f1a74475be4372ebcaee75f453106741d155825afee'
CURRENT_SHA = 'fa31541044a4da8d11d6e3d57cea654bc0ea0cc0911de880f04ac3828b3e7503'
PROBE_REL = 'tools/dev/CityStreetTraversalProbe.gd'
PROBE_SHA = '0a3f23935fdd6153f19a606e9b7e9a601a14b72b745234594e102b7604c31755'
FOCUSED = ('city22-street-frontage-r4',)
FULL_CONTINUITY = 'city22-street-continuity-dressed-r2'
MATRIX_DRIVER = BASE / 'street-continuity-matrix.py'
SOURCE_RELS = (
    SITE_REL, PROBE_REL, 'tools/dev/CityBlockPlayablePreview.gd',
    'tools/dev/EliteCrowdFightPreview.gd',
    'core/systems/world/proc/chunkgen/ChunkGenDistrict.gd',
    'core/systems/world/ChunkManager.gd',
    'core/systems/world/ground/GroundSplatRenderer.gd',
    'core/systems/world/ground/DistrictGroundPolicy.gd',
    'scenes/world/volumes/IndoorVolume.gd',
    'scenes/world/buildings/RoofOverlay.gd', 'project.godot',
)
EXTERNAL = (
    BASE / 'StreetRewardCameraProbe.gd', BASE / 'StreetRewardCameraProbe.tscn',
    BASE / 'StreetNativeAcceptanceProbe.gd', BASE / 'StreetNativeAcceptanceProbe.tscn',
    BASE / 'street-native-source-parse.gd', BASE / 'street-native-source-parse.tscn',
    Path(__file__).resolve(), GUARD, MATRIX_DRIVER,
)
CANCELLED = False


def stamp() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path: Path) -> dict:
    return json.loads(path.read_text())


def write_json(path: Path, value: dict) -> None:
    temporary = path.with_name(path.name + '.pending')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.replace(path)


def sources() -> dict:
    paths = [PROJECT / item for item in SOURCE_RELS] + list(EXTERNAL)
    return {str(path): {'exists': path.exists(), 'sha256': sha(path) if path.exists() else None} for path in paths}


def run_record(label: str) -> dict:
    found = sorted(RUNS.glob(label + '-*/run-results.json'))
    if len(found) != 1:
        raise RuntimeError(f'{label}: expected exactly one completed run record; got {len(found)}')
    data = read_json(found[0])
    thermal_path = BASE / (label + '-thermal.json')
    thermal = read_json(thermal_path)
    if not data.get('ended_utc') or data.get('actual_exit') != 0 or data.get('runner_exit') != 0 or data.get('stop_reason') != 'completed' or data.get('diagnostics'):
        raise RuntimeError(f'{label}: incomplete/failing run; inspect {found[0]}')
    if thermal.get('wrapper_exit') != 0 or thermal.get('reason') != 'completed':
        raise RuntimeError(f'{label}: incomplete/failing guard; inspect {thermal_path}')
    return {'path': str(found[0]), 'sha256': sha(found[0]), 'actual_exit': data['actual_exit'], 'runner_exit': data['runner_exit'], 'diagnostics': data['diagnostics'], 'elapsed_seconds': data.get('elapsed_seconds'), 'source_hashes': data.get('source_hashes', {}), 'thermal_path': str(thermal_path), 'thermal_sha256': sha(thermal_path), 'thermal_peak_c': max((entry.get('package_c') or 0 for entry in thermal.get('samples', [])), default=None), 'duty_released': thermal.get('duty_released')}


def command(label: str, args: list[str], timeout: int, release: bool = True) -> list[str]:
    cmd = [sys.executable, str(GUARD), '--label', label, '--project', str(PROJECT), '--start-temperature', '70', '--max-wait', '900', '--timeout', str(timeout)]
    if release:
        cmd += ['--release-marker', '[Game] ready']
    return cmd + ['--'] + args


def image_records(directory: Path) -> list[dict]:
    return [{'path': str(path), 'bytes': path.stat().st_size, 'sha256': sha(path)} for path in sorted(directory.rglob('*.png'))]


def cancellation(signum: int, _frame: object) -> None:
    global CANCELLED
    CANCELLED = True
    # Let the current guarded case finish its own cleanup; then restore before
    # leaving. Killing this queue with SIGKILL cannot execute a finally block.
    print(f'Cancellation requested ({signum}); waiting for the current guarded case to finish before source restoration.', flush=True)


def vector_pair(value: str) -> tuple[int, int]:
    match = re.fullmatch(r'\((-?\d+),\s*(-?\d+)\)', value)
    if not match:
        raise RuntimeError('Unexpected vector spelling: ' + repr(value))
    return int(match[1]), int(match[2])


def camera_pair(value: str) -> tuple[float, float]:
    match = re.fullmatch(r'\(([^,]+),\s*([^\)]+)\)', value)
    if not match:
        raise RuntimeError('Unexpected camera vector spelling: ' + repr(value))
    return float(match[1]), float(match[2])


def validate_route(directory: Path, segment: int, seed: int, coord: tuple[int, int], render_fps: int) -> dict:
    path = directory / 'traversal.json'
    data = read_json(path)
    passage = data.get('passage', {})
    trace = passage.get('trace_validation', {})
    director = data.get('encounter_director', {})
    checks = {
        'failures_zero': data.get('failures') == 0,
        'segment_seed': data.get('segment') == segment and data.get('world_seed') == seed,
        'requested_passage_chunk': vector_pair(passage.get('chunk', '')) == coord,
        'dressed_continuity': data.get('decoration') is True and data.get('street_continuity') is True,
        'narrow_inside_through': all(passage.get(key) is True for key in ('narrow_between_buildings', 'inside', 'through')),
        'strict_physics_trace': trace.get('valid') is True and trace.get('ordered_mouth_middle_mouth') is True and trace.get('near_index') == 0 and not trace.get('outside_indices') and not trace.get('jump_indices') and trace.get('observed_cell_count', 0) > 2,
        'original_entry_exit': data.get('original_entry', {}).get('opened') is True and data.get('original_entry', {}).get('restored') is True,
        'infill_entry_exit': data.get('infill_entry', {}).get('opened') is True and data.get('infill_entry', {}).get('restored') is True,
        'real_collection': data.get('collected') is True and data.get('pickup', {}).get('picked') is True,
        'chunk_crossing': data.get('boundary', {}).get('crossed') is True,
        'director_stayed_live': director.get('requested') is True and director.get('stayed_live') is True and director.get('start', {}).get('live') is True and director.get('end', {}).get('live') is True,
        'walks_arrived': bool(data.get('route')) and all(item.get('destination_reached') is True for item in data.get('route', []) if item.get('event') == 'walk'),
        'save_writes_observed_zero': data.get('save_observation', {}).get('writes_during_acceptance') == 0 and data.get('save_observation', {}).get('current_profile_is_null') is True and data.get('save_observation', {}).get('autosave_disabled') is True,
        'requested_render_cap_unchanged_physics': data.get('runtime_fixture', {}).get('engine_max_fps') == render_fps and data.get('runtime_fixture', {}).get('physics_ticks_per_second') == 60,
        'expected_stills': all((directory / (name + '.png')).is_file() for name in ('traversal-1-passage', 'traversal-2-inside', 'traversal-3-inside-infill', 'traversal-4-collected', 'traversal-5-boundary')),
    }
    return {'path': str(path), 'sha256': sha(path), 'checks': checks, 'valid': all(checks.values()), 'window': data.get('window'), 'camera_zoom': data.get('camera_zoom'), 'trace': trace, 'original_entry': data.get('original_entry'), 'infill_entry': data.get('infill_entry'), 'boundary': data.get('boundary'), 'director': director, 'limits': data.get('limits'), 'save_observation': data.get('save_observation'), 'runtime_fixture': data.get('runtime_fixture')}


def validate_reward(directory: Path, render_fps: int) -> dict:
    path = directory / 'capture-info.json'
    data = read_json(path)
    binding = data.get('reward_camera_binding', {})
    checks = {
        'failures_zero': data.get('failures') == 0,
        'segment_seed': data.get('segment') == 2 and data.get('seed') == 16102026,
        'context_camera_chunk': data.get('ground_context_world_px') == [576, 19264] and vector_pair(data.get('coord', '')) == (0, 9) and camera_pair(data.get('camera', {}).get('position', '')) == (576.0, 19264.0),
        'actual_building_geometry': binding.get('building_id') == 2098284276 and binding.get('chunk') == [0, 9] and binding.get('entry_visible') is True and binding.get('width_px', 0) > 0 and len(binding.get('world_footprint', [])) >= 4,
        'ground_taps': len(binding.get('ground_taps', [])) == 16,
        'reload_equal': any(item.get('event') == 'ground_context_streamed_reload' and item.get('equal') is True and item.get('care_equal') is True for item in data.get('route', [])),
        'save_writes_zero': data.get('save_writes') == 0,
        'requested_render_cap_unchanged_physics': binding.get('runtime_render_fps_cap') == render_fps and binding.get('physics_ticks_per_second') == 60,
        'native_image': (directory / 'ground-before.png').is_file(),
    }
    return {'path': str(path), 'sha256': sha(path), 'checks': checks, 'valid': all(checks.values()), 'reward_camera_binding': binding, 'limits': data.get('limits')}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute', action='store_true', help='Actually run; otherwise print the commands and write nothing.')
    parser.add_argument('--mode', choices=['all', 'reward', 'routes', 's2', 's7', 's6'], default='all')
    parser.add_argument('--runtime-fps', type=int, choices=[20, 30, 60], default=20, help='Capture-only render cap; physics and strict acceptance stay unchanged.')
    parser.add_argument('--continuity-matrix', type=Path, help='Complete passing14-theme aggregate; all raw runs and original5global assertions are revalidated.')
    parser.add_argument('--suffix', default='v1', help='Unique short suffix for immutable run labels/output directories.')
    args = parser.parse_args()
    if not re.fullmatch(r'[a-z0-9-]+', args.suffix):
        parser.error('--suffix must contain only lowercase letters, digits and hyphens')
    output = Path('/var/tmp/sa-city22/streets') / ('native-' + args.suffix)
    prefix = 'city22-street-native-' + args.suffix
    parse_args = ['--headless', str(BASE / 'street-native-source-parse.tscn'), '--', str(BASE / 'StreetRewardCameraProbe.gd'), str(BASE / 'StreetNativeAcceptanceProbe.gd'), 'res://' + PROBE_REL]
    cases = [{'id': 'parse', 'label': prefix + '-parse', 'command': command(prefix + '-parse', parse_args, 240, False)}]
    native = ['--rendering-driver', 'opengl3', '--audio-driver', 'Dummy']
    if args.mode in ('all', 'reward'):
        for state in ('before', 'after'):
            directory = output / ('reward-' + state)
            label = prefix + '-reward-' + state
            godot_args = native + [str(BASE / 'StreetRewardCameraProbe.tscn'), '--', '--visible', '--runtime-fps=' + str(args.runtime_fps), '--review=small', '--segment=2', '--world-seed=16102026', '--ground-context=576,19264', '--out=' + str(directory)]
            cases.append({'id': 'reward-' + state, 'label': label, 'out': str(directory), 'command': command(label, godot_args, 600)})
    if args.mode in ('all', 'routes', 's2', 's7', 's6'):
        for segment, seed, coord in ((2, 16102026, (0, 2)), (7, 16102028, (-4, 3)), (6, 16102028, (1, -1))):
            if args.mode.startswith('s') and args.mode != 's' + str(segment):
                continue
            label = prefix + '-s' + str(segment)
            directory = output / ('s' + str(segment))
            godot_args = native + [str(BASE / 'StreetNativeAcceptanceProbe.tscn'), '--', '--visible', '--runtime-fps=' + str(args.runtime_fps), '--review=small', '--segment=' + str(segment), '--world-seed=' + str(seed), '--passage-chunk=' + ','.join(map(str, coord)), '--out=' + str(directory)]
            cases.append({'id': 's' + str(segment), 'label': label, 'out': str(directory), 'segment': segment, 'seed': seed, 'coord': coord, 'command': command(label, godot_args, 1800)})
    plan = {'created_utc': stamp(), 'project': str(PROJECT), 'mode': args.mode, 'output': str(output), 'required_clean_cases': list(FOCUSED) + ([] if args.continuity_matrix else [FULL_CONTINUITY]), 'continuity_matrix_gate': str(args.continuity_matrix) if args.continuity_matrix else None, 'runtime_render_fps_cap': args.runtime_fps, 'route_window': [1280, 720], 'reward_window': [960, 540], 'source_substitution': {'path': str(SITE), 'before_sha256': OLD_SHA, 'after_sha256': CURRENT_SHA, 'scope': 'Only actual apron implementation differs; reward city_shared_ground remains the candidate true value in both. This pair does not isolate the separate reward shared-ground config fix.'}, 'commands': cases, 'sources_before': sources(), 'limits': 'Functional checks with explicit 70 C start and unchanged90 C/85 C sustained runtime limits. Continuity requires either the clean full dressed suite or strict complete14-theme matrix plus identical original5global assertions; partials never satisfy the gate. External duty released on [Game] ready; external subclasses set and record the explicit render cap, preserving physics ticks and physical acceptance, no performance claim. Route traces use actual physics; initial discovery/placement, god mode, one staged item and scripted combat remain disclosed. The original route probe itself does not consume --runtime-fps. Reward images inherit frozen streaming and disabled ambient combat.'}
    if not args.execute:
        print(json.dumps(plan, indent=2))
        return 0
    lock_file = (BASE / 'street-native-queue.lock').open('a+')
    fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    if sha(SITE) != CURRENT_SHA or sha(OLD_SITE) != OLD_SHA or sha(PROJECT / PROBE_REL) != PROBE_SHA:
        raise RuntimeError('Street source bytes differ from the reviewed current/old/probe hashes; re-review before execution.')
    prerequisites = {label: run_record(label) for label in list(FOCUSED) + ([] if args.continuity_matrix else [FULL_CONTINUITY])}
    for label, item in prerequisites.items():
        for relative in (SITE_REL, 'core/systems/world/proc/chunkgen/ChunkGenDistrict.gd'):
            if item['source_hashes'].get(relative) != sha(PROJECT / relative):
                raise RuntimeError(label + ': focused run did not check these current runtime bytes: ' + relative)
        del item['source_hashes']
    if args.continuity_matrix:
        spec = importlib.util.spec_from_file_location('street_continuity_matrix_gate', MATRIX_DRIVER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        prerequisites['complete_dressed_continuity_matrix'] = module.validate_aggregate_file(args.continuity_matrix.resolve())
    if output.exists() or any(list(RUNS.glob(case['label'] + '-*')) or (BASE / (case['label'] + '-thermal.json')).exists() for case in cases):
        raise RuntimeError('Outputs or run labels already exist; use a fresh --suffix, preserving prior attempts.')
    output.mkdir(parents=True)
    (output / '.gdignore').write_text('')
    report_path = output / 'queue.json'
    plan.update({'started_utc': stamp(), 'prerequisites': prerequisites, 'cases': [], 'status': 'running'})
    current_bytes = SITE.read_bytes()
    restore_backup = output / 'restore-SiteParcelsImpl.gd.data'
    restore_backup.write_bytes(current_bytes)
    plan['restore_backup'] = {'path': str(restore_backup), 'sha256': sha(restore_backup)}
    write_json(report_path, plan)
    signal.signal(signal.SIGINT, cancellation)
    signal.signal(signal.SIGTERM, cancellation)
    try:
        for case in cases:
            if CANCELLED:
                raise RuntimeError('Queue cancelled between guarded cases')
            if case['id'] == 'reward-before':
                SITE.write_bytes(OLD_SITE.read_bytes())
            else:
                SITE.write_bytes(current_bytes) if SITE.read_bytes() != current_bytes else None
            item = {**case, 'started_utc': stamp(), 'sources_before': sources()}
            plan['cases'].append(item)
            write_json(report_path, plan)
            try:
                print('START', case['label'], flush=True)
                child = subprocess.Popen(case['command'], cwd=ROOT)
                while child.poll() is None:
                    time.sleep(0.25)
                item['wrapper_exit'] = child.returncode
            finally:
                # A successful, failing, thermally aborted or cancelled before
                # case must never leave the reviewed runtime source reverted.
                if case['id'] == 'reward-before':
                    SITE.write_bytes(current_bytes)
                item['ended_utc'] = stamp()
                item['source_restored_sha256'] = sha(SITE)
                write_json(report_path, plan)
            if item['wrapper_exit'] != 0:
                raise RuntimeError(case['label'] + ': guard failed; preserve raw run and inspect it')
            checked_run = run_record(case['label'])
            del checked_run['source_hashes']
            item['run'] = checked_run
            if 'out' in case:
                directory = Path(case['out'])
                item['images'] = image_records(directory)
                item['manifest'] = validate_reward(directory, args.runtime_fps) if case['id'].startswith('reward-') else validate_route(directory, case['segment'], case['seed'], tuple(case['coord']), args.runtime_fps)
                if not item['manifest']['valid']:
                    write_json(report_path, plan)
                    raise RuntimeError(case['label'] + ': manifest acceptance failed; inspect individual checks')
            write_json(report_path, plan)
            time.sleep(3)
        plan['status'] = 'checked'
    except BaseException as error:
        plan['status'] = 'stopped'
        plan['error'] = repr(error)
        raise
    finally:
        SITE.write_bytes(current_bytes) if SITE.read_bytes() != current_bytes else None
        plan['ended_utc'] = stamp()
        plan['restored_source_sha256'] = sha(SITE)
        plan['sources_after'] = sources()
        write_json(report_path, plan)
        lock_file.close()
    print('CHECKED', report_path, flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
