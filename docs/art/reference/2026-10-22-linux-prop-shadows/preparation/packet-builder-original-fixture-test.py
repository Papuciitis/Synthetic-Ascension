import ast,hashlib,json,tempfile
from pathlib import Path
p=Path('/var/tmp/sa-city22/packets/props/build_packet.py');t=ast.parse(p.read_text());t.body=[n for n in t.body if not (isinstance(n,ast.If) and isinstance(n.test,ast.Compare))]
ns={};exec(compile(t,str(p),'exec'),ns)
checks=[]
def check(label, fn):
 try:fn();checks.append({'label':label,'ok':True})
 except Exception as e:checks.append({'label':label,'ok':False,'error':repr(e)})
def reject(fn):
 try:fn()
 except RuntimeError:return
 raise AssertionError('invalid fixture accepted')
m=json.loads(ns['META'].read_text())
check('metadata exactly matches reviewed34a1',lambda: ns['require'](ns['sha'](ns['META'].read_bytes())==ns['META_SHA'],'hash'))
check('all52currentprojectinputs match',lambda:ns['require'](len(m['project_bindings'])==52 and all(ns['sha']((ns['PROJECT']/f).read_bytes())==h for f,h in m['project_bindings'].items()),'project'))
check('all5externalinputs still frozen',lambda:ns['require'](len(m['external_bindings'])==5 and all(ns['sha'](Path(f).read_bytes())==h for f,h in m['external_bindings'].items()),'external'))
check('unchanged fixture matches preservedf0fe',lambda:ns['require']((ns['CONTROL']/'CityPropShadowAcceptance.gd').read_bytes()==(ns['PREP']/'previous-binding/CityPropShadowAcceptance.gd').read_bytes(),'fixture'))
check('bind accepts exactscopedhashes',lambda:ns['bind']({'source_hashes':{'x':'a'},'run_root':'fake'}, {'x':'a'}))
check('bind rejects changedhashes',lambda:reject(lambda:ns['bind']({'source_hashes':{'x':'b'},'run_root':'fake'},{'x':'a'})))
check('bind rejects missinghashes',lambda:reject(lambda:ns['bind']({'source_hashes':{},'run_root':'fake'},{'x':'a'})))
with tempfile.TemporaryDirectory(prefix='sa-prop-builder-byte-') as temp:
 b=Path(temp);run=b/'fake-1/run-results.json';run.parent.mkdir();ns['CONTROL']=b;thermal=b/'fake-thermal.json'
 raw={'ended_utc':'fixture','actual_exit':0,'runner_exit':0,'stop_reason':'completed','diagnostics':[],'source_hashes':{'x':'a'}}
 run.write_text(json.dumps(raw));thermal.write_text(json.dumps({'reason':'completed','wrapper_exit':0}))
 check('clean admits completedrawandguard',lambda:ns['clean'](run))
 raw['diagnostics']=['unexpected'];run.write_text(json.dumps(raw))
 check('clean rejects diagnostics',lambda:reject(lambda:ns['clean'](run)))
 raw['diagnostics']=[];raw['actual_exit']=1;run.write_text(json.dumps(raw))
 check('clean rejects nonzeroengineexit',lambda:reject(lambda:ns['clean'](run)))
 raw['actual_exit']=0;run.write_text(json.dumps(raw));thermal.write_text(json.dumps({'reason':'external_sigterm','wrapper_exit':-15}))
 check('clean rejects cancelledguard',lambda:reject(lambda:ns['clean'](run)))
result={'scope':'Only AST, actualsmallsourceSHAreads and tiny temporaryJSON byte fixtures. main/build/Godot/Git not invoked; no packet rebuilt.','builder_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'passed':sum(x['ok'] for x in checks),'failed':sum(not x['ok'] for x in checks),'checks':checks}
out=Path('/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/prop-shadow-final-9b7-prep/packet-builder-source-checks.json');out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2));assert result['failed']==0
