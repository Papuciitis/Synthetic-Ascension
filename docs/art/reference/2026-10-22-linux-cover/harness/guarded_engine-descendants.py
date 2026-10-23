from pathlib import Path
import argparse, json, os, signal, subprocess, time

ROOT = Path('/home/user/Nauris/Synthetic-Ascension')
BASE = Path(__file__).resolve().parent

def temperature():
    for hw in Path('/sys/class/hwmon').glob('hwmon*'):
        try:
            if (hw/'name').read_text().strip() != 'coretemp': continue
            for label in hw.glob('temp*_label'):
                if label.read_text().strip().startswith('Package'):
                    return int((hw/label.name.replace('_label', '_input')).read_text())/1000
        except OSError: pass
    return None

def run(label, args, timeout=240, release_marker=None):
    label += ''
    thermal = BASE/(label+'-thermal.json')
    assert not thermal.exists(), thermal
    cmd = ['taskset','-c','0,1','python3',str(ROOT/'.superpowers/claude-city-20261021/sa_engine.py'),
           '--name',label,'--project',str(Path(options.project).resolve()),'--exclusive','--timeout',str(timeout),
           '--max-wait','180','--tail','3','--',*args]
    env = os.environ|{'SA_ENGINE_SLOTS':'1','SA_ENGINE_THERMAL_LIMIT_C':'65','SA_FULL_PROVENANCE':'1'}
    env.pop('INTEL_DEBUG',None); env.pop('MESA_SHADER_CACHE_DISABLE',None)
    started=time.monotonic(); samples=[]; owned=set(); hot=0; last=-10; discovery_at=-10; marker_logs={}; reason='completed'; released=False; cycles=0
    with (BASE/(label+'-wrapper.log')).open('w') as log:
        proc=subprocess.Popen(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
        while proc.poll() is None:
            now=time.monotonic()
            if now-last>=1:
                last=now; value=temperature()
                samples.append({'elapsed_seconds':round(now-started,3),'package_c':value,'duty_released':released})
                hot=hot+1 if value is not None and value>=85 else 0
                if (value is not None and value>=90) or hot>=3:
                    reason='thermal_limit'
                    for pid in owned:
                        try: os.kill(pid,signal.SIGCONT)
                        except ProcessLookupError: pass
                    os.killpg(proc.pid,signal.SIGTERM)
                    try: proc.wait(timeout=10)
                    except subprocess.TimeoutExpired: os.killpg(proc.pid,signal.SIGKILL); proc.wait()
                    break
            if not released:
                # Discover at thermal-poll cadence, then retain the exact owned
                # PID/log pair. A full /proc scan at every duty tick needlessly
                # heats a queued launcher before Godot even starts.
                if not owned and now-discovery_at>=1.0:
                    discovery_at=now
                    token=('/runs/'+label+'-').encode()
                    pending=[proc.pid]
                    while pending:
                        entry=Path('/proc')/str(pending.pop())
                        try:
                            children=entry/'task'/entry.name/'children'
                            pending.extend(int(value) for value in children.read_text().split())
                            pid=int(entry.name); exe=Path(os.readlink(entry/'exe')).name.lower()
                            arguments=(entry/'cmdline').read_bytes().split(b'\0')
                            matches=[a for a in arguments if token in a and a.endswith(b'/logs/engine.log')]
                            if exe.startswith('godot') and matches and os.getpgid(pid)==pid:
                                owned.add(pid)
                                marker_logs[pid]=Path(os.fsdecode(matches[0])).with_name('stdout.log')
                        except (OSError,ProcessLookupError): pass
                if release_marker:
                    for stdout in marker_logs.values():
                        if stdout.exists() and release_marker.encode() in stdout.read_bytes(): released=True
                if owned and not released:
                    time.sleep(.05)
                    for pid in owned:
                        try: os.kill(pid,signal.SIGSTOP)
                        except ProcessLookupError: pass
                    try: time.sleep(.15)
                    finally:
                        for pid in owned:
                            try: os.kill(pid,signal.SIGCONT)
                            except ProcessLookupError: pass
                    cycles+=1
                else: time.sleep(.2)
            else: time.sleep(.5)
        rc=proc.wait()
    thermal.write_text(json.dumps({'command':cmd,'environment_overrides':{k:env[k] for k in ['SA_ENGINE_SLOTS','SA_ENGINE_THERMAL_LIMIT_C','SA_FULL_PROVENANCE']},
        'cpu_affinity':[0,1],'runtime_temperature_stop_c':90,'sustained_temperature_stop_c':85,'sustained_temperature_samples':3,
        'reason':reason,'duty_cycle':.25,'release_marker':release_marker,'duty_released':released,'throttle_cycles':cycles,
        'owned_pids':sorted(owned),'wrapper_exit':rc,'samples':samples},indent=2)+'\n')
    print((BASE/(label+'-wrapper.log')).read_text(),flush=True)
    print('THERMAL',label,reason,'peak',max((s['package_c'] or 0 for s in samples),default=0),flush=True)
    if rc or reason!='completed': raise SystemExit(rc or 1)

parser=argparse.ArgumentParser()
parser.add_argument('--label',required=True)
parser.add_argument('--project',required=True)
parser.add_argument('--timeout',type=int,default=300)
parser.add_argument('--release-marker')
parser.add_argument('args',nargs=argparse.REMAINDER)
options=parser.parse_args()
args=options.args[1:] if options.args[:1]==['--'] else options.args
run(options.label,args,options.timeout,options.release_marker)
