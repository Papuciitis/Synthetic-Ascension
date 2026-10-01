// Regenerates the synthetic sample captures in this folder.
//
//   node tools/perf/capture_viewer_samples/generate_samples.mjs
//
// The generator itself lives in capture_viewer.html (the <script id="core"> block), so the
// viewer's "Load demo data" button and these files come from the same code. The output is
// deterministic: running this again rewrites identical files. The data is made up; it is
// not from a real play session.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const html = fs.readFileSync(path.join(here, '..', 'capture_viewer.html'), 'utf8');
const match = /<script id="core">([\s\S]*?)<\/script>/.exec(html);
if (!match) throw new Error('capture_viewer.html has no <script id="core"> block');
// Runs the viewer's own logic block (a trusted file from this repository) in this process.
vm.runInThisContext(match[1], { filename: 'capture_viewer.html#core' });
const Core = globalThis.CaptureCore;

// Short capture windows (0.8 s before a hitch + 0.4 s after) keep the sample files small.
export const SAMPLE_OPTIONS = { history: 0.8, aftermath: 0.4, full: false };
const KEEP = new Set(['.gdignore', 'generate_samples.mjs']);

export async function sampleFiles() {
  const { files, expected } = Core.generateSyntheticCapture(SAMPLE_OPTIONS);
  const out = [];
  for (const f of files) {
    out.push({ name: f.name, data: f.base64 ? Buffer.from(f.base64, 'base64') : Buffer.from(await f.text(), 'utf8') });
  }
  return { files: out, expected };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const { files } = await sampleFiles();
  for (const name of fs.readdirSync(here)) {
    if (!KEEP.has(name)) fs.unlinkSync(path.join(here, name));
  }
  let bytes = 0;
  for (const f of files) { fs.writeFileSync(path.join(here, f.name), f.data); bytes += f.data.length; }
  // Godot would otherwise import the .csv files as translations.
  fs.writeFileSync(path.join(here, '.gdignore'), '');
  console.log(`wrote ${files.length} files (${(bytes / 1024).toFixed(0)} KB) to ${here}`);
}
