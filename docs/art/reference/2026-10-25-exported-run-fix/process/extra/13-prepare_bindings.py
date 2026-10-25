from pathlib import Path
import json,hashlib,re,subprocess
root=Path('/home/user/Nauris/Synthetic-Ascension');local=root/'.superpowers/continuation-20261025-menu';runs=root/'.superpowers/claude-city-20261021/runs';guards=root/'.superpowers/continuation-20261022'
fixed=json.loads((local/'execution-r4.json').read_text())['sources_fixed'];original=json.loads((local/'execution.json').read_text());before=original['sources_before'];initial=original['sources_fixed']
labels=['menu25-packed-red-r1','menu25-frontend-source-r1','menu25-binding-source-r1','menu25-offer-source-r1','menu25-doctrine-source-r1','menu25-export-fixed-r1','menu25-packed-green-r1','menu25-packed-load-diagnostic-r1','menu25-packed-script-warm-diagnostic-r1','menu25-export-fixed-r2','menu25-packed-green-r2','menu25-packed-progress-diagnostic-r2','menu25-packed-scene-sync-diagnostic-r1','menu25-export-fixed-r3','menu25-packed-green-r3','menu25-script-graph-diagnostic-r1','menu25-frontend-source-r4','menu25-interruption-source-r4','menu25-preparation-menu-r4','menu25-preparation-menu-r4b','menu25-preparation-terminal-r4b','menu25-export-fixed-r4','menu25-packed-green-r4','menu25-packed-native-r4','menu25-packed-native-r4b']
accepted={'menu25-frontend-source-r1','menu25-binding-source-r1','menu25-offer-source-r1','menu25-doctrine-source-r1','menu25-frontend-source-r4','menu25-preparation-menu-r4b','menu25-preparation-terminal-r4b','menu25-export-fixed-r4','menu25-packed-green-r4','menu25-packed-native-r4b'}
inspections=[local/'rejected-r2-playtest-pack-inspection.json',local/'rejected-r3-playtest-pack-inspection.json'];artifact_by_path={json.loads(p.read_text())['build']['path']:json.loads(p.read_text())['build']['sha256'] for p in [local/'old-playtest-pack-inspection.json',local/'failed-r1-new-playtest-pack-inspection.json',local/'final-r4-playtest-pack-inspection.json',*inspections]}
cases=[]
for label in labels:
 run=runs/(label+'-1');raw=json.loads((run/'run-results.json').read_text());guard=json.loads((guards/(label+'-thermal.json')).read_text())
 classification='accepted' if label in accepted else 'expected_red' if label=='menu25-packed-red-r1' else 'intermediate_failure' if label in {'menu25-packed-green-r1','menu25-packed-green-r2'} else 'diagnostic'
 role={'menu25-export-fixed-r4':'export','menu25-packed-green-r4':'functional','menu25-packed-native-r4b':'native'}.get(label,'focused' if label in accepted else 'historical')
 pins=before if label=='menu25-packed-red-r1' else initial if label in labels[:16] else {p:v for p,v in fixed.items() if p!='tools/tests/PreparationCancellationTest.gd'} if label in {'menu25-frontend-source-r4','menu25-interruption-source-r4'} else fixed
 if label=='menu25-preparation-menu-r4':pins={**fixed,'tools/tests/PreparationCancellationTest.gd':'e6c87683b0272fdb5edcfad94d1268a50ac7488dfc47059a72d6474bef9f0a67'}
 pins={p:v for p,v in pins.items() if p!='export_presets.cfg'}
 c={'label':label,'classification':classification,'role':role,'source_pins':pins,'expected':{'actual_exit':raw['actual_exit'],'runner_exit':raw['runner_exit'],'stop_reason':raw['stop_reason'],'guard_reason':guard['reason'],'guard_wrapper_exit':guard['wrapper_exit'],'guard_received_signal':guard['received_signal'],'diagnostics_sha256':hashlib.sha256(json.dumps(raw['diagnostics'],separators=(',',':')).encode()).hexdigest()}}
 cmd=raw['command']
 if '--main-pack' in cmd:c['artifact_sha256']=artifact_by_path.get(cmd[cmd.index('--main-pack')+1])
 if '--export-debug' in cmd:c['artifact_sha256']=artifact_by_path.get(cmd[-1])
 if '--script' in cmd:
  script=Path(cmd[cmd.index('--script')+1])
  if script.is_absolute() and label!='menu25-preparation-menu-r4':c['script_pin']={'path':str(script),'sha256':hashlib.sha256(script.read_bytes()).hexdigest()}
 matches=re.findall(r'([A-Za-z0-9_\[\]-]+): (\d+) passed, (\d+) failed',(run/'logs/stdout.log').read_text())
 if matches:
  assert len(matches)==1,(label,matches)
  c['summary']=[matches[0][0],int(matches[0][1]),int(matches[0][2])]
 cases.append(c)
controls=[]
for case in cases:
 raw=json.loads((runs/(case['label']+'-1/run-results.json')).read_text())
 body=subprocess.check_output(['git','show',raw['git_head']+':export_presets.cfg'],cwd=root)
 dirty=[line for line in raw['git_status_porcelain'].splitlines() if 'export_presets.cfg' in line]
 controls.append({'label':case['label'],'recorded_git_head':raw['git_head'],'git_object_cfg_sha256':hashlib.sha256(body).hexdigest(),'recorded_cfg_status':dirty,'runner_hash_field_present':'export_presets.cfg' in raw['source_hashes']})
 if case['classification']=='accepted' and case['label'].endswith(('r4','r4b')):assert not dirty and controls[-1]['git_object_cfg_sha256']==fixed['export_presets.cfg']
(local/'export-config-provenance.json').write_text(json.dumps({'method':'Runner omits *.cfg from source_hashes. Bind configuration using its recorded Git head and clean tracked-file status, plus direct source snapshot; these are not reconstructed runner hashes.','cases':controls},indent=2)+'\n')
extra=[local/x for x in ['execution-r4.json','checks-r4.json','checks-r4b.json','r4-cache-quarantine.json','r3-stop.json','artifact-native-before-r4.json','artifact-native-after-r4.json','artifact-native-before-r4b.json','artifact-native-after-r4b.json','delivery-artifact.json','independent-review.json','root-review-r4-rejected.json','PreparationCancellationTest.gd','prepare_bindings.py','export-config-provenance.json']]
extra.extend(Path('/var/tmp/sa-menu25-native-r4')/x for x in ['base-populated.png','augment-three-cards.png','base-populated.png.json','augment-three-cards.png.json'])
bindings={'engine_queue_idle':True,'source_checkpoint':'ee6ff2f8164c447645f9bdef7fe62171092fcf45','sources_fixed':fixed,'readme':str(local/'packet-README-draft.md'),'baseline_files':{p:str(local/'baseline'/Path(p).name) for p in ['autoload/global.gd','core/systems/major_choice/MajorChoiceDB.gd']},'new_inspection':str(local/'final-r4-playtest-pack-inspection.json'),'historical_inspections':list(map(str,inspections)),'build_manifest':str(root/'build/playtest-20261025-r4/BUILD.json'),'artifact_observations':[json.loads((local/x).read_text()) for x in ['artifact-native-before-r4.json','artifact-native-after-r4.json','artifact-native-before-r4b.json','artifact-native-after-r4b.json']],'cases':cases,'preparation_case_labels':['menu25-preparation-menu-r4b','menu25-preparation-terminal-r4b'],'native_wrapper':json.loads((local/'artifact-native-before-r4b.json').read_text())['native_wrapper'],'originals':{x:str(Path('/var/tmp/sa-menu25-native-r4b')/x) for x in ['base-populated.png','augment-three-cards.png']},'reviews':{'root':str(local/'root-review-r4b.json'),'independent':str(local/'independent-review-r4b.json')},'extra_metadata':list(map(str,extra))}
(local/'final-bindings.json').write_text(json.dumps(bindings,indent=2)+'\n');print('prepared',len(cases),'classified cases')
