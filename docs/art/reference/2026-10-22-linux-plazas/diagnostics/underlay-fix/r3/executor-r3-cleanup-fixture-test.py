#!/usr/bin/env python3
"""Only tiny JSON/byte fixtures; no processes, engines or real cache changes."""
from pathlib import Path
import importlib.util
import json
import os
import tempfile
import time

script = Path(__file__).with_name('root-underlay-red-green-r3.py')
spec = importlib.util.spec_from_file_location('underlay_executor_r2', script)
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
passed = []
with tempfile.TemporaryDirectory(prefix='sa-underlay-cleanup-fixture-') as name:
    root = Path(name); module.BASE = root
    (root / 'guarded_engine.py').write_bytes(b'guard fixture')
    row = {'label': 'fixture', 'command': ['python', 'guard', '--', '--headless', 'fixture.tscn'], 'guard_started_unix_ns': time.time_ns(), 'guard_source_sha256': module.sha(root / 'guarded_engine.py')}
    final = root / 'fixture-thermal.json'
    normal = {'command': ['python', 'sa_engine', '--name', 'fixture', '--project', str(module.PROJECT), '--', '--headless', 'fixture.tscn'], 'wrapper_exit': 1, 'reason': 'completed', 'received_signal': None}
    def check(label, record, allowed, stale=False):
        if final.exists(): final.unlink()
        if record is not None:
            final.write_text(json.dumps(record))
            stamp = row['guard_started_unix_ns'] - 100 if stale else row['guard_started_unix_ns'] + 100
            os.utime(final, ns=(stamp, stamp))
        try:
            module.guard_cleanup_record(row)
            assert allowed, label + ' should refuse rollback'
        except RuntimeError:
            assert not allowed, label + ' should admit confirmed cleanup'
        passed.append(label)
    check('missing-final-record-refuses', None, False)
    check('stale-final-record-refuses', normal, False, True)
    check('wrong-label-refuses', dict(normal, command=['--name', 'other', '--project', str(module.PROJECT)]), False)
    check('wrong-project-refuses', dict(normal, command=['--name', 'fixture', '--project', '/tmp/other', '--headless', 'fixture.tscn']), False)
    check('incomplete-record-refuses', dict(normal, reason='running', wrapper_exit=None), False)
    check('normal-expected-failure-final-admits', normal, True)
    check('thermal-final-admits', dict(normal, reason='thermal_limit', wrapper_exit=-15), True)
    check('sigterm-final-admits', dict(normal, reason='external_sigterm', received_signal=15, wrapper_exit=-15), True)
    check('sigint-final-admits', dict(normal, reason='external_sigint', received_signal=2, wrapper_exit=-2), True)
    (root / 'guarded_engine.py').write_bytes(b'changed guard fixture')
    check('changed-guard-source-refuses', normal, False)
print(json.dumps({'passed': len(passed), 'cases': passed, 'engines': 0, 'subprocesses': 0, 'real_project_mutations': 0}))
