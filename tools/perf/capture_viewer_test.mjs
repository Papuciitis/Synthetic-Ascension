// Tests for the capture viewer's logic (the <script id="core"> block of capture_viewer.html).
//
//   node tools/perf/capture_viewer_test.mjs
//
// No npm packages needed. Exits non-zero when anything fails.
// The last section re-checks the published reference numbers against the real
// 2026-10-01 captures; it is skipped when that folder is not on this machine.
// Set CAPTURE_VIEWER_REAL_DIR to point it at a copy of the folder.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '..', '..');
const html = fs.readFileSync(path.join(here, 'capture_viewer.html'), 'utf8');
const coreMatch = /<script id="core">([\s\S]*?)<\/script>/.exec(html);
if (!coreMatch) { console.error('capture_viewer.html has no <script id="core"> block'); process.exit(1); }
// Runs the viewer's own logic block (a trusted file from this repository) in this process.
vm.runInThisContext(coreMatch[1], { filename: 'capture_viewer.html#core' });
const Core = globalThis.CaptureCore;

let passed = 0, failed = 0, skipped = 0;
function check(condition, message) {
  if (condition) { passed++; }
  else { failed++; console.error('FAIL: ' + message); }
}
function eq(actual, expected, message) {
  check(Object.is(actual, expected) || actual === expected, `${message} (got ${JSON.stringify(actual)}, expected ${JSON.stringify(expected)})`);
}
function near(actual, expected, tolerance, message) {
  check(Math.abs(actual - expected) <= tolerance, `${message} (got ${actual}, expected ${expected} ± ${tolerance})`);
}
function section(name) { console.log('— ' + name); }

/* A file on disk, shaped like the browser's File (name + text()). */
function diskFile(dir, name) {
  return { name, path: path.join(dir, name), text: async () => fs.readFileSync(path.join(dir, name), 'utf8') };
}
/* The same loading steps the page performs: CSV when there is one, else the JSON. */
async function loadFolder(dir) {
  const files = fs.readdirSync(dir).filter((n) => fs.statSync(path.join(dir, n)).isFile()).map((n) => diskFile(dir, n));
  const cls = Core.classifyFiles(files);
  const records = [];
  for (const inc of cls.incidents) {
    let table = null, source = 'csv', meta = null;
    if (inc.csv) table = Core.parseCsvTable(await inc.csv.text());
    if ((!table || table.error) && inc.json) {
      const obj = JSON.parse(await inc.json.text());
      table = Core.tableFromJson(obj); meta = obj.metadata || null; source = 'json';
    }
    if (table && !(table.error && !table.n)) records.push({ info: inc.info, table, source, csv: inc.csv, json: inc.json, meta });
  }
  return { cls, sessions: Core.buildSessions(records) };
}
function record(name, csvText, extra) {
  return Object.assign({ info: Core.parseCaptureName(name), table: Core.parseCsvTable(csvText), source: 'csv', csv: null, json: null, meta: null }, extra || {});
}

/* ------------------------------------------------------------ file names */
section('file names');
{
  const p = Core.parseCaptureName('2026-10-01_20-04-32_segment-02_incident-001.csv');
  check(p !== null, 'a capture CSV name parses');
  eq(p.date, '2026-10-01', 'date'); eq(p.segment, 2, 'segment'); eq(p.incident, 1, 'incident'); eq(p.ext, 'csv', 'extension');
  eq(p.clockSec, 20 * 3600 + 4 * 60 + 32, 'clock seconds');
  eq(p.base, '2026-10-01_20-04-32_segment-02_incident-001', 'base name');
  const q = Core.parseCaptureName('C:\\caps\\2026-10-01\\2026-10-01_21-15-50_segment-11_incident-336.JSON');
  check(q !== null && q.ext === 'json' && q.segment === 11 && q.incident === 336, 'a Windows path and an upper-case extension parse');
  check(Core.parseCaptureName('some/dir/2026-08-22_15-26-15_segment-02_incident-001.json') !== null, 'a POSIX path parses');
  for (const bad of ['notes.txt', 'screenshot.png', 'benchmark-summary.csv', 'enemy-pressure.json', '2026-10-01.zip',
    '2026-10-01_20-04-32_segment-02.csv', '2026-10-01_20-04-32_segment-02_incident-001.csv.bak', 'horde_2026-08-22_21-16-26.txt']) {
    eq(Core.parseCaptureName(bad), null, `"${bad}" is not a capture file`);
  }
  const cls = Core.classifyFiles([
    { name: '2026-10-01_20-04-52_segment-02_incident-002.json' }, { name: 'notes.txt' },
    { name: '2026-10-01_20-04-32_segment-02_incident-001.csv' }, { name: '2026-10-01_20-04-32_segment-02_incident-001.json' },
    { name: 'screenshot.png' }
  ]);
  eq(cls.ignored, 2, 'unrelated files are counted as ignored');
  eq(cls.incidents.length, 2, 'csv and json of one incident pair up');
  check(cls.incidents[0].csv && cls.incidents[0].json && cls.incidents[0].info.incident === 1, 'incidents come back in time order with both files');
  check(cls.incidents[1].csv === null && cls.incidents[1].json !== null, 'a JSON-only incident keeps csv = null');
}

/* -------------------------------------------------------------------- CSV */
section('CSV parsing');
{
  const full = Core.CSV_HEADER_CURRENT + '\n' +
    '1000,0.001,16.6,60.0,9.0,1.0,5,7,3,100,2,false,5,0,0,0,5,0,0,0,0,5,2,17.5,400,20,0.3,0.0,0,,0.0\n' +
    '2000,0.002,66.6,60.0,9.0,1.0,6,8,3,100,2,false,5,0,0,0,5,0,0,0,0,6,3,83.5,900,40,0.4,0.0,0,physics_catchup,26.9\n';
  const t = Core.parseCsvTable(full);
  eq(t.n, 2, 'two rows'); eq(t.error, '', 'no error');
  eq(t.t[1], 2000, 't_usec'); near(t.cols.wall_ms[1], 83.5, 1e-4, 'wall_ms read by name');
  eq(t.cols.enemies[0], 5, 'enemies'); eq(t.cols.world_data_only[1], 3, 'world_data_only');
  eq(Core.tagName(t.tags[1]), 'physics_catchup', 'hitch_tag'); eq(Core.tagName(t.tags[0]), '', 'empty hitch_tag');
  eq(t.tMin, 1000, 'tMin'); eq(t.tMax, 2000, 'tMax');
  check(!('physics_ticks' in t.cols), 'a column the file does not have is absent, not zero');

  // read by header NAME: shuffled order plus columns nobody knows about
  const shuffled = 'future_metric,wall_ms,enemies,t_usec,hitch_tag,physics_ticks,sampling_usec\n9,30.5,12,5000,ascension,2,150\n';
  const s = Core.parseCsvTable(shuffled);
  eq(s.n, 1, 'shuffled header: one row'); eq(s.t[0], 5000, 'shuffled header: t_usec');
  near(s.cols.wall_ms[0], 30.5, 1e-4, 'shuffled header: wall_ms'); eq(s.cols.physics_ticks[0], 2, 'appended physics_ticks column');
  eq(s.cols.sampling_usec[0], 150, 'appended sampling_usec column'); eq(Core.tagName(s.tags[0]), 'ascension', 'shuffled header: tag');
  check(s.unknown.includes('future_metric'), 'an unknown column is noted and otherwise ignored');
  check(!('frame_ms' in s.cols), 'missing frame_ms stays missing');

  // old, short header: no wall_ms, no hitch_tag
  const old = Core.parseCsvTable(Core.CSV_HEADER_OLD + '\n1273268778,1229.18449,66.6666666666667,20.0,1208.826,294.707,27,24,22,7047,22,false,50,28,1,18,78,0,2,10316,3317,27,1\n');
  eq(old.n, 1, 'old header: one row'); check(!('wall_ms' in old.cols), 'old header: wall_ms absent'); eq(old.tags, null, 'old header: no tags');
  near(old.cols.frame_ms[0], 66.6667, 1e-3, 'old header: frame_ms'); near(old.cols.elapsed_sec[0], 1229.18449, 1e-9, 'elapsed_sec keeps full precision');

  // quoted fields, doubled quotes, a quoted line break, CRLF, BOM
  const quoted = '\uFEFFt_usec,hitch_tag,wall_ms,note\r\n' +
    '10,"chunk, content",40.5,"says ""hi"""\r\n' +
    '20,"two\nlines",41.5,plain\r\n' +
    '30,,12,\r\n';
  const qt = Core.parseCsvTable(quoted);
  eq(qt.n, 3, 'quoted CSV: three records (one spans two lines)');
  eq(Core.tagName(qt.tags[0]), 'chunk, content', 'a quoted field keeps its comma');
  near(qt.cols.wall_ms[0], 40.5, 1e-4, 'the field after a quoted one lines up'); near(qt.cols.wall_ms[1], 41.5, 1e-4, 'the field after a quoted line break lines up');
  eq(qt.t[2], 30, 'CRLF line endings');
  eq(JSON.stringify(Core.splitCsvLine('a,"b ""q"" c",,d')), JSON.stringify(['a', 'b "q" c', '', 'd']), 'splitCsvLine handles doubled quotes and empty fields');

  // empty and broken files
  eq(Core.parseCsvTable('').error, 'empty file', 'empty file is reported'); eq(Core.parseCsvTable('').n, 0, 'empty file has no rows');
  eq(Core.parseCsvTable('\n\n').error, 'empty file', 'blank-lines-only file is reported');
  eq(Core.parseCsvTable(Core.CSV_HEADER_CURRENT + '\n').error, 'no rows', 'header-only file is reported');
  eq(Core.parseCsvTable('a,b,c\n1,2,3\n').error, 'no t_usec column', 'a CSV without t_usec is rejected');
  const ragged = Core.parseCsvTable('t_usec,wall_ms,enemies\n100,17.0,4\nnot-a-number,1,2\n200,18.0\n300\n');
  eq(ragged.n, 3, 'rows with a bad t_usec are dropped, short rows are kept'); eq(ragged.badRows, 1, 'bad rows are counted');
  check(Number.isNaN(ragged.cols.enemies[1]) && Number.isNaN(ragged.cols.wall_ms[2]), 'missing values in a short row are NaN, not 0');
  const blanks = Core.parseCsvTable('t_usec,wall_ms,enemies\n100,,\n');
  check(Number.isNaN(blanks.cols.wall_ms[0]) && Number.isNaN(blanks.cols.enemies[0]), 'empty cells are NaN, not 0');
}

/* ------------------------------------------------------------ percentiles */
section('percentiles and threshold counts');
{
  eq(Core.percentile([1, 2, 3, 4], 50), 2.5, 'median of 1..4 interpolates');
  near(Core.percentile([10, 20, 30, 40, 50], 95), 48, 1e-9, 'p95 of five values');
  eq(Core.percentile([7], 99), 7, 'a single value'); check(Number.isNaN(Core.percentile([], 50)), 'no values gives NaN');
  eq(Core.percentile([1, 2, 3], 0), 1, 'p0'); eq(Core.percentile([1, 2, 3], 100), 3, 'p100');

  const rows = [[1000, 16, 0], [2000, 28, 1], [3000, 28.5, 2], [4000, 33, 3], [5000, 33.5, 0], [6000, 50, 5], [7000, 50.5, 6], [8000, 100, 7], [9000, 100.5, 8], [10000, 4000, 9]];
  const csv = 't_usec,wall_ms,enemies\n' + rows.map((r) => r.join(',')).join('\n') + '\n';
  const [s] = Core.buildSessions([record('2026-01-01_10-00-00_segment-02_incident-001.csv', csv)]);
  const all = Core.summarize(s, {});
  eq(all.frames, 10, 'all frames counted');
  eq(JSON.stringify(all.over), JSON.stringify([8, 6, 4, 2]), 'threshold counts are strictly greater-than (28, 33, 50, 100)');
  near(all.median, 41.75, 1e-9, 'median'); eq(all.max, 4000, 'max'); eq(all.fallbackFrames, 0, 'no fallback frames when wall_ms is there');
  const withEnemies = Core.summarize(s, { enemiesOnly: true });
  eq(withEnemies.frames, 8, 'the enemies > 0 filter drops frames with no enemies');
  eq(JSON.stringify(withEnemies.over), JSON.stringify([7, 5, 4, 2]), 'threshold counts follow the filter');
  eq(s.hitchIdx.length, 8, 'hitches are frames over 28 ms');
  eq(JSON.stringify(Core.worstHitches(s, {}, 3).map((i) => s.t[i])), JSON.stringify([10000, 9000, 8000]), 'worst hitches come slowest first');
}

/* ------------------------------------------------- sessions and de-dup */
section('session grouping and de-duplication');
{
  const H = 't_usec,wall_ms,enemies,hitch_tag,hitch_ms\n';
  const a = record('2026-01-01_10-00-10_segment-02_incident-001.csv', H + '100,17,1,,0\n200,40,1,ascension,20\n300,17,1,,0\n');
  const b = record('2026-01-01_10-00-20_segment-02_incident-002.csv', H + '200,40,1,flow,9\n300,17,1,,0\n400,45,2,projectiles,14\n');
  const c = record('2026-01-01_10-00-40_segment-03_incident-003.csv', H + '9000,17,3,,0\n9100,30,3,unattributed,1\n');
  const d = record('2026-01-01_11-30-00_segment-02_incident-001.csv', H + '150,17,0,,0\n250,60,0,unattributed,0.5\n');
  const sessions = Core.buildSessions([d, c, a, b]);   // order given must not matter
  eq(sessions.length, 2, 'the incident number going back to 001 starts a new session');
  const s = sessions[0];
  eq(s.n, 6, 'frames seen in two overlapping windows are kept once'); eq(s.totalRows, 8, 'rows before de-dup'); eq(s.duplicates, 2, 'duplicates removed');
  eq(JSON.stringify(Array.from(s.t)), JSON.stringify([100, 200, 300, 400, 9000, 9100]), 'frames are in time order');
  eq(Core.tagName(s.tag[1]), 'ascension', 'a duplicated frame keeps the copy that is not a first row (the first row has no predecessor to tag against)');
  eq(JSON.stringify(Array.from(s.seg)), JSON.stringify([2, 2, 2, 2, 3, 3]), 'segment comes from the file name');
  eq(JSON.stringify(Array.from(s.gapBefore)), JSON.stringify([1, 0, 0, 0, 1, 0]), 'overlapping windows merge; a gap is marked only between separate windows');
  eq(s.windows.length, 2, 'two continuous stretches'); eq(s.segRuns.length, 2, 'two segment runs');
  eq(sessions[1].n, 2, 'the second session has its own frames'); eq(sessions[1].incidents.length, 1, 'one capture in the second session');
  near(Core.coveredSeconds(s), (300 + 100) / 1e6, 1e-12, 'covered time is the sum of the stretches');

  // the same t_usec in both rows of one file's non-first rows: earliest file wins
  const e1 = record('2026-01-02_10-00-10_segment-02_incident-001.csv', H + '100,17,1,,0\n200,40,1,ascension,20\n300,50,1,fragments,30\n');
  const e2 = record('2026-01-02_10-00-20_segment-02_incident-002.csv', H + '150,17,1,,0\n200,40,1,flow,9\n300,50,1,flow,9\n');
  const [es] = Core.buildSessions([e1, e2]);
  eq(es.n, 4, 'interleaved windows merge by t_usec'); eq(Core.tagName(es.tag[3]), 'fragments', 'between two ordinary copies the earlier file wins');

  // t_usec going backwards also means a new process, even if the incident number keeps rising
  const f1 = record('2026-01-03_10-00-10_segment-02_incident-004.csv', H + '900000000,17,1,,0\n');
  const f2 = record('2026-01-03_10-05-10_segment-02_incident-005.csv', H + '30000000,17,1,,0\n');
  eq(Core.buildSessions([f1, f2]).length, 2, 't_usec jumping backwards starts a new session');
  // a different build is a different session
  const g1 = record('2026-01-04_10-00-10_segment-02_incident-001.csv', H + '100,17,1,,0\n', { meta: { build: { git_commit: 'aaaa' } } });
  const g2 = record('2026-01-04_10-00-30_segment-02_incident-002.csv', H + '200000000,17,1,,0\n', { meta: { build: { git_commit: 'bbbb' } } });
  const g3 = record('2026-01-04_10-00-50_segment-02_incident-003.csv', H + '300000000,17,1,,0\n', { meta: { build: { git_commit: 'unknown' } } });
  eq(Core.buildSessions([g1, g2, g3]).length, 2, 'a different git commit starts a new session; "unknown" does not');
  // one session can run past midnight
  const m1 = record('2026-09-14_23-59-50_segment-05_incident-065.csv', H + '1000000000,17,1,,0\n');
  const m2 = record('2026-09-15_00-01-41_segment-05_incident-066.csv', H + '1100000000,17,1,,0\n');
  const midnight = Core.buildSessions([m2, m1]);
  eq(midnight.length, 1, 'a session that runs past midnight stays one session');
  near(Core.clockAt(midnight[0], 1100000000) - Core.clockAt(midnight[0], 1000000000), 100, 1e-6, 'clock time follows t_usec');
  // an empty capture file must not break grouping
  const z = record('2026-01-05_10-00-10_segment-02_incident-001.csv', '');
  const z2 = record('2026-01-05_10-00-30_segment-02_incident-002.csv', H + '500,17,1,,0\n');
  const zs = Core.buildSessions([z, z2]);
  eq(zs.length, 1, 'an empty capture file stays in its session'); eq(zs[0].n, 1, 'and contributes no frames');
}

/* ---------------------------------------------------- missing fields */
section('older captures and missing fields');
{
  const [s] = Core.buildSessions([record('2026-09-15_00-01-41_segment-05_incident-066.csv',
    Core.CSV_HEADER_OLD + '\n1000000,1.0,16.6666666666667,60.0,9,1,27,24,22,7047,22,false,50,28,1,18,78,0,2,10316,3317,27,1\n' +
    '1070000,1.07,66.6666666666667,20.0,1208.826,294.707,27,24,22,7047,22,false,50,28,1,18,78,0,2,10316,3317,27,1\n')]);
  eq(s.wallMissing, s.n, 'every frame of an old capture is flagged as having no wall time');
  near(s.eff[1], 66.6667, 1e-3, 'frame time falls back to Godot frame delta');
  const sum = Core.summarize(s, {});
  eq(sum.fallbackFrames, 2, 'the summary says how many frames used the fallback'); eq(sum.over[0], 1, 'hitch count still works on the fallback');
  check(!s.recorded.wall_ms && !s.recorded.physics_ticks && s.recorded.enemies === 2, '"recorded" tells present columns from absent ones');
  eq(s.tagsRecorded, false, 'old CSVs record no tags'); eq(Core.tagName(s.tag[1]), '', 'so the hitch has no tag (not a made-up one)');
  const bd = Core.breakdownFromRow(s, 1);
  check(bd.wallIsFallback && bd.items.length === 0, 'no timers are invented for an old CSV row');
  near(bd.unmeasuredMs, 66.6667, 1e-3, 'the whole frame is unmeasured');
  // a row with nothing but a time stamp
  const [bare] = Core.buildSessions([record('2026-01-06_10-00-10_segment-02_incident-001.csv', 't_usec\n100\n200\n')]);
  eq(Core.summarize(bare, {}).frames, 0, 'frames with no frame time at all are left out of the statistics');
  check(Number.isNaN(Core.summarize(bare, {}).median), 'and the median is NaN (shown as "not recorded"), not 0');
  eq(Core.summarize(bare, { enemiesOnly: true }).frames, 0, 'the enemies filter on a capture without an enemies column matches nothing');
}

/* --------------------------------------------- hitch tagger (GDScript port) */
section('hitch attribution (port of PerformanceHitchTagger.gd)');
{
  // Same cases as tools/tests/PerformanceHitchTaggerTest.gd.
  const base = (t, wall) => ({
    t_usec: t, elapsed_sec: t / 1e6, frame_ms: 16.0, wall_ms: wall, process_ms: wall * 0.7, physics_ms: 3.0, enemies: 120, projectiles: 200, projectile_ms: 0.4,
    ascension: { tick_usec: 300, flush_usec: 100, hit_usec: 200, BR: { fragment_usec: 100 } },
    chunk_stream: { queue_length: 0, last_phases: { coord: '(1, 1)', total_ms: 3.0, content_ms: 2.0, blocker_physics_ms: 0.5, blocker_render_ms: 0.3 } },
    flow_revision: 4, flow_building: false, flow_snapshot_usec: 0, flow_publish_usec: 0,
    enemy_lifecycle: { attach_total_usec: 1000, detach_total_usec: 500, retire_total_usec: 200 },
    enemy_scheduler: { physics_step_ms: 0.8 }, sampling_overhead_usec: 120
  });
  const clone = (o) => JSON.parse(JSON.stringify(o));
  const tag = (s, p) => Core.tagSample(s, p).tag;
  const quiet = base(1e6, 12);
  eq(tag(quiet, {}), '', 'a 12 ms sample is not a hitch');
  // A scene change: the recorder marks the samples around it and the whole frame is the change.
  const change = base(1.5e6, 1100); change.scene_change = 'HubWorld'; change.physics_ticks = 4; change.physics_frame_ms = 2.7;
  const changeTag = Core.tagSample(change, quiet);
  eq(changeTag.tag, 'scene_change', 'a frame that spans a scene change tags "scene_change"'); near(changeTag.ms, 1100, 1e-9, 'with the whole frame as its cost');
  const unmarked = clone(change); delete unmarked.scene_change;
  eq(tag(unmarked, quiet), 'unattributed', 'the same frame without the mark stays unattributed');
  eq(Core.tagFamily('scene_change'), 'scene_change', 'scene changes have their own family');
  check(Core.describeTag('scene_change').text.includes('changed scene'), 'and a plain explanation');
  const phaseMaps = Core.extractCostMaps({ frame_phases: { process: 9.0, deferred: 1.5, render_present: 12.0 } });
  check(phaseMaps.length === 1 && phaseMaps[0].entries.some((e) => e.name.includes('vsync')) && phaseMaps[0].entries.some((e) => e.name.includes('_process')), 'the recorder’s frame phases get plain names');
  const tree = base(2e6, 40); tree.ascension = { tick_usec: 18000, flush_usec: 2000, hit_usec: 1000, BR: { fragment_usec: 500 } };
  const treeTag = Core.tagSample(tree, quiet);
  eq(treeTag.tag, 'ascension', 'a 21 ms tree tick tags "ascension"'); near(treeTag.ms, 20.5, 1e-9, 'with the fragments taken out');
  const fragments = base(3e6, 40); fragments.ascension = { tick_usec: 20000, flush_usec: 200, hit_usec: 100, BR: { fragment_usec: 17000 } };
  eq(tag(fragments, quiet), 'fragments', 'fragment updates tag "fragments" when they are the larger part');
  const projectiles = base(4e6, 35); projectiles.projectile_ms = 14;
  eq(tag(projectiles, quiet), 'projectiles', 'a 14 ms projectile step tags "projectiles"');
  const chunk = base(5e6, 45);
  chunk.chunk_stream = { queue_length: 3, last_phases: { coord: '(2, 1)', total_ms: 24.0, setup_ms: 0.1, ground_ms: 0.2, content_ms: 21.0, floor_ms: 0.2, blocker_physics_ms: 1.5, blocker_render_ms: 1.0 } };
  const chunkTag = Core.tagSample(chunk, quiet);
  eq(chunkTag.tag, 'chunk_content', 'a new activation whose content phase dominates tags "chunk_content"'); near(chunkTag.ms, 24, 1e-9, 'with the activation total');
  const sameChunk = clone(chunk); sameChunk.t_usec = 5016000;
  check(tag(sameChunk, chunk) !== 'chunk_content', 'the same activation is not charged to the next frame');
  const flow = base(6e6, 36); flow.flow_revision = 5; flow.flow_publish_usec = 9000; flow.flow_snapshot_usec = 3000;
  const flowTag = Core.tagSample(flow, quiet);
  eq(flowTag.tag, 'flow', 'a flow revision change tags "flow"'); near(flowTag.ms, 12, 1e-9, 'snapshot plus publish');
  const snapshot = base(6.5e6, 36); snapshot.flow_building = true; snapshot.flow_snapshot_usec = 11000;
  eq(tag(snapshot, quiet), 'flow', 'a build starting this frame charges its snapshot to "flow"');
  const lifecycle = base(7e6, 33); lifecycle.enemy_lifecycle = { attach_total_usec: 9000, detach_total_usec: 3000, retire_total_usec: 200 };
  eq(tag(lifecycle, quiet), 'lifecycle', 'attach and detach deltas of 10.5 ms tag "lifecycle"');
  const step = base(8e6, 33); step.enemy_scheduler = { physics_step_ms: 9.5 };
  eq(tag(step, quiet), 'enemy_step', 'the scheduler step tags "enemy_step"');
  const fresh = clone(step); fresh.physics_step_ms = 0.6; fresh.physics_ticks = 1; fresh.physics_frame_ms = 0.6;
  check(tag(fresh, quiet) !== 'enemy_step', 'a stale snapshot step does not tag a frame whose own physics was light');
  fresh.physics_frame_ms = 12; fresh.physics_step_ms = 12;
  eq(tag(fresh, quiet), 'enemy_step', 'one heavy physics tick tags "enemy_step"');
  const catchup = clone(step); Object.assign(catchup, { wall_ms: 60, frame_ms: 60, physics_step_ms: 8, physics_ticks: 3, physics_frame_ms: 24 });
  const caught = Core.tagSample(catchup, quiet);
  eq(caught.tag, 'physics_catchup', 'several physics ticks in one frame tag "physics_catchup"'); near(caught.ms, 24, 1e-9, 'with their sum');
  const legacy = clone(catchup); delete legacy.physics_step_ms; delete legacy.physics_ticks; delete legacy.physics_frame_ms; legacy.enemy_scheduler = { physics_step_ms: 8 };
  eq(tag(legacy, quiet), 'unattributed', 'older captures without the per-frame fields keep their original tags');
  eq(tag(base(9e6, 40), quiet), 'unattributed', 'a 40 ms frame with only sub-millisecond costs is "unattributed"');
  const physics = base(10e6, 40); physics.physics_ms = 24;
  eq(tag(physics, quiet), 'physics_monitor', 'a physics monitor over half the frame tags "physics_monitor"');
  const small = base(11e6, 30); small.projectile_ms = 1.5;
  eq(tag(small, quiet), 'unattributed', 'a 1.5 ms cost cannot claim a 30 ms frame');
  // staged chunk activation
  const content = base(1e6, 30);
  content.chunk_stream = { last_phases: { coord: '(4, 2)', total_ms: 7.0, content_ms: 6.5, blocker_ms: 0, blocker_physics_ms: 0, blocker_render_ms: 0, staged_pending: true } };
  const phys = clone(content); phys.t_usec = 1016000; phys.chunk_stream.last_phases.blocker_physics_ms = 6.0;
  const render = clone(phys); render.t_usec = 1032000;
  render.chunk_stream = { last_phases: { coord: '(4, 2)', total_ms: 16.0, content_ms: 6.5, blocker_ms: 9.0, blocker_physics_ms: 6.0, blocker_render_ms: 3.0, staged_pending: false } };
  eq(tag(content, {}), 'chunk_content', 'the content step of a staged activation tags "chunk_content"');
  const renderTag = Core.tagSample(render, phys);
  eq(renderTag.tag, 'chunk_blocker_render', 'the completing blocker stage tags "chunk_blocker_render"'); near(renderTag.ms, 9, 1e-9, 'with the blocker delta');
  eq(tag(phys, content), 'unattributed', 'a frame where the chunk sample did not grow is not charged to the chunk');
  // old captures: no wall_ms, the tag falls back to frame_ms
  const oldSample = { t_usec: 5, frame_ms: 50, physics_ms: 30, enemies: 3 };
  eq(tag(oldSample, {}), 'physics_monitor', 'without wall_ms the tagger uses frame_ms');
  eq(tag({ t_usec: 6 }, {}), '', 'a sample with no time at all is not a hitch');
}

/* ----------------------------------------------------------- evidence */
section('evidence classification');
{
  const prev = { enemy_lifecycle: { attach_total_usec: 0, detach_total_usec: 0, retire_total_usec: 0 }, flow_revision: 4 };
  const sample = {
    t_usec: 2e6, wall_ms: 60, frame_ms: 60, physics_ms: 3, physics_ticks: 3, physics_frame_ms: 24, sampling_overhead_usec: 500, projectile_ms: 1.5,
    ascension: { tick_usec: 4000, flush_usec: 0, hit_usec: 0, BR: { fragment_usec: 1000 } },
    enemy_lifecycle: { attach_total_usec: 2000, detach_total_usec: 0, retire_total_usec: 0 }, flow_revision: 4
  };
  const bd = Core.breakdownFromSample(sample, prev);
  const byKey = Object.fromEntries(bd.items.map((it) => [it.key, it]));
  near(byKey.physics_catchup.ms, 24, 1e-9, 'physics ticks are a measured cost'); eq(byKey.physics_catchup.scope, 'frame', 'measured in this frame');
  check(byKey.physics_catchup.label.includes('3'), 'the label says how many ticks ran');
  near(byKey.ascension.ms, 3, 1e-9, 'ascension has the fragments taken out'); near(byKey.fragments.ms, 1, 1e-9, 'fragments are their own cost');
  eq(byKey.projectiles.scope, 'snapshot', 'projectile time is flagged as a half-second snapshot value');
  eq(byKey.lifecycle.scope, 'snapshot', 'lifecycle time is flagged as a since-last-snapshot total');
  check(bd.items.every((it) => it.evidence === 'measured'), 'every timer is "measured"');
  near(bd.measuredMs, 24 + 3 + 1 + 1.5 + 2 + 0.5, 1e-9, 'measured total');
  near(bd.unmeasuredMs, 60 - 32, 1e-9, 'the remainder is wall time minus every timer'); eq(bd.overshootMs, 0, 'no overshoot');
  const ev = Core.classifyEvidence(bd, 'physics_catchup', 24, 2);
  eq(ev.filter((e) => e.kind === 'measured').length, bd.items.length, 'timers are listed as measured');
  eq(ev.find((e) => e.key === 'tag').kind, 'correlated', 'a tag is correlated: it was only the largest measured cost');
  eq(ev.find((e) => e.key === 'events').kind, 'correlated', 'nearby events are correlated');
  eq(ev.find((e) => e.key === 'unmeasured').kind, 'unknown', 'the uncovered remainder is unknown');
  eq(Core.tagEvidence('unattributed'), 'unknown', '"unattributed" is unknown'); eq(Core.tagEvidence('physics_monitor'), 'correlated', '"physics_monitor" is correlated');
  eq(Core.tagEvidence(''), null, 'no tag, no evidence');
  check(Core.describeTag('physics_catchup').text.includes('two or more physics ticks ran in one rendered frame') &&
    Core.describeTag('physics_catchup').text.includes('may not identify what started the delay'), 'physics_catchup carries the required explanation');
  eq(Core.describeTag('chunk_blocker_render').family, 'world', 'chunk tags share one family'); eq(Core.tagFamily('fragments'), 'ascension', 'fragments belong with ascension');
  eq(Core.tagFamily('some_future_tag'), 'unknown', 'a tag from a newer build still gets a family');
  // timers that add up to more than the frame
  const over = Core.breakdownFromSample({ wall_ms: 20, physics_ticks: 1, physics_frame_ms: 18, projectile_ms: 6 }, {});
  eq(over.unmeasuredMs, 0, 'the remainder never goes negative'); near(over.overshootMs, 4, 1e-9, 'overshoot is reported instead');
  // old sample: frame_ms fallback is flagged
  const oldBd = Core.breakdownFromSample({ frame_ms: 50, physics_ms: 30 }, {});
  check(oldBd.wallIsFallback && oldBd.items.length === 0 && oldBd.unmeasuredMs === 50, 'an old sample: fallback time, nothing measured, all unknown');
  check(Number.isNaN(Core.breakdownFromSample({}, {}).wallMs), 'a sample with no time gives NaN, not 0');
  // optional cost maps render generically
  const maps = Core.extractCostMaps({ frame_phases: { process: 9.0, deferred: 1.5, render_present: 12.0 }, ascension: { engine_usec: { BR: 4000, DT: 250 } }, later_phases: { a: 1 }, enemy_lifecycle: { x: 1 } });
  eq(maps.length, 3, 'frame_phases, ascension.engine_usec and another *_phases map are picked up; unrelated objects are not');
  eq(maps[0].entries[0].name, 'Draw + present (includes any wait for vsync)', 'entries are sorted largest first, under their plain names'); near(maps[1].entries[0].ms, 4, 1e-9, 'microsecond maps are shown in ms');
  eq(Core.extractCostMaps({ enemies: 3 }).length, 0, 'no maps, no sections');
}

/* --------------------------------------------------- synthetic samples */
section('synthetic sample folder');
const samplesDir = path.join(here, 'capture_viewer_samples');
{
  const gen = await import('./capture_viewer_samples/generate_samples.mjs');
  const { files, expected } = await gen.sampleFiles();
  let same = fs.existsSync(path.join(samplesDir, '.gdignore'));
  for (const f of files) {
    const p = path.join(samplesDir, f.name);
    if (!fs.existsSync(p) || !fs.readFileSync(p).equals(f.data)) { same = false; console.error('  differs or missing: ' + f.name); }
  }
  check(same, 'the sample files on disk are exactly what generate_samples.mjs produces (and .gdignore exists)');
  eq(fs.readFileSync(path.join(samplesDir, '.gdignore')).length, 0, '.gdignore is empty');

  const { cls, sessions } = await loadFolder(samplesDir);
  eq(cls.ignored, 5, 'notes.txt, screenshot.png, benchmark-summary.csv, .gdignore and the generator script are ignored');
  eq(sessions.length, 3, 'three sessions: the incident number restarts three times');
  eq(expected.length, 3, 'the generator describes three sessions');
  sessions.forEach((s, i) => {
    const e = expected[i];
    eq(s.incidents.length, e.incidents, `${e.key}: capture count`);
    eq(s.n, e.uniqueFrames, `${e.key}: unique frames after de-dup`);
    eq(s.totalRows, e.totalRows, `${e.key}: rows before de-dup`);
    eq(s.hitchIdx.length, e.hitches, `${e.key}: frames over 28 ms`);
    eq(JSON.stringify([...new Set(Array.from(s.seg))].sort((a, b) => a - b)), JSON.stringify(e.segments), `${e.key}: segments`);
    eq(s.incidents[0].base, e.firstBase, `${e.key}: first capture`);
    for (let k = 1; k < s.n; k++) if (!(s.t[k] > s.t[k - 1])) { check(false, `${e.key}: t_usec strictly increasing`); break; }
  });
  const [old, cur, next] = sessions;
  check(sessions.some((s) => s.duplicates > 0) && cur.duplicates > 0, 'incident windows overlap, so there are duplicate rows to remove');
  check(cur.segRuns.length >= 3, 'several segments in one session');
  // old format
  eq(old.wallMissing, old.n, 'old-format session: no wall time anywhere'); eq(old.tagsRecorded, false, 'old-format session: no tags in the CSV');
  check(!old.recorded.ascension_usec && old.recorded.enemies > 0, 'old-format session: new columns absent, old ones present');
  // current format with a JSON-only incident
  eq(cur.wallMissing, 0, 'current-format session: wall time everywhere');
  const jsonOnly = cur.incidents.filter((x) => x.source === 'json');
  eq(jsonOnly.length, 1, 'one capture had no CSV and was read from its JSON'); eq(jsonOnly[0].info.incident, expected[1].jsonOnly[0], 'and it is the expected incident');
  check(jsonOnly[0].csv === null && jsonOnly[0].rows > 0, 'the JSON-only capture contributed rows');
  eq(cur.build && cur.build.git_commit, expected[1].commit, 'build info comes along with a JSON-read capture');
  const tags = Core.tagCounts(cur, {});
  check(tags.length >= 3 && tags.every((x) => x.tag !== ''), 'current-format hitches all carry a tag');
  eq(tags.reduce((a, x) => a + x.count, 0), cur.hitchIdx.length, 'tag counts add up to the hitch count');
  // next format: appended and unknown columns
  check(next.recorded.physics_ticks > 0 && next.recorded.physics_frame_ms > 0 && next.recorded.sampling_usec > 0, 'appended columns (physics_ticks, physics_frame_ms, sampling_usec) are read');
  check(next.incidents.every((x) => x.unknown.includes('future_metric')), 'an unknown appended column is tolerated');
  check(!cur.recorded.physics_ticks || cur.recorded.physics_ticks < cur.n, 'physics_ticks is not invented for CSVs without it');

  // the CSV tags written by the "game" match what the port recomputes from the JSON
  const pair = cur.incidents.find((x) => x.csv && x.json);
  const json = JSON.parse(await pair.json.text());
  const csv = Core.parseCsvTable(await pair.csv.text());
  let agree = csv.n === json.samples.length;
  for (let k = 0; k < csv.n && agree; k++) agree = Core.tagName(csv.tags[k]) === Core.tagSample(json.samples[k], k ? json.samples[k - 1] : {}).tag;
  check(agree, 'CSV hitch tags equal the tags recomputed from the JSON samples');

  // detail lookup for the worst hitch of the current session
  const worst = Core.worstHitches(cur, {}, 1)[0];
  const picks = Core.pickDetailIncidents(cur, cur.t[worst]);
  check(picks.length >= 1 && picks.every((x) => x.json && x.tMin <= cur.t[worst] && cur.t[worst] <= x.tMax), 'the detail JSON is found through the window index');
  const found = Core.findSample(JSON.parse(await picks[0].json.text()), cur.t[worst]);
  check(found && found.sample.t_usec === cur.t[worst], 'and it holds the frame');
  near(found.sample.wall_ms, cur.eff[worst], 1e-3, 'with the same wall time as the overview');
  // a frame inside the JSON-only window
  const jo = cur.incidents.indexOf(jsonOnly[0]);
  let inside = -1;
  for (let k = 0; k < cur.n; k++) if (cur.inc[k] === jo) { inside = k; break; }
  check(inside >= 0, 'some frames exist only in the JSON-only capture');
  check(Core.pickDetailIncidents(cur, cur.t[inside]).some((x) => x.base === jsonOnly[0].base), 'and their detail resolves to that JSON');
  // overlapping windows: a frame in two files resolves to the window that holds it most centrally
  let dup = -1;
  for (let k = 0; k < cur.n && dup < 0; k++) if (cur.incidents.filter((x) => x.tMin <= cur.t[k] && cur.t[k] <= x.tMax).length >= 2) dup = k;
  check(dup >= 0, 'some frame sits in two capture windows');
  const cands = Core.pickDetailIncidents(cur, cur.t[dup]);
  check(cands.length === 2, 'near a window edge a second JSON is offered for the nearby events');
  // nearby events
  const evJson = JSON.parse(await picks[0].json.text());
  const events = Core.nearbyEvents([evJson, evJson], cur.t[worst], found.sample.wall_ms);
  check(events.every((e) => Math.abs(e.relMs) <= 1500), 'nearby events stay within 1.5 s');
  eq(events.length, new Set(events.map((e) => e.t_usec + e.category + e.name + JSON.stringify(e.details))).size, 'the same event from two files is listed once');
  check(events.every((e, k) => k === 0 || events[k - 1].t_usec <= e.t_usec), 'events are in time order');
  const span = evJson.events.filter((e) => Math.abs(e.t_usec - cur.t[worst]) <= 1.5e6).length;
  eq(events.length, span, 'every event inside the window is listed');
  // next-format detail: generic cost maps
  const nj = JSON.parse(await next.incidents[0].json.text());
  const maps = Core.extractCostMaps(nj.samples[5]);
  check(maps.some((m) => m.title === 'Frame phases') && maps.some((m) => m.title === 'Ascension engines'), 'frame_phases and ascension.engine_usec are found in a next-format sample');
  // old-format detail: the tag can still be worked out from the JSON
  const oj = JSON.parse(await old.incidents[0].json.text());
  const oldHitch = oj.samples.findIndex((x) => x.frame_ms > 28);
  check(oldHitch > 0 && Core.tagSample(oj.samples[oldHitch], oj.samples[oldHitch - 1]).tag !== '', 'an old capture without hitch_tag still gets a tag from its JSON');
  check(!('wall_ms' in oj.samples[0]) && !('physics_ticks' in oj.samples[0]), 'old-format JSON really lacks the newer fields');

  // JSON-only folder (how the oldest real captures look)
  const jsonRecords = [];
  for (const inc of Core.classifyFiles(fs.readdirSync(samplesDir).map((n) => diskFile(samplesDir, n))).incidents) {
    const obj = JSON.parse(await inc.json.text());
    jsonRecords.push({ info: inc.info, table: Core.tableFromJson(obj), source: 'json', csv: null, json: inc.json, meta: obj.metadata });
  }
  const viaJson = Core.buildSessions(jsonRecords);
  eq(viaJson.length, 3, 'reading only the JSON files gives the same sessions');
  viaJson.forEach((s, i) => {
    eq(s.n, sessions[i].n, `${expected[i].key}: JSON-only loading finds the same unique frames`);
    eq(s.hitchIdx.length, sessions[i].hitchIdx.length, `${expected[i].key}: and the same hitches`);
  });
  check(viaJson[0].tagsRecorded && Core.tagCounts(viaJson[0], {}).every((x) => x.tag !== ''), 'tags are computed while reading old JSON-only captures');
  const a = Core.summarize(viaJson[1], {}), b = Core.summarize(cur, {});
  near(a.p95, b.p95, 1e-3, 'statistics agree between the CSV and JSON paths');
  check(Core.tableFromJson({}).error !== '' && Core.tableFromJson({ samples: [] }).n === 0 && Core.tableFromJson(null).n === 0, 'a JSON without samples is reported, not crashed on');
  eq(Core.tableFromJson({ samples: [{ t_usec: 1 }, 'junk', { no_time: true }] }).n, 1, 'junk entries in samples are skipped');
}

/* ------------------------------------------------ older real captures */
section('older real captures (smoke test; skipped when absent)');
{
  const oldCsvDir = path.join(repo, 'performance_results', '2026-09-15');
  if (fs.existsSync(oldCsvDir)) {
    const { sessions } = await loadFolder(oldCsvDir);
    check(sessions.length >= 1 && sessions[0].n > 0, '2026-09-15 (old CSV header) loads');
    eq(sessions[0].wallMissing, sessions[0].n, '2026-09-15 has no wall time, and says so');
    const sum = Core.summarize(sessions[0], {});
    check(sum.frames > 0 && Number.isFinite(sum.median), '2026-09-15 gives a finite median from the fallback');
    console.log(`  2026-09-15: ${sessions[0].incidents.length} captures, ${sessions[0].n} unique frames, median ${sum.median.toFixed(1)} ms (Godot frame delta)`);
  } else { skipped++; console.log('  skipped: performance_results/2026-09-15 not found'); }
  const jsonDir = path.join(repo, 'performance_results', '2026-08-22');
  if (fs.existsSync(jsonDir)) {
    const names = fs.readdirSync(jsonDir).filter((n) => Core.parseCaptureName(n)).sort().slice(0, 12);
    const records = [];
    for (const n of names) {
      const obj = JSON.parse(fs.readFileSync(path.join(jsonDir, n), 'utf8'));
      records.push({ info: Core.parseCaptureName(n), table: Core.tableFromJson(obj), source: 'json', csv: null, json: diskFile(jsonDir, n), meta: obj.metadata });
    }
    const sessions = Core.buildSessions(records);
    check(sessions.length >= 1 && sessions[0].n > 0, '2026-08-22 (JSON only) loads through the JSON path');
    check(sessions[0].duplicates > 0, '2026-08-22 windows overlap and are de-duplicated');
    console.log(`  2026-08-22 (first ${names.length} files): ${sessions.length} session(s), ${sessions[0].n} unique frames, ${sessions[0].hitchIdx.length} hitches by frame delta`);
  } else { skipped++; console.log('  skipped: performance_results/2026-08-22 not found'); }
}

/* --------------------------------------- real 2026-10-01 reference numbers */
section('real 2026-10-01 captures against the reference numbers (skipped when absent)');
{
  const candidates = [
    process.env.CAPTURE_VIEWER_REAL_DIR,
    path.join(repo, 'performance_results', '2026-10-01'),
    path.join(process.env.LOCALAPPDATA || '', 'Temp', 'claude', 'e--Synthetic-Ascension', 'c923da1b-cf59-428b-b0bf-8dbdfb3876fc', 'scratchpad', 'captures', '2026-10-01')
  ].filter(Boolean);
  const dir = candidates.find((d) => fs.existsSync(path.join(d, '2026-10-01_20-04-32_segment-02_incident-001.csv')));
  if (!dir) { skipped++; console.log('  skipped: the 2026-10-01 capture folder is not on this machine'); }
  else {
    const names = fs.readdirSync(dir);
    const started = performance.now();
    const texts = [];
    const cls = Core.classifyFiles(names.map((n) => diskFile(dir, n)));
    for (const inc of cls.incidents) texts.push(inc.csv ? fs.readFileSync(inc.csv.path, 'utf8') : null);
    const read = performance.now();
    const records = [];
    cls.incidents.forEach((inc, k) => { if (texts[k] !== null) records.push({ info: inc.info, table: Core.parseCsvTable(texts[k]), source: 'csv', csv: inc.csv, json: inc.json, meta: null }); });
    const parsed = performance.now();
    const sessions = Core.buildSessions(records);
    const built = performance.now();
    const bytes = texts.reduce((a, x) => a + (x ? x.length : 0), 0);
    console.log(`  ${records.length} CSV files, ${(bytes / 1e6).toFixed(1)} MB: read ${(read - started).toFixed(0)} ms, parse ${(parsed - read).toFixed(0)} ms, group + de-dup ${(built - parsed).toFixed(0)} ms`);
    const evening = sessions.find((s) => s.incidents[0].base === '2026-10-01_20-04-32_segment-02_incident-001');
    const afternoon = sessions.find((s) => s.incidents[0].base === '2026-10-01_14-38-41_segment-02_incident-001');
    if (!evening || evening.incidents.length !== 336) {
      skipped++; console.log('  skipped: the evening session is not the 336-capture set the reference numbers were taken from');
    } else {
      eq(evening.n, 160893, 'evening session: unique frames after de-dup');
      const withEnemies = Core.summarize(evening, { enemiesOnly: true });
      eq(withEnemies.frames, 107842, 'evening session: frames with enemies > 0');
      eq(withEnemies.median.toFixed(1), '17.8', 'evening session: median wall time (enemies > 0)');
      eq(withEnemies.p95.toFixed(1), '36.3', 'evening session: p95 wall time (enemies > 0)');
      eq(withEnemies.p99.toFixed(1), '55.0', 'evening session: p99 wall time (enemies > 0)');
      const all = Core.summarize(evening, {});
      eq(JSON.stringify(all.over), JSON.stringify([17975, 10478, 2682, 227]), 'evening session: frames over 28 / 33 / 50 / 100 ms');
      eq(evening.wallMissing, 0, 'evening session: wall time everywhere');
      eq(evening.hitchIdx.length, 17975, 'evening session: hitch index');
      eq(Core.tagCounts(evening, {}).reduce((a, x) => a + x.count, 0), 17975, 'evening session: every hitch has a tag row');
      eq(JSON.stringify(evening.segRuns.map((r) => r.seg)), JSON.stringify([2, 3, 4, 5, 6, 7, 8, 9, 10, 11]), 'evening session: segments 2 to 11, in order');
      console.log(`  evening: ${evening.n} unique frames; enemies>0 ${withEnemies.frames} frames, median ${withEnemies.median.toFixed(2)} / p95 ${withEnemies.p95.toFixed(2)} / p99 ${withEnemies.p99.toFixed(2)} ms; all frames over 28/33/50/100 ms: ${all.over.join(' / ')}`);
      if (afternoon) {
        eq(afternoon.n, 2095, 'afternoon session: unique frames'); eq(afternoon.incidents.length, 3, 'afternoon session: three captures');
        eq(evening.n + afternoon.n, 162988, 'both sessions together');
        console.log(`  afternoon: ${afternoon.n} unique frames; both sessions ${evening.n + afternoon.n}`);
      }
      // the JS port of the tagger agrees with the tags the game wrote
      const sample = [evening.incidents[40], evening.incidents[200]].filter((x) => x && x.json);
      for (const inc of sample) {
        const json = JSON.parse(fs.readFileSync(inc.json.path, 'utf8'));
        const csv = Core.parseCsvTable(fs.readFileSync(inc.csv.path, 'utf8'));
        let differ = csv.n === json.samples.length ? 0 : -1;
        for (let k = 0; k < csv.n && differ >= 0; k++) if (Core.tagName(csv.tags[k]) !== Core.tagSample(json.samples[k], k ? json.samples[k - 1] : {}).tag) differ++;
        eq(differ, 0, `${inc.base}: recomputed tags equal the CSV's hitch_tag column`);
        const viaJson = Core.tableFromJson(json);
        check(viaJson.n === csv.n && viaJson.cols.wall_ms.every((v, k) => Math.abs(v - csv.cols.wall_ms[k]) < 1e-3), `${inc.base}: the JSON path reads the same wall times as the CSV`);
        eq(json.metadata.build.git_commit, '8d6e124d6f40', `${inc.base}: build commit`);
      }
    }
  }
}

console.log(`\n${passed} passed, ${failed} failed${skipped ? `, ${skipped} section(s) skipped` : ''}`);
process.exit(failed ? 1 : 0);
