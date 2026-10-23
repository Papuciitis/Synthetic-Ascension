# Household care edge correction — 23 October 2026

Production includes shader/test commit `9a2ef8b8`, normal-merged at `572ed5b7` after Claude's playtest fixes. The paved-yard shader now preserves fractional household care, rather than turning every cell above 50% into solid lawn. CPU mask bytes, eligibility, terrain, doors, generation and collision are unchanged.

| Original S7 views | Evidence |
| --- | --- |
| Before | [PNG](native/before-s7/ground-before.png), [manifest](native/before-s7/capture-info.json) |
| After | [PNG](native/after-s7-r2/ground-before.png), [manifest](native/after-s7-r2/capture-info.json) |

Root and independent original-image review accept the softer transition with its useful green centre retained. Visible care cells, care mask and material counts match exactly. Both actual Game captures exit 0 with zero diagnostics, normal HUD, opaque exteriors, 20 FPS rendering, 60 Hz physics and zero save writes. These are staged static views, with god mode, ambient encounters disabled and streaming frozen after reload. They do not establish combat or performance.

The real-renderer regression first reports **43 passed / 6 expected cutoff failures**: quarter and half care have zero influence, while three-quarter care looks full. After the correction it reports **49/0**, actual exit 0 and zero diagnostics. Proportional blending, full green cores, zero-mask/road/lane/door controls and clearing care are checked. Eight original fixture images per run remain under `native/render-red-r3` and `native/render-green`.

[Review and source qualifications](review.json), [all actual outcomes](results.json) and [independent S7 review](process/s7-independent-review.json) retain the exact limits. In particular, the S7 after receipt also contains the S9-only candidate policy file; its canal profile is unchanged. The accepted GREEN shader/test bytes match production exactly; no clean merged-main replay is claimed.

## Pending S9 calibration

The smaller, neutral grassy-cobble candidate is committed as **`745f96ef` on `codex/c23-ground`**. It is **not merged or visually accepted**. Its policy catalogue passes116/0. The [original S9 baseline](native/before-s9-r2/ground-before.png) and [manifest](native/before-s9-r2/capture-info.json) are context only; there is no accepted after image. Full-Game after attempts hit97–98 C thermal stops, including a one-CPU retry. A quiet, cool session must finish normal and small-window native review before integration. The prepared source is retained under `pending-s9/` and in Git even if `/tmp` is wiped again.

Current CityGroundCareTest attempts also stopped thermally; the queued WorldGroundSplat suite never ran. They are not counted as passes. Earlier fixture parse/thermal failures and all actual raw records are preserved separately. Broad property/plaza shapes, large mossy flags and tiny covered-item discoverability remain open.

## Transport and runner

Each run retains its complete original source map, guard receipt, guard-owned launcher capture and three logs, including empty files. Large text uses deterministic gzip level6/mtime0 with verified round trips; see `compression-map.json`. Original PNGs and native manifests are unchanged. `.gdignore` was written first. The private candidate cache was copied from the current main checkout; no broad editor import or source-asset alteration was performed.

The local guard gained optional `--cpu-count 1`, preserving its two-CPU default,65 C launch gate,90 C peak stop,85 C sustained stop, identity checks and owned cleanup. Both guard versions and actual later non-Godot OS-affinity recheck outputs are included. Those tests validate affinity transport, not an engine thermal pass. There is no new cost or whole-Game performance claim.
