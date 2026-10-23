#!/usr/bin/env python3
"""Source-bound scenery timing pairs. Dry run by default; no project mutations.

Execution requires root's explicit final candidate commit and attestation that
the board quiet window is open and Claude has acknowledged it. This does not
send messages or open a timing window on the user's behalf.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import fcntl
import hashlib
import json
import math
from pathlib import Path
import re
import signal
import subprocess
import sys
import time

ROOT = Path('/home/user/Nauris/Synthetic-Ascension')
BASE = ROOT / '.superpowers/continuation-20261022'
RUNS = ROOT / '.superpowers/claude-city-20261021/runs'
BASELINE = Path('/tmp/sa-wp2-evidence')
CANDIDATE = Path('/tmp/sa-c22-weathering')
BASELINE_SHA = 'd14d71c3a52e85f4fc5d77a1150eed8240c3b548'
PENDING_SHA = '3b90f4c0613b4561138825320f2b4312f2a4643d'
R3 = BASE / 'stage4-cost-r3'
DIMENSION_PROOF = BASE / 'stage4-cost-viewport-source-review'
HELPER = R3 / 'Stage4StaticCostProbe.gd'
HELPER_SHA = '4c9d5696082bf46a96960cbe82ddb2b500d350c8bcbc53002af04366fb566724'
SCENE = R3 / 'Stage4StaticCostProbe.tscn'
SCENE_SHA = 'e8e55092a329bdf194e029f7cb347c9c50895d6d9ea2a0819afa3db5596558a3'
GUARD = BASE / 'guarded_engine.py'
CAMERA_SOURCES = BASE / 'stage4-cost-camera-sources.json'
CAMERA_SOURCES_SHA = '6d5541c4fb7419e8871fd91dfd1c0821479311b05b001e1a3214c20879135c71'
CONTEXTS = {
    's2': {'segment': 2, 'seed': 16102026, 'theme': 'service_courtyards', 'camera': [416, -104], 'survey': 's2', 'point': 'kit1', 'survey_sides': ['before', 'after'], 'camera_note': 'Clean baseline/candidate survey manifests agree exactly; inspected actual row-house frontage play image.'},
    's6': {'segment': 6, 'seed': 16102028, 'theme': 'industrial_cutthrough', 'camera': [384, -424], 'survey': 's6a', 'point': 'kit1', 'survey_sides': ['before', 'after'], 'camera_note': 'Clean baseline/candidate survey manifests agree exactly; inspected actual workshop frontage play image.'},
    's7': {'segment': 7, 'seed': 16102028, 'theme': 'canal_services', 'camera': [-1632, 1304], 'survey': 's7b', 'point': 'kit1', 'survey_sides': ['before'], 'camera_note': 'Only the clean baseline survey is available. Candidate survey.json was absent during preparation; pairing must be established by these new timed fixture hashes.'},
    's9': {'segment': 9, 'seed': 16102026, 'theme': 'outer_wall', 'camera': [-3104, -1384], 'survey': 's9a', 'point': 'kit1', 'survey_sides': ['after'], 'camera_note': 'Clean candidate survey establishes seed16102026 and workshop frontage. Baseline survey was interrupted and absent; pairing must be established by these new timed fixture hashes.'},
}
ALLOWED_EXACT = {
    'project.godot', 'scenes/world/buildings/CityFacadeComposer.gd',
    'scenes/world/buildings/facade_wall.gdshader',
    'scenes/world/buildings/facade_wall.gdshaderinc',
    'scenes/world/buildings/facade_module.gdshader',
    'scenes/world/buildings/roof.gdshader',
    'core/systems/world/atmosphere/ThemeAtmosphereProfiles.gd',
    'core/systems/world/atmosphere/WorldAtmosphere.gd',
    'core/systems/world/atmosphere/ground_air.gdshader',
    'tools/tests/CityFacadeComposerTest.gd',
}
CANCELLED = False


def stamp() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def json_read(path: Path) -> dict:
    return json.loads(path.read_text())


def json_write(path: Path, value: dict) -> None:
    temporary = path.with_name(path.name + '.pending')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.replace(path)


def git(project: Path, *args: str) -> str:
    # Read-only Git inspection, executed only by root's --execute invocation.
    return subprocess.check_output(['git', '-C', str(project), *args], text=True, stderr=subprocess.PIPE, timeout=30)


def allowed(path: str) -> bool:
    if path.endswith('.uid'):
        return allowed(path[:-4])
    return path in ALLOWED_EXACT or path.startswith(('assets/world/weathering/v1/', 'scenes/world/buildings/weathering/', 'tools/tests/CityWeathering', 'tools/dev/CityWeathering', 'tools/design/bake_weathering_'))


def source_keys(project: Path) -> dict:
    result = {}
    suffixes = {'.gd', '.gdshader', '.gdshaderinc', '.tscn', '.tres', '.res', '.py', '.ps1'}
    for relative in set(git(project, 'ls-files', '-co', '--exclude-standard', '-z').split('\0')):
        path = project / relative
        if not relative or not path.is_file():
            continue
        if relative == 'project.godot' or path.suffix in suffixes or (relative.startswith('assets/') and path.suffix == '.json') or (relative.startswith('assets/world/') and path.suffix.lower() in {'.png', '.jpg', '.jpeg', '.webp', '.svg', '.exr', '.hdr', '.import'}):
            result[relative] = sha(path)
    return result


def changed_keys(before: dict, after: dict) -> list[dict]:
    return [{'path': path, 'baseline_sha256': before.get(path), 'candidate_sha256': after.get(path)} for path in sorted(before.keys() | after.keys()) if before.get(path) != after.get(path)]


def project_without_globals(path: Path) -> str:
    text = re.sub(r'(?ms)^\[shader_globals\]\s*\n.*?(?=^\[|\Z)', '', path.read_text())
    return '\n'.join(line for line in text.splitlines() if line.strip())


def project_state(project: Path, expected_sha: str) -> dict:
    head = git(project, 'rev-parse', 'HEAD').strip()
    dirty = git(project, 'status', '--porcelain=v1', '--untracked-files=no')
    if head != expected_sha or dirty:
        raise RuntimeError(f'{project}: expected clean tracked commit {expected_sha}, got {head} / {dirty!r}')
    return {'project': str(project), 'git_head': head, 'tracked_status': dirty, 'untracked': git(project, 'ls-files', '--others', '--exclude-standard', '-z').split('\0')[:-1]}


def external_bindings() -> dict:
    paths = [R3 / 'FinalCombinedCityPreview.gd', R3 / 'FinalCombinedCityPreview.tscn', DIMENSION_PROOF / 'viewport.cpp', DIMENSION_PROOF / 'window.cpp', DIMENSION_PROOF / 'official-source.json', HELPER, SCENE, CAMERA_SOURCES, R3 / 'stage4-cost-source-parse.gd', R3 / 'stage4-cost-source-parse.tscn', Path(__file__).resolve(), GUARD, ROOT / '.superpowers/claude-city-20261021/sa_engine.py', ROOT / '.superpowers/claude-city-20261021/run_engine_slot.py']
    return {str(path): {'sha256': sha(path), 'bytes': path.stat().st_size} for path in paths}


def check_helper() -> None:
    proof = json_read(DIMENSION_PROOF / 'official-source.json')
    expected = {'viewport.cpp':'db949779da96c93cbbdd3d97976efe00211fe900ca2e1283d67ce44671c4a652', 'window.cpp':'1e94ba6ccef7fea34b00aab4e40d06730e796471f232d21ced7255d06d45f9fb'}
    if any(sha(DIMENSION_PROOF / name) != digest or proof.get(name, {}).get('sha256') != digest for name,digest in expected.items()):
        raise RuntimeError('Exact engine-source dimension proof changed')
    if sha(HELPER) != HELPER_SHA or sha(SCENE) != SCENE_SHA:
        raise RuntimeError('Frozen cost helper/scene changed; re-review and bind the new bytes before timing')


def survey_binding(context: dict) -> list[dict]:
    if sha(CAMERA_SOURCES) != CAMERA_SOURCES_SHA:
        raise RuntimeError('Frozen camera-source metadata changed; re-review before execution')
    key = 's' + str(context['segment'])
    frozen = json_read(CAMERA_SOURCES)
    if frozen['context_definitions'][key] != context:
        raise RuntimeError('Frozen context definition changed: ' + key)
    records = frozen['camera_sources'][key]
    for record in records:
        path = Path(record['frozen_survey'])
        run_path = Path(record['run_result'])
        image = Path(record['frozen_inspected_play_image'])
        if sha(path) != record['survey_sha256'] or sha(image) != record['image_sha256'] or sha(run_path) != record['run_sha256']:
            raise RuntimeError('Frozen camera-source bytes changed for ' + key)
        data, run = json_read(path), json_read(run_path)
        point = next(value for value in data['points'] if value['name'] == context['point'])
        if run.get('actual_exit') != 0 or run.get('runner_exit') != 0 or run.get('stop_reason') != 'completed' or run.get('diagnostics') or data.get('failures') != 0:
            raise RuntimeError('Camera survey source was incomplete/failing: ' + str(run_path))
        if data.get('segment') != context['segment'] or data.get('world_seed') != context['seed'] or data.get('theme_id') != context['theme'] or point.get('world') != context['camera']:
            raise RuntimeError('Camera survey source changed: ' + str(path))
    return records


def finite_mask_imports(project: Path) -> dict:
    # This is explicitly a four-mask sample, not the Game import closure.
    result = {}
    for name in ('wall_base_damp', 'roof_lichen', 'runoff_streaks', 'vent_soot'):
        source = project / ('assets/world/weathering/v1/' + name + '.png')
        sidecar = source.with_name(source.name + '.import')
        record = {'source_exists': source.exists(), 'source_sha256': sha(source) if source.exists() else None, 'sidecar_exists': sidecar.exists(), 'sidecar_sha256': sha(sidecar) if sidecar.exists() else None, 'artifacts': []}
        if sidecar.exists():
            for relative in sorted(set(re.findall(r'"(res://\.godot/imported/[^"\n]+)"', sidecar.read_text()))):
                artifact = project / relative.removeprefix('res://')
                record['artifacts'].append({'path': relative, 'exists': artifact.exists(), 'sha256': sha(artifact) if artifact.exists() else None})
        result[str(source.relative_to(project))] = record
    return result


def guard_command(label: str, project: Path, godot_args: list[str], native: bool) -> list[str]:
    command = [sys.executable, str(GUARD), '--label', label, '--project', str(project), '--start-temperature', '65', '--max-wait', '900', '--timeout', '600']
    if native:
        command += ['--release-marker', 'TOOL_COST_READY']
    return command + ['--'] + godot_args


def parse_vector(value: str) -> tuple[float, float]:
    match = re.fullmatch(r'\(([^,]+),\s*([^\)]+)\)', value)
    if not match:
        raise RuntimeError('Unexpected vector spelling: ' + repr(value))
    return float(match[1]), float(match[2])


def run_record(label: str) -> dict:
    paths = sorted(RUNS.glob(label + '-*/run-results.json'))
    if len(paths) != 1:
        raise RuntimeError(label + ': missing/ambiguous run record')
    data = json_read(paths[0])
    thermal_path = BASE / (label + '-thermal.json')
    thermal = json_read(thermal_path)
    if data.get('actual_exit') != 0 or data.get('runner_exit') != 0 or data.get('stop_reason') != 'completed' or data.get('diagnostics') or not data.get('ended_utc') or thermal.get('wrapper_exit') != 0 or thermal.get('reason') != 'completed':
        raise RuntimeError(label + ': failed/incomplete guard/run; retain raw evidence and stop')
    return {'path': str(paths[0]), 'sha256': sha(paths[0]), 'data': data, 'thermal_path': str(thermal_path), 'thermal_sha256': sha(thermal_path), 'thermal': thermal}


def exterior_state_valid(fixture: dict) -> bool:
    state = fixture.get('exterior_state', {})
    volumes, roofs, planes, facades = [state.get(key, []) for key in ('indoor_volume_checks', 'roofs', 'roof_planes', 'facades')]
    if not (state.get('all_opaque_outside') is True and state.get('player_walkable') is True and state.get('outside_all_bounds_with_clearance') is True and volumes and roofs and planes and facades and state.get('in_view_roof_planes', 0) > 0 and state.get('in_view_facades', 0) > 0):
        return False
    if not any(volume.get('connected_roof_keys') for volume in volumes):
        return False
    if not all(not volume.get('contains_player', True) and not volume.get('overlaps_player_body', True) and not volume.get('player_inside_flag', True) for volume in volumes):
        return False
    if not all(roof.get('inside_count') == 0 and not roof.get('tween_running', True) and roof.get('host_modulate_alpha', 0) >= 0.99999 and roof.get('host_inherited_alpha', 0) >= 0.99999 and roof.get('outside_target_alpha', 0) >= 0.99999 for roof in roofs):
        return False
    if not all(plane.get('visible') is True and plane.get('inherited_alpha', 0) * plane.get('color_alpha', 0) >= 0.99999 for plane in planes):
        return False
    if not all(facade.get('facade_alpha', 0) >= 0.99999 and all(owner.get('visible') is True and owner.get('inherited_alpha', 0) >= 0.99999 for owner in facade.get('owners', [])) for facade in facades):
        return False
    if state.get('owner_issues'):
        return False
    if not all(item.get('classification') == 'empty_clipped_dungeon_host'
            and item.get('source_script') == 'res://scenes/world/buildings/DungeonRoof.gd'
            and item.get('authoritative_host') is True and item.get('dungeon_wing_metadata') is True
            and item.get('polygon_vertices') == 0 for item in state.get('non_drawable_roof_planes', [])):
        return False
    return all(record.get('key', '').startswith(prefix) for records, prefix in ((volumes, 'volume:'), (roofs, 'roof:'), (planes, 'roof-plane:'), (facades, 'kit:')) for record in records)


def render_dimensions_valid(fixture: dict, size: tuple[int, int]) -> bool:
    dimensions = fixture.get('render_dimensions', {})
    logical = [1920, 1080]
    sx, sy = size[0] / logical[0], size[1] / logical[1]
    expected_stretch = [sx, 0.0, 0.0, sy, 0.0, 0.0]
    return (dimensions.get('basis') == 'Godot ed1daf0bf native CANVAS_ITEMS source contract'
            and str(dimensions.get('engine_hash', '')).startswith('ed1daf0bf')
            and dimensions.get('window_is_viewport') is True and dimensions.get('native_window_id') == 0
            and dimensions.get('nonembedded') is True and dimensions.get('canvas_items_mode') is True
            and dimensions.get('window_size') == list(size) and dimensions.get('display_server_size') == list(size)
            and dimensions.get('content_scale_size') == logical and dimensions.get('content_scale_factor') == 1.0
            and dimensions.get('logical_visible_size') == logical and dimensions.get('stretch_transform') == expected_stretch
            and dimensions.get('source_derived_native_size') == list(size)
            and dimensions.get('texture_size_getter_diagnostic') == [math.ceil(size[0]*sx), math.ceil(size[1]*sy)]
            and parse_vector(fixture.get('viewport_texture_size', '')) == tuple(dimensions['texture_size_getter_diagnostic']))


def validate_report(path: Path, context: dict, size: tuple[int, int], smoke: bool, reduced: bool) -> dict:
    data = json_read(path)
    initial, final = data.get('fixture_initial', {}), data.get('fixture_final', {})
    frames, rounds = (30, 1) if smoke else (120, 3)
    checks = {
        'complete_without_save_writes': data.get('failures') == 0 and data.get('save_writes') == 0,
        'same_frozen_helper': data.get('helper_sha256') == HELPER_SHA,
        'explicit_theme_seed': data.get('segment') == context['segment'] and data.get('seed') == context['seed'] and data.get('requested_seed') == context['seed'] and data.get('actual_theme') == context['theme'] and data.get('requested_theme') == '',
        'requested_dimensions': parse_vector(initial.get('actual_window', '')) == size and parse_vector(final.get('actual_window', '')) == size and render_dimensions_valid(initial, size) and render_dimensions_valid(final, size),
        'true_fullscreen_for_1080': size != (1920, 1080) or (data.get('requested_fullscreen') is True and initial.get('window_mode') == 3 and final.get('window_mode') == 3),
        'explicit_camera': parse_vector(initial.get('camera', '')) == tuple(context['camera']) and parse_vector(final.get('camera', '')) == tuple(context['camera']) and parse_vector(initial.get('zoom', '')) == (1.0, 1.0) and initial.get('zoom') == final.get('zoom'),
        'geometry_frozen': bool(initial.get('physical_sha256')) and initial.get('physical_sha256') == final.get('physical_sha256') and initial.get('chunks') == final.get('chunks') and bool(initial.get('chunks')),
        'exterior_owners_frozen_opaque': exterior_state_valid(initial) and exterior_state_valid(final) and initial.get('exterior_state') == final.get('exterior_state') and bool(initial.get('exterior_state_sha256')) and initial.get('exterior_state_sha256') == final.get('exterior_state_sha256'),
        'exterior_parking_observed': all(item.get('player_parking', {}).get('outside_and_opaque_before_freeze') is True and item.get('player_parking', {}).get('static_capsule_checked') is True and item.get('player_parking', {}).get('clearance_px') == 64.0 and item.get('player_parking', {}).get('ordinary_physics_frames_after_stream_settle', 0) >= 4 for item in (initial, final)),
        'terrain_frozen': initial.get('terrain_samples') == final.get('terrain_samples') and len(initial.get('terrain_samples', [])) == 9,
        'matched_sampling_settings': data.get('sample_fps_cap') == 30 and data.get('warmup_frames') == 45 and data.get('reduced_motion') == reduced and len(data.get('rounds', [])) == rounds,
        'positive_gpu_observations': all(item.get('requested_frames') == frames and item.get('gpu_positive_samples') == frames and len(item.get('samples', [])) == frames and all(row.get('gpu_ms', 0) > 0 for row in item.get('samples', [])) for item in data.get('rounds', [])),
        'real_drawn_frames': all(item.get('drawn_frames', 0) >= frames - 1 for item in data.get('rounds', [])),
    }
    return {'path': str(path), 'sha256': sha(path), 'checks': checks, 'valid': all(checks.values()), 'data': data}


def compare_pair(before: dict, after: dict) -> dict:
    baseline, candidate = before['data'], after['data']
    fixture_keys = ('render_dimensions', 'camera', 'zoom', 'requested_window', 'actual_window', 'viewport_texture_size', 'window_mode', 'viewport', 'canvas_transform', 'world_bounds', 'chunks', 'physical_sha256', 'terrain_samples', 'ground_quads', 'exterior_state', 'exterior_state_sha256')
    checks = {key: baseline['fixture_initial'].get(key) == candidate['fixture_initial'].get(key) for key in fixture_keys}
    parking_keys = ('selected_world', 'selected_cell', 'clearance_px', 'static_capsule_checked', 'camera_unchanged', 'after_settle_world', 'outside_and_opaque_before_freeze')
    checks.update({'parking_' + key: baseline['fixture_initial'].get('player_parking', {}).get(key) == candidate['fixture_initial'].get('player_parking', {}).get(key) for key in parking_keys})
    checks.update({key: baseline.get(key) == candidate.get(key) for key in ('helper_sha256', 'segment', 'seed', 'actual_theme', 'sample_fps_cap', 'warmup_frames', 'reduced_motion', 'renderer', 'adapter', 'api')})
    deltas = []
    if all(checks.values()):
        for index, (left, right) in enumerate(zip(baseline['rounds'], candidate['rounds'])):
            deltas.append({'round': index, **{metric: {'baseline': left['summary'][metric], 'candidate': right['summary'][metric], 'p50_delta_ms': right['summary'][metric]['p50'] - left['summary'][metric]['p50']} for metric in ('gpu_ms', 'viewport_cpu_ms', 'setup_cpu_ms', 'process_ms')}})
    return {'checks': checks, 'comparable_geometry_and_protocol': all(checks.values()), 'round_observations': deltas, 'baseline_material_inventory': baseline['fixture_initial'].get('material_counts'), 'candidate_material_inventory': candidate['fixture_initial'].get('material_counts'), 'limits': 'Static scenery observations at a matched cap and physical fixture. Material/polygon/atmosphere changes are intentional. GPU timer returns positive last-frame observations without exposed query identity; cap periods are not throughput, process time is not live-Game CPU cost, and order rotation is not statistical isolation.'}


def stop_after_case(signum: int, _frame: object) -> None:
    global CANCELLED
    CANCELLED = True
    print(f'Cancellation requested ({signum}); wait for the active guarded case cleanup, then stop.', flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--candidate-sha', help='Explicit final clean 40-character candidate commit; required for execution.')
    parser.add_argument('--timing-window-open', action='store_true', help='Root attests board quiet window OPEN and Claude ACK received; never inferred by this script.')
    parser.add_argument('--contexts', default='s2,s6,s7,s9')
    parser.add_argument('--sizes', default='960,1080', help='Comma-separated960 and/or1080;1080 is true1920x1080 fullscreen.')
    parser.add_argument('--smoke', action='store_true', help='One pair only: first requested context/size,1x30 frames. Functional GPU-timer smoke evidence only.')
    parser.add_argument('--reduced-motion', action='store_true')
    parser.add_argument('--suffix', default='r3')
    args = parser.parse_args()
    keys = args.contexts.split(',')
    sizes = args.sizes.split(',')
    if len(set(keys)) != len(keys) or any(key not in CONTEXTS for key in keys) or len(set(sizes)) != len(sizes) or any(size not in ('960', '1080') for size in sizes) or not re.fullmatch('[a-z0-9-]+', args.suffix):
        parser.error('Use unique context keys s2/s6/s7/s9, sizes960/1080, lowercase alphanumeric/hyphen suffix.')
    if args.execute and (not args.candidate_sha or not re.fullmatch('[0-9a-f]{40}', args.candidate_sha) or args.candidate_sha in (PENDING_SHA, BASELINE_SHA) or not args.timing_window_open):
        parser.error('Execution needs explicit FINAL --candidate-sha (pending3b90 is refused) and root --timing-window-open attestation after board OPEN/Claude ACK.')
    if args.smoke:
        keys, sizes = keys[:1], sizes[:1]
    output = Path('/var/tmp/sa-city22/stage4') / ('static-' + args.suffix)
    prefix = 'city22-stage4-cost-' + args.suffix
    cases = []
    for side, project in (('baseline', BASELINE), ('candidate', CANDIDATE)):
        label = prefix + '-parse-' + side
        cases.append({'id': 'parse-' + side, 'side': side, 'project': str(project), 'label': label, 'native': False, 'command': guard_command(label, project, ['--headless', str(R3 / 'stage4-cost-source-parse.tscn')], False)})
    for size_index, size_name in enumerate(sizes):
        rotated = keys[size_index % len(keys):] + keys[:size_index % len(keys)]
        for key in rotated:
            context = CONTEXTS[key]
            size = (960, 540) if size_name == '960' else (1920, 1080)
            order = ('baseline', 'candidate') if (keys.index(key) + size_index) % 2 == 0 else ('candidate', 'baseline')
            for side in order:
                project = BASELINE if side == 'baseline' else CANDIDATE
                label = f'{prefix}-{key}-{size_name}-{side}'
                result_path = output / f'{key}-{size_name}-{side}.json'
                native = ['--rendering-driver', 'opengl3', '--audio-driver', 'Dummy', str(SCENE), '--', '--visible', '--segment=' + str(context['segment']), '--world-seed=' + str(context['seed']), '--expect-theme=' + context['theme'], '--camera=' + ','.join(map(str, context['camera'])), '--size=' + 'x'.join(map(str, size)), '--sample-fps=30', '--warmup=45', '--frames=' + ('30' if args.smoke else '120'), '--rounds=' + ('1' if args.smoke else '3'), '--json=' + str(result_path)]
                if size_name == '1080':
                    native.append('--fullscreen')
                if args.reduced_motion:
                    native.append('--reduced-motion')
                cases.append({'id': f'{key}-{size_name}-{side}', 'pair': f'{key}-{size_name}', 'key': key, 'side': side, 'project': str(project), 'size': size, 'label': label, 'native': True, 'json': str(result_path), 'command': guard_command(label, project, native, True)})
    plan = {'created_utc': stamp(), 'output': str(output), 'baseline_expected_sha': BASELINE_SHA, 'candidate_expected_sha': args.candidate_sha, 'timing_window_attestation': args.timing_window_open, 'smoke_only': args.smoke, 'reduced_motion': args.reduced_motion, 'contexts': {key: CONTEXTS[key] for key in keys}, 'planned_cases': cases, 'external_bindings': external_bindings(), 'protocol': {'start_c': 65, 'max_queue_wait_s': 900, 'cpu_affinity': [0, 1], 'setup_duty': 0.25, 'release_marker': 'TOOL_COST_READY', 'runtime_stop_c': 90, 'sustained_stop_c': 85, 'sustained_samples': 3, 'sample_fps': 30, 'warmup_frames': 45, 'rounds': 1 if args.smoke else 3, 'frames_per_round': 30 if args.smoke else 120, 'per_case_yield_s': 3}, 'limits': 'No capture, readback, PNG encoding or per-frame writes. Actual Game scenery with AI/physics/streaming frozen after settle, actors/HUD hidden, local materials/atmosphere processing live. Compare only exact geometry/bounds/terrain/protocol pairs. Frozen helper source/scene and all out-of-tree launcher/parser bytes explicitly bound; finite four-mask import sample is not a complete generated import closure.'}
    if not args.execute:
        print(json.dumps(plan, indent=2))
        return 0
    lock_file = (BASE / 'stage4-static-cost-queue.lock').open('a+')
    fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    check_helper()
    states = {'baseline': project_state(BASELINE, BASELINE_SHA), 'candidate': project_state(CANDIDATE, args.candidate_sha)}
    committed_paths = git(CANDIDATE, 'diff', '--name-only', BASELINE_SHA, args.candidate_sha, '--').splitlines()
    if any(not allowed(path) for path in committed_paths):
        raise RuntimeError('Candidate includes changes outside isolated weathering/atmosphere scope: ' + repr([path for path in committed_paths if not allowed(path)]))
    if project_without_globals(BASELINE / 'project.godot') != project_without_globals(CANDIDATE / 'project.godot'):
        raise RuntimeError('project.godot changes extend outside shader_globals; rendering/physics/foundations must remain identical')
    source_maps = {'baseline': source_keys(BASELINE), 'candidate': source_keys(CANDIDATE)}
    delta = changed_keys(source_maps['baseline'], source_maps['candidate'])
    if any(not allowed(item['path']) for item in delta):
        raise RuntimeError('Actual source inputs differ outside weathering scope: ' + repr([item['path'] for item in delta if not allowed(item['path'])]))
    cameras = {key: survey_binding(CONTEXTS[key]) for key in keys}
    if output.exists() or any(list(RUNS.glob(case['label'] + '-*')) or (BASE / (case['label'] + '-thermal.json')).exists() for case in cases):
        raise RuntimeError('Output/labels already exist; preserve attempts and choose a new suffix')
    output.mkdir(parents=True)
    (output / '.gdignore').write_text('')
    bound_sources = output / 'external-sources'
    bound_sources.mkdir()
    for path, record in plan['external_bindings'].items():
        source = Path(path)
        target = bound_sources / (record['sha256'] + '-' + source.name)
        target.write_bytes(source.read_bytes())
    plan.update({'started_utc': stamp(), 'source_states': states, 'committed_changed_paths': committed_paths, 'changed_source_keys': delta, 'source_maps_initial': source_maps, 'camera_sources': cameras, 'board_path': str(ROOT / '.superpowers/COORDINATION.md'), 'board_sha256_at_start': sha(ROOT / '.superpowers/COORDINATION.md'), 'cases': [], 'pairs': {}, 'status': 'running'})
    report_path = output / 'queue.json'
    json_write(report_path, plan)
    signal.signal(signal.SIGINT, stop_after_case)
    signal.signal(signal.SIGTERM, stop_after_case)
    completed = {}
    completed_run_sources = {}
    try:
        for case in cases:
            if CANCELLED:
                raise RuntimeError('Queue cancelled between owned guarded cases')
            check_helper()
            if external_bindings() != plan['external_bindings']:
                raise RuntimeError('Out-of-tree helper/launcher/parser bytes changed during the queue')
            project = Path(case['project'])
            expected = BASELINE_SHA if case['side'] == 'baseline' else args.candidate_sha
            project_state(project, expected)
            if source_keys(project) != source_maps[case['side']]:
                raise RuntimeError('Project source bytes changed before a queued case: ' + case['id'])
            item = {**case, 'started_utc': stamp(), 'mask_imports_before': finite_mask_imports(project)}
            plan['cases'].append(item)
            json_write(report_path, plan)
            print('START', case['label'], flush=True)
            child = subprocess.Popen(case['command'], cwd=ROOT)
            while child.poll() is None:
                time.sleep(0.25)
            item.update({'wrapper_exit': child.returncode, 'ended_utc': stamp(), 'mask_imports_after': finite_mask_imports(project)})
            json_write(report_path, plan)
            if child.returncode != 0:
                raise RuntimeError(case['label'] + ': failed/incomplete guard; preserve raw attempt, no cost conclusion')
            record = run_record(case['label'])
            run, thermal = record['data'], record['thermal']
            item['run'] = {key: value for key, value in record.items() if key not in ('data', 'thermal')}
            item['run'].update({'git_head': run.get('git_head'), 'actual_exit': run.get('actual_exit'), 'diagnostic_count': len(run.get('diagnostics', [])), 'peak_c': max((sample.get('package_c') or 0 for sample in thermal.get('samples', [])), default=None), 'duty_released': thermal.get('duty_released'), 'source_map_sha256': hashlib.sha256(json.dumps(run.get('source_hashes', {}), sort_keys=True).encode()).hexdigest()})
            if run.get('git_head') != expected or run.get('git_status_porcelain') or any(run.get('source_hashes', {}).get(path) != digest for path, digest in source_maps[case['side']].items()):
                raise RuntimeError('Launched run did not bind the expected clean project bytes: ' + case['id'])
            if case['native']:
                if not thermal.get('duty_released'):
                    raise RuntimeError('External setup duty was not released before sampling')
                item['report'] = validate_report(Path(case['json']), CONTEXTS[case['key']], tuple(case['size']), args.smoke, args.reduced_motion)
                if not item['report']['valid']:
                    raise RuntimeError(case['label'] + ': measured fixture validation failed')
                completed.setdefault(case['pair'], {})[case['side']] = item['report']
                completed_run_sources.setdefault(case['pair'], {})[case['side']] = run['source_hashes']
                pair = completed[case['pair']]
                if len(pair) == 2:
                    comparison = compare_pair(pair['baseline'], pair['candidate'])
                    launched_source_delta = changed_keys(completed_run_sources[case['pair']]['baseline'], completed_run_sources[case['pair']]['candidate'])
                    comparison['launched_changed_source_keys'] = launched_source_delta
                    comparison['launched_source_scope_valid'] = all(allowed(delta['path']) for delta in launched_source_delta)
                    plan['pairs'][case['pair']] = comparison
                    if not comparison['comparable_geometry_and_protocol'] or not comparison['launched_source_scope_valid']:
                        raise RuntimeError(case['pair'] + ': geometry/bounds/terrain/protocol mismatch, no comparative cost result')
            if source_keys(project) != source_maps[case['side']] or external_bindings() != plan['external_bindings']:
                raise RuntimeError('Project/helper bytes changed during the completed case')
            json_write(report_path, plan)
            time.sleep(3)
        plan['status'] = 'smoke_checked' if args.smoke else 'paired_observations_checked'
    except BaseException as error:
        plan['status'] = 'stopped'
        plan['error'] = repr(error)
        raise
    finally:
        plan['ended_utc'] = stamp()
        json_write(report_path, plan)
        lock_file.close()
    print('CHECKED', report_path, flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
