#!/usr/bin/env python3
"""Compact completed weathering evidence. Never launches engines, Git, or bakes.

Source preparation only: root must release the heavy-work hold before --execute.
"""
from pathlib import Path
import argparse
import gzip
import hashlib
import json
import math
import re
import runpy

HERE = Path('/var/tmp/sa-city22/packets/weathering') # Proposed adapter; original packet builder stays frozen.
ROOT = Path('/home/user/Nauris/Synthetic-Ascension')
CONTROL = ROOT / '.superpowers/continuation-20261022'
RUNS = ROOT / '.superpowers/claude-city-20261021/runs'
STAGE4 = Path('/var/tmp/sa-city22/stage4')
PLAN_SHA = 'e667861b9b136fa79e60b64e60feafb269a43166c5ccac9cea8ba97d56d517a4'
COST_ROOT = CONTROL / 'stage4-cost-r3'
COST_DRIVER_SHA = 'a8ea1573fea86c4f6a01bd202a5821e64238c1b8d1facc479ae46df0dc424af2'
RESUME_ROOT = CONTROL / 'stage4-cost-resume-r4'
RESUME_PROTOCOL_SHA = '1939eb80399153253515ab1597f23fe9174cf86e2b0f59599c9061fcea819c32'
RESUME_REFERENCE_PINS = {'/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/stage4-cost-resume-r4/resume.py': {'sha256': '74a80dc8f84b53681e65ddf63f854df35e80c9e1ccd7c73621a6a137f3b78291', 'bytes': 18348}, '/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/stage4-cost-resume-r4/protocol.json': {'sha256': '1939eb80399153253515ab1597f23fe9174cf86e2b0f59599c9061fcea819c32', 'bytes': 5512}, '/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/stage4-cost-resume-r4/source-bindings.json': {'sha256': '4c80eebe93add7329bc49d99e0b8a2d7ac43a81d2bbe8251e3de23a19b772cea', 'bytes': 1737}, '/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/stage4-cost-resume-r4/root-source-review.json': {'sha256': '887b9686f914652f2fcf42bd9d1221f440123807f840d9e9ec8ebdbc197c488d', 'bytes': 1292}, '/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/stage4-cost-resume-r4-independent-review.json': {'sha256': '4a3980288f06766aa37ebb240bdf0b357246192c47980163045177e15fe90c33', 'bytes': 3528}}
THRESHOLD = 128 * 1024


def sha(data):
    return hashlib.sha256(data).hexdigest()


def load(path):
    return json.loads(path.read_text())


def require(ok, message):
    if not ok:
        raise ValueError(message)


def matched(path, digest):
    require(sha(path.read_bytes()) == digest, 'Recorded bytes changed: ' + str(path))


def clean_transport(raw, outer, expected=0):
    return (bool(raw.get('ended_utc')) and raw.get('actual_exit') == expected
            and raw.get('runner_exit') == expected
            and raw.get('stop_reason') == ('completed' if expected == 0 else 'nonzero_exit')
            and outer.get('reason') == 'completed' and outer.get('wrapper_exit') == expected
            and outer.get('received_signal') is None
            and (not raw.get('diagnostics') if expected == 0 else bool(raw.get('diagnostics'))
                 and all(line.startswith('ERROR: FAIL: ') for line in raw['diagnostics'])))


def bind(raw, expected):
    require(all(raw.get('source_hashes', {}).get(path) == digest for path, digest in expected.items()),
            'Actual launch source differs from reviewed bytes')


def run_input(raw_path):
    raw_path = raw_path.resolve()
    require(raw_path.parent.parent == RUNS and raw_path.name == 'run-results.json', 'Run path outside recorded roots')
    raw = load(raw_path)
    label = re.sub(r'-\d+$', '', raw_path.parent.name)
    outer_path = CONTROL / (label + '-thermal.json')
    return raw, load(outer_path), outer_path, (raw_path.parent/'logs/stdout.log').read_text()


def validate_appearance(review, plan):
    require(review.get('candidate') == plan['candidate']
            and review.get('status') == 'selected material-support stills visually accepted; receipt review and comparative cost pending'
            and {row.get('context') for row in review.get('views', [])} == set(plan['contexts'])
            and len(review.get('views', [])) == 4, 'Root selected-view review missing or stale')
    for row in review['views']:
        require(row.get('root_viewed_both') is True, 'Root did not review both selected originals')
        for side in ('before', 'after'):
            selected = plan['views'][row['context']+'/'+side]
            image = Path(selected['directory'])/selected['selected_image']
            record = row.get('original_views', {}).get(side, {})
            require(record.get('path') == str(image), 'Root review selected a different image')
            matched(image, record.get('sha256'))


def positive_gpu(report):
    if not report.get('rounds'): return False
    for index,item in enumerate(report['rounds']):
        samples=item.get('samples',[]);count=len(samples)
        if item.get('round')!=index or not count or item.get('gpu_positive_samples')!=count or item.get('requested_frames')!=count: return False
        for metric in ('gpu_ms','viewport_cpu_ms','setup_cpu_ms','process_ms'):
            values=[row.get(metric) for row in samples]
            if not all(type(value) in (int,float) and math.isfinite(value) for value in values): return False
            if metric=='gpu_ms' and min(values)<=0: return False
            values.sort();expected={'count':count,'min':values[0],'p50':values[(count-1)//2],'p95':values[math.ceil((count-1)*0.95)],'max':values[-1]}
            if item.get('summary',{}).get(metric)!=expected: return False
    return True


def canonical_cost_command(case, directory, queue, driver):
    """Reconstruct frozen protocol; saved planned/raw agreement alone is insufficient."""
    side=case.get('side');require(side in ('baseline','candidate'), 'Cost source side differs')
    project=driver['BASELINE'] if side=='baseline' else driver['CANDIDATE']
    require(case.get('project')==str(project), 'Cost command project differs')
    if case.get('native') is False:
        require(case.get('id')=='parse-'+side, 'Cost parser identity differs')
        arguments=['--headless',str(driver.get('R3', CONTROL)/'stage4-cost-source-parse.tscn')]
    else:
        match=re.fullmatch(r'(s[2679])-(960|1080)-(baseline|candidate)',case.get('id',''))
        require(match is not None and case.get('native') is True, 'Cost native identity differs')
        key,size_name,identity_side=match.groups();size=(960,540) if size_name=='960' else (1920,1080)
        require(identity_side==side and case.get('key')==key and case.get('pair')==key+'-'+size_name
                and case.get('size')==list(size), 'Cost native identity/context/size fields differ')
        context=driver['CONTEXTS'][key];output=directory/(case['id']+'.json')
        require(case.get('json')==str(output), 'Cost native report path differs')
        arguments=['--rendering-driver','opengl3','--audio-driver','Dummy',str(driver['SCENE']),'--','--visible',
            '--segment='+str(context['segment']),'--world-seed='+str(context['seed']),'--expect-theme='+context['theme'],
            '--camera='+','.join(map(str,context['camera'])),'--size='+'x'.join(map(str,size)),'--sample-fps=30','--warmup=45',
            '--frames='+('30' if queue['smoke_only'] else '120'),'--rounds='+('1' if queue['smoke_only'] else '3'),'--json='+str(output)]
        if size_name=='1080': arguments.append('--fullscreen')
        if queue['reduced_motion']: arguments.append('--reduced-motion')
    expected=driver['guard_command'](case['label'],project,arguments,case['native'])
    require(case.get('command')==expected, 'Cost command is not the canonical frozen parser/native invocation')
    return expected


def validate_cost_external(external, plan, driver):
    """Only frozen R3's fourteen advertised programs/proofs can admit new cost."""
    proof = CONTROL/'stage4-cost-viewport-source-review'
    expected = {str(COST_ROOT/name) for name in ('FinalCombinedCityPreview.gd','FinalCombinedCityPreview.tscn',
        'Stage4StaticCostProbe.gd','Stage4StaticCostProbe.tscn','stage4-cost-source-parse.gd',
        'stage4-cost-source-parse.tscn','stage4-static-cost-queue.py')}
    expected |= {str(proof/name) for name in ('viewport.cpp','window.cpp','official-source.json')}
    expected |= {str(CONTROL/name) for name in ('stage4-cost-camera-sources.json','guarded_engine.py')}
    expected |= {str(ROOT/'.superpowers/claude-city-20261021'/name) for name in ('sa_engine.py','run_engine_slot.py')}
    require(plan.get('cost_protocol',{}).get('revision') == 'R3'
            and set(external) == expected and len(external) == 14
            and external == plan['cost_protocol']['external_bindings'], 'Cost exact R3 external program/proof inventory differs')
    require(external[str(COST_ROOT/'stage4-static-cost-queue.py')]['sha256'] == COST_DRIVER_SHA
            and external[str(driver['HELPER'])]['sha256'] == driver['HELPER_SHA']
            and external[str(driver['SCENE'])]['sha256'] == driver['SCENE_SHA']
            and external[str(driver['CAMERA_SOURCES'])]['sha256'] == driver['CAMERA_SOURCES_SHA'], 'Cost frozen R3 helper/driver/camera differs')


def validate_cost_queue(directory, queue, plan, driver):
    """Recompute actual receipt/report/pair gates; a saved 'checked' string is insufficient."""
    require(queue.get('ended_utc') and queue.get('status') in ('smoke_checked', 'paired_observations_checked'), 'Cost queue partial/stopped')
    require(not queue.get('error') and queue['status'] == ('smoke_checked' if queue.get('smoke_only') else 'paired_observations_checked'), 'Cost status/flags differ')
    require(queue.get('candidate_expected_sha') == plan['candidate'] and queue.get('baseline_expected_sha') == plan['baseline']
            and queue.get('timing_window_attestation') is True, 'Cost source/window attestation differs')
    require(Path(queue.get('output','')).resolve()==directory.resolve(), 'Cost output directory differs')
    protocol = {'start_c':65, 'max_queue_wait_s':900, 'cpu_affinity':[0,1], 'setup_duty':0.25,
                'release_marker':'TOOL_COST_READY', 'runtime_stop_c':90, 'sustained_stop_c':85,
                'sustained_samples':3, 'sample_fps':30, 'warmup_frames':45,
                'rounds':1 if queue.get('smoke_only') else 3, 'frames_per_round':30 if queue.get('smoke_only') else 120, 'per_case_yield_s':3}
    require(queue.get('protocol') == protocol, 'Cost protocol differs')
    for side, project in (('baseline',driver['BASELINE']),('candidate',driver['CANDIDATE'])):
        state=queue.get('source_states',{}).get(side,{})
        require(state.get('project')==str(project) and state.get('git_head')==plan[side]
                and state.get('tracked_status')=='', 'Cost preflight source state differs')
    require(all(driver['allowed'](item['path']) for item in driver['changed_keys'](queue['source_maps_initial']['baseline'],queue['source_maps_initial']['candidate']))
            and all(driver['allowed'](path) for path in queue.get('committed_changed_paths',[])), 'Cost initial source scope differs')
    external = queue.get('external_bindings', {})
    validate_cost_external(external, plan, driver)
    for path, entry in external.items():
        matched(directory/'external-sources'/(entry['sha256']+'-'+Path(path).name), entry['sha256'])
    planned, cases = queue.get('planned_cases', []), queue.get('cases', [])
    require(len(planned) == len(cases) and len({item['id'] for item in cases}) == len(cases), 'Cost cases missing or duplicated')
    contexts=queue.get('contexts',{})
    require(contexts and all(value==driver['CONTEXTS'].get(key) for key,value in contexts.items()), 'Cost context definitions differ')
    sizes={tuple(case.get('size',[])) for case in planned if case.get('native')}
    require(sizes and sizes<={(960,540),(1920,1080)}, 'Cost size scope differs')
    expected_ids={'parse-baseline','parse-candidate'}|{key+'-'+('960' if size[0]==960 else '1080')+'-'+side for key in contexts for size in sizes for side in ('baseline','candidate')}
    require({case['id'] for case in planned}==expected_ids, 'Cost planned parsers/context-size pairs are incomplete')
    pairs = {}
    for expected, case in zip(planned, cases):
        require(all(case.get(key) == value for key, value in expected.items()) and case.get('ended_utc')
                and case.get('wrapper_exit') == 0, 'Cost case differs or did not end')
        canonical_cost_command(case,directory,queue,driver)
        receipt = case.get('run', {}); raw_path = Path(receipt.get('path', ''))
        raw, outer, outer_path, stdout = run_input(raw_path)
        require(raw_path.parent.name.startswith(case['label']+'-') and clean_transport(raw, outer), 'Unclean actual cost case')
        matched(raw_path, receipt.get('sha256')); matched(outer_path, receipt.get('thermal_sha256'))
        require(receipt.get('thermal_path') == str(outer_path), 'Cost guard path differs')
        side = case['side']; expected_head = plan['baseline'] if side == 'baseline' else plan['candidate']
        project=driver['BASELINE'] if side=='baseline' else driver['CANDIDATE']
        require(case.get('project')==str(project) and Path(raw.get('project_root','')).resolve()==project, 'Cost actual project differs')
        engine_args=case['command'][case['command'].index('--')+1:]
        require(raw.get('command',[])[-len(engine_args):]==engine_args, 'Cost actual engine arguments differ')
        require(raw.get('git_head') == expected_head and not raw.get('git_status_porcelain'), 'Actual cost source commit is dirty/different')
        bind(raw, queue['source_maps_initial'][side])
        require(outer.get('cpu_affinity') == [0,1] and outer.get('start_temperature_c') == 65
                and outer.get('runtime_temperature_stop_c') == 90 and outer.get('sustained_temperature_stop_c') == 85
                and outer.get('sustained_temperature_samples') == 3 and outer.get('duty_cycle') == 0.25, 'Actual cost guard protocol differs')
        if not case.get('native'):
            require('--headless' in raw.get('command', []) and 'Stage4CostSourceParse: checked=2 failures=0' in stdout
                    and outer.get('duty_released') is False and outer.get('release_marker') is None, 'Cost parser verdict/protocol missing')
            continue
        require(outer.get('duty_released') is True and outer.get('release_marker') == 'TOOL_COST_READY'
                and '--headless' not in raw.get('command', []) and 'TOOL_COST_READY' in stdout, 'Actual cost setup duty/backend differs')
        path = Path(case['json']).resolve(); require(path.parent == directory.resolve(), 'Cost report outside case directory')
        report = driver['validate_report'](path, driver['CONTEXTS'][case['key']], tuple(case['size']), queue['smoke_only'], queue['reduced_motion'])
        require(report.get('valid') is True and report == case.get('report') and positive_gpu(report['data']), 'Actual cost timer/fixture report rejected')
        fingerprints=report['data'].get('shader_source_fingerprints',{})
        require(fingerprints and all(raw.get('source_hashes',{}).get(path.removeprefix('res://'))==digest for path,digest in fingerprints.items()), 'Cost shader-source fingerprints differ from actual launch')
        pairs.setdefault(case['pair'], {})[side] = (report, raw)
    require(len(pairs) > 0 and set(pairs) == set(queue.get('pairs', {})), 'Cost pairs absent/incomplete')
    checked = {}
    for key, sides in pairs.items():
        require(set(sides) == {'baseline','candidate'}, 'Unpaired cost result')
        before, after = sides['baseline'], sides['candidate']
        comparison = driver['compare_pair'](before[0], after[0])
        delta = driver['changed_keys'](before[1]['source_hashes'], after[1]['source_hashes'])
        comparison.update(launched_changed_source_keys=delta, launched_source_scope_valid=all(driver['allowed'](item['path']) for item in delta))
        require(comparison['comparable_geometry_and_protocol'] is True and comparison['launched_source_scope_valid'] is True
                and comparison == queue['pairs'][key], 'Cost actual geometry/protocol/source pair mismatch')
        checked[key] = comparison
    full = set(checked) == {key+'-'+size for key in ('s2','s6','s7','s9') for size in ('960','1080')}
    return {'state':'functional_gpu_smoke_only' if queue['smoke_only'] else 'paired_static_observations_checked', 'protocol_revision':'R3',
            'full_normal_motion_matrix':full and not queue['smoke_only'] and not queue['reduced_motion'], 'reduced_motion':queue['reduced_motion'],
            'dimension_contract':plan['cost_protocol']['dimension_contract'],
            'pairs':checked, 'limits':queue.get('limits'), 'not_claimed':'Live Game CPU budget, uncapped throughput, exact GPU query identity or final combined-source cost.'}



def validate_resume_case(case, directory, origin, plan, driver, resume):
    """Actual old/new receipts retain their own canonical command and source origin."""
    canonical_cost_command(case, directory, {'smoke_only':False,'reduced_motion':False}, driver)
    receipt, report, source = resume['validated_case'](case, origin['source_maps_initial'], plan[case['side']], case)
    raw, outer, guard, stdout = run_input(Path(receipt['path']))
    require(clean_transport(raw, outer) and str(guard) == receipt['thermal_path'], 'Resume actual transport differs')
    require(outer.get('cpu_affinity') == [0,1] and outer.get('start_temperature_c') == 65
            and outer.get('runtime_temperature_stop_c') == 90 and outer.get('sustained_temperature_stop_c') == 85
            and outer.get('sustained_temperature_samples') == 3 and outer.get('duty_cycle') == 0.25,
            'Resume actual guard protocol differs')
    if case['native']:
        require(Path(case['json']).resolve().parent == directory.resolve()
                and '--headless' not in raw['command'] and 'TOOL_COST_READY' in stdout
                and report == case.get('report') and positive_gpu(report['data']), 'Resume native report/backend/timer differs')
        fingerprints = report['data'].get('shader_source_fingerprints',{})
        require(fingerprints and all(source.get(path.removeprefix('res://')) == digest for path,digest in fingerprints.items()),
                'Resume shader-source fingerprints differ from actual launch')
    else:
        require('--headless' in raw['command'], 'Reused parser backend differs')
    return receipt, report, source


def validate_resume_queue(directory, queue, plan, driver, resume):
    """Only terminal complete 2-parser/6-old/10-new evidence admits eight corrected pairs."""
    require(queue.get('ended_utc') and queue.get('status') == 'mixed_origin_paired_observations_checked'
            and not queue.get('error') and queue.get('received_signals') == []
            and queue.get('timing_window_attestation') is True, 'Resume active/partial/stopped/unattested')
    require(directory == STAGE4/'static-ecb-resume-r4' and queue.get('output') == str(directory), 'Resume output differs')
    matched(RESUME_ROOT/'protocol.json', RESUME_PROTOCOL_SHA)
    protocol = load(RESUME_ROOT/'protocol.json')
    require(queue.get('protocol_revision') == protocol['revision']
            and queue.get('origin_queue') == protocol['origin_queue']
            and queue.get('origin_queue_sha256') == protocol['origin_queue_sha256']
            and queue.get('original_failed_queue_unchanged') is True, 'Resume original strict failure binding differs')
    validate_cost_external(queue.get('original_fourteen_bindings',{}), plan, driver)
    two = {path:RESUME_REFERENCE_PINS[path] for path in (str(RESUME_ROOT/'resume.py'),str(RESUME_ROOT/'protocol.json'))}
    require(queue.get('resume_bindings') == two, 'Resume exact separate driver/protocol bindings differ')
    for path,entry in {**queue['original_fourteen_bindings'],**two}.items():
        matched(directory/'external-sources'/(entry['sha256']+'-'+Path(path).name), entry['sha256'])
    origin, reused, reports, sources, _ = resume['prior_evidence'](protocol)
    require(queue.get('reused_cases') == reused and origin['smoke_only'] is False
            and origin['reduced_motion'] is False and origin.get('timing_window_attestation') is True,
            'Resume original cases/scope differ')
    for side in ('baseline','candidate'):
        state = origin['source_states'][side]
        require(state.get('git_head') == plan[side] and state.get('tracked_status') == ''
                and state.get('project') == str(driver[side.upper()]), 'Resume original source state differs')
    require(all(driver['allowed'](item['path']) for item in driver['changed_keys'](origin['source_maps_initial']['baseline'],origin['source_maps_initial']['candidate']))
            and all(driver['allowed'](path) for path in origin.get('committed_changed_paths',[])), 'Resume source scope differs')
    expected_directory, remaining = resume['remaining_plan'](origin, protocol, 'ecb-resume-r4')
    require(expected_directory == directory and queue.get('planned_remaining_cases') == remaining
            and len(queue.get('cases',[])) == 10
            and [case['id'] for case in queue['cases']] == protocol['remaining_case_ids'], 'Resume fresh case plan incomplete/duplicated/different')
    origins = []
    old_ids = [case['id'] for case in origin['cases']]
    require(old_ids == protocol['reused_case_ids'] and len(old_ids) == 8, 'Resume original prefix differs')
    for old, case in [(True,case) for case in origin['cases']] + [(False,case) for case in queue['cases']]:
        if not old:
            expected = remaining[len(origins)-8]
            require(all(case.get(key) == value for key,value in expected.items()) and case.get('ended_utc')
                    and case.get('wrapper_exit') == 0
                    and case.get('origin') == 'new resume driver; original fourteen R3 helper/program inputs', 'Resume fresh case differs')
        case_directory = Path(protocol['origin_queue']).parent if old else directory
        receipt, report, source = validate_resume_case(case, case_directory, origin, plan, driver, resume)
        if report:
            reports.setdefault(case['pair'],{})[case['side']] = report
            sources.setdefault(case['pair'],{})[case['side']] = source
        origins.append({'id':case['id'],'label':case['label'],'origin_queue':protocol['origin_queue'] if old else str(directory/'queue.json'),
            'launch_program_set':'original_fourteen' if old else 'original_fourteen_plus_resume_two',
            'command':case['command'],'run':receipt,'report':case.get('json'),
            'report_sha256':report['sha256'] if report else None,'source_inventory_origin':receipt['path']+'#source_hashes'})
    checked = resume['comparisons'](reports, sources)
    require(set(checked) == {key+'-'+size for key in ('s2','s6','s7','s9') for size in ('960','1080')}
            and checked == queue.get('pairs'), 'Resume eight actual corrected pairs differ/incomplete')
    return {'state':'mixed_origin_paired_static_observations_checked','protocol_revision':protocol['revision'],
        'full_normal_motion_matrix':True,'reduced_motion':False,'dimension_contract':plan['cost_protocol']['dimension_contract'],
        'strict_origin':{'path':protocol['origin_queue'],'sha256':protocol['origin_queue_sha256'],
            'status':origin['status'],'error':origin['error'],'pairs':origin['pairs']},
        'pairs':checked,'case_origins':origins,'program_sets':{'original_fourteen':queue['original_fourteen_bindings'],
            'original_fourteen_plus_resume_two':{**queue['original_fourteen_bindings'],**two}},
        'limits':protocol['mixed_origin_limit'],
        'not_claimed':'Statistical isolation, FPS/uncapped throughput, live Game CPU budget or final combined-source cost.'}


def setup_diagnostic_r2(plan):
    """Retain the exact completed setup failure; it cannot become cost evidence."""
    history = plan['setup_diagnostic_r2']; report_path = Path(history['report'])
    matched(report_path, history['report_sha256']); report = load(report_path)
    require(report.get('diagnose_only') is True and report.get('sampling_started') is False
            and report.get('rounds') == [] and report.get('failures') == 1 and report.get('save_writes') == 0,
            'Historical R2 setup failure changed; never admit it as timing')
    execution = load(Path(history['execution'])); records = []
    require(execution.get('ended_utc') and len(execution.get('cases',[])) == 2, 'Historical R2 execution incomplete')
    for selected, case in zip(history['records'], execution['cases']):
        path = Path(selected['raw_path']); raw, outer, guard, stdout = run_input(path)
        matched(path, selected['raw_sha256']); matched(guard, selected['guard_sha256'])
        code = selected['expected_exit']; args = selected['command'][selected['command'].index('--')+1:]
        require(case.get('label') == selected['name'] and case.get('command') == selected['command']
                and case.get('wrapper_exit') == code and raw.get('ended_utc')
                and raw.get('actual_exit') == code and raw.get('runner_exit') == code
                and raw.get('stop_reason') == ('completed' if code == 0 else 'nonzero_exit')
                and outer.get('reason') == 'completed' and outer.get('wrapper_exit') == code
                and outer.get('received_signal') is None and outer.get('duty_released') is False
                and raw.get('command',[])[-len(args):] == args and 'TOOL_COST_READY' not in stdout,
                'Historical R2 transport/setup boundary changed')
        records.append((selected['name'], path, raw, guard))
    return records, {'path':history['execution'], 'state':'setup_diagnostic_failed_before_sampling_no_cost',
        'historical_setup_diagnostic':True, 'report':str(report_path), 'report_sha256':history['report_sha256'],
        'sampling_started':False, 'rounds':0, 'actual_exit':1,
        'reason':'Original full exterior gate rejected one legitimate empty streamed DungeonRoof host; no editor-only API error, READY, timer sample or candidate measurement.'}


def prepare(plan):
    """Read/validate selected completed evidence before any packet writes."""
    records, selections = [], []
    for path, digest in plan['external_inputs'].items(): matched(Path(path), digest)
    for path,entry in RESUME_REFERENCE_PINS.items(): matched(Path(path),entry['sha256'])
    appearance = load(CONTROL/'weathering-root-native-appearance-review.json'); validate_appearance(appearance, plan)
    for name, case in plan['cases'].items():
        path = Path(case['raw_path']); raw, outer, outer_path, stdout = run_input(path)
        matched(path, case['raw_sha256']); matched(outer_path, case['guard_sha256']); matched(path.parent/'logs/stdout.log', case['stdout_sha256'])
        require(clean_transport(raw, outer, case['expected_exit']) and case['footer'] in stdout, 'Incorrect completed assertion outcome: '+name)
        bind(raw, case['source_bindings'])
        require(('--headless' not in raw['command']) == name.startswith('seam'), 'Correctness native/headless scope changed')
        records.append((name, path, raw, outer_path))
    for side,selected in plan['seam_artifacts'].items():
        directory=Path(selected['directory']);matched(directory/'provenance.json',selected['provenance_sha256'])
        provenance=load(directory/'provenance.json');raw=next(item[2] for item in records if item[0]=='seam-'+side)
        bind(raw,provenance['scoped_sha256'])
        require(str(Path(provenance['run_result']['run_root'])/'run-results.json')==plan['cases']['seam-'+side]['raw_path'], 'Seam provenance run differs')
        for name,digest in provenance['outputs_sha256'].items(): matched(directory/name,digest)
    for key, selected in plan['views'].items():
        context, side = key.split('/'); directory = Path(selected['directory']); context = plan['contexts'][context]
        matched(directory/'provenance.json', selected['provenance_sha256']); matched(directory/'survey.json', selected['survey_sha256'])
        provenance, survey = load(directory/'provenance.json'), load(directory/'survey.json')
        path = Path(selected['raw_path']); raw, outer, outer_path, _stdout = run_input(path)
        matched(path, selected['raw_sha256']); matched(outer_path, selected['guard_sha256'])
        require(clean_transport(raw, outer) and survey.get('failures') == 0, 'Unclean selected survey')
        bind(raw, provenance['scoped_sha256'])
        require(raw['git_head'] == provenance['commit'], 'Survey provenance actual HEAD differs')
        require(survey.get('segment') == context['segment'] and survey.get('world_seed') == context['seed'] and survey.get('theme_id') == context['theme']
                and next(item for item in survey['points'] if item['name']=='kit1')['world'] == context['camera'], 'Selected survey context differs')
        if side == 'before': require(raw['git_head'] == plan['baseline'] and not raw.get('git_status_porcelain'), 'Baseline survey not clean d14')
        else: bind(raw, plan['final_sources'])
        image = directory/selected['selected_image']; matched(image, provenance['outputs_sha256'][image.name])
        records.append(('view-'+key.replace('/','-'), path, raw, outer_path)); selections.append((key, directory, image, provenance))
    diagnostic_records, diagnostic_state = setup_diagnostic_r2(plan); records.extend(diagnostic_records)
    driver_path = COST_ROOT/'stage4-static-cost-queue.py'; matched(driver_path, COST_DRIVER_SHA)
    driver = runpy.run_path(str(driver_path)) # Only pinned read-only validators; main/Git/engines are never called.
    resume = runpy.run_path(str(RESUME_ROOT/'resume.py')) # Definitions/read-only correction only; never main/source_keys/project_state.
    costs = [diagnostic_state]
    for path in sorted(STAGE4.glob('static-*/queue.json')):
        require(path.resolve().parent.parent==STAGE4, 'Cost queue outside stage4 root')
        queue = load(path)
        if not queue.get('ended_utc'):
            costs.append({'path':str(path),'state':'active_or_unfinished_queue_not_harvested'}); continue
        try:
            state = (validate_resume_queue(path.parent,queue,plan,driver,resume) if path.parent == STAGE4/'static-ecb-resume-r4'
                     else validate_cost_queue(path.parent,queue,plan,driver))
        except (ValueError,RuntimeError,KeyError,TypeError,OSError) as error: state = {'state':'partial_failed_or_invalid_cost_not_accepted','reason':str(error)}
        attempts=[]
        for case in queue.get('cases',[]):
            label=case.get('label','')
            if not case.get('ended_utc') or not re.fullmatch(r'city22-stage4-cost-[a-z0-9-]+',label): continue
            guard=CONTROL/(label+'-thermal.json');outer=load(guard) if guard.is_file() else {}
            finished=[]
            for raw_path in RUNS.glob(label+'-*/run-results.json'):
                raw=load(raw_path)
                if raw.get('ended_utc'): finished.append((str(raw_path),raw))
            attempts.append({'label':label,'raw_finished_count':len(finished),'outer_reason':outer.get('reason'),
                'recorded_owned_pids':outer.get('owned_pids',[]),'no_recorded_engine_behavior':not finished and not outer.get('owned_pids'),
                'raw_outcomes':[{'path':raw_path,'actual_exit':raw.get('actual_exit'),'runner_exit':raw.get('runner_exit'),'stop_reason':raw.get('stop_reason'),'diagnostics':raw.get('diagnostics',[])} for raw_path,raw in finished]})
        state['ended_attempts']=attempts
        costs.append({'path':str(path),**state})
    return records, selections, appearance, costs


def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--execute', action='store_true'); args = parser.parse_args()
    if not args.execute:
        print('Source-only plan: no packet build. Root may --execute after CPU-work release.'); return
    plan_path = HERE/'source-plan.json'; matched(plan_path, PLAN_SHA); plan = load(plan_path)
    records, views, appearance, costs = prepare(plan)
    files, compressed, blobs = [], [], {}
    (HERE/'.gdignore').touch(exist_ok=True)
    def put(data, relative, origin, role):
        packed = len(data) > THRESHOLD and not str(relative).endswith('.png')
        target = HERE/(str(relative)+('.gz' if packed else '')); target.parent.mkdir(parents=True,exist_ok=True)
        payload = gzip.compress(data,compresslevel=6,mtime=0) if packed else data; target.write_bytes(payload)
        record = {'path':str(target.relative_to(HERE)), 'source_path':str(origin),'role':role,'raw_sha256':sha(data),'raw_bytes':len(data),'delivered_sha256':sha(payload),'delivered_bytes':len(payload)}
        files.append(record)
        if packed:
            require(gzip.decompress(payload)==data, 'Lossless compression verification failed'); compressed.append(record)
    def copy(path, relative, role): put(path.read_bytes(),relative,path,role)
    def output(relative, data): put((json.dumps(data,indent=2)+'\n').encode(),relative,'derived from explicit recorded inputs','derived evidence index')
    def retain_run(name, path, raw, guard):
        prefix = 'runs/'+name+'/'
        copy(path,prefix+'run-results.json','original launch/source/diagnostic record'); copy(guard,prefix+'thermal.json','original guard/control metadata')
        for log in (path.parent/'logs').glob('*.log'): copy(log,prefix+'logs/'+log.name,'original completed-run log')
        label = re.sub(r'-\d+$','',path.parent.name); wrapper=CONTROL/(label+'-wrapper.log')
        if wrapper.is_file(): copy(wrapper,prefix+'wrapper.log','original outer wrapper log')
    for name, run_path, raw, guard in records: retain_run(name,run_path,raw,guard)
    for key,directory,image,provenance in views:
        prefix='native/'+key+'/'
        copy(image,prefix+image.name,'unmodified root-selected kit1 native original')
        for name in ('provenance.json','survey.json'): copy(directory/name,prefix+name,'full original selected-view manifest')
    for side,selected in plan['seam_artifacts'].items():
        directory=Path(selected['directory']); provenance=load(directory/'provenance.json')
        for name,digest in provenance['outputs_sha256'].items():
            image=directory/name;matched(image,digest);copy(image,'seam/'+side+'/'+name,'original finite seam reference/candidate plate')
        copy(directory/'provenance.json','seam/'+side+'/provenance.json','original finite native seam provenance')
        if (directory/'failures.txt').is_file(): copy(directory/'failures.txt','seam/'+side+'/failures.txt','original expected RED assertion detail')
    for absolute in dict.fromkeys([*plan['external_inputs'],*RESUME_REFERENCE_PINS]):
        source=Path(absolute);relative=str(source.relative_to(CONTROL)) if source.is_relative_to(CONTROL) else 'launchers/'+source.name
        copy(source,'references/'+relative,'pinned handoff/review/helper/protocol source; not retrofitted to older launches')
    copy(plan_path,'references/source-plan.json','exact packet preparation source/record plan')
    for absolute,digest in plan['historical_stain_sources'].items():
        source=Path(absolute);matched(source,digest);blobs[digest]=source.read_bytes()
    all_bindings=[('final-candidate',plan['final_sources'])]+[(name,{key:value for key,value in raw['source_hashes'].items() if key in plan['final_sources']}) for name,_path,raw,_guard in records]
    source_index={}
    for name,bindings in all_bindings:
        source_index[name]={}
        for relative,digest in bindings.items():
            data=blobs.get(digest)
            if data is None:
                for root in map(Path,plan['source_candidates']):
                    candidate=root/relative
                    if candidate.is_file() and sha(candidate.read_bytes())==digest: data=candidate.read_bytes();blobs[digest]=data;break
            source_index[name][relative]={'recorded_sha256':digest,'snapshot':'sources/blobs/'+digest if data is not None else None,'status':'exact bytes included' if data is not None else 'hash only; exact historical bytes unavailable'}
    for digest,data in blobs.items(): put(data,'sources/blobs/'+digest,'exact launch/review-matched source','scoped source/asset bytes; not full Game closure')
    for cost in costs:
        if cost.get('historical_setup_diagnostic'):
            copy(Path(cost['report']),'setup-diagnostics/r2/report.json','exact failed setup-only R2 diagnostic; no timing samples')
            continue
        if cost['state']=='active_or_unfinished_queue_not_harvested': continue
        queue_path=Path(cost['path']);directory=queue_path.parent;queue=load(queue_path);prefix='cost/'+directory.name+'/'
        copy(queue_path,prefix+'queue.json','original ended cost queue including failures/finite mask samples')
        for absolute,entry in (queue.get('external_bindings') or {**queue.get('original_fourteen_bindings',{}),**queue.get('resume_bindings',{})}).items():
            source=directory/'external-sources'/(entry['sha256']+'-'+Path(absolute).name)
            if source.is_file(): copy(source,prefix+'external-sources/'+source.name,'actual advertised prelaunch external snapshot; exact hashes remain in queue')
        for case in queue.get('cases',[]):
            if not re.fullmatch(r'city22-stage4-cost-[a-z0-9-]+',case.get('label','')): continue
            retained=False
            for raw_path in RUNS.glob(case['label']+'-*/run-results.json'):
                raw=load(raw_path)
                if raw.get('ended_utc'):
                    guard=CONTROL/(case['label']+'-thermal.json');retain_run(directory.name+'-'+case['id']+'/'+raw_path.parent.name,raw_path,raw,guard);retained=True
            if not retained:
                for suffix in ('-thermal.json','-wrapper.log'):
                    source=CONTROL/(case['label']+suffix)
                    if source.is_file(): copy(source,'runs/'+directory.name+'-'+case['id']+'/'+source.name,'original no-finished-raw guard/preflight record; not a behavioral result')
            report=Path(case.get('json',''))
            if case.get('ended_utc') and report.is_file() and report.resolve().parent==directory.resolve(): copy(report,prefix+report.name,'original completed-case cost report; acceptance is separate')
    output('evidence-index.json',{'candidate':plan['candidate'],'baseline':plan['baseline'],'correctness':plan['cases'],'selected_native_images':8,'appearance':appearance,'cost_queues':costs,'timing_state':('pending_no_accepted_measurement' if not any(item['state'] in ('functional_gpu_smoke_only','paired_static_observations_checked','mixed_origin_paired_static_observations_checked') for item in costs) else 'see_each_queue; smoke/partial never substitute for complete paired results'),'scope':'Eight selected kit1 originals only; full manifests retain additional image hashes without claiming delivery. Earlier145 native checks use pre-tuning CityWeathering.d25 with the same corrected seam shaders; final32203 usesb569. Actual capture HEAD/dirty state is preserved. No per-theme closeup lichen, soot owner, combined-source cost, live-Game CPU budget or uncapped throughput claim.','launcher_import_limit':'Earlier owner native/correctness records retain original commands/thermal/source maps. No current launcher or generated cache bytes are retroactively assigned to missing launch hashes. Future cost queues supply actual external-source snapshots and a finite four-mask import hash sample, not full Game/import/driver closure.'})
    output('sources/source-bindings.json',source_index); output('compression-map.json',{'threshold_bytes':THRESHOLD,'format':'gzip6 mtime0','entries':compressed})
    text='# Weathering evidence\n\nCandidate `'+plan['candidate']+'`; baseline `'+plan['baseline']+'`.\n\n'
    text+='Four expected correctness records are retained: seam GREEN145/0 and RED61/84; final helper32203/0 and old-source RED25095/812. RED diagnostics are assertion outcomes, not thermal/parse failures. The earlier native145 fixture predates profile-only tuning; its exact corrected seam shader bytes are retained separately.\n\n'
    text+='Eight unchanged root-selected kit1 originals have source-bound full manifests and native appearance review. Other survey output hashes remain in provenance without claiming their delivery. Actual capture HEAD/dirty state is retained, including precommit tuned bytes matching finalecb. S6/S7 use16102028; S2/S9 use16102026.\n\n'
    text+='Cost state: '+('pending/unrun' if not costs else '; '.join(Path(item['path']).parent.name+': '+item['state'] for item in costs))+'. Smoke/partial cases cannot supply a full normal-motion four-context960/true1080 matrix. Positive finite GPU samples, recomputed statistics, clean source/guard receipts and matched physical/exterior fixtures are required.\n\n'
    text+='Only frozen R3 fourteen-input receipts can admit new measurements; its parser checks both external helpers. Window/DisplayServer/content/stretch invariants establish the native960/1920 target using exact ed1daf0bf source proof; ViewportTexture.get_size is retained as a diagnostic rather than treated as raw allocation. R1 failed before READY; R2 failed setup-only with zero samples. The narrow empty authoritative DungeonRoof host classification preserves all real drawable opacity, fade, indoor and visibility gates.\n\n'
    text+='The original full R3 queue remains strictly stopped at S7. A complete separately validated R4 continuation may add a conditional hidden/frozen parking comparison with six reused native and ten fresh native cases; original strict results, Godot hashes and per-case program origins remain explicit. Mixed-window, weather-phase, last-frame query and scheduling limits prevent a statistical or FPS claim.\n\n'
    text+='See evidence-index.json, sources/source-bindings.json and compression-map.json. Capped periods are not throughput; static scenery process time is not live Game CPU cost. GPU timer query identity is not exposed. No full import/compiled-driver closure, combined-source cost or per-theme closeup lichen claim is made.\n'
    put(text.encode(),'EVIDENCE.md','derived from validated selected records','compact evidence/limits guide')
    copy(Path(__file__).resolve(),'sources/helpers/build_packet.py','exact packet builder source')
    for name in ('.gdignore','README.md','source-plan.json','build_packet.py'):
        source=HERE/name
        if source.is_file(): files.append({'path':name,'source_path':str(source),'role':'packet preparation/ignore source','raw_sha256':sha(source.read_bytes()),'raw_bytes':source.stat().st_size,'delivered_sha256':sha(source.read_bytes()),'delivered_bytes':source.stat().st_size})
    (HERE/'manifest.json').write_text(json.dumps({'schema':1,'files':files,'raw_originals_modified':False},indent=2)+'\n')
    print(json.dumps({'files':len(files),'cost_queues':len(costs),'bytes':sum(item['delivered_bytes'] for item in files)}))


if __name__ == '__main__': main()
