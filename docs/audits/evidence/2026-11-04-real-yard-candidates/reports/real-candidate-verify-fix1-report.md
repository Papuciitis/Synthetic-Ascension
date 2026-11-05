# Actual household candidate check — fix1 status

**Final helper replay: 14 passed, 0 failed in actual Godot4.7.1.** The parent
ran the corrected fresh project once after its authorized memory recovery.
`parent-recovery-run-result.json` reports native exit0, no diagnostic or guard
stop,0.58sec elapsed /0.359sec CPU, startup879.57 MB RAM /3863.30 MB commit,
and minimum recorded910 MB RAM /3808 MB commit. The guard's `peak_private_mb:0`
means the fast process completed before a private-memory sample; **it is not a
zero-allocation claim or measured peak**. The64 MB cap was unchanged; no stop
was observed, but an unsampled transient peak cannot be ruled out.

Raw stdout says `RealCandidateVerify: 14 passed, 0 failed`; raw stderr is empty.
The produced `fixture/derived-results.json` SHA256 is
`d114555c681e5bd770ce7ecddf3fff72afc2715fe88b0f4455f5a61f0f394ec4`.
After the run this worker independently read the raw logs, result and complete
derived JSON and rechecked all24 source pins unchanged. No further engine was
started by this worker. The parent retains engine ownership.

## Actual verified IDs and returned geometry

All are derived from the exact observed historical sample with plan seed
1208827904 and chunk(-8,-4), **not new district observations**:

| Observed rect | Global interior top-left | Actual signed64 mixed | Actual ID | Variant |
| --- | --- | --- | --- | --- |
| 21,7,8,7 | -234,-120 | 3519723295800754992 | 1910440753 | 1 |
| 3,6,8,8 | -252,-121 | 5556449076785241059 | 2052381668 | 0 |
| 21,20,8,8 | -234,-107 | 4193459259170773922 | 1928485795 | 3 |

The first two pass the ID-only care eligibility condition; the third fails
that condition because variant3 is skipped. This does not produce a care spec.

The actual unchanged carver returned the following source-parameter replays;
door width2 is **DERIVED from source, not historically observed**:

* Rect(21,7,8,7): seed7701479269626763827, room max6x5. Doors(25,13),(26,13).
  Walls are exactly the24 perimeter cells excluding those two door cells;
  no interior partition cells. Windows(23,7),(28,9),(28,10),(21,12),(28,12).
  Main fallback floor stamp(22,8,6,5), then corridor stamps
  (25,12,1,1),(25,10,1,3),(25,10,1,1),(25,10,1,3).
  Returned half-cover entries: (22,8),(27,9),(22,10),(27,10),(22,11),(27,11).
  Final RNG state-8687586686976478507. Pre-roof-inset footprint pixels:
  (1344,448),(1856,448),(1856,896),(1344,896).
* Rect(3,6,8,8): seed6765106841434776422, room max6x6. Doors(7,13),(8,13).
  Walls are exactly the26 perimeter cells excluding those two door cells;
  no interior partition cells. Windows(7,6),(10,7),(3,9),(10,11).
  Main fallback floor stamp(4,7,6,6), then corridor stamps
  (7,12,1,1),(7,10,1,3),(7,10,1,1),(7,10,1,3).
  Returned half-cover entries: (8,7),(8,7),(8,7),(4,8),(9,9),(4,12);
  duplicate entries are preserved, not deduplicated. Final RNG state
  -8557149413311061381. Pre-roof-inset footprint pixels:
  (192,384),(704,384),(704,896),(192,896).

Both use room attempts12/min4x4/padding1/corridor1/window0.22/floor texture2.
Main stamp alpha0.98, corridor alpha0.92, all stamps z-93. All exact returned
coordinates, counts through arrays, source parameters and missing fields are in
the hash-bound derived JSON. For the third, only ID/variant and the pre-inset
arithmetic footprint were derived; no carve was run.

The14 checks are six actual ID/variant assertions and eight geometry assertions
(two doors, open door cells, bounded walls, perimeter except doors for each
carved lot). This verifies bounded helper derivation/geometry only.

## Preserved failures and preparation

The original parent run failed parsing before any assertions: the authored
harness used spaces while the verbatim extracted method used tabs. Raw original
fixture, pins, worker refusal, parent stdout/stderr and parent result are retained
unchanged under `real-candidate-verify/`. Its parent launch exited1 with a clear
mixed-indentation diagnostic, no guard stop, sampled35 MB private, minimum801 MB
RAM /3618 MB commit and0.76sec elapsed. It verified **zero IDs and zero geometry**.

The corrected fresh project is `real-candidate-verify-fix1/`. Only authored
harness indentation was changed to tabs; the extracted `_mix_seed` method remains
byte-exact (SHA256 `7a508e56eca823288cba76cec91934acefd931191e0bd72bbb2299dc5448c81f`),
occurs exactly once, and matches the original extracted method. An independent
byte check confirms no space-leading indented line in the corrected harness;
all24 packet pins match. The project was built `.gdignore` first and has no
autoloads, Game, assets or copied cache. It copies the same unchanged actual
carvers. Original source binding/input derivations and limits are documented
in `real-candidate-verify-report.md` and repeated in the fresh packet's exact
payloads, source pins, input-derivation JSON and observed-inputs JSON.

This worker's **one corrected startup attempt was refused before launch**:
RAM470 MB / commit3954 MB at the final unchanged512/1536 gate (recorded preceding
snapshot475.46/3955.38). Guard was preloaded/compiled first. No engine/cache,
engine stdout/stderr or derived JSON was produced by that attempt. No worker
recovery or retry followed. The exact new runner sent to the parent is:

```powershell
& '.superpowers/sdd/2026-11-04-trailer-yard-preview/real-candidate-verify-fix1-run.ps1' -EvidenceName 'parent-recovery'
```

Fix1 runner SHA256:
`f0ef58441f1a2dcddcc687e38c8a9dad26083a6a853330721541e46bf8a872db`.
Engine SHA256 unchanged:
`323f9c4cc5db674e98815cdd8e69da007d5efc779abedc8c0e42883b7fdea12a`.
Guard SHA256 unchanged:
`dfe25730c5e24ac0e4ed6031af387c5fa2038ef30c37c1c7ac087856c19e7382`.

The accepted parent corrected run above establishes the three actual-GDScript
IDs/variants and two source carves. Garden contact, actual care/semantic bytes,
final roof/kit geometry and native Game evidence stay unknown/current-runtime
pending. Door2
remains source-derived rather than historically observed. No production/tool/docs
files changed, no target activated, no cap raised, no app trimmed/killed, and no
commit made by this worker.
