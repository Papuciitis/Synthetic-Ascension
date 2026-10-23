#!/usr/bin/env python3
"""One source-isolation audit; invoked explicitly by root, never on import.

Writes existing files in place, preserving their directory entries. The seven
candidate files are restored and hash-checked in finally after the guarded child
exits, including assertion, diagnostics, thermal-preflight and timeout outcomes.
SIGINT/SIGTERM request no further work and defer restoration until that owned
child exits; they never leave the running audit with a changed source snapshot.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys

ROOT = Path('/home/user/Nauris/Synthetic-Ascension')
HERE = Path(__file__).resolve().parent
MANIFEST = HERE / 'manifest.json'
GUARD = HERE.parent / 'guarded_engine.py'
RUNS = ROOT / '.superpowers/claude-city-20261021/runs'
AUDIT = 'res://tools/tests/ScriptParseAuditTest.tscn'
AUDIT_SHA = '0a1a538b70404fdf68e27678cbcaf0c7137d07ff1bdf8b3b701eae8b5fd32736'
EXPECTED_MAIN_HEAD = 'd14d71c3a52e85f4fc5d77a1150eed8240c3b548'
SCAN_ROOTS = ['core', 'ui', 'autoload', 'scenes', 'effects', 'data', 'assets', 'spells']


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def ordered_scripts(project: Path) -> dict:
    paths: list[str] = []

    def scan(relative: str) -> None:
        with os.scandir(project / relative) as entries:
            for entry in entries:
                path = relative + '/' + entry.name
                if entry.is_dir():
                    if not entry.name.startswith('.'):
                        scan(path)
                elif entry.name.endswith('.gd'):
                    paths.append(path)

    for root in SCAN_ROOTS:
        scan(root)
    return {'count': len(paths), 'sha256': sha('\n'.join(paths).encode()), 'paths': paths}


def active_project_godots(project: Path) -> list[int]:
    found: list[int] = []
    for process in Path('/proc').iterdir():
        if not process.name.isdecimal():
            continue
        try:
            executable = Path(os.readlink(process / 'exe')).name.lower()
            if not executable.startswith('godot'):
                continue
            args = [os.fsdecode(value) for value in (process / 'cmdline').read_bytes().split(b'\0') if value]
            for index, value in enumerate(args[:-1]):
                if value == '--path' and Path(args[index + 1]).resolve() == project:
                    found.append(int(process.name))
        except (OSError, ValueError):
            continue
    return found


def validate(main_result: Path, label: str) -> tuple[Path, list[dict], dict, dict]:
    require(re.fullmatch(r'city22-plaza-parse-overlay-[a-z0-9-]+', label) is not None,
            'Use a fresh city22-plaza-parse-overlay-* label.')
    require(not (HERE / (label + '-result.json')).exists(), 'Overlay label already has a result.')
    require(not list(RUNS.glob(label + '-*')), 'Engine label already exists.')
    require(not (HERE.parent / (label + '-thermal.json')).exists(), 'Guard label already exists.')
    manifest = json.loads(MANIFEST.read_text())
    project = Path(manifest['project']).resolve()
    require(project == Path('/tmp/sa-wp2-plazas'), 'Unexpected target project.')
    require(len(manifest['files']) == 7, 'Expected exactly seven runtime scripts.')
    clean = json.loads(main_result.read_text())
    require(Path(clean['project_root']).resolve() == ROOT, 'Prerequisite is not the production checkout.')
    require(clean.get('git_head') == EXPECTED_MAIN_HEAD, 'Prerequisite is not the d14 production source.')
    require(clean.get('actual_exit') == 0 and clean.get('runner_exit') == 0
            and clean.get('stop_reason') == 'completed' and clean.get('diagnostics') == [],
            'Prerequisite production audit is not clean; do not run this overlay.')
    require(AUDIT in clean['command'], 'Prerequisite did not run the original full audit.')
    require(clean['source_hashes'].get('tools/tests/ScriptParseAuditTest.gd') == AUDIT_SHA,
            'Prerequisite audit body changed.')
    require(sha((project / 'tools/tests/ScriptParseAuditTest.gd').read_bytes()) == AUDIT_SHA,
            'Candidate original audit body changed.')
    files: list[dict] = []
    for item in manifest['files']:
        relative = item['runtime_path']
        path = project / relative
        require(path.is_file() and not path.is_symlink(), 'Expected ordinary existing file: ' + relative)
        candidate = Path(item['candidate']['path']).read_bytes()
        baseline = Path(item['baseline']['path']).read_bytes()
        require(sha(candidate) == item['candidate']['sha256'], 'Candidate backup mismatch: ' + relative)
        require(sha(baseline) == item['baseline']['sha256'], 'Baseline backup mismatch: ' + relative)
        require(sha(path.read_bytes()) == sha(candidate), 'Live candidate source changed: ' + relative)
        require(clean['source_hashes'].get(relative) == sha(baseline),
                'Clean production prerequisite source differs from baseline: ' + relative)
        files.append({'relative': relative, 'path': path, 'candidate': candidate,
                      'baseline': baseline, 'inode': path.stat().st_ino})
    require(not active_project_godots(project), 'A Godot process currently reads the plaza project.')
    return project, files, clean, ordered_scripts(project)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--main-result', type=Path, required=True)
    parser.add_argument('--label', required=True)
    parser.add_argument('--timeout', type=int, default=420)
    parser.add_argument('--max-wait', type=int, default=900)
    parser.add_argument('--validate-only', action='store_true', help='Read-only validation; no source writes or engine.')
    args = parser.parse_args()
    project, files, clean, order = validate(args.main_result.resolve(), args.label)
    if args.validate_only:
        print(json.dumps({'validated': True, 'project': str(project), 'files': len(files),
                          'scan_count': order['count'], 'scan_order_sha256': order['sha256'],
                          'source_writes': 0, 'engines_started': 0}, indent=2), flush=True)
        return 0
    require(args.timeout > 0 and args.max_wait > 0, 'Timeouts must be positive.')
    command = [sys.executable, str(GUARD), '--label', args.label, '--project', str(project),
               '--timeout', str(args.timeout), '--max-wait', str(args.max_wait),
               '--start-temperature', '70', '--', '--headless', AUDIT]
    report = {'started_utc': now(), 'project': str(project), 'label': args.label,
              'prerequisite_result': str(args.main_result.resolve()),
              'prerequisite_sha256': sha(args.main_result.read_bytes()),
              'prerequisite_head': clean['git_head'], 'command': command,
              'guard_sha256': sha(GUARD.read_bytes()), 'source_before': {},
              'source_overlay': {}, 'source_restored': {}, 'scan_before': order,
              'signal_requests': [], 'exception': None, 'restore_errors': []}
    report_path = HERE / (args.label + '-result.json')
    log_path = HERE / (args.label + '-queue.log')
    previous_handlers = {}
    child: subprocess.Popen | None = None
    return_code = 1

    def requested(signum, _frame) -> None:
        report['signal_requests'].append({'signal': signum, 'utc': now()})
        print('Overlay interruption requested; awaiting owned guard exit before exact restoration.', flush=True)

    for signum in (signal.SIGINT, signal.SIGTERM):
        previous_handlers[signum] = signal.signal(signum, requested)
    try:
        for item in files:
            path = item['path']
            # In-place writes preserve the existing entry/inode and scan order.
            report['source_before'][item['relative']] = sha(path.read_bytes())
            path.write_bytes(item['baseline'])
            require(path.stat().st_ino == item['inode'], 'Inode changed: ' + item['relative'])
            require(path.read_bytes() == item['baseline'], 'Overlay verification failed: ' + item['relative'])
            report['source_overlay'][item['relative']] = sha(path.read_bytes())
        report['scan_overlay'] = ordered_scripts(project)
        require(report['scan_overlay'] == order, 'Source overlay changed traversal order.')
        require(not active_project_godots(project), 'A plaza Godot appeared before guard launch.')
        require(not report['signal_requests'], 'Interrupted before engine launch; restoring the candidate.')
        report_path.write_text(json.dumps(report, indent=2) + '\n')
        print('Seven baseline scripts applied in place; original audit queued through the guard.', flush=True)
        with log_path.open('x') as log:
            child = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
            while True:
                try:
                    return_code = child.wait(timeout=15)
                    break
                except subprocess.TimeoutExpired:
                    print('Overlay audit guard is still running or waiting for the engine slot.', flush=True)
    except BaseException as error:
        report['exception'] = type(error).__name__ + ': ' + str(error)
        # Never restore while this owned audit can still be reading the overlay.
        if child is not None and child.poll() is None:
            print('Waiting for owned guard to finish before restoration.', flush=True)
            child.wait()
        return_code = 1
    finally:
        for item in files:
            path = item['path']
            try:
                if path.exists() and path.read_bytes() not in (item['baseline'], item['candidate']):
                    unexpected = HERE / (args.label + '-unexpected') / (item['relative'] + '.data')
                    unexpected.parent.mkdir(parents=True, exist_ok=True)
                    unexpected.write_bytes(path.read_bytes())
                    report['restore_errors'].append('Unexpected concurrent bytes preserved: ' + str(unexpected))
                path.write_bytes(item['candidate'])
                digest = sha(path.read_bytes())
                report['source_restored'][item['relative']] = digest
                require(digest == sha(item['candidate']), 'Restored hash mismatch: ' + item['relative'])
                require(path.stat().st_ino == item['inode'], 'Restored inode mismatch: ' + item['relative'])
            except BaseException as error:
                report['restore_errors'].append(type(error).__name__ + ': ' + str(error))
        report['scan_restored'] = ordered_scripts(project)
        if report['scan_restored'] != order:
            report['restore_errors'].append('Traversal order differs after restoration.')
        report['guard_exit'] = child.returncode if child is not None else None
        report['engine_result_paths'] = [str(p) for p in RUNS.glob(args.label + '-*/run-results.json')]
        report['ended_utc'] = now()
        report['restored_exactly'] = (len(report['source_restored']) == len(files)
                                    and not report['restore_errors'])
        report_path.write_text(json.dumps(report, indent=2) + '\n')
        for signum, handler in previous_handlers.items():
            signal.signal(signum, handler)
    if log_path.exists():
        print(log_path.read_text(), flush=True)
    print(json.dumps({'guard_exit': report['guard_exit'], 'restored_exactly': report['restored_exactly'],
                      'restore_errors': report['restore_errors'], 'report': str(report_path)}, indent=2), flush=True)
    return return_code if report['restored_exactly'] and report['exception'] is None else 1


if __name__ == '__main__':
    raise SystemExit(main())
