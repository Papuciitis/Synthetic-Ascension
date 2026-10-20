#!/usr/bin/env python3
"""Validate explicit no-readback cover measurements; default preflight is read-only.

No engine, Git, renderer, image, video, or shader-cache work is performed.
Two final root-selected policy arms are required before --write is accepted.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil

BASE = Path(__file__).resolve().parent
ROOT = BASE.parent.parent
OUT = ROOT / "docs/art/reference/2026-10-20-linux-cover-performance"
START = "<!-- RECORDED_COVER_PERFORMANCE_START -->"
END = "<!-- RECORDED_COVER_PERFORMANCE_END -->"
SAFE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
SCOPED = (
    "core/systems/world/visibility/WorldCover.gd",
    "tools/tests/WorldCoverSnapshotReuseTest.gd",
    "tools/tests/WorldCoverSnapshotReuseTest.tscn",
    "tools/dev/WorldCoverStreamingProfile.gd",
    "tools/dev/WorldCoverStreamingProfile.tscn",
    "tools/dev/analyze_world_cover_profile.py",
)
SIDECARS = (
    "tools/tests/WorldCoverSnapshotReuseTest.gd.uid",
    "tools/dev/WorldCoverStreamingProfile.gd.uid",
)
RUNS = {
    "cover-stream-baseline-small": (
        "failed_first_waypoint_pilot", None,
        "Distance-scaled input stopped below the actual .2 movement deadzone; 0/50 route cells and zero activations. Not a movement baseline."),
    "cover-stream-baseline-small2": (
        "clean_original_movement_baseline", None,
        "Full-strength production input completes the actual occupied streaming route before reuse changes; later visual/cue sources differ from final pair."),
    "continuation-cover-reuse-red": (
        "invalid_parse_attempt", None,
        "weakref() inferred Variant under warning-as-error policy; interrupted after parse diagnostics. No feature RED demonstrated."),
    "continuation-cover-reuse-red2": (
        "clean_feature_red", (0, 1),
        "Expected missing snapshot/upload/reuse/material-bind counters; no unrelated diagnostics."),
    "continuation-cover-reuse-green": (
        "clean_native_check", (24, 0),
        "Exact reuse and live invalidation, including actual native fractional uploaded data."),
    "continuation-cover-reuse-headless": (
        "clean_headless_check", (23, 0),
        "Same semantic controls without native image readback assertion."),
    "continuation-cover-regression": (
        "clean_existing_regression", (25, 0),
        "Existing shared WorldCover contract, independently retained."),
}


def require(ok: bool, message: str) -> None:
    if not ok:
        raise ValueError(message)


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False).encode()


def save(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False) + "\n")


def analysis_module():
    path = ROOT / "tools/dev/analyze_world_cover_profile.py"
    spec = importlib.util.spec_from_file_location("cover_analysis", path)
    require(spec is not None and spec.loader is not None, "Missing checked analysis module")
    module = importlib.util.module_from_spec(spec)
    # Compile/exec directly avoids writing a __pycache__ during read-only preflight.
    exec(compile(path.read_text(), str(path), "exec"), module.__dict__)
    return module


def footer(label: str) -> dict | None:
    text = (BASE / label / "logs/stdout.log").read_text()
    matches = list(re.finditer(r"(?m)^([A-Za-z0-9_]+): (\d+) passed, (\d+) failed", text))
    if not matches:
        return None
    result = matches[-1]
    return {"test": result[1], "passed": int(result[2]), "failed": int(result[3])}


def run_record(label: str, rule: tuple) -> dict:
    require(bool(SAFE.fullmatch(label)), f"Unsafe label: {label}")
    record = load(BASE / label / "run-results.json")
    require(record["source_hashes"] and isinstance(record["resource_samples"], list), f"Missing monitored sources/resources: {label}")
    for filename in ("stdout.log", "stderr.log", "engine.log"):
        require((BASE / label / "logs" / filename).is_file(), f"Missing full log: {label}/{filename}")
    kind, counts, note = rule
    assertions = footer(label)
    if counts is not None:
        require(assertions is not None and (assertions["passed"], assertions["failed"]) == counts, f"Unexpected assertion footer: {label}: {assertions}")
    diagnostics = record["diagnostics"]
    if kind.startswith("clean_") and kind != "clean_feature_red":
        require(record["actual_exit"] == 0 and record["stop_reason"] == "completed" and not diagnostics, f"Not clean: {label}")
    elif kind == "invalid_parse_attempt":
        require(record["actual_exit"] == -15 and record["stop_reason"] == "interrupted", f"Invalid parse attempt changed: {label}")
        require(len(diagnostics) == 2 and "Parse Error" in diagnostics[0] and "Parse error" in diagnostics[1], f"Unexpected parse history: {label}")
    else:
        require(record["actual_exit"] == 1 and record["stop_reason"] == "nonzero_exit" and diagnostics, f"Missing expected failure: {label}")
        require(all(d.startswith("ERROR: ") and "SCRIPT ERROR" not in d and "Parse Error" not in d for d in diagnostics), f"Unexpected non-assertion failure: {label}")
        if kind == "clean_feature_red":
            require(len(diagnostics) == 1 and "exposes exact snapshot/upload/reuse/material-bind counters" in diagnostics[0], f"Feature RED is not the expected missing API: {label}")
    return {"label": label, "classification": kind, "note": note, "footer": assertions, "record": record}


def profile_path(label: str) -> Path:
    return BASE / (label + "-profile") / "profile-info.json"


def validate_profile(label: str, expected_force: bool | None) -> dict:
    data = load(profile_path(label))
    require(data["tool"] == "res://tools/dev/WorldCoverStreamingProfile.tscn" and data["scene"] == "res://scenes/game.tscn", f"Wrong actual fixture: {label}")
    require(data["seed"] == 16102026 and data["segment"] == 2 and data["actual_theme"] == "service_courtyards", f"Wrong district identity: {label}")
    require(data["fixture"]["capture_readbacks"] == data["fixture"]["per_frame_file_writes"] == data["fixture"]["controlled_enemies"] == 0, f"Profile contains excluded workload: {label}")
    require(not data["fixture"]["scheduler_frozen"] and not data["fixture"]["streaming_frozen"] and data["fixture"]["normal_hud"], f"Production owners disabled: {label}")
    require(data["footways"]["initial_live_shader_polygons"] > 0 and data["footways"]["final_live_shader_polygons"] > 0, f"No actual footway draw owners: {label}")
    require(data["save_writes"] == 0, f"Profile wrote saves: {label}")
    if label == "cover-stream-baseline-small":
        require(data["failures"] == 2 and not data["route"]["completed"] and data["route"]["completed_cells"] == 0 and data["streaming"]["activations_during_route"] == 0, "Failed pilot history changed")
    else:
        require(data["combat"]["weapon_fires"] > 0 and data["combat"]["hits"] > 0 and data["combat"]["max_projectiles"] > 0, f"No real occupied combat: {label}")
        require(data["route"]["planned_cells"] == data["route"]["completed_cells"] == 50, f"Unexpected actual route: {label}")
    if expected_force is not None:
        require(data["cover"].get("force_uploads") is expected_force, f"Wrong measured cover policy: {label}")
        require(all(key in data["cover"]["final"] for key in ("snapshot_builds", "snapshot_reuses", "data_uploads", "data_upload_bytes", "material_binds", "alpha_uploads", "alpha_upload_bytes")), f"Missing actual work counters: {label}")
    return data


def normalize_command(command: list[str]) -> list[str]:
    result, skip_next = [], False
    for arg in command:
        if skip_next:
            skip_next = False
        elif arg == "--log-file":
            skip_next = True
        elif arg == "--cover-force-upload" or arg.startswith(("--out=", "--profile-label=")):
            continue
        else:
            result.append(arg)
    require(not skip_next, "Incomplete monitor log-file command")
    return result


def source_record(record: dict) -> tuple[str, dict]:
    source = {"source_hashes": record["source_hashes"], "source_untracked": record.get("source_untracked", [])}
    return "process/sources/" + hashlib.sha256(canonical(source)).hexdigest() + ".json", source


def compact_summary(summary: dict, record: dict, label: str) -> dict:
    result = copy.deepcopy(summary)
    result["file"] = "profiles/" + label + "/profile-info.json"
    result["source_record"] = {"file": source_record(record)[0], "original_run_results_sha256": sha(BASE / label / "run-results.json")}
    return result


def scoped_bindings(records: dict, selected: dict) -> dict:
    result = {}
    for path in SCOPED:
        values = {arm: records[label]["record"]["source_hashes"].get(path) for arm, label in selected.items()}
        require(all(values.values()) and len(set(values.values())) == 1, f"Scoped final launch inputs differ/missing: {path}")
        require((ROOT / path).is_file() and sha(ROOT / path) == next(iter(values.values())), f"Current scoped source differs from final launch: {path}")
        result[path] = {"current_sha256": sha(ROOT / path), "final_arms": values}
    return {"method": "Recorded launch SHA256 maps and read-only current file bytes; not Git blob/commit verification.", "inputs": result,
            "uid_sidecars": {path: {"current_sha256": sha(ROOT / path), "launch_binding": "Not included in monitor's source extension set; no launch identity claim."} for path in SIDECARS}}


def final_analysis(module, records: dict, selected: dict) -> tuple[dict, dict]:
    control_label, reuse_label = selected["control-small"], selected["reuse-small"]
    a, b = records[control_label]["record"], records[reuse_label]["record"]
    require(a.get("source_untracked", []) == b.get("source_untracked", []), "Final untracked source records differ")
    require(a.get("other_godot_pids") == b.get("other_godot_pids") == [], "Other engine processes confound the final timing pair")
    require("--cover-force-upload" in a["command"] and "--cover-force-upload" not in b["command"], "Final commands do not select opposite cover policies")
    require(normalize_command(a["command"]) == normalize_command(b["command"]), "Final commands differ beyond log/output/label/policy")
    control = module.summarize(profile_path(control_label), BASE / control_label / "run-results.json")
    reuse = module.summarize(profile_path(reuse_label), BASE / reuse_label / "run-results.json")
    comparison = module.compare(control, reuse, [])
    require(comparison["changed_source_paths"] == [], "Final policy pair has source differences")
    ca, cb = control["work_accounting"], reuse["work_accounting"]
    for summary, label in ((control, control_label), (reuse, reuse_label)):
        data = load(profile_path(label))
        summary["work_accounting"]["alpha_upload_bytes_delta"] = int(data["cover"]["final"]["alpha_upload_bytes"]) - int(data["cover"]["initial"]["alpha_upload_bytes"])
        counts = summary["work_accounting"]
        require(counts["snapshot_builds_delta"] + counts["snapshot_reuses_delta"] == counts["generation_delta"], f"Collection/build/reuse counters disagree: {label}")
    require(ca["force_uploads"] and not cb["force_uploads"], "Actual provider policy differs from command")
    require(ca["snapshot_reuses_delta"] == 0 and ca["data_uploads_delta"] == ca["snapshot_builds_delta"] * 3 > 0, "Forced-upload accounting is inconsistent")
    require(cb["snapshot_reuses_delta"] > 0 and cb["data_uploads_delta"] == cb["snapshot_builds_delta"] * 3, "Reuse accounting is inconsistent")
    result = {"control": compact_summary(control, a, control_label), "reuse": compact_summary(reuse, b, reuse_label), "comparison": comparison,
              "limits": "Same code/route/settings and real activation count, with naturally varying combat. Single native early-S2 pair; CPU-facing intervals/call counts, no GPU timing or footway fragment-cost attribution. Lifetime startup peak is excluded from measured route percentiles."}
    return result, scoped_bindings(records, selected)


def table_row(name: str, item: dict) -> str:
    d, w = item["distributions"], item["work_accounting"]
    uploads = w.get("data_uploads_delta", w.get("source_derived_data_uploads"))
    return f"| {name} | {d['frame_wall_ms']['count']} | {d['frame_wall_ms']['p95']:.3f} | {d['cover_refresh_ms']['p95']:.3f} | {d['cover_refresh_ms']['max']:.3f} | {uploads} | {d['enemies']['p50']:g} / {d['enemies']['p95']:g} |"


def readme_summary(baseline: dict, pair: dict, records: dict, selected: dict) -> str:
    lines = [START, "", "Actual monitored process results and raw-series nearest-rank statistics:", "",
             "| Measured route | Frames | Frame p95 ms | Cover p95 ms | Cover max ms | Data upload calls | Enemies p50 / p95 |",
             "| --- | ---: | ---: | ---: | ---: | ---: | ---: |",
             table_row("Original moving baseline", baseline), table_row("Final same-source forced uploads", pair["control"]), table_row("Final same-source exact reuse", pair["reuse"]), "",
             "The original baseline's upload count is source-derived; final arms use actual instrumented CPU call counters. The two final arms have identical full launch source maps and untracked records, normalized command settings, planned physical route and actual streaming activation count. Other visual/cue sources advanced after the original baseline, so the final pair provides the bounded policy comparison.", ""]
    a, b = pair["control"], pair["reuse"]
    ac, bc = a["work_accounting"], b["work_accounting"]
    lines += [f"Reuse skipped packed snapshots on {bc['snapshot_reuses_delta']:,} of {bc['generation_delta']:,} collected frames ({100.0*bc['snapshot_reuses_delta']/bc['generation_delta']:.2f}%). It built {bc['snapshot_builds_delta']:,} snapshots, requested {bc['data_upload_bytes_delta']:,} data bytes and bound materials {bc['material_binds_delta']:,} times; control requested {ac['data_upload_bytes_delta']:,} bytes and bound materials {ac['material_binds_delta']:,} times. Alpha-array upload calls/bytes and new source-image reads were {ac['alpha_uploads_delta']}/{ac['alpha_upload_bytes_delta']}/{ac['source_reads_delta']} in control and {bc['alpha_uploads_delta']}/{bc['alpha_upload_bytes_delta']}/{bc['source_reads_delta']} in reuse.", "",
              "| Cover phase | Control mean / p95 ms | Reuse mean / p95 ms |", "| --- | ---: | ---: |"]
    for key, label in (("collection", "Live geometry/alpha collection"), ("comparison", "Exact semantic comparison"), ("snapshot", "Packing/upload calls"), ("binding", "Material cleanup/binding")):
        av, bv = a["distributions"]["cover_"+key+"_ms"], b["distributions"]["cover_"+key+"_ms"]
        lines.append(f"| {label} | {av['mean']:.3f} / {av['p95']:.3f} | {bv['mean']:.3f} / {bv['p95']:.3f} |")
    lines += ["", f"Collection remains the dominant measured cover work. Frame p99 changed {a['distributions']['frame_wall_ms']['p99']:.3f}→{b['distributions']['frame_wall_ms']['p99']:.3f} ms; the final route quarter's cover p95 changed {a['route_quarters']['3']['cover_refresh_ms']['p95']:.3f}→{b['route_quarters']['3']['cover_refresh_ms']['p95']:.3f} ms. Enemy p50/p95 changed {a['distributions']['enemies']['p50']:g}/{a['distributions']['enemies']['p95']:g}→{b['distributions']['enemies']['p50']:g}/{b['distributions']['enemies']['p95']:g}, while projectile p50/p95 changed {a['distributions']['projectiles']['p50']:g}/{a['distributions']['projectiles']['p95']:g}→{b['distributions']['projectiles']['p50']:g}/{b['distributions']['projectiles']['p95']:g}. Removed snapshot/binding calls are direct work evidence; whole-frame differences remain confounded by natural combat and timing variation.", "",
              "| Focused correctness check | Passed / failed |", "| --- | ---: |"]
    for label in ("continuation-cover-reuse-green", "continuation-cover-reuse-headless", "continuation-cover-regression"):
        f = records[label]["footer"]
        lines.append(f"| {f['test']} ({'native' if label.endswith('green') else 'headless' if label.endswith('headless') else 'existing'}) | {f['passed']} / {f['failed']} |")
    lines += ["", "Final control/reuse run labels are `" + selected["control-small"] + "` and `" + selected["reuse-small"] + "`; both exit 0 with zero diagnostics, zero fixture failures and zero saves. Each completes 50/50 cells with " + str(pair["control"]["stream_activations"]) + " actual new chunk activations. Raw profiles, population/projectile distributions, route quarters, density strata and phase timings are retained in [analysis.json](analysis.json).", "",
              "This is a bounded observed pair. Natural combat differs between runs; it does not establish GPU savings, continuous human-play comfort, a 60 FPS guarantee or a historical feature regression. The failed first-waypoint pilot and invalid parse attempt remain failures in [the process catalogue](process/summary.json).", "", END]
    return "\n".join(lines)


def package(records: dict, selected: dict, baseline: dict, pair: dict, binding: dict) -> None:
    copies, generated, catalogue = {}, {}, []
    def retain(path: Path, destination: str) -> None:
        require(path.is_file() and destination not in copies and destination not in generated, f"Missing/duplicate artifact: {destination}")
        copies[destination] = path
    for label, item in records.items():
        original = item["record"]
        record = copy.deepcopy(original)
        source_path, source = source_record(record)
        generated[source_path] = source
        record.pop("source_hashes")
        record.pop("source_untracked", None)
        record.pop("git_status_porcelain", None)
        record.update(original_run_results_sha256=sha(BASE / label / "run-results.json"), source_record=source_path,
                      packet_classification=item["classification"], packet_note=item["note"])
        generated[f"process/{label}/run-results.json"] = record
        for filename in ("stdout.log", "stderr.log", "engine.log"):
            retain(BASE / label / "logs" / filename, f"process/{label}/logs/{filename}")
        catalogue.append({"label": label, "classification": item["classification"], "note": item["note"], "assertions": item["footer"],
                          "actual_exit": original["actual_exit"], "stop_reason": original["stop_reason"], "diagnostics": original["diagnostics"]})
    profiles = ["cover-stream-baseline-small", "cover-stream-baseline-small2", *selected.values()]
    for label in profiles:
        retain(profile_path(label), f"profiles/{label}/profile-info.json")
    retain(Path(__file__).resolve(), "process/package-cover-performance.py")
    retain(ROOT / "tools/dev/analyze_world_cover_profile.py", "process/analyze_world_cover_profile.py")
    generated.update({"analysis.json": {"original_baseline": baseline, "final_policy_pair": pair}, "process/summary.json": catalogue,
                      "process/scoped-inputs.json": binding,
                      "profile-catalogue.json": {"failed_pilot": "cover-stream-baseline-small", "original_baseline": "cover-stream-baseline-small2", **selected}})
    expected = set(copies) | set(generated) | {"README.md", ".gdignore", "evidence-index.json"}
    existing = {path.relative_to(OUT).as_posix() for path in OUT.rglob("*") if path.is_file()}
    require(not existing - expected, f"Unexpected packet files: {sorted(existing-expected)}")
    text = (OUT / "README.md").read_text()
    before, tail = text.split(START)
    _, after = tail.split(END)
    for relative, source in copies.items():
        target = OUT / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        require(sha(source) == sha(target), f"Raw copy digest differs: {relative}")
    for relative, value in generated.items():
        save(OUT / relative, value)
    (OUT / "README.md").write_text(before + readme_summary(baseline, pair, records, selected) + after)
    (OUT / ".gdignore").touch()
    save(OUT / "evidence-index.json", [{"file": path.relative_to(OUT).as_posix(), "sha256": sha(path), "bytes": path.stat().st_size}
                                         for path in sorted(OUT.rglob("*")) if path.is_file() and path.name != "evidence-index.json"])
    print(f"Packaged {len(records)} monitored histories and four raw profile records; no images, video or raw frame work.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sample", action="append", default=[], metavar="ARM=RUN_LABEL", help="Explicit control-small/reuse-small final labels")
    parser.add_argument("--write", action="store_true", help="Write only after both actual final arms validate")
    args = parser.parse_args()
    module = analysis_module()
    records = {label: run_record(label, rule) for label, rule in RUNS.items()}
    validate_profile("cover-stream-baseline-small", None)
    validate_profile("cover-stream-baseline-small2", None)
    baseline_record = records["cover-stream-baseline-small2"]["record"]
    baseline = compact_summary(module.summarize(profile_path("cover-stream-baseline-small2"), BASE / "cover-stream-baseline-small2/run-results.json"), baseline_record, "cover-stream-baseline-small2")
    selected = {}
    for value in args.sample:
        require(value.count("=") == 1, f"Expected ARM=RUN_LABEL: {value}")
        arm, label = value.split("=")
        require(arm in ("control-small", "reuse-small") and arm not in selected and label not in records and label not in selected.values(), f"Duplicate/unsupported final mapping: {value}")
        selected[arm] = label
        records[label] = run_record(label, ("clean_final_policy_profile", None, "Explicit root-selected final no-readback actual occupied streaming sample; opposite policy on source-matched candidate."))
        validate_profile(label, arm == "control-small")
    text = (OUT / "README.md").read_text()
    require(text.count(START) == text.count(END) == 1, "README needs one generated summary block")
    print(f"Validated {len(RUNS)} explicit historical records and {len(selected)} selected final policy arms. No files written.")
    pending = sorted({"control-small", "reuse-small"} - set(selected))
    if pending:
        print("PENDING: " + ", ".join(pending))
        require(not args.write, "Cannot write a passing packet with pending measurements")
        return 2
    pair, binding = final_analysis(module, records, selected)
    print("Final full source maps, route/settings/streaming and actual policy accounting validate. This is a packet preflight, not a GPU or frame-budget claim.")
    if args.write:
        package(records, selected, baseline, pair, binding)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise SystemExit(f"Cover performance packet validation failed: {error}")
