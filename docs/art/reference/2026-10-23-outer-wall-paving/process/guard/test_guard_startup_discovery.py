#!/usr/bin/env python3
"""Bounded real-/proc startup regression using a safe-named CPU stub, never Godot.

Run frozen old source with --expect startup-gap, then changed source with
--expect throttled. Only isolated copied guard ROOT, thermal reader and asserted
executable-name predicate are adapted. No actual engine slot or hardware sensor
is used. JSON is printed; use --output to preserve a receipt outside the tempdir.
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

DEFAULT = Path(__file__).resolve().parents[1] / 'continuation-20261022/guarded_engine.py'
PROBE = r'''import time
until=time.monotonic()+1.6
value=1
while time.monotonic()<until:
    for _ in range(1000): value=(value*17+3)%1000003
'''
LAUNCHER = r'''from pathlib import Path
import json, os, signal, subprocess, sys, time
root=Path(os.environ['GUARD_STARTUP_ROOT'])
label=sys.argv[sys.argv.index('--name')+1]
project=Path(sys.argv[sys.argv.index('--project')+1])
logs=root/'.superpowers/claude-city-20261021/runs'/(label+'-1')/'logs'
logs.mkdir(parents=True,exist_ok=True)
(logs/'stdout.log').write_text('')
child=None
def cleanup(signum=None,frame=None):
    if child is not None and child.poll() is None:
        try:
            os.kill(child.pid,signal.SIGCONT)
            os.killpg(child.pid,signal.SIGTERM)
        except ProcessLookupError: pass
        child.wait(timeout=1)
    (root/'launcher-cleaned').write_text(str(signum))
    if signum is not None: raise SystemExit(0)
signal.signal(signal.SIGTERM,cleanup)
signal.signal(signal.SIGINT,cleanup)
time.sleep(.05)
child=subprocess.Popen([str(root/'OwnedProbeStub'),'-c',os.environ['GUARD_STARTUP_PROGRAM'],
    '--path',str(project),'--log-file',str(logs/'engine.log')],start_new_session=True)
(root/'probe.pid').write_text(str(child.pid))
(root/'identity.json').write_text(json.dumps({'pid':child.pid,'pgid':os.getpgid(child.pid),
    'affinity':sorted(os.sched_getaffinity(child.pid)),'exe':os.readlink('/proc/'+str(child.pid)+'/exe')}))
child.wait(timeout=5)
cleanup()
'''
THERMAL = '''def temperature():
    pid_file=ROOT/'probe.pid'
    try:
        fields=(Path('/proc')/pid_file.read_text().strip()/'stat').read_text().rsplit(')',1)[1].split()
        cpu=(int(fields[11])+int(fields[12]))/os.sysconf('SC_CLK_TCK')
        with (ROOT/'observed-cpu.jsonl').open('a') as output:
            output.write(json.dumps({'cpu_seconds':cpu,'temperature_c':95 if cpu>.25 else 60})+'\\n')
        return 95 if cpu>.25 else 60
    except (OSError,ValueError,IndexError): return 60
'''


def is_live(pid):
    try:
        return (Path('/proc')/str(pid)/'stat').read_text().rsplit(')',1)[1].split()[0] != 'Z'
    except OSError:
        return False


def run(source, expect):
    original = source.read_text()
    assert original.count("ROOT = Path('/home/user/Nauris/Synthetic-Ascension')") == 1
    assert original.count("exe.startswith('godot')") == 1
    with tempfile.TemporaryDirectory(prefix='sa-guard-startup-stub-') as temporary:
        root = Path(temporary)
        binary = root / 'OwnedProbeStub'
        shutil.copyfile(Path(sys.executable).resolve(), binary)
        binary.chmod(0o700)
        launcher = root / '.superpowers/claude-city-20261021/sa_engine.py'
        launcher.parent.mkdir(parents=True)
        launcher.write_text(LAUNCHER)
        adapted = original.replace("ROOT = Path('/home/user/Nauris/Synthetic-Ascension')", 'ROOT = Path('+repr(str(root))+')')
        adapted = adapted.replace("exe.startswith('godot')", "exe.startswith('ownedprobestub')")
        first = adapted.index('def temperature():')
        last = adapted.index('\ndef run(', first)
        adapted = adapted[:first]+THERMAL+adapted[last:]
        guard = root / 'guard.py'
        guard.write_text(adapted)
        # Same safe executable name, outside owned launch tree, wrong project/log.
        canary = subprocess.Popen([str(binary), '-c', 'import time;time.sleep(20)',
            '--path', str(root/'foreign'), '--log-file', str(root/'foreign.log')], start_new_session=True)
        env = os.environ | {'GUARD_STARTUP_ROOT': str(root), 'GUARD_STARTUP_PROGRAM': PROBE}
        command = [sys.executable, str(guard), '--label', 'startup-stub', '--project', str(root),
            '--cpu-count', '1', '--duty-percent', '10', '--timeout', '5']
        child = None
        started = time.monotonic()
        try:
            child = subprocess.Popen(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            stdout, _ = child.communicate(timeout=7)
            elapsed = round(time.monotonic()-started, 3)
            report = json.loads((root/'startup-stub-thermal.json').read_text())
            identity = json.loads((root/'identity.json').read_text())
            observations = [json.loads(line) for line in (root/'observed-cpu.jsonl').read_text().splitlines()]
            canary_state = (Path('/proc')/str(canary.pid)/'stat').read_text().rsplit(')',1)[1].split()[0]
            failures = []
            def require(condition, message):
                if not condition: failures.append(message)
            require(identity['pgid'] == identity['pid'], 'stub did not own its new process group')
            require(identity['exe'] == str(binary), 'stub executable identity did not match copied ELF')
            require(identity['affinity'] == [0] and report['cpu_affinity'] == [0], 'single-CPU affinity differs')
            require(report['owned_pids'] == [identity['pid']], 'guard owned PID set differs from exact stub PID')
            require(report['runtime_temperature_stop_c'] == 90 and report['sustained_temperature_stop_c'] == 85
                and report['sustained_temperature_samples'] == 3, 'runtime thresholds changed')
            require(report['start_temperature_c'] == 65 and report['duty_cycle'] == .1
                and not report['duty_released'], 'start/duty bounds differ')
            require(not is_live(identity['pid']), 'owned stub survived guard completion')
            require((root/'launcher-cleaned').exists(), 'owned fake launcher did not clean up')
            require(canary.poll() is None and canary_state != 'T', 'foreign canary was stopped or terminated')
            if expect == 'startup-gap':
                require(report['reason'] == 'thermal_limit' and report['throttle_cycles'] == 0,
                    'old guard did not reproduce unthrottled startup thermal stop')
                require(max(x['cpu_seconds'] for x in observations) > .25, 'old stub did not exceed CPU budget')
            else:
                require(child.returncode == 0 and report['reason'] == 'completed', 'new guard did not finish')
                require(report['throttle_cycles'] >= 1, 'new guard never actually duty-stopped stub')
                require(all(x['temperature_c'] == 60 for x in observations), 'new stub exceeded simulated thermal budget')
            return {'source':str(source.resolve()),'source_sha256':hashlib.sha256(original.encode()).hexdigest(),
                'expect':expect,'real_godot_started':False,'temperature_is_simulated':True,
                'elapsed_seconds':elapsed,'guard_exit':child.returncode,'identity':identity,
                'foreign_canary_live_and_unstopped':canary.poll() is None and canary_state != 'T',
                'cpu_observations':observations,'thermal':report,'assertion_failures':failures,
                'guard_stdout':stdout[-1500:]}
        finally:
            if child is not None and child.poll() is None:
                child.terminate()
                child.wait(timeout=2)
            # Only own exact fake PID/groups; no broad process-name signaling.
            pid_file=root/'probe.pid'
            if pid_file.exists():
                pid=int(pid_file.read_text())
                if is_live(pid):
                    os.kill(pid,signal.SIGCONT)
                    os.killpg(pid,signal.SIGTERM)
            if canary.poll() is None:
                canary.terminate()
            canary.wait(timeout=2)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=DEFAULT)
    parser.add_argument('--expect',choices=['startup-gap','throttled'],required=True)
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    result=run(args.source,args.expect)
    body=json.dumps(result,indent=2)+'\n'
    if args.output:
        if args.output.exists(): raise SystemExit('Refusing to overwrite '+str(args.output))
        args.output.write_text(body)
    print(body,end='')
    raise SystemExit(bool(result['assertion_failures']))


if __name__=='__main__':
    main()
