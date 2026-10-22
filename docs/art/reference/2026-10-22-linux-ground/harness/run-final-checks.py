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
    label += options.suffix
    thermal = BASE/(label+'-thermal.json')
    assert not thermal.exists(), thermal
    cmd = ['taskset','-c','0,1','python3',str(ROOT/'.superpowers/claude-city-20261021/sa_engine.py'),
           '--name',label,'--project',str(ROOT),'--exclusive','--timeout',str(timeout),
           '--max-wait','180','--tail','3','--',*args]
    env = os.environ|{'SA_ENGINE_SLOTS':'1','SA_ENGINE_THERMAL_LIMIT_C':'65','SA_FULL_PROVENANCE':'1'}
    env.pop('INTEL_DEBUG',None); env.pop('MESA_SHADER_CACHE_DISABLE',None)
    started=time.monotonic(); samples=[]; owned=set(); hot=0; last=-10; reason='completed'; released=False; cycles=0
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
                token=('/runs/'+label+'-').encode()
                for entry in Path('/proc').iterdir():
                    if not entry.name.isdigit(): continue
                    try:
                        pid=int(entry.name); exe=Path(os.readlink(entry/'exe')).name.lower()
                        arguments=(entry/'cmdline').read_bytes().split(b'\0')
                        matches=[a for a in arguments if token in a and a.endswith(b'/logs/engine.log')]
                        if exe.startswith('godot') and matches and os.getpgid(pid)==pid:
                            owned.add(pid)
                            if release_marker:
                                stdout=Path(os.fsdecode(matches[0])).with_name('stdout.log')
                                if stdout.exists() and release_marker.encode() in stdout.read_bytes(): released=True
                    except (OSError,ProcessLookupError): pass
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

parser=argparse.ArgumentParser(); parser.add_argument('phase',choices=['checks','surveys','live']); parser.add_argument('--suffix',default=''); options=parser.parse_args()
native=['--rendering-driver','opengl3','--audio-driver','Dummy']
if options.phase=='checks':
    for short,suite in [('policy','DistrictGroundPolicyTest'),('splat','WorldGroundSplatTest'),('care','CityGroundCareTest'),
                        ('care-natural','CityGroundCareNaturalTest'),('material-cache','GroundMaterialCacheTest'),
                        ('generation-material','CityGenerationMaterialTest')]:
        run('ground22-merged-'+short,['--headless','res://tools/tests/'+suite+'.tscn'])
    for short,suite in [('footway','CityFootwayEdgeRenderTest'),('dry','ThemeAtmosphereDryReceiverTest')]:
        run('ground22-merged-'+short,[*native,'res://tools/tests/'+suite+'.tscn'])
    run('ground22-merged-parse',['--headless','res://tools/tests/ScriptParseAuditTest.tscn'])
elif options.phase=='surveys':
    for short,segment,theme in [('s2',2,'service_courtyards'),('s6',6,'industrial_cutthrough'),('s7a',7,'underpass_veins'),('s7b',7,'canal_services')]:
        output=BASE/('final-'+short)
        assert not output.exists(), output
        run('ground22-final-'+short,[*native,'res://tools/dev/CitySegmentSurvey.tscn','--',f'--segment={segment}',
            '--world-seed=16102026','--theme='+theme,'--route-points=2','--kit-points=2','--out='+str(output)],timeout=300)
else:
    run('ground22-merged-occupied',[*native,'res://tools/dev/WorldCoverStreamingProfile.tscn','--','--visible','--review=small',
        '--segment=2','--world-seed=16102026','--start=608,7392','--waypoints=2208,7392:608,7392',
        '--warmup=6','--route-timeout=75','--fps-cap=60','--profile-label=ground22-merged-occupied','--out='+str(BASE/'occupied')],
        timeout=300,release_marker='[Game] ready')
