import ast,copy,hashlib,json,tempfile
from pathlib import Path
p=Path('/var/tmp/sa-city22/packets/props/build_packet.py');tree=ast.parse(p.read_text());tree.body=[n for n in tree.body if not (isinstance(n,ast.If) and isinstance(n.test,ast.Compare))];ns={};exec(compile(tree,str(p),'exec'),ns)
rows=[]
def good(label,fn):
 try:fn();rows.append({'label':label,'ok':True})
 except Exception as e:rows.append({'label':label,'ok':False,'error':repr(e)})
def reject(fn):
 try:fn()
 except RuntimeError:return
 raise AssertionError('bad review accepted')
with tempfile.TemporaryDirectory(prefix='sa-prop-objective-byte-') as tmp:
 root=Path(tmp);dirs={side:root/side for side in ['before','after']}
 for side,d in dirs.items():
  d.mkdir()
  for name in ['objectives.png','provenance.json']:(d/name).write_bytes((side+'/'+name).encode())
 review={'current_objective_source_sha256':'expected-source','ground_control_bytes_identical':True,'sources':{s:{n:ns['sha']((d/n).read_bytes()) for n in ['objectives.png','provenance.json']} for s,d in dirs.items()}}
 def call(r):ns['validate_objective_ground_review'](r,'expected-source',dirs['before'],dirs['after'])
 good('positive exact four input hashes/source/true flag accepted',lambda:call(review))
 for side in dirs:
  for name in ['objectives.png','provenance.json']:
   changed=copy.deepcopy(review);changed['sources'][side][name]='stale'
   good('stale '+side+'/'+name+' rejected',lambda r=changed:reject(lambda:call(r)))
 changed=copy.deepcopy(review);changed['current_objective_source_sha256']='wrong'
 good('stale runtime source rejected',lambda:reject(lambda:call(changed)))
 for flag in [False,None,'true',1]:
  changed=copy.deepcopy(review);changed['ground_control_bytes_identical']=flag
  good('non-True identity '+repr(flag)+' rejected',lambda r=changed:reject(lambda:call(r)))
 changed=copy.deepcopy(review);del changed['ground_control_bytes_identical']
 good('missing identity flag rejected',lambda:reject(lambda:call(changed)))
 changed=copy.deepcopy(review);del changed['sources']['after']['provenance.json']
 good('missing provenance hash rejected',lambda:reject(lambda:call(changed)))
b=Path('/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022');meta=json.loads((b/'prop-shadow-acceptance-source.json').read_text())
good('actual current objective review passes without native rerun',lambda:ns['validate_objective_ground_review'](json.loads((b/'prop-objective-visual-review.json').read_text()),meta['project_bindings']['core/systems/world/objectives/ObjectiveWorldArt.gd'],Path('/var/tmp/sa-c22/objectives/before'),Path('/var/tmp/sa-c22/objectives/after')))
result={'scope':'Only isolated function and temporary byte/JSON fixtures plus existing small review hashes. No main/build/Godot/Git execution or source mutation.','builder_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'passed':sum(r['ok'] for r in rows),'failed':sum(not r['ok'] for r in rows),'checks':rows}
(b/'prop-shadow-final-9b7-prep/packet-builder-objective-gate-checks.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2));assert not result['failed']
