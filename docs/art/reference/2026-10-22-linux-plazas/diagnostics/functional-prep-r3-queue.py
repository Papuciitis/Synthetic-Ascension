from pathlib import Path
import json,subprocess,time
root=Path('/home/user/Nauris/Synthetic-Ascension');base=root/'.superpowers/continuation-20261022';results=[]
parse=str(base/'external_source_parse_probe.tscn')
cases=[
('city22-street-part-tools-parse','/tmp/sa-wp2-streets',300,25,['--headless',parse,'--',*[str(base/name) for name in ['CityStreetContinuityThemePart.gd','StreetNativeAcceptanceProbe.gd','StreetRewardCameraProbe.gd']]]),
('city22-plaza-bed-tools-parse','/tmp/sa-wp2-plazas',300,25,['--headless',parse,'--',*[str(base/name) for name in ['PlazaBedDiscovery.gd','PlazaBedGamePreview.gd','plaza-parse-diagnostic-sorted.gd']]]),
('city22-plaza-bed-discovery','/tmp/sa-wp2-plazas',900,10,['--headless',str(base/'PlazaBedDiscovery.tscn'),'--','--out='+str(base/'plaza-bed-discovery.json')]),
('city22-plaza-parse-sorted-candidate-r2','/tmp/sa-wp2-plazas',420,10,['--headless',str(base/'plaza-parse-diagnostic-sorted.tscn'),'--','--trace-out='+str(base/'city22-plaza-parse-sorted-candidate-r2-trace.json')]),
('city22-stage4-cost-parse-r3','/tmp/sa-wp2-evidence',300,25,['--headless',parse,'--',str(base/'Stage4StaticCostProbe.gd')]),
]
for label,project,timeout,duty,args in cases:
 cmd=['python3',str(base/'guarded_engine.py'),'--label',label,'--project',project,'--start-temperature','70','--max-wait','900','--timeout',str(timeout),'--duty-percent',str(duty),'--',*args]
 rc=subprocess.run(cmd).returncode
 results.append({'label':label,'command':cmd,'returncode':rc});(base/'functional-prep-r3-queue.json').write_text(json.dumps(results,indent=2)+'\n')
 print('QUEUE_RESULT',label,rc,flush=True)
 if rc:raise SystemExit(rc)
 time.sleep(3)
