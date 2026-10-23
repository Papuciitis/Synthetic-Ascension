"""Read-only actual reused parse/S2 admission, plus small forged-state negatives."""
from copy import deepcopy
import importlib.util
import json
from pathlib import Path
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location('street_remaining_continuation_test', HERE / 'continuation.py')
C = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(C)
plan = C.read(HERE / 'command-plan.json')
pins = C.read(HERE.parent / 'street-pickup-r2/source-bindings.json')
old = C.read(C.OLD_QUEUE)
checks = 0
for case in plan['reused_cases']:
    value = C.case_evidence(case, pins)
    assert value['id'] == case['id'] and value['project_state']['tracked_status'] == ''
    if case['id'] == 's2':
        assert value['original_r2_collection_verdict']['valid'] is False
        assert value['corrected_r3_collection_verdict']['valid'] is True
    checks += 1
case = plan['reused_cases'][1]
raw_path = Path(old['cases'][1]['run']['path'])
actual_raw = C.read(raw_path)
real_read = C.read
for field, value in [('git_head', 'other-commit'), ('git_status_porcelain', ' M runtime.gd')]:
    forged = deepcopy(actual_raw); forged[field] = value
    with patch.object(C, 'read', side_effect=lambda path, data=forged: data if Path(path) == raw_path else real_read(path)):
        try:
            C.case_evidence(case, pins)
        except ValueError:
            checks += 1
        else:
            raise AssertionError('Forged project state accepted: ' + field)
sidecars = deepcopy(actual_raw); sidecars['source_untracked'].append('assets/offline-fixture.png.import')
with patch.object(C, 'read', side_effect=lambda path: sidecars if Path(path) == raw_path else real_read(path)):
    value = C.case_evidence(case, pins)
    assert value['project_state']['source_untracked'] == sidecars['source_untracked']
    checks += 1
with patch.object(C, 'frozen_protocol', return_value=(C.read(HERE / 'source-bindings.json'), pins, old, plan)):
    result = C.evidence(False)
    assert result['status'] == 'reused_parse_s2_checked_remaining_native_pending'
    assert [row['id'] for row in result['cases']] == ['parse', 's2']
    assert result['original_r2_queue']['status'] == 'stopped'
    assert [row['id'] for row in result['remaining_manual_commands']] == ['s7', 's6']
    checks += 1
    try:
        C.evidence(True)
    except (ValueError, RuntimeError, OSError):
        checks += 1
    else:
        raise AssertionError('Unfinished remaining native cases incorrectly accepted')
print(json.dumps({'status': 'passed', 'checks': checks, 'scope': 'Actual static reused raw/guard/command/source/physical/image evidence and forged raw state rejection. Frozen preflight stubbed only to avoid current-project scans during root temporary reward-before source; no engine rerun or completed remaining-case claim.'}))
