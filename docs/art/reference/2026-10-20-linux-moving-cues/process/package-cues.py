#!/usr/bin/env python3
"""Bounded cue evidence; read-only preflight unless --write is explicit.

No engine, Git mutation, image editing, encoding or raw-frame directory copy.
Only named monitor files, five selected PNGs and optional complete video triplet.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

BASE = Path(__file__).resolve().parent
ROOT = BASE.parent.parent
OUT = ROOT / 'docs/art/reference/2026-10-20-linux-moving-cues'
RUNTIME = (
 'assets/vfx/world/enemies/VFX_BomberBlast.gd',
 'assets/vfx/world/enemies/VFX_BomberHazardRing.gd',
 'assets/vfx/world/enemies/VFX_ChargeWindup.gd',
 'assets/vfx/world/enemies/VFX_EliteModifierMark.gd',
 'assets/vfx/world/enemies/VFX_EnemyMuzzleFlash.gd',
 'assets/vfx/world/enemies/VFX_EnemyShootCone.gd',
 'assets/vfx/world/enemies/VFX_EnemyShotWindup.gd',
 'assets/vfx/world/enemies/VFX_HeraldPulseRing.gd',
 'core/actors/enemy/FrontShieldVisual.gd',
 'core/actors/enemy/enemy.gd',
 'core/actors/enemy/modules/EnemySniper.gd',
 'core/combat/BattleTextRenderer.gd',
 'core/combat/projectile/AttackProjectileLight.gdshader',
 'core/combat/projectile/EnemyProjectile.gd',
 'core/combat/projectile/ImpactBurstRenderer.gd',
 'core/combat/projectile/ProjectileSimulationManager.gd',
 'core/systems/enemy_world/EnemyProxyRegion.gdshader',
 'core/systems/world/visibility/WorldCueCover.gd',
 'core/systems/world/visibility/WorldCueMix.gdshader',
 'core/systems/world/visibility/WorldCueAdd.gdshader',
 'scenes/world/pickups/PickupVfx.gd',
)
OWNED = RUNTIME + tuple('tools/tests/'+stem+suffix for stem in (
 'WorldCueCoverRenderTest','WorldCueAdditionalRenderTest','EnemyCalloutContactTest') for suffix in ('.gd','.tscn')) + (
 'tools/tests/WorldCueCoverRenderTest.gd.uid',
 'tools/dev/CityMovingCoverPreview.gd','tools/dev/CityMovingCoverPreview.tscn',
)
DEPENDENCIES = (
 'core/systems/world/visibility/WorldCover.gd',
 'core/systems/world/visibility/world_cover.gdshaderinc',
 'core/systems/world/visibility/ForegroundSpriteCoverage.gd',
 'tools/dev/CityEntityCoverPreview.gd','tools/dev/CityBlockPlayablePreview.gd',
 'tools/dev/EliteCrowdFightPreview.gd','tools/capture/run_city_linux.py',
 'tools/capture/test_run_city_linux.py',
)
# Explicit classification; labels themselves are not acceptance criteria.
RUNS = {
 'continuation-cue-red': ('invalid_fixture',(44,15),'Sniper attempted invalid current_scene parenting, blank sniper probes. Other missing-cover assertions observed; this is not the accepted RED.'),
 'continuation-cue-red2': ('valid_red',(46,13),'Corrected real sniper owners; only 13 missing covered-presentation assertions.'),
 'continuation-cue-green': ('failed_runtime_attempt',(58,1),'Autoload binding tried adding WorldCover while root added children, orphaning service/resources. Animated glint also changed static screenshot comparison. Not GREEN.'),
 'continuation-cue-green2': ('invalid_fixture',(58,1),'Autoload lifecycle fixed/no leaks; sniper fixture cross-bound one cached material between two viewport services. Not GREEN.'),
 'continuation-cue-green3': ('clean_historical_check',(59,0),'First scope after real sniper attachment was reapplied following explicit fixture viewport move; precedes secondary/contact tests.'),
 'continuation-battletext': ('clean_historical_check',(41,0),'Initial text-column regression before final contact/source additions.'),
 'continuation-cue-additional-red': ('qualified_red',(27,10),'Eight secondary draw-owner missing-cover assertions are valid. Ordinary node bolt had only 6 covered pixels and failed its >8 presence guard; corrected isolated RED follows.'),
 'continuation-node-projectile-red': ('valid_red',(4,1),'Corrected actual bolt core has 38 covered pixels; only missing presentation fails.'),
 'continuation-cue-contact-red': ('valid_red',(65,2),'Real resized atlas-region contact and front owner sharing a visual text column fail.'),
 'continuation-caller-red': ('valid_red',(2,1),'Real elite announcer preserves layout but reports raised paint Y instead of physical birth Y.'),
 'continuation-cue-final': ('clean_check',(67,0),'Native raw pixels: covered/exposed/restored cues, projectile families, sniper, text, atlas and owner-ground contacts.'),
 'continuation-cue-additional-green': ('clean_check',(39,0),'Native actual cone/muzzle, bomber perimeter/fuse/front-fuse/blast, elite secondary marks, impacts and ordinary node bolt.'),
 'continuation-caller-green': ('clean_check',(3,0),'Actual elite caller retains both existing visual raises and physical birth contact.'),
 'continuation-moving-cover': ('failed_route',None,'Live occupied attempt demonstrates cues/collection/cutaway but abandons final westbound destination at cell(7,115). Not acceptance.'),
}
for test, count in (
 ('CombatTextPresentationTest',62),('BattleTextColumnTest',41),('EnemyVisualBatchingTest',9),
 ('EliteTellArtTest',12),('ProjectileIdentityTest',7),('EnemyProjectileTimeBaseTest',4),
 ('EnemyProjectileAttributionTest',74),('PooledProjectileRecycleTest',8),('PickupCoverTest',16),
 ('HealthPickupLockTest',8),
): RUNS['continuation-regression-'+test] = ('clean_check',(count,0),'Focused existing headless regression.')
RUNS['continuation-provider-EnemyCoverRenderTest'] = ('clean_check',(38,0),'Existing native enemy body/proxy/materialized presentation remains covered.')
RUNS['continuation-provider-PickupCoverTest'] = ('clean_check',(33,0),'Existing native ordinary/healing icon/glow coverage remains correct.')


def digest(data: bytes) -> str:
 return hashlib.sha256(data).hexdigest()

def encoded(value: object) -> bytes:
 return (json.dumps(value,indent=2,sort_keys=True,ensure_ascii=False)+'\n').encode()

def footer(text: str):
 matches = re.findall(r'(\w+Test)(?::\s*(\d+)\s+passed,\s*(\d+)\s+failed|\s+passes=(\d+)\s+failures=(\d+))',text)
 if not matches: return None
 name,a,b,c,d = matches[-1]
 return name,int(a or c),int(b or d)

def main() -> None:
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--write',action='store_true')
 parser.add_argument('--moving-label',default='continuation-moving-cover2')
 parser.add_argument('--code-commit',default='7875d1981c79e85f049a07b5c696889b0350a1c4')
 args=parser.parse_args()
 runs=dict(RUNS)
 runs[args.moving_label]=('clean_moving_route',None,'Final actual-Game route with mandatory arrivals and normal live producers.')
 planned: dict[str,bytes] = {}
 def add(path: str,data: bytes) -> None:
  if path in planned and planned[path]!=data: raise ValueError('Conflicting artifact '+path)
  planned[path]=data
 add('.gdignore',(OUT/'.gdignore').read_bytes() if (OUT/'.gdignore').exists() else b'')
 bindings=[]; run_index=[]; source_records={}
 for label,(kind,expected,note) in runs.items():
  folder=BASE/label
  raw=(folder/'run-results.json').read_bytes()
  result=json.loads(raw)
  stdout=(folder/'logs/stdout.log').read_text()
  observed=footer(stdout)
  if expected is not None and (observed is None or observed[1:]!=expected): raise ValueError((label,'unexpected assertion footer',observed,expected))
  clean=kind.startswith('clean_')
  if clean and (result.get('actual_exit')!=0 or result.get('stop_reason')!='completed' or result.get('diagnostics')): raise ValueError((label,'not clean',result.get('actual_exit'),result.get('diagnostics')))
  if kind=='valid_red':
   allowed=('covered pixels receive quiet depth presentation','exposed/front-depth pixels retain authored presentation','elite callout physical birth contact')
   if result.get('actual_exit')!=1 or any(not any(token in d for token in allowed) for d in result.get('diagnostics',[])): raise ValueError((label,'unexpected RED diagnostics',result.get('diagnostics')))
  source_hashes=result.pop('source_hashes',{})
  source_records[label]=source_hashes
  for key in ('source_untracked',):
   if key in result:
    data=encoded(result.pop(key)); ref='process/source-sets/'+digest(data)+'.json'
    add(ref,data); result[key+'_ref']=ref
  data=encoded(source_hashes); ref='process/source-sets/'+digest(data)+'.json'
  add(ref,data); result['source_hashes_ref']=ref
  result.pop('git_status_porcelain',None)
  result['original_run_results_sha256']=digest(raw)
  result['curation_classification']=kind
  result['curation_note']=note
  add('process/runs/'+label+'/run-results.json',encoded(result))
  for name in ('engine.log','stdout.log','stderr.log'):
   add('process/runs/'+label+'/logs/'+name,(folder/'logs'/name).read_bytes())
  matches=[]; missing=[]
  for path in OWNED+DEPENDENCIES:
   wanted=source_hashes.get(path)
   if not wanted: missing.append({'path':path,'reason':'not recorded in this run'}); continue
   actual=(ROOT/path).read_bytes()
   if digest(actual)!=wanted: missing.append({'path':path,'recorded_sha256':wanted,'reason':'historical bytes differ from current scoped input; not reconstructed'}); continue
   snapshot='process/inputs/'+wanted+'/'+Path(path).name
   add(snapshot,actual)
   matches.append({'path':path,'sha256':wanted,'snapshot':snapshot})
  bindings.append({'run':label,'matching_scoped_inputs':matches,'unavailable_historical_inputs':missing,'qualification':'Only explicitly matching bytes are supplied. Full monitor source-hash maps remain recorded; this is not a full historical checkout.'})
  run_index.append({'run':label,'classification':kind,'actual_exit':result.get('actual_exit'),'elapsed_seconds':result.get('elapsed_seconds'),'assertion_footer':observed,'diagnostics':result.get('diagnostics'),'note':note})
 final_folder=BASE/(args.moving_label+'-plates')
 info=json.loads((final_folder/'capture-info.json').read_bytes())
 assert info['failures']==0 and info['save_writes']==0 and info['producers_stayed_live']
 assert info['mandatory_west_boundary_arrived'] and info['inside_cutaway'] and info['outside_restored']
 assert info['ordinary_pickup']['picked'] and info['ordinary_pickup']['armed'] and info['ordinary_pickup']['monitoring'] and info['inventory_received_staged_instance']
 assert info['ambient_spawned']>0 and info['projectile_covered_observations']>0 and info['projectile_exposed_observations']>0 and info['tell_covered_observations']>0 and info['tell_exposed_observations']>0
 assert len(info['route'])==7 and all(q['destination_reached'] and q['arrival_distance']<8 for q in info['route'])
 frames=info['frames']
 crossings=info['first_foreground_crossings']
 pick=lambda t:min(range(len(frames)),key=lambda i:abs(frames[i]['simulation_time']-t))
 selected={
  'visible-windup.png':pick(next(q['simulation_time'] for q in crossings if q['kind']=='visible ordinary windup')),
  'foreground-projectile.png':pick(next(q['simulation_time'] for q in crossings if q['kind']=='visible projectile')),
  'ordinary-collection.png':next(i for i,q in enumerate(frames) if q['ordinary_picked']),
  'doorway-cutaway.png':min((i for i,q in enumerate(frames) if q['phase']=='actual doorway cutaway'),key=lambda i:float(re.search(r',\s*([-\d.]+)\)',frames[i]['player_world']).group(1))),
  'boundary-arrival.png':len(frames)-1,
 }
 image_index=[]
 for name,index in selected.items():
  source=final_folder/('frames/frame-%04d.png'%index)
  data=source.read_bytes(); add('native/'+name,data)
  image_index.append({'file':'native/'+name,'source_frame':index,'source_sha256':digest(data),'sample':frames[index]})
 add('native/capture-info.json',(final_folder/'capture-info.json').read_bytes())
 failed_info=BASE/'continuation-moving-cover-plates/capture-info.json'
 add('process/failed-route/capture-info.json',failed_info.read_bytes())
 add('process/failed-route/crowded-final-leg.png',(BASE/'continuation-moving-cover-plates/frames/frame-0107.png').read_bytes())
 # Read actual committed bytes; a commit label alone proves no input match.
 commit=subprocess.check_output(['git','-C',str(ROOT),'rev-parse',args.code_commit],text=True).strip()
 def committed(path):
  value=subprocess.run(['git','-C',str(ROOT),'show',commit+':'+path],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
  return value.stdout if value.returncode==0 else None
 owned_commit=[]
 for path in OWNED:
  content=committed(path)
  if content is None or digest(content)!=digest((ROOT/path).read_bytes()): raise ValueError('Owned code commit differs: '+path)
  owned_commit.append({'path':path,'sha256':digest(content)})
 native_commit=[]
 scopes={
  'continuation-cue-final':RUNTIME+('tools/tests/WorldCueCoverRenderTest.gd','tools/tests/WorldCueCoverRenderTest.tscn'),
  'continuation-cue-additional-green':RUNTIME+('tools/tests/WorldCueAdditionalRenderTest.gd','tools/tests/WorldCueAdditionalRenderTest.tscn','tools/tests/WorldCueCoverRenderTest.gd'),
  'continuation-caller-green':RUNTIME+('tools/tests/EnemyCalloutContactTest.gd','tools/tests/EnemyCalloutContactTest.tscn'),
  args.moving_label:OWNED,
 }
 for label,scope in scopes.items():
  matches=[]; unrecorded=[]
  for path in scope:
   content=committed(path); recorded=source_records[label].get(path)
   if recorded is None: unrecorded.append(path); continue
   if content is None or digest(content)!=recorded: raise ValueError('Committed scoped input differs from native run: '+label+' '+path)
   matches.append({'path':path,'sha256':recorded})
  native_commit.append({'run':label,'matching_execution_scope':matches,'monitor_unhashed_paths':unrecorded})
 add('code-commit-bindings.json',encoded({'commit':commit,'owned_commit_files':owned_commit,'native_execution_bindings':native_commit,'qualification':'All 30 owned files match actual Git blobs. The monitor hashes 29 of them for the final moving run; the UID sidecar is committed/staging-verified but not a monitor-hashed runtime input. Native probe execution scopes omit unused moving/test files. This establishes the bounded cue slice, not a full integrated-Game checkout or later household edits.'}))
 add('process/package-cues.py',Path(__file__).read_bytes())
 add('process/input-bindings.json',encoded(bindings))
 add('process/run-index.json',encoded(run_index))
 add('process/selected-frames.json',encoded(image_index))
 add('process/owned-code-paths.json',encoded({'runtime':RUNTIME,'all_owned_paths':OWNED,'shared_dependencies_read_only':DEPENDENCIES}))
 # Root may encode directly to OUT; or provide the matching complete scratch
 # triplet. Never bundle an MP4 without its actual encoding/decode records.
 video=[OUT/('moving-route'+suffix) for suffix in ('.mp4','.encoding.json','.decode.json')]
 if not any(p.exists() for p in video): video=[BASE/'videos'/(args.moving_label+suffix) for suffix in ('.mp4','.encoding.json','.decode.json')]
 video_present=all(p.exists() for p in video)
 if any(p.exists() for p in video) and not video_present: raise ValueError('Incomplete moving video/encoding/decode triplet')
 if video_present:
  encoding=json.loads(video[1].read_bytes()); decoding=json.loads(video[2].read_bytes())
  if decoding.get('exit_code',decoding.get('exit'))!=0 or encoding.get('video_sha256')!=digest(video[0].read_bytes()): raise ValueError('Video hash/decode failure')
  if encoding.get('source_metadata_sha256')!=digest((final_folder/'capture-info.json').read_bytes()): raise ValueError('Video is bound to another capture manifest')
  for source,suffix in zip(video,('.mp4','.encoding.json','.decode.json')): add('moving-route'+suffix,source.read_bytes())
  concat=OUT/'moving-route.ffconcat'
  if concat.exists():
   if encoding.get('concat_sha256')!=digest(concat.read_bytes()): raise ValueError('Concat execution record hash differs')
   add('moving-route.ffconcat',concat.read_bytes())
 table='\n'.join('| '+q['run']+' | '+q['classification']+' | '+str(q['actual_exit'])+' | '+(str(q['assertion_footer'][1])+'/'+str(q['assertion_footer'][2]) if q['assertion_footer'] else 'see log')+' |' for q in run_index)
 readme=f'''# Bounded live cue and entity-depth continuation

20 October 2026. Qualified local V1 implementation/evidence for the kept S2 home, seed 16102026/chunk(0,3), building 944996572. This closes the sampled remaining draw-owner failures; full visual, ordinary human-play, balance and performance acceptance remain unclaimed.

The existing enemy body/pickup icon treatment is preserved. Ordinary mixed cues, four projectile body families, sniper lines, Warden/pickup frames, secondary elite/bomber paint, pooled text and eligible fallback bodies use the shared WorldCover contract. Covered additive light is suppressed. Atlas-frame contact, raised physical-owner contact and shared visual text columns are tested independently. Boss-owned custom surfaces/anchor exceptions and exotic attack families are outside this bounded coverage claim. No actor AI, collision, damage, spawning, pickup rules, atlas buffers or gameplay RNG was changed by this slice.

## Actual moving route

The [measured clip](moving-route.mp4) is accompanied by its encoding and decode records when the complete triplet is present. The encoder sidecar uses generic “combat” wording for its measured wall-time hold; this recording is the moving route described below. Video present in this packaging pass: **{str(video_present).lower()}**. Five useful unedited source PNGs are selected, with original frame indices/hashes in [selected-frames.json](process/selected-frames.json): [ordinary windup](native/visible-windup.png), [foreground projectile](native/foreground-projectile.png), [ordinary collection](native/ordinary-collection.png), [actual doorway cutaway](native/doorway-cutaway.png), [boundary arrival](native/boundary-arrival.png). The entire raw-frame directory is omitted.

The [full capture manifest](native/capture-info.json) records {len(frames)} sampled frames, {info['simulation_seconds']:.2f} simulated seconds and {info['wall_seconds']:.3f} measured route wall seconds. All seven mandatory destinations were reached within 8 world pixels; actual westbound boundary arrival is true. The real roof opens on entry and restores on exit. Ambient spawning produced {info['ambient_spawned']} enemies during recording; streaming, the procedural director and enemy scheduling stayed active. An ordinary ring_crusher instance armed with its normal one-second delay, kept monitoring/magnet eligibility, collected through production contact/magnet logic at {info['ordinary_pickup']['collection_distance']:.2f}px and reached inventory/bag. Zero failures/profile writes.

There are {info['projectile_covered_observations']} covered and {info['projectile_exposed_observations']} exposed on-screen projectile observations, plus {info['tell_covered_observations']} covered and {info['tell_exposed_observations']} exposed ordinary windup observations. These are repeated sampled observations, not unique entity counts. The first covered windup matches original tree alpha 0.9608. The first covered projectile has tree-source strength 0 and crosses another opaque foreground surface; both are not claimed to cross the same tree.

Initial player warp, two ordinary live Spitters, one ordinary ring instance, god mode and scripted native movement/aim/fire are disclosed staging. Modal dossier onboarding is bypassed. No never_cull metadata, frozen actor simulation, disabled spawner/streaming/scheduler, pickup monitoring override, direct collection call or recorded-route teleport is used. The camera follows the player. One approach required bounded replanning and real capsule-tested/input-driven sidesteps; every destination retains the arrival gate. Its sampled slide-contact list is empty, so that timeout is not attributed to a specific collider. These captures include low-rate framebuffer readback and post-route PNG encoding and establish no rendering-performance result.

## Test chronology and limits

| Recorded run | Classification | Exit | Assertions |
| --- | --- | --- | --- |
{table}

The initial sniper current_scene attempt is invalid. The first implementation attempt has a real autoload child-creation/orphan-resource failure and an animated-glint screenshot comparison. The next attempt has an isolated viewport material-ownership fixture error. They are retained as failures, never GREEN. The qualified additional RED establishes eight draw-owner failures but its initial tiny ordinary-bolt presence guard is invalid; the separate 4/1 bolt RED corrects that fixture. The first occupied route also fails its final destination; [its manifest](process/failed-route/capture-info.json) and [crowded-leg diagnostic](process/failed-route/crowded-final-leg.png) remain historical evidence.

Focused tests and the native moving route are different scopes. Headless icon/elite checks cover their headless branches; the additional native pixel tests supply actual paint checks. Native enemy/pickup regressions keep existing sampled body/icon behavior. Source/material snapshots vary across these historical runs, and final household frontage/pale-surface edits may proceed separately. This packet does not retroactively claim final integrated-main checks for older snapshots.

## Provenance

[Run index](process/run-index.json), complete monitor command/exits/resource samples/logs, and original run-results JSON SHA256 are retained. Full source-hash/source-untracked maps are losslessly deduplicated under process/source-sets. git_status_porcelain is omitted; its original JSON hash remains. Only scoped current files whose bytes exactly match a recorded hash are supplied as [input bindings](process/input-bindings.json); unavailable historical bytes are explicitly listed and never reconstructed. The monitor's absolute native/scratch paths are historical execution records, not promises that all raw outputs are bundled. Selected PNGs retain exact source bytes. The encoded frame list/concat records refer to the original scratch sequence; only the five indexed source PNGs are bundled here. [Actual code-commit bindings](code-commit-bindings.json) verify commit7875d1981c79e85f049a07b5c696889b0350a1c4 against the declared owned/execution scopes. All 30 owned code files match actual Git blobs;29 are monitor-hashed final moving inputs. The UID sidecar is staging/commit-verified and is not represented as a captured source hash. These bindings establish the cue slice, not all integrated household/world source files.
'''
 add('README.md',readme.encode())
 index={'scope':'bounded V1 cues and one occupied route','moving_run':args.moving_label,'video_triplet_present':video_present,'files':[{'path':p,'sha256':digest(data),'bytes':len(data)} for p,data in sorted(planned.items())]}
 add('index.json',encoded(index))
 if args.write:
  for path,data in planned.items():
   destination=OUT/path; destination.parent.mkdir(parents=True,exist_ok=True); destination.write_bytes(data)
  print('Wrote',len(planned),'explicit artifacts to',OUT)
 else: print('Read-only preflight:',len(planned),'artifacts;',len(runs),'runs;',len(selected),'unedited PNGs; video=',video_present)

if __name__=='__main__': main()
