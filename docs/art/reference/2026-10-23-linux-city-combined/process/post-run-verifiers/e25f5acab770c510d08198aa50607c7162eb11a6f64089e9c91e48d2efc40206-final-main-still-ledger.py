import hashlib,importlib.util,json,struct,sys
from pathlib import Path
P=Path('/var/tmp/sa-city22/final-combined/main-r5-r1/execution.json')
x=json.loads(P.read_text());index=int(sys.argv[1]);c=x['cases'][index]
assert 2<=index<=6 and len(x['executed_cases'])==index
spec=importlib.util.spec_from_file_location('final_record',Path('/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/street-native-queue.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
r=m.run_record(c['label']);raw=json.loads(Path(r['path']).read_text())
args=c['command'][c['command'].index('--')+1:]
assert raw['git_head']==x['final_main_sha'] and not raw['git_status_porcelain'] and raw['command'][-len(args):]==args
for name,h in x['final_main_source_hashes'].items():
 assert raw['source_hashes'].get(str(Path(name).relative_to(Path(x['project']))))==h,name
p=Path(c['out'])/'capture-info.json';d=json.loads(p.read_text());fc=d['final_combined'];rd=fc['render_dimensions'];reduced=c['review']=='reduced'
checks={'zero_failures':d['failures']==0,'zero_save_writes':d['save_writes']==0,
'context':d['segment']==c['segment'] and d['seed']==c['seed'] and d['theme']==c['theme'] and d['review']==c['review'],
'actual_r4_entrypoint':d['capture_scene']==str(Path(x['project'])/'.superpowers/continuation-20261022/final-combined-r4/FinalCombinedCityPreview.tscn'),
'normal_hud_details':d['normal_hud'] is True and d['optional_details_hidden'] is False,
'ordinary_reload_fixture':d['fixture']['streaming_frozen_after_reload'] is True,
'cap_and_physics':fc['render_fps_cap']==20 and fc['physics_ticks_per_second']==60,
'real_settings':fc['reduced_motion_setting'] is reduced and fc['atmosphere']['reduced_motion'] is reduced and fc['combat_flash_setting']==('off' if reduced else 'full'),
'actual_atmosphere_theme':fc['atmosphere']['profile']['id']==c['theme'],
'actual_native_dimensions':rd['window_size']==c['expected_window'] and rd['display_server_size']==c['expected_window'] and rd['content_scale_size']==c['expected_logical_view'] and rd['logical_visible_size']==c['expected_logical_view'] and all(abs(a-b)<0.1 for a,b in zip(rd['source_derived_native_size'],c['expected_window'])),
'real_opaque_exterior':fc['final_exterior']['all_opaque_outside'] is True,
'actual_parking':fc['parking']['clearance_px']==64 and fc['parking']['static_capsule_checked'] is True and fc['parking']['ordinary_physics_frames']>=4 and fc['parking']['outside_and_opaque_after_settle'] is True and fc['parking']['camera_unchanged'] is True}
stills=fc['capture_stills'];checks['capture_still_controls']=len(stills)==1 and stills[0]['file']=='ground-before.png' and all(s['exterior']['all_opaque_outside'] is True and s['render_fps_cap_before_still']==20 and s['physics_ticks_per_second_before_still']==60 for s in stills)
png=Path(c['out'])/'ground-before.png';b=png.read_bytes();checks['original_png_size']=b[:8]==b'\x89PNG\r\n\x1a\n' and list(struct.unpack('>II',b[16:24]))==c['expected_window']
assert all(checks.values()),checks
sha=lambda q:hashlib.sha256(Path(q).read_bytes()).hexdigest()
x['executed_cases'].append({'id':c['id'],'label':c['label'],'command':c['command'],'run':{k:v for k,v in r.items() if k!='source_hashes'},'actual_source_head':raw['git_head'],'required_source_map_matches':True,'manifest':{'path':str(p),'sha256':sha(p)},'checks':checks,'images':[{'path':str(png),'bytes':len(b),'sha256':sha(png)}],'scope':'Functional staged exterior; no actor/tell combat or performance claim. Root final visual review is separate.'})
P.write_text(json.dumps(x,indent=2)+'\n');print('accepted',c['id'],'checks',len(checks),'sources',len(x['final_main_source_hashes']))

