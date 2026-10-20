#!/usr/bin/env python3
"""Read-only native no-readback profile analysis; optional explicit JSON output.

Reject failed/stationary fixtures as movement baselines. Compare raw timing and
population distributions without turning faster timings into a GPU/budget claim.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path


def require(ok: bool, message: str) -> None:
    if not ok:
        raise ValueError(message)


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def distribution(values: list[float]) -> dict:
    values = sorted(values)
    if not values:
        return {"count": 0}
    return {"count": len(values), "min": values[0], "p50": values[math.ceil(len(values)*.5)-1],
            "p95": values[math.ceil(len(values)*.95)-1], "p99": values[math.ceil(len(values)*.99)-1],
            "max": values[-1], "mean": sum(values)/len(values)}


def summarize(path: Path, monitor: Path | None) -> dict:
    data = load(path)
    require(data["failures"] == data["save_writes"] == 0, f"Failed/saving fixture cannot be a movement baseline: {path}")
    require(data["route"]["completed"] and data["route"]["completed_cells"] == data["route"]["planned_cells"] > 0, f"Incomplete route: {path}")
    require(data["streaming"]["enabled"] and data["streaming"]["activations_during_route"] > 0, f"No actual moving streaming: {path}")
    require(data["fixture"]["capture_readbacks"] == data["fixture"]["per_frame_file_writes"] == data["fixture"]["controlled_enemies"] == 0, f"Readback/disk/staged-population workload: {path}")
    require(data["combat"]["ambient_spawner_active"] and data["combat"]["encounter_beats"], f"Ordinary population owners muted: {path}")
    rows = data["samples"]
    require(len(rows) >= 30 and all(math.isfinite(float(row["frame_wall_ms"])) for row in rows), f"Insufficient/invalid frame series: {path}")
    keys = ("frame_wall_ms", "cover_refresh_ms", "engine_process_ms", "engine_physics_ms", "instrumentation_usec", "enemies", "projectiles", "draw_calls", "primitives")
    stats = {key: distribution([float(row[key]) for row in rows]) for key in keys}
    stats["cover_primitives"] = distribution([float(row["cover"]["primitive_count"]) for row in rows])
    stats["cover_candidates"] = distribution([float(row["cover"]["max_candidates"]) for row in rows])
    for phase in ("collection", "comparison", "snapshot", "binding"):
        field = phase+"_usec"
        if field in rows[0]["cover"]:
            stats["cover_"+phase+"_ms"] = distribution([float(row["cover"][field])/1000.0 for row in rows])
    # Lifetime peak_refresh_usec includes startup. The recorded route series
    # alone defines this sample's refresh max/percentiles.
    first, last = data["cover"]["initial"], data["cover"]["final"]
    accounting = {"generation_delta": int(last["generation"])-int(first["generation"]),
                  "source_reads_delta": int(last["source_reads"])-int(first["source_reads"]),
                  "alpha_array_rebuild_observations": data["cover"]["alpha_array_rebuild_observations"],
                  "force_uploads": data["cover"].get("force_uploads", False)}
    if "data_uploads" in last:
        for key in ("snapshot_builds", "snapshot_reuses", "data_uploads", "data_upload_bytes", "material_binds", "alpha_uploads"):
            require(key in first and key in last, f"Incomplete candidate work accounting: {key}")
            accounting[key+"_delta"] = int(last[key])-int(first[key])
        accounting["upload_count_method"] = "Instrumented CPU calls/requested payload bytes; not measured GPU transfer/stall time."
    else:
        accounting["source_derived_data_uploads"] = int(data["cover"]["baseline_inferred_data_uploads"])
        accounting["upload_count_method"] = "Unmodified baseline source-derived three uploads per generation; not instrumented GPU activity."
    by_route = {}
    for quarter in range(4):
        selected = [r for r in rows if min(3, int(r["path_index"])*4//data["route"]["planned_cells"]) == quarter]
        by_route[str(quarter)] = {key: distribution([float(r[key]) for r in selected]) for key in ("frame_wall_ms", "cover_refresh_ms", "enemies", "projectiles")}
    by_density = {}
    for name, low, high in (("empty", 0, 0), ("1-7", 1, 7), ("8-15", 8, 15), ("16+", 16, 1000000)):
        selected = [r for r in rows if low <= int(r["enemies"]) <= high]
        by_density[name] = {key: distribution([float(r[key]) for r in selected]) for key in ("frame_wall_ms", "cover_refresh_ms", "projectiles")}
    source_record = None
    if monitor is not None:
        run = load(monitor)
        require(run["actual_exit"] == 0 and run["stop_reason"] == "completed" and not run["diagnostics"], f"Monitor is not clean: {monitor}")
        source_record = {"file": str(monitor), "sha256": sha(monitor), "source_hashes": run["source_hashes"]}
    return {"file": str(path), "sha256": sha(path), "seed": data["seed"], "segment": data["segment"], "theme": data["actual_theme"],
            "route": data["route"], "render": data["render"], "wall_seconds": data["wall_seconds"], "simulation_seconds": data["simulation_seconds"],
            "warmup_simulation_seconds": data["warmup_simulation_seconds"], "distributions": stats, "work_accounting": accounting,
            "stream_activations": data["streaming"]["activations_during_route"], "stream_max_queue": data["streaming"]["max_queue"],
            "route_quarters": by_route, "density_strata": by_density, "combat": data["combat"], "source_record": source_record}


def compare(baseline: dict, candidate: dict, allowed: list[str]) -> dict:
    for key in ("seed", "segment", "theme", "warmup_simulation_seconds"):
        require(baseline[key] == candidate[key], f"Different comparison identity: {key}")
    require(baseline["route"]["cells_sha256"] == candidate["route"]["cells_sha256"], "Different planned actual walkable route")
    for key in ("native_window", "logical_viewport", "fps_cap", "vsync_mode", "backend", "adapter"):
        require(baseline["render"][key] == candidate["render"][key], f"Different renderer/settings: {key}")
    require(baseline["stream_activations"] == candidate["stream_activations"], "Different real streaming activation count")
    changed = None
    if baseline["source_record"] is not None and candidate["source_record"] is not None:
        a, b = baseline["source_record"]["source_hashes"], candidate["source_record"]["source_hashes"]
        changed = [path for path in sorted(set(a) | set(b)) if a.get(path) != b.get(path)]
        require(not set(changed)-set(allowed), f"Unapproved source differences prevent a matched policy comparison: {sorted(set(changed)-set(allowed))}")
    deltas = {}
    for metric in ("frame_wall_ms", "cover_refresh_ms", "engine_process_ms", "engine_physics_ms", "enemies", "projectiles", "instrumentation_usec"):
        a, b = baseline["distributions"][metric], candidate["distributions"][metric]
        deltas[metric] = {q: {"baseline": a[q], "candidate": b[q], "delta": b[q]-a[q], "relative_change": b[q]/a[q]-1 if a[q] else None} for q in ("p50", "p95", "p99", "max", "mean")}
    return {"identity_route_settings_streaming_match": True, "changed_source_paths": changed,
            "source_pair_verified": changed is not None, "deltas": deltas,
            "population_qualifier": "Same initial seed/route does not force equal natural combat/population. Inspect enemy/projectile distributions, route quarters and density strata; no unconditional speedup acceptance is inferred.",
            "scope": "Candidate comparison of recorded CPU-facing intervals/work, not pre-feature regression, GPU attribution, ordinary human comfort or frame-budget acceptance."}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("--candidate", type=Path)
    parser.add_argument("--baseline-monitor", type=Path)
    parser.add_argument("--candidate-monitor", type=Path)
    parser.add_argument("--allow-source-change", action="append", default=["core/systems/world/visibility/WorldCover.gd"])
    parser.add_argument("--out", type=Path, help="Explicit optional JSON artifact; default stdout only")
    args = parser.parse_args()
    baseline = summarize(args.baseline, args.baseline_monitor)
    result = {"baseline": baseline, "limits": "No viewport readback in the measured tool. Engine monitors may lag up to1s; no GPU timing/footway fragment attribution. Startup and path planning excluded, live streaming included."}
    if args.candidate:
        candidate = summarize(args.candidate, args.candidate_monitor)
        result.update(candidate=candidate, comparison=compare(baseline, candidate, args.allow_source_change))
    text = json.dumps(result, indent=2, allow_nan=False) + "\n"
    if args.out:
        require(not args.out.resolve() in {args.baseline.resolve(), args.candidate.resolve() if args.candidate else None}, "Analysis cannot overwrite source profiles")
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text)
        print(f"Wrote read-only-input profile analysis: {args.out}")
    else:
        print(text, end="")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise SystemExit(f"Profile analysis rejected: {error}")
