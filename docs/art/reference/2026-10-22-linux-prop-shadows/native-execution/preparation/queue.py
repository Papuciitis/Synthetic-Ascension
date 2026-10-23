#!/usr/bin/env python3
"""Dry-run by default. Reuse the clean parser; root opts into ONE native fixture.

The frozen48 GDScript assertions are unchanged. Dummy headless MultiMesh setters
and per-instance getters cannot establish uploaded transforms (Godot ed1daf0bf).
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path('/home/user/Nauris/Synthetic-Ascension')
BASE = ROOT / '.superpowers/continuation-20261022'
HERE = Path(__file__).resolve().parent
SCENE = HERE / 'NativePropShadowAcceptance.tscn'
RUNS = ROOT / '.superpowers/claude-city-20261021/runs'
PROJECT = Path('/tmp/sa-c22-props')
BASELINE_META = BASE / 'prop-shadow-acceptance-source.json'
BASELINE_META_SHA = '34a1c6af13108bcf63f10aefb1d5f96197dda7b9b48bbe24ce9a651b6f1b3561'
META = HERE / 'source.json'
PARSER_LABEL = 'city22-prop-shadow-parse-9b7-r1'
GUARD = BASE / 'guarded_engine.py'
NATIVE_FLAGS = ['--rendering-driver', 'opengl3', '--rendering-method', 'gl_compatibility',
                '--audio-driver', 'Dummy', '--windowed', '--resolution', '640x360', '--max-fps', '20']


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path: Path) -> dict:
    return json.loads(path.read_text())


def verify() -> tuple[dict, dict]:
    if sha(BASELINE_META) != BASELINE_META_SHA:
        raise RuntimeError('Original reviewed source metadata changed')
    baseline, meta = read(BASELINE_META), read(META)
    if meta['project_bindings'] != baseline['project_bindings'] or meta['external_bindings'] != baseline['external_bindings']:
        raise RuntimeError('Native variant changed the original57 project/helper expectations')
    for path, expected in meta['native_execution_bindings'].items():
        if sha(Path(path)) != expected:
            raise RuntimeError('Native driver/guard source changed: ' + path)
    observed = {}
    for path, expected in ({str(PROJECT / key): value for key, value in baseline['project_bindings'].items()} | baseline['external_bindings']).items():
        observed[path] = sha(Path(path))
        if observed[path] != expected:
            raise RuntimeError('Original bound source changed: ' + path)
    return observed, meta


def clean_run(label: str) -> tuple[dict, dict]:
    paths = list(RUNS.glob(label + '-*/run-results.json'))
    if len(paths) != 1:
        raise RuntimeError(f'{label}: expected one raw result, found {len(paths)}')
    raw = read(paths[0])
    thermal_path = BASE / (label + '-thermal.json')
    thermal = read(thermal_path)
    if (not raw.get('ended_utc') or raw.get('actual_exit') != 0 or raw.get('runner_exit') != 0
            or raw.get('stop_reason') != 'completed' or raw.get('diagnostics') != []
            or not raw.get('source_hashes') or Path(raw.get('project_root', '')).resolve() != PROJECT):
        raise RuntimeError('Unclean engine result: ' + str(paths[0]))
    if thermal.get('wrapper_exit') != 0 or thermal.get('reason') != 'completed' or thermal.get('received_signal') is not None:
        raise RuntimeError('Unclean guard result: ' + str(thermal_path))
    meta = read(META)
    if any(raw['source_hashes'].get(path) != expected for path, expected in (meta['project_bindings'] | meta['native_project_bindings']).items()):
        raise RuntimeError('Actual raw project sources differ from reviewed final9b7')
    receipt = {'label': label, 'path': str(paths[0]), 'sha256': sha(paths[0]),
               'thermal_path': str(thermal_path), 'thermal_sha256': sha(thermal_path)}
    return raw, receipt


def parser_receipt(observed: dict) -> dict:
    raw, receipt = clean_run(PARSER_LABEL)
    old_queue = read(Path('/var/tmp/sa-city22/prop-shadow-acceptance/9b7-r1/queue.json'))
    old_parse = [case for case in old_queue['cases'] if case.get('role') == 'parse']
    if len(old_parse) != 1 or old_parse[0]['label'] != PARSER_LABEL or old_parse[0].get('wrapper_exit') != 0:
        raise RuntimeError('Original completed parser case missing')
    saved = old_parse[0]['raw_result']
    if any(saved.get(key) != receipt[key] for key in ('path', 'sha256', 'thermal_path', 'thermal_sha256')):
        raise RuntimeError('Original parser raw/guard binding changed')
    if old_queue.get('source_before') != observed or old_queue.get('source_after') != observed:
        raise RuntimeError('Original parser source inventory no longer matches all57 current bytes')
    command = raw.get('command', [])
    if '--headless' not in command or str(BASE / 'street-native-source-parse.tscn') not in command:
        raise RuntimeError('Original parser was not the scoped headless parser')
    stdout = Path(receipt['path']).parent / 'logs/stdout.log'
    if 'StreetNativeSourceParse: checked=6 failures=0' not in stdout.read_text():
        raise RuntimeError('Original six-source parser verdict missing')
    receipt.update({'reused_without_new_engine': True, 'checked_sources': 6,
                    'stdout_sha256': sha(stdout), 'original_queue_path': '/var/tmp/sa-city22/prop-shadow-acceptance/9b7-r1/queue.json'})
    return receipt


def validate_native(raw: dict, receipt: dict, output: Path) -> str:
    command = raw['command']
    required = [*NATIVE_FLAGS, str(SCENE), '--out=' + str(output), '--native-state=' + str(output.with_name('native-state.json'))]
    if '--headless' in command or any(value not in command for value in required):
        raise RuntimeError('Actual fixture command was not the exact reviewed native invocation')
    thermal = read(Path(receipt['thermal_path']))
    if any(thermal.get(key) != value for key, value in {
        'start_temperature_c': 65, 'runtime_temperature_stop_c': 90,
        'sustained_temperature_stop_c': 85, 'sustained_temperature_samples': 3,
        'duty_cycle': 0.25, 'duty_released': False, 'release_marker': None}.items()):
        raise RuntimeError('Actual native functional guard protocol differs')
    stdout = (Path(receipt['path']).parent / 'logs/stdout.log').read_text()
    banners = [line for line in stdout.splitlines() if line.startswith('OpenGL API ') and 'Compatibility' in line and 'Using Device:' in line]
    if len(banners) != 1 or re.search(r'(?i)llvmpipe|softpipe|dummy', banners[0]):
        raise RuntimeError('Actual native Mesa/adapter banner missing or software/dummy backend')
    state_path = output.with_name('native-state.json')
    state = read(state_path)
    required_state = {'driver': 'opengl3', 'renderer': 'gl_compatibility', 'engine_max_fps': 20,
                      'physics_ticks_per_second': 60, 'window_mode': 0, 'window_borderless': False,
                      'window_size': [640, 360], 'parent_source_sha256': '1c22d005cb33475250e53e91b21854e206cd5bb3c6461ab2aad9f632c8a9cb41'}
    if state.get('display') == 'headless' or not state.get('adapter') or any(state.get(key) != value for key, value in required_state.items()):
        raise RuntimeError('Actual inherited native fixture boot state differs')
    return banners[0]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--suffix', default='9b7-native-r2')
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]{0,55}', args.suffix):
        raise RuntimeError('Use a fresh lowercase suffix')
    observed, meta = verify()
    prerequisite = parser_receipt(observed)
    directory = Path('/var/tmp/sa-city22/prop-shadow-acceptance') / args.suffix
    label = 'city22-prop-shadow-fixture-' + args.suffix
    if directory.exists() or (BASE / (label + '-thermal.json')).exists() or list(RUNS.glob(label + '-*')):
        raise RuntimeError('Fresh fixture output/label required')
    output = directory / 'acceptance.json'
    command = [sys.executable, str(GUARD), '--label', label, '--project', str(PROJECT),
               '--start-temperature', '65', '--max-wait', '900', '--timeout', '300', '--duty-percent', '25',
               '--', *NATIVE_FLAGS, str(SCENE), '--', '--out=' + str(output), '--native-state=' + str(directory / 'native-state.json')]
    record = {'source_before': observed, 'cases': [{'role': 'fixture', 'label': label, 'command': command}],
              'prerequisite_parser': prerequisite, 'passed': False,
              'source_metadata_path': str(META), 'source_metadata_sha256': sha(META),
              'baseline_metadata_sha256': BASELINE_META_SHA,
              'native_execution_bindings': meta['native_execution_bindings'], 'execution_protocol': meta['execution_protocol']}
    if not args.execute:
        print(json.dumps({'execute': False, **record}, indent=2))
        return
    directory.mkdir(parents=True, exist_ok=False)
    try:
        current, _meta = verify()
        if current != observed or sha(META) != record['source_metadata_sha256']:
            raise RuntimeError('Sources changed after native plan creation')
        case = record['cases'][0]
        case['wrapper_exit'] = subprocess.run(command, check=False).returncode
        if case['wrapper_exit'] != 0:
            raise RuntimeError('Native fixture guard failed; raw result remains authoritative')
        raw, case['raw_result'] = clean_run(label)
        record['actual_renderer_banner'] = validate_native(raw, case['raw_result'], output)
        record['native_state_sha256'] = sha(directory / 'native-state.json')
        record['source_after'], _meta = verify()
        if record['source_after'] != observed or sha(META) != record['source_metadata_sha256']:
            raise RuntimeError('Sources changed during native fixture')
        acceptance = read(output)
        if (acceptance.get('suite') != 'CityPropShadowAcceptance' or acceptance.get('passes') != 48
                or acceptance.get('failures') != 0 or len(acceptance.get('checks', [])) != 48
                or not all(check.get('ok') is True for check in acceptance['checks'])):
            raise RuntimeError('Unchanged48 predicates did not all pass')
        record['acceptance_sha256'] = sha(output)
        record['passed'] = True
    except BaseException as error:
        record['error'] = repr(error)
        raise
    finally:
        (directory / 'queue.json').write_text(json.dumps(record, indent=2) + '\n')


if __name__ == '__main__':
    main()
