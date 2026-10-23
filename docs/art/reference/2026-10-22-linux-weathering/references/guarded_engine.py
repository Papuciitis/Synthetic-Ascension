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
           '--max-wait',str(options.max_wait),'--tail','3','--',*args]
    env = os.environ|{'SA_ENGINE_SLOTS':'1','SA_ENGINE_THERMAL_LIMIT_C':str(options.start_temperature),'SA_FULL_PROVENANCE':'1'}
    env.pop('INTEL_DEBUG',None); env.pop('MESA_SHADER_CACHE_DISABLE',None)
    started=time.monotonic(); samples=[]; owned=set(); hot=0; last=-10; marker_logs={}; identities={}; reason='completed'; released=False; cycles=0
    duty=options.duty_percent/100.0; pause_seconds=.05*(1.0-duty)/duty
    received_signal=None
    token=('/runs/'+label+'-').encode()
    project=os.fsencode(str(Path(options.project).resolve()))

    def identity(pid):
        entry=Path('/proc')/str(pid)
        try:
            stat=(entry/'stat').read_text().rsplit(')',1)[1].split()
            executable=os.readlink(entry/'exe'); exe=Path(executable).name.lower()
            arguments=(entry/'cmdline').read_bytes().split(b'\0')
            matches=[a for a in arguments if token in a and a.endswith(b'/logs/engine.log')]
            paths=[arguments[i+1] for i,a in enumerate(arguments[:-1]) if a==b'--path']
            if stat[0]=='Z' or not exe.startswith('godot') or not matches or paths!=[project] or os.getpgid(pid)!=pid:
                return None
            return (stat[19],executable,matches[0])
        except (OSError,ProcessLookupError,IndexError):
            return None

    def live_owned():
        for pid in list(identities):
            if identity(pid)!=identities[pid]:
                identities.pop(pid,None); marker_logs.pop(pid,None)
        return set(identities)

    def discover(proc):
        pending=[proc.pid]
        while pending:
            entry=Path('/proc')/str(pending.pop())
            try:
                pending.extend(int(value) for value in (entry/'task'/entry.name/'children').read_text().split())
                pid=int(entry.name); found=identity(pid)
                if found is not None:
                    owned.add(pid); identities[pid]=found
                    marker_logs[pid]=Path(os.fsdecode(found[2])).with_name('stdout.log')
            except (OSError,ProcessLookupError): pass

    def stop_launcher(proc):
        # Discover before cleanup too, then resume only still-identical owners.
        discover(proc)
        for pid in live_owned():
            try: os.kill(pid,signal.SIGCONT)
            except ProcessLookupError: pass
        if proc.poll() is None:
            try:
                if os.getpgid(proc.pid)==proc.pid: os.killpg(proc.pid,signal.SIGTERM)
            except ProcessLookupError: pass
            try: proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                try:
                    if os.getpgid(proc.pid)==proc.pid: os.killpg(proc.pid,signal.SIGKILL)
                except ProcessLookupError: pass
                proc.wait()

    def interrupted(signum,_frame):
        nonlocal received_signal
        received_signal=signum

    previous={sig:signal.getsignal(sig) for sig in [signal.SIGTERM,signal.SIGINT]}
    for sig in previous: signal.signal(sig,interrupted)
    try:
        with (BASE/(label+'-wrapper.log')).open('w') as log:
            proc=subprocess.Popen(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
            while True:
                if received_signal is not None:
                    reason='external_'+signal.Signals(received_signal).name.lower()
                    stop_launcher(proc)
                    break
                if proc.poll() is not None: break
                now=time.monotonic()
                if now-last>=1:
                    last=now
                    # Validate cached start-time/executable/arguments/PGID, then
                    # discover before temperature. Queue heat is not runtime heat.
                    if not live_owned(): discover(proc)
                    value=temperature()
                    active=live_owned()
                    samples.append({'elapsed_seconds':round(now-started,3),'package_c':value,'duty_released':released,
                                    'owned_engine_live':bool(active),'live_owned_pids':sorted(active)})
                    hot=hot+1 if active and value is not None and value>=85 else 0
                    if active and ((value is not None and value>=90) or hot>=3):
                        reason='thermal_limit'; stop_launcher(proc)
                        break
                if not released:
                    if release_marker:
                        for stdout in marker_logs.values():
                            if stdout.exists() and release_marker.encode() in stdout.read_bytes(): released=True
                    if live_owned() and not released:
                        time.sleep(.05)
                        for pid in live_owned():
                            try: os.kill(pid,signal.SIGSTOP)
                            except ProcessLookupError: pass
                        try: time.sleep(pause_seconds)
                        finally:
                            for pid in live_owned():
                                try: os.kill(pid,signal.SIGCONT)
                                except ProcessLookupError: pass
                        cycles+=1
                    else: time.sleep(.2)
                else: time.sleep(.5)
            rc=proc.wait()
        if received_signal is not None: reason='external_'+signal.Signals(received_signal).name.lower()
        thermal.write_text(json.dumps({'command':cmd,'environment_overrides':{k:env[k] for k in ['SA_ENGINE_SLOTS','SA_ENGINE_THERMAL_LIMIT_C','SA_FULL_PROVENANCE']},
            'cpu_affinity':[0,1],'start_temperature_c':options.start_temperature,'runtime_temperature_stop_c':90,'sustained_temperature_stop_c':85,'sustained_temperature_samples':3,
            'reason':reason,'received_signal':received_signal,'duty_cycle':duty,'duty_run_seconds':.05,'duty_pause_seconds':pause_seconds,'release_marker':release_marker,'duty_released':released,'throttle_cycles':cycles,
            'owned_pids':sorted(owned),'wrapper_exit':rc,'samples':samples},indent=2)+'\n')
        print((BASE/(label+'-wrapper.log')).read_text(),flush=True)
        print('THERMAL',label,reason,'peak',max((s['package_c'] or 0 for s in samples),default=0),flush=True)
    finally:
        for sig,handler in previous.items(): signal.signal(sig,handler)
    if received_signal is not None: raise SystemExit(128+received_signal)
    if rc or reason!='completed': raise SystemExit(rc or 1)

parser=argparse.ArgumentParser()
parser.add_argument('--label',required=True)
parser.add_argument('--project',required=True)
parser.add_argument('--timeout',type=int,default=300)
parser.add_argument('--release-marker')
parser.add_argument('--duty-percent',type=int,choices=[10,25],default=25)
parser.add_argument('--start-temperature',type=float,choices=[65.0,70.0],default=65.0)
parser.add_argument('--max-wait',type=int)
parser.add_argument('args',nargs=argparse.REMAINDER)
options=parser.parse_args()
if options.max_wait is None: options.max_wait=900 if options.start_temperature==70 else 180
args=options.args[1:] if options.args[:1]==['--'] else options.args
run(options.label,args,options.timeout,options.release_marker)
