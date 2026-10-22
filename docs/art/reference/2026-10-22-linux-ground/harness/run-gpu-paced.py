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

for label,segment,theme,point in [('ground22-gpu-s2-start-paced',2,'service_courtyards','start'),('ground22-gpu-s2-route1-paced',2,'service_courtyards','route1'),('ground22-gpu-s7b-start-paced',7,'canal_services','start'),('ground22-gpu-s7b-route1-paced',7,'canal_services','route1')]:
 output=base/(label+'.json')
 assert not output.exists(),output
 variants='none,current,phase1='+str(base/'variants/phase1.gdshader')
 cmd=['python3',str(root/'.superpowers/claude-city-20261021/sa_engine.py'),'--name',label,'--project','/tmp/sa-wp2-ground','--exclusive','--timeout','240','--max-wait','180','--tail','2','--','--rendering-driver','opengl3','--audio-driver','Dummy','res://tools/dev/GroundShaderCostProbe.tscn','--',f'--segment={segment}',f'--theme={theme}','--variants='+variants,'--rounds=5','--frames=120','--warmup=45','--cooldown-seconds=3','--points='+point,'--json='+str(output)]
 env=os.environ|{'SA_ENGINE_SLOTS':'1','SA_ENGINE_THERMAL_LIMIT_C':'65','SA_FULL_PROVENANCE':'1'}
 env.pop('INTEL_DEBUG',None);env.pop('MESA_SHADER_CACHE_DISABLE',None)
 started=time.monotonic();samples=[];reason='completed';hot_samples=0
 with (base/(label+'-wrapper.log')).open('w') as log:
  proc=subprocess.Popen(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
  while proc.poll() is None:
   value=temperature();samples.append({'elapsed_seconds':round(time.monotonic()-started,3),'package_c':value})
   hot_samples = hot_samples+1 if value is not None and value>=85 else 0
   if (value is not None and value>=90) or hot_samples>=3:
    reason='thermal_limit';os.killpg(proc.pid,signal.SIGTERM)
    try:proc.wait(timeout=10)
    except subprocess.TimeoutExpired:os.killpg(proc.pid,signal.SIGKILL);proc.wait()
    break
   time.sleep(1)
  rc=proc.wait()
 (base/(label+'-thermal.json')).write_text(json.dumps({'command':cmd,'environment_overrides':{k:env[k] for k in ['SA_ENGINE_SLOTS','SA_ENGINE_THERMAL_LIMIT_C','SA_FULL_PROVENANCE']},'runtime_temperature_stop_c':90,'sustained_temperature_stop_c':85,'sustained_temperature_samples':3,'reason':reason,'wrapper_exit':rc,'samples':samples},indent=2)+'\n')
 print((base/(label+'-wrapper.log')).read_text(),flush=True)
 print('Thermal',label,'peak',max(s['package_c'] or 0 for s in samples),reason,flush=True)
 if rc or reason!='completed':raise SystemExit(rc or 1)
