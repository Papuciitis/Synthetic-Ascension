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

for label,segment,theme in [('ground22-gpu-s2',2,'service_courtyards'),('ground22-gpu-s7b',7,'canal_services')]:
 output=base/(label+'.json')
 assert not output.exists(),output
 variants='none,current,phase1='+str(base/'variants/phase1.gdshader')+',before_edges='+str(base/'variants/candidate-before-edges.gdshader')
 cmd=['python3',str(root/'.superpowers/claude-city-20261021/sa_engine.py'),'--name',label,'--project','/tmp/sa-wp2-ground','--exclusive','--timeout','240','--max-wait','180','--tail','2','--','--rendering-driver','opengl3','--audio-driver','Dummy','res://tools/dev/GroundShaderCostProbe.tscn','--',f'--segment={segment}',f'--theme={theme}','--variants='+variants,'--rounds=5','--frames=180','--warmup=45','--points=start,route1','--json='+str(output)]
 env=os.environ|{'SA_ENGINE_SLOTS':'1','SA_ENGINE_THERMAL_LIMIT_C':'75','SA_FULL_PROVENANCE':'1'}
 env.pop('INTEL_DEBUG',None);env.pop('MESA_SHADER_CACHE_DISABLE',None)
 started=time.monotonic();samples=[];reason='completed'
 with (base/(label+'-wrapper.log')).open('w') as log:
  proc=subprocess.Popen(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
  while proc.poll() is None:
   value=temperature();samples.append({'elapsed_seconds':round(time.monotonic()-started,3),'package_c':value})
   if value is not None and value>=85:
    reason='thermal_limit';os.killpg(proc.pid,signal.SIGTERM)
    try:proc.wait(timeout=10)
    except subprocess.TimeoutExpired:os.killpg(proc.pid,signal.SIGKILL);proc.wait()
    break
   time.sleep(1)
  rc=proc.wait()
 (base/(label+'-thermal.json')).write_text(json.dumps({'command':cmd,'environment_overrides':{k:env[k] for k in ['SA_ENGINE_SLOTS','SA_ENGINE_THERMAL_LIMIT_C','SA_FULL_PROVENANCE']},'runtime_temperature_stop_c':85,'reason':reason,'wrapper_exit':rc,'samples':samples},indent=2)+'\n')
 print((base/(label+'-wrapper.log')).read_text(),flush=True)
 print('Thermal',label,'peak',max(s['package_c'] or 0 for s in samples),reason,flush=True)
 if rc or reason!='completed':raise SystemExit(rc or 1)
