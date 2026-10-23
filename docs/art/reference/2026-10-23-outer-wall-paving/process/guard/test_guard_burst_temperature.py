#!/usr/bin/env python3
"""Real owned fake-process lifecycle with controlled thermal sequences, no Godot.

--red runs one new-option case against the frozen old guard and should fail.
Normal mode covers default90, optional98 brief95 (one/two owned samples),
sustained85/95 for three samples, immediate98, and rejected97. Uses the existing
safe-named launcher fixture. Only copied ROOT, sensor and executable predicate
are adapted; real /proc identity, CPU affinity, sessions and signals remain live.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from test_guard_startup_discovery import DEFAULT, LAUNCHER, is_live

THERMAL = '''def temperature():
    try:
        pid=int((ROOT/'probe.pid').read_text())
        fields=(Path('/proc')/str(pid)/'stat').read_text().rsplit(')',1)[1].split()
        if fields[0]=='Z': return 60
    except (OSError,ValueError,IndexError): return 60
    counter=ROOT/'sensor-count'
    index=int(counter.read_text()) if counter.exists() else 0
    counter.write_text(str(index+1))
    sequence=json.loads(os.environ['GUARD_BURST_SEQUENCE'])
    return sequence[min(index,len(sequence)-1)]
'''
CASES = (
    ('default90', [95], (), 'thermal_limit', 90, 1),
    ('brief95-one', [95, 60], ('--burst-temperature', '98'), 'completed', 98, None),
    ('brief95-two', [95, 95, 60], ('--burst-temperature', '98'), 'completed', 98, None),
    ('sustained85', [85, 85, 85], ('--burst-temperature', '98'), 'thermal_limit', 98, 3),
    ('sustained95', [95, 95, 95], ('--burst-temperature', '98'), 'thermal_limit', 98, 3),
    ('immediate98', [98], ('--burst-temperature', '98'), 'thermal_limit', 98, 1),
    ('reject97', [60], ('--burst-temperature', '97'), 'argparse_reject', None, None),
)


def run_case(source, case):
    name, sequence, extra, expected, threshold, sample_count = case
    original = source.read_text()
    assert original.count("ROOT = Path('/home/user/Nauris/Synthetic-Ascension')") == 1
    assert original.count("exe.startswith('godot')") == 1
    with tempfile.TemporaryDirectory(prefix='sa-guard-burst-stub-') as temporary:
        root=Path(temporary)
        binary=root/'OwnedProbeStub'
        shutil.copyfile(Path(sys.executable).resolve(), binary)
        binary.chmod(0o700)
        launcher=root/'.superpowers/claude-city-20261021/sa_engine.py'
        launcher.parent.mkdir(parents=True)
        launcher.write_text(LAUNCHER)
        adapted=original.replace("ROOT = Path('/home/user/Nauris/Synthetic-Ascension')", 'ROOT = Path('+repr(str(root))+')')
        adapted=adapted.replace("exe.startswith('godot')", "exe.startswith('ownedprobestub')")
        first=adapted.index('def temperature():')
        last=adapted.index('\ndef run(', first)
        adapted=adapted[:first]+THERMAL+adapted[last:]
        guard=root/'guard.py'
        guard.write_text(adapted)
        canary=subprocess.Popen([str(binary), '-c', 'import time;time.sleep(20)',
            '--path', str(root/'foreign'), '--log-file', str(root/'foreign.log')], start_new_session=True)
        env=os.environ|{'GUARD_STARTUP_ROOT':str(root), 'GUARD_STARTUP_PROGRAM':'import time;time.sleep(4.1)',
                        'GUARD_BURST_SEQUENCE':json.dumps(sequence)}
        command=[sys.executable, str(guard), '--label', name, '--project', str(root),
                 '--cpu-count', '1', '--duty-percent', '10', '--timeout', '6', *extra]
        child=None
        started=time.monotonic()
        try:
            child=subprocess.Popen(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            stdout,_=child.communicate(timeout=8)
            report_path=root/(name+'-thermal.json')
            report=json.loads(report_path.read_bytes()) if report_path.exists() else None
            identity=json.loads((root/'identity.json').read_bytes()) if (root/'identity.json').exists() else None
            canary_state=(Path('/proc')/str(canary.pid)/'stat').read_text().rsplit(')',1)[1].split()[0]
            failures=[]
            def require(ok,message):
                if not ok: failures.append(message)
            require(canary.poll() is None and canary_state!='T', 'foreign canary was stopped/terminated')
            if expected=='argparse_reject':
                require(child.returncode==2 and report is None and identity is None, 'unsupported threshold97 was not rejected before launch')
            else:
                require(report is not None, 'guard produced no thermal receipt (new option unsupported)')
                require(identity is not None, 'owned fake engine did not launch')
                if report is not None and identity is not None:
                    active=[s for s in report['samples'] if s['owned_engine_live']]
                    require(report['reason']==expected, 'actual guard terminal reason differs')
                    require(report['runtime_temperature_stop_c']==threshold, 'burst threshold receipt differs')
                    require(report['sustained_temperature_stop_c']==85 and report['sustained_temperature_samples']==3
                            and report['start_temperature_c']==65, 'sustained/start bounds changed')
                    require(report['cpu_affinity']==[0] and identity['affinity']==[0], 'single-CPU affinity differs')
                    require(identity['pid']==identity['pgid'] and identity['exe']==str(binary)
                            and report['owned_pids']==[identity['pid']], 'exact owned identity/session differs')
                    require(report['duty_cycle']==.1 and report['duty_run_seconds']==.05
                            and report['duty_pause_seconds']==.45 and report['release_marker'] is None
                            and report['duty_released'] is False and report['throttle_cycles']>0, 'bounded active duty differs')
                    require(bool(active) and [s['package_c'] for s in active] ==
                            [sequence[min(i,len(sequence)-1)] for i in range(len(active))],
                            'controlled thermal sequence differs')
                    if sample_count is not None:
                        require(len(active)==sample_count, 'thermal stop did not occur at exact expected sample')
                    if expected=='completed':
                        require(child.returncode==0 and len(active)>=3, 'brief burst did not complete through cool sample')
                        require([s['package_c'] for s in active].count(95)==sequence.count(95), 'brief95 sample count differs')
                    else:
                        require(child.returncode!=0, 'thermal stop returned success')
                    require(not is_live(identity['pid']) and (root/'launcher-cleaned').exists(), 'owned fake engine/launcher cleanup incomplete')
            return {'case':name, 'expected_reason':expected, 'sequence':sequence,
                    'elapsed_seconds':round(time.monotonic()-started,3), 'guard_exit':child.returncode,
                    'identity':identity, 'thermal':report, 'foreign_canary_live_and_unstopped':canary.poll() is None and canary_state!='T',
                    'assertion_failures':failures, 'guard_stdout':stdout[-1800:]}
        finally:
            if child is not None and child.poll() is None:
                child.terminate();child.wait(timeout=2)
            if (root/'probe.pid').exists():
                pid=int((root/'probe.pid').read_text())
                if is_live(pid):
                    os.kill(pid,signal.SIGCONT);os.killpg(pid,signal.SIGTERM)
            if canary.poll() is None: canary.terminate()
            canary.wait(timeout=2)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=DEFAULT)
    parser.add_argument('--red',action='store_true')
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    if args.output.exists(): raise SystemExit('Refusing existing receipt '+str(args.output))
    cases=CASES[1:2] if args.red else CASES
    results=[run_case(args.source,case) for case in cases]
    report={'source':str(args.source.resolve()),'source_sha256':hashlib.sha256(args.source.read_bytes()).hexdigest(),
            'real_godot_started':False,'temperature_is_simulated':True,'cases':results,
            'failed_cases':sum(bool(r['assertion_failures']) for r in results)}
    args.output.write_text(json.dumps(report,indent=2)+'\n')
    for result in results:print(result['case'], 'FAIL' if result['assertion_failures'] else 'PASS', result['assertion_failures'])
    print('REPORT',args.output)
    raise SystemExit(bool(report['failed_cases']))


if __name__=='__main__':main()
