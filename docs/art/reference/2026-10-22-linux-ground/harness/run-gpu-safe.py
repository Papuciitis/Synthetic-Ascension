from pathlib import Path
import subprocess,os,json,time,signal,sys
root=Path('/home/user/Nauris/Synthetic-Ascension');base=Path(__file__).resolve().parent

def temperature():
 for h in Path('/sys/class/hwmon').glob('hwmon*'):
  try:
   if (h/'name').read_text().strip()!='coretemp':continue
   for f in h.glob('temp*_label'):
    if f.read_text().strip().startswith('Package'):return int((h/f.name.replace('_label','_input')).read_text())/1000.0
  except OSError:pass
 return None

for label,segment,theme,point in [('ground22-gpu-s2-start-safe',2,'service_courtyards','start'),('ground22-gpu-s2-route1-safe',2,'service_courtyards','route1'),('ground22-gpu-s7b-start-safe',7,'canal_services','start'),('ground22-gpu-s7b-route1-safe',7,'canal_services','route1')]:
 output=base/(label+'.json')
 assert not output.exists(),output
 variants='none,current,phase1='+str(base/'variants/phase1.gdshader')
 cmd=['taskset','-c','0,1','python3',str(root/'.superpowers/claude-city-20261021/sa_engine.py'),'--name',label,'--project','/tmp/sa-wp2-ground','--exclusive','--timeout','300','--max-wait','180','--tail','2','--','--rendering-driver','opengl3','--audio-driver','Dummy','res://tools/dev/GroundShaderCostProbe.tscn','--',f'--segment={segment}',f'--theme={theme}','--variants='+variants,'--rounds=3','--frames=120','--warmup=30','--cooldown-seconds=2','--sample-fps=60','--points='+point,'--json='+str(output)]
 env=os.environ|{'SA_ENGINE_SLOTS':'1','SA_ENGINE_THERMAL_LIMIT_C':'65','SA_FULL_PROVENANCE':'1'}
 env.pop('INTEL_DEBUG',None);env.pop('MESA_SHADER_CACHE_DISABLE',None)
 started=time.monotonic();samples=[];reason='completed';hot_samples=0;sampling_started=False;last_sensor=-10.0;throttle_cycles=0;owned_pids=set()
 with (base/(label+'-wrapper.log')).open('w') as log:
  proc=subprocess.Popen(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
  while proc.poll() is None:
   now=time.monotonic()
   if now-last_sensor>=1:
    last_sensor=now
    value=temperature();samples.append({'elapsed_seconds':round(now-started,3),'package_c':value,'sampling_started':sampling_started})
    hot_samples=hot_samples+1 if value is not None and value>=85 else 0
    if (value is not None and value>=90) or hot_samples>=3:
     reason='thermal_limit'
     for pid in owned_pids:
      try:os.kill(pid,signal.SIGCONT)
      except ProcessLookupError:pass
     os.killpg(proc.pid,signal.SIGTERM)
     try:proc.wait(timeout=10)
     except subprocess.TimeoutExpired:os.killpg(proc.pid,signal.SIGKILL);proc.wait()
     break
   if not sampling_started:
    # Only the isolated Godot child with this exact run-label log path may
    # be paused. The monitor/desktop/other processes are never suspended.
    for entry in Path('/proc').iterdir():
     if not entry.name.isdigit():continue
     try:
      pid=int(entry.name)
      exe=Path(os.readlink(entry/'exe')).name.lower()
      args=(entry/'cmdline').read_bytes().split(b'\0')
      token='/runs/'+label+'-'
      if exe.startswith('godot') and any(token.encode() in arg and arg.endswith(b'/logs/engine.log') for arg in args) and os.getpgid(pid)==pid:
       owned_pids.add(pid)
       log_path=next(Path(os.fsdecode(arg)).with_name('stdout.log') for arg in args if token.encode() in arg and arg.endswith(b'/logs/engine.log'))
       if log_path.exists():
        with log_path.open('rb') as stream:
         stream.seek(max(0,log_path.stat().st_size-16384));tail=stream.read()
        sampling_started=b'GROUND_PROBE_VARIANT_BEGIN' in tail
     except (OSError,ProcessLookupError,StopIteration):pass
    for pid in owned_pids:
     try:os.kill(pid,signal.SIGCONT)
     except ProcessLookupError:pass
    if not sampling_started and owned_pids:
     time.sleep(0.05)
     for pid in owned_pids:
      try:os.kill(pid,signal.SIGSTOP)
      except ProcessLookupError:pass
     try:time.sleep(0.15)
     finally:
      for pid in owned_pids:
       try:os.kill(pid,signal.SIGCONT)
       except ProcessLookupError:pass
     throttle_cycles+=1
    else:time.sleep(0.2)
   else:time.sleep(0.5)
  rc=proc.wait()
 (base/(label+'-thermal.json')).write_text(json.dumps({'command':cmd,'environment_overrides':{k:env[k] for k in ['SA_ENGINE_SLOTS','SA_ENGINE_THERMAL_LIMIT_C','SA_FULL_PROVENANCE']},'cpu_affinity':[0,1],'runtime_temperature_stop_c':90,'sustained_temperature_stop_c':85,'sustained_temperature_samples':3,'reason':reason,'startup_duty_cycle':0.25,'startup_throttle_cycles':throttle_cycles,'startup_throttled_pids':sorted(owned_pids),'wrapper_exit':rc,'samples':samples},indent=2)+'\n')
 print((base/(label+'-wrapper.log')).read_text(),flush=True)
 print('Thermal',label,'peak',max(s['package_c'] or 0 for s in samples),reason,flush=True)
 if rc or reason!='completed':raise SystemExit(rc or 1)
