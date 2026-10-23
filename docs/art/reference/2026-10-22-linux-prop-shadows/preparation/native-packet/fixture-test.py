import ast,copy,hashlib,json,tempfile
from pathlib import Path
from types import SimpleNamespace
HERE=Path(__file__).resolve().parent
script=Path('/var/tmp/sa-city22/packets/props/build_packet.py')
tree=ast.parse(script.read_text());tree.body=[n for n in tree.body if not(isinstance(n,ast.If) and isinstance(n.test,ast.Compare))];ns={};exec(compile(tree,str(script),'exec'),ns)
checks=[]
def expect(label,fn,reject=False):
 try:
  fn()
  if reject:raise AssertionError('bad native packet receipt accepted')
  checks.append({'label':label,'ok':True})
 except RuntimeError as e:
  if not reject:raise
  checks.append({'label':label,'ok':True})

a={'suite':'CityPropShadowAcceptance','passes':48,'failures':0,'checks':[{'ok':True} for _ in range(48)]}
assert ns['independent_48_clean'](a);checks.append({'label':'original48 clean predicates accepted','ok':True})
for label,mutate in [('fewer checks',lambda x:x['checks'].pop()),('failed predicate',lambda x:x['checks'][0].update(ok=False)),('wrong pass count',lambda x:x.update(passes=47)),('nonzero failures',lambda x:x.update(failures=1))]:
 b=copy.deepcopy(a);mutate(b);assert not ns['independent_48_clean'](b);checks.append({'label':label+' rejected','ok':True})
meta=ns['load'](ns['NATIVE_PREP']/'source.json');original=ns['load'](ns['META']);observed={str(ns['PROJECT']/p):h for p,h in original['project_bindings'].items()}|original['external_bindings']
with tempfile.TemporaryDirectory(prefix='sa-prop-native-packet-byte-') as temp:
 root=Path(temp);directory=root/'fixture';directory.mkdir();raw=root/'native-run.json';parse_raw=root/'parse-run.json';thermal=root/'native-thermal.json';parse_thermal=root/'parse-thermal.json'
 raw.write_text('{}');parse_raw.write_text('{}');thermal.write_text('{}');parse_thermal.write_text('{}')
 (directory/'native-state.json').write_text('{"stub":"native-driver validates exact actual state"}')
 receipt={'label':'city22-prop-shadow-fixture-fixture','path':str(raw),'sha256':ns['sha'](raw.read_bytes()),'thermal_path':str(thermal),'thermal_sha256':ns['sha'](thermal.read_bytes())}
 prerequisite={'label':'city22-prop-shadow-parse-9b7-r1','path':str(parse_raw),'thermal_path':str(parse_thermal),'reused_without_new_engine':True,'checked_sources':6}
 banner='OpenGL API fixture Compatibility Using Device: fixture-hardware'
 calls=[]
 def verify():calls.append('verify');return observed,meta
 def parser(obs):assert obs==observed;calls.append('parser');return prerequisite
 def clean(label):assert label==receipt['label'];calls.append('clean');return {},receipt
 def validate(*args):calls.append('validate-native');return banner
 fake=SimpleNamespace(verify=verify,parser_receipt=parser,clean_run=clean,validate_native=validate)
 ns['importlib']=SimpleNamespace(util=SimpleNamespace(spec_from_file_location=lambda *a:SimpleNamespace(loader=SimpleNamespace(exec_module=lambda m:None)),module_from_spec=lambda s:fake))
 queue={'passed':True,'source_before':observed,'source_after':observed,'source_metadata_path':str(ns['NATIVE_PREP']/'source.json'),'source_metadata_sha256':ns['NATIVE_META_SHA'],'baseline_metadata_sha256':ns['META_SHA'],'native_execution_bindings':meta['native_execution_bindings'],'execution_protocol':meta['execution_protocol'],'prerequisite_parser':prerequisite,'cases':[{'role':'fixture','label':receipt['label'],'wrapper_exit':0,'raw_result':receipt}],'actual_renderer_banner':banner,'native_state_sha256':ns['sha']((directory/'native-state.json').read_bytes())}
 def run(change=None):
  q=copy.deepcopy(queue);output=copy.deepcopy(a)
  if change:change(q,output)
  (directory/'acceptance.json').write_text(json.dumps(output));q['acceptance_sha256']=ns['sha']((directory/'acceptance.json').read_bytes())
  (directory/'queue.json').write_text(json.dumps(q));return ns['native_fixture_evidence']('fixture',observed,root)
 expect('new native receipt delegates frozen source/parser/raw/backend validation and retains real old25/15',run)
 assert all(key in calls for key in ['verify','parser','clean','validate-native'])
 for label,change in [
  ('pending passedfalse',lambda q,a:q.update(passed=False)),
  ('stale original source map',lambda q,a:q['source_after'].update({'wrong':'source'})),
  ('stale native source metadata',lambda q,a:q.update(source_metadata_sha256='wrong')),
  ('stale native execution bindings',lambda q,a:q.update(native_execution_bindings={})),
  ('changed execution protocol',lambda q,a:q.update(execution_protocol={})),
  ('wrong reused parser',lambda q,a:q.update(prerequisite_parser={})),
  ('new duplicate parser case',lambda q,a:q['cases'].append({'role':'parse'})),
  ('failed native guard',lambda q,a:q['cases'][0].update(wrapper_exit=1)),
  ('wrong actual raw receipt',lambda q,a:q['cases'][0].update(raw_result={})),
  ('wrong hardware banner receipt',lambda q,a:q.update(actual_renderer_banner='headless dummy')),
  ('wrong actual boot state hash',lambda q,a:q.update(native_state_sha256='wrong')),
  ('native predicate failure',lambda q,a:a['checks'][0].update(ok=False)),
 ]:expect(label+' rejected',lambda change=change:run(change),True)
 def refuse(*args):raise RuntimeError('native hardware/state validation failed')
 fake.validate_native=refuse;expect('frozen native backend validator refusal blocks packet',run,True)
result={'builder_sha256':hashlib.sha256(script.read_bytes()).hexdigest(),'passed':len(checks),'failed':0,'checks':checks,'scope':'AST/functions only; tiny temporary receipt/byte fixtures; frozen native driver mocked only for delegation checks. Actual old25/15 immutable hashes and records read. No packet build, Godot, Git or project/native-source edits.'}
(HERE/'fixture-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
