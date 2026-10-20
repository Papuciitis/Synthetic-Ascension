#!/usr/bin/env python3
"""Curate the bounded Linux integration record; default preflight is read-only.

The only Git operation is `git show` of explicit committed blobs. No engine,
encoder, decoder or image processing runs. --write copies an explicit allowlist;
it never traverses native caches, user data or raw frame directories.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
BASE = ROOT / ".superpowers/handoff-linux-next-20261020"
COMMIT = "de93d886a2b6392b1ff21d46147c3dd0cbf9287e"
FAILURE = "ERROR: building sun shadows exclude their own and neighboring interiors"
START = "<!-- RECORDED_INTEGRATION_SUMMARY_START -->"
END = "<!-- RECORDED_INTEGRATION_SUMMARY_END -->"
FOOTER = re.compile(r"(?m)^([A-Za-z0-9_]+): (\d+) passed, (\d+) failed")
RUNS = {
    "integrated-CityBlockKitTest": (1300, 0, "clean_check", "Earlier integrated kit regression."),
    "integrated-DungeonRoofContractTest": (99, 0, "clean_check", "Earlier integrated dungeon roof contract."),
    "integrated-WorldCoverTest": (25, 0, "clean_check", "Earlier integrated shared coverage contract."),
    "integrated-CityDomesticInteriorTest": (336, 0, "clean_check", "Earlier integrated actual eligible homes and furnishing policy."),
    "integrated-DomesticRewardStabilityTest": (43, 0, "clean_check", "Earlier integrated actual chance/claim and full item-factory comparison; original rolls retained."),
    "integrated-CityBlockProceduralTest": (6092, 1, "stale_test_expectation", "Real assertion failure: old bounding-box interior check rejects an empty L notch."),
    "integrated-procedural-diagnostic": (6092, 1, "diagnostic_reproduction", "Same assertion plus exact bbox/occupied-outline intersections; temporary diagnostic source is identified by its recorded hash."),
    "integrated-procedural-actual-outline": (6318, 0, "corrected_test", "Independent actual receiver outlines, explicit S2 setup/restore, and a positive transformed overlap detector control; no production change."),
    "integrated-entity-cover": (None, None, "native_combined_regression", "Actual generated Game with atmosphere WIP later committed as the bound runtime; eleven unedited small-window stills."),
    "final-WorldFootprintTest": (11, 0, "final_committed_check", "Final main at the bound commit."),
    "final-CityGroundCareTest": (125, 0, "final_committed_check", "Final main at the bound commit."),
    "final-ScriptParseAuditTest": (557, 0, "final_committed_check", "Final main at the bound commit; 557 scripts across 8 roots."),
}
PLATES = (
    "roof-covered.png", "roof-front-controls.png", "facade-covered.png",
    "facade-front-controls.png", "ordinary-tree-enemies-covered.png",
    "ordinary-tree-enemies-front-controls.png", "ordinary-tree-pickups-covered.png",
    "ordinary-tree-pickups-front-controls.png", "roof-before-entry.png",
    "roof-player-inside-cutaway.png", "roof-player-outside-restored.png",
)
# Explicit review scope, not a claim that all project files or dependencies are
# represented by these snapshots. Every original monitor hash remains preserved.
RUNTIME = (
    "project.godot", "scenes/game.tscn",
    "core/actors/player/player.gd", "core/actors/player/PlayerRoofOcclusion.gd",
    "core/actors/player/player_roof_occlusion.gdshader",
    "core/systems/enemy_world/EnemyProxyRenderer.gd",
    "core/systems/enemy_world/EnemyProxyRegion.gdshader",
    "core/systems/world/ChunkManager.gd",
    "core/systems/world/chunks/ChunkBlockPhysics.gd",
    "core/systems/world/chunks/ChunkBlockRenderer.gd",
    "core/systems/world/chunks/ChunkBlockVisualCatalog.gd",
    "core/systems/world/proc/SiteParcelsImpl.gd",
    "core/systems/world/ground/CityGroundCare.gd",
    "core/systems/world/ground/GroundSplatRenderer.gd",
    "core/systems/world/ground/ground_splat.gdshader",
    "core/systems/world/atmosphere/GameAtmosphereBinder.gd",
    "core/systems/world/atmosphere/ThemeAtmosphereProfiles.gd",
    "core/systems/world/atmosphere/WorldAtmosphere.gd",
    "core/systems/world/atmosphere/ground_air.gdshader",
    "core/systems/world/atmosphere/world_atmosphere.gdshader",
    "core/systems/world/visibility/ForegroundSpriteCoverage.gd",
    "core/systems/world/visibility/WorldCover.gd",
    "core/systems/world/visibility/world_cover.gdshaderinc",
    "core/systems/world/visibility/PickupCover.gd",
    "core/systems/world/visibility/pickup_cover.gdshader",
    "scenes/world/pickups/ItemPickup.gd", "scenes/world/pickups/ItemPickup.tscn",
    "scenes/world/pickups/HealthPickup.gd", "scenes/world/pickups/HealthPickup.tscn",
    "scenes/world/buildings/CityBlockKit.gd",
    "scenes/world/buildings/CityBlockFrontages.gd",
    "scenes/world/buildings/CityBlockRoofForms.gd",
    "scenes/world/buildings/CityDomesticInterior.gd",
    "scenes/world/buildings/CityFootprintGeometry.gd",
    "scenes/world/buildings/CityStreetFrontage.gd",
    "scenes/world/buildings/DistrictVisualProfiles.gd",
    "scenes/world/buildings/DungeonBuilding.gd",
    "scenes/world/buildings/DungeonRoof.gd",
    "scenes/world/buildings/RoofOverlay.gd", "scenes/world/buildings/RoofOverlay.tscn",
    "scenes/world/buildings/roof.gdshader",
    "scenes/world/buildings/city_ground.gdshader",
    "scenes/world/buildings/city_footway.gdshader",
    "scenes/world/buildings/city_paving.gdshader",
    "scenes/world/buildings/domestic_stone.gdshader",
    "scenes/world/buildings/domestic_plaster.gdshader",
    "tools/dev/CityBlockPlayablePreview.gd",
    "tools/dev/CityEntityCoverPreview.gd", "tools/dev/CityEntityCoverPreview.tscn",
)
TESTS = (
    "CityBlockKitTest", "DungeonRoofContractTest", "WorldCoverTest",
    "CityDomesticInteriorTest", "DomesticRewardStabilityTest",
    "CityBlockProceduralTest", "WorldFootprintTest", "CityGroundCareTest",
    "ScriptParseAuditTest",
)
TEST_PATHS = tuple(f"tools/tests/{name}.{suffix}" for name in TESTS for suffix in ("gd", "tscn"))


def require(ok: bool, message: str) -> None:
    if not ok:
        raise ValueError(message)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def encoded(value: object) -> bytes:
    return (json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False) + "\n").encode()


def load(path: Path) -> dict:
    return json.loads(path.read_bytes())


def committed(path: str, commit: str = COMMIT) -> bytes:
    # Arguments remain separate; no shell expansion and no Git mutation.
    result = subprocess.run(["git", "show", f"{commit}:{path}"], cwd=ROOT,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    require(result.returncode == 0, f"Missing committed source {commit}:{path}: {result.stderr.decode()}")
    return result.stdout


def inspect_runs(payload: dict[str, bytes]) -> tuple[dict, list[dict]]:
    records, summary = {}, []
    for label, (passed, failed, classification, note) in RUNS.items():
        folder = BASE / label
        raw = (folder / "run-results.json").read_bytes()
        record = json.loads(raw)
        logs = {name: (folder / "logs" / name).read_bytes()
                for name in ("stdout.log", "stderr.log", "engine.log")}
        matches = list(FOOTER.finditer(logs["stdout.log"].decode()))
        footer = None if not matches else {"test": matches[-1][1], "passed": int(matches[-1][2]), "failed": int(matches[-1][3])}
        require(record["runner_exit"] == record["actual_exit"], f"Runner/process exit mismatch: {label}")
        if passed is not None:
            require(footer is not None and (footer["passed"], footer["failed"]) == (passed, failed), f"Wrong assertion footer: {label}: {footer}")
        if failed:
            require(record["actual_exit"] == 1 and record["stop_reason"] == "nonzero_exit" and record["diagnostics"] == [FAILURE], f"Historical assertion failure changed: {label}")
        else:
            require(record["actual_exit"] == 0 and record["stop_reason"] == "completed" and record["diagnostics"] == [], f"Claimed clean run is not clean: {label}")
        if classification == "final_committed_check":
            require(record["git_head"] == COMMIT, f"Final check launched at another HEAD: {label}")
        require(record["resource_samples"] and record["command"] and record["source_hashes"], f"Incomplete process record: {label}")
        prefix = f"process/runs/{label}"
        payload[f"{prefix}/run-results.json"] = raw  # Exact original bytes, including original HEAD/status/full hashes.
        for name, data in logs.items():
            payload[f"{prefix}/logs/{name}"] = data
        records[label] = record
        summary.append({"label": label, "classification": classification, "note": note,
                        "footer": footer, "git_head": record["git_head"],
                        "actual_exit": record["actual_exit"], "stop_reason": record["stop_reason"],
                        "elapsed_seconds": record["elapsed_seconds"],
                        "peak_sampled_rss_mb": max(row["rss_mb"] for row in record["resource_samples"]),
                        "diagnostics": record["diagnostics"], "run_results_sha256": sha(raw),
                        "log_sha256": {name: sha(data) for name, data in logs.items()}})
    return records, summary


def inspect_capture(payload: dict[str, bytes], records: dict) -> dict:
    folder = BASE / "integrated-entity-cover-plates"
    raw = (folder / "capture-info.json").read_bytes()
    info = json.loads(raw)
    require({p.name for p in folder.glob("*.png")} == set(PLATES), "Unexpected/missing native named stills")
    require(tuple(row["file"] for row in info["plates"]) == PLATES, "Native plate order changed")
    require(info["capture_scene"] == "res://tools/dev/CityEntityCoverPreview.tscn" and info["scene"] == "res://scenes/game.tscn", "Wrong native scene")
    require((info["segment"], info["attempt_seed"], info["building_id"], info["tree_kind"]) == (2, 16102026, 944996572, "ordinary"), "Wrong native household/tree scope")
    require(info["failures"] == 0 and info["save_writes"] == 0, "Native failure/save write")
    require(info["inside_alpha"] == 0.0 and info["outside_alpha"] == 1.0, "Roof cutaway/restore did not complete")
    require(any(row.get("event") == "streamed_reload" and row.get("equal") for row in info["route"]), "Missing real stable streamed reload")
    require("CityEntityCoverPreview: plates=11 failures=0 save_writes=0 -> " in payload["process/runs/integrated-entity-cover/logs/stdout.log"].decode(), "Wrong native footer")
    files = []
    for plate in info["plates"]:
        name = plate["file"]
        data = (folder / name).read_bytes()
        require(data[:8] == b"\x89PNG\r\n\x1a\n" and data[12:16] == b"IHDR" and struct.unpack(">II", data[16:24]) == (960, 540), f"Wrong native PNG/dimensions: {name}")
        require(plate["window"] == "(960, 540)" and plate["expected_condition_asserted"] is True, f"Missing actual plate condition: {name}")
        require(plate["entities"] and all(not row.get("missing", False) for row in plate["entities"]), f"Missing live consumer: {name}")
        for entity in plate["entities"]:
            strength = entity["cover_strength"]
            require(strength > 0.9 if plate["intended_covered"] else strength < 0.001, f"Coverage control drifted: {name}/{entity['kind']}")
            if entity["kind"] in ("ordinary", "elite"):
                require(entity["batched"] and entity["world_handle_valid"] and not entity["dead"] and not entity["in_pool"], f"Enemy bypassed live production batch: {name}")
        payload[f"native/{name}"] = data
        files.append({"file": name, "sha256": sha(data), "bytes": len(data), "dimensions": [960, 540]})
    payload["native/capture-info.json"] = raw
    return {"capture_info_sha256": sha(raw), "plates": files, "world_cover": info["world_cover"],
            "limits": info["limits"], "original_launch_head": records["integrated-entity-cover"]["git_head"]}


def inspect_diagnosis_and_rewards(payload: dict[str, bytes]) -> None:
    text = payload["process/runs/integrated-procedural-diagnostic/logs/stdout.log"].decode()
    prefix = "CityBlockProceduralTest shadow diagnostic: "
    rows = [json.loads(line.split(prefix, 1)[1]) for line in text.splitlines() if line.startswith(prefix)]
    require(len(rows) == 1 and rows[0]["seed"] == 2026 and rows[0]["segment"] == 1, "Wrong exact diagnostic fixture")
    require(rows[0]["bbox_area"] == 14560.5625 and len(rows[0]["actual_occupied"]) == 3 and all(row["intersect_area"] == 0.0 for row in rows[0]["actual_occupied"]), "Diagnostic no longer supports empty-notch cause")
    payload["process/procedural-diagnosis.json"] = encoded(rows[0])
    text = payload["process/runs/integrated-DomesticRewardStabilityTest/logs/stdout.log"].decode()
    prefix = "DomesticRewardStabilityTest evidence: "
    rewards = [json.loads(line.split(prefix, 1)[1]) for line in text.splitlines() if line.startswith(prefix)]
    require(len(rewards) == 2 and {row["building_id"] for row in rewards} == {944996572, 2128236757}, "Missing exact integrated reward records")
    for row in rewards:
        for before, after in (("actual_before", "actual_furnished"), ("factory_before", "factory_furnished")):
            # Preserve and compare every original field, including these runs'
            # equal positions, claims and secondary state. Do not replace rolls.
            require(row[before] == row[after], f"Integrated full reward comparison changed: {row['building_id']}/{before}")
    payload["process/integrated-reward-comparisons.json"] = encoded(rewards)


def source_bindings(payload: dict[str, bytes], records: dict) -> dict:
    info = json.loads(payload["native/capture-info.json"])
    ground = info["ground"]
    assets = [ground["cache_path"].removeprefix("res://"), ground["manifest_path"].removeprefix("res://")]
    for selected in ground["selected_sources"]:
        path = selected["record"]["path"].removeprefix("res://")
        assets += [path, path + ".import"]
    paths = RUNTIME + TEST_PATHS + tuple(assets)
    require(len(paths) == len(set(paths)), "Duplicate scoped source")
    committed_hashes = {}
    for path in paths:
        data = committed(path)
        committed_hashes[path] = sha(data)
        if path not in assets:
            payload[f"process/committed-source/{path}"] = data
    native = records["integrated-entity-cover"]["source_hashes"]
    for path in RUNTIME + tuple(assets):
        require(native.get(path) == committed_hashes[path], f"Combined native source differs from committed runtime: {path}")
    for label, record in records.items():
        if RUNS[label][2] in ("stale_test_expectation", "diagnostic_reproduction", "native_combined_regression"):
            continue
        test_name = "CityBlockProceduralTest" if label == "integrated-procedural-actual-outline" else label.split("-", 1)[1]
        for suffix in ("gd", "tscn"):
            path = f"tools/tests/{test_name}.{suffix}"
            require(record["source_hashes"].get(path) == committed_hashes[path], f"Reported checked test does not match committed test source: {label}/{path}")
    old_path = "tools/tests/CityBlockProceduralTest.gd"
    old_record = records["integrated-CityBlockProceduralTest"]
    old_data = committed(old_path, old_record["git_head"])
    require(sha(old_data) == old_record["source_hashes"][old_path], "Original failing test is not the original launch blob")
    payload[f"process/original-failing-source/{old_path}"] = old_data
    matrix = {}
    for label, record in records.items():
        matrix[label] = {path: {"recorded_sha256": record["source_hashes"].get(path),
                               "matches_bound_commit": record["source_hashes"].get(path) == value}
                         for path, value in committed_hashes.items()}
    return {"bound_commit": COMMIT, "method": "SHA-256 of explicit git show <commit>:<path> blobs compared with untouched monitor launch source_hashes; no launch HEAD is rewritten.",
            "committed_sha256": committed_hashes, "content_snapshots": list(RUNTIME + TEST_PATHS),
            "asset_hashes_only": assets, "original_launch_matrix": matrix,
            "temporary_diagnostic_source": {"path": old_path, "recorded_sha256": records["integrated-procedural-diagnostic"]["source_hashes"][old_path],
                "content_retained": False, "qualification": "The temporary uncommitted diagnostic script bytes were not retained. Its original launch hash, full stdout JSON and full engine/stderr logs remain exact; no reconstructed script is substituted."}}


def table(summary: list[dict]) -> str:
    rows = ["| Original run label | Result | Seconds | Original launch HEAD |", "| --- | --- | ---: | --- |"]
    for row in summary:
        result = "11 plates; 0 failures/saves" if row["footer"] is None else f"{row['footer']['passed']} / {row['footer']['failed']}"
        rows.append(f"| [{row['label']}](process/runs/{row['label']}/run-results.json) | {result} | {row['elapsed_seconds']:.3f} | `{row['git_head'][:8]}` |")
    return "\n".join(rows)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="Copy validated allowlisted evidence; otherwise validate without writing")
    args = parser.parse_args()
    payload: dict[str, bytes] = {}
    records, summary = inspect_runs(payload)
    capture = inspect_capture(payload, records)
    inspect_diagnosis_and_rewards(payload)
    binding = source_bindings(payload, records)
    payload["process/source-bindings.json"] = encoded(binding)
    payload["process/summary.json"] = encoded({"bound_commit": COMMIT, "runs": summary, "native": capture,
        "record_policy": "Every run-results.json, command, original HEAD/status, full source hashes, resource samples and full logs are copied byte for byte. Only explicit code/scene source snapshots and capture stills are bundled; no caches or user data."})
    readme = (OUT / "README.md").read_text()
    require(readme.count(START) == 1 and readme.count(END) == 1, "Missing/duplicate README summary markers")
    before, rest = readme.split(START)
    _, after = rest.split(END)
    payload["README.md"] = (before + START + "\n\n" + table(summary) + "\n\n" + END + after).encode()
    payload["package-integration.py"] = Path(__file__).read_bytes()
    payload[".gdignore"] = (OUT / ".gdignore").read_bytes()
    index = {name: {"bytes": len(data), "sha256": sha(data)} for name, data in sorted(payload.items())}
    payload["evidence-index.json"] = encoded({"bound_commit": COMMIT, "files": index,
                                              "index_policy": "Index includes every bundled file except itself."})
    existing = {str(path.relative_to(OUT)) for path in OUT.rglob("*") if path.is_file()}
    require(existing <= set(payload), f"Unexpected output files; nothing removed: {sorted(existing - set(payload))}")
    if args.write:
        for name, data in payload.items():
            target = OUT / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        require(all(sha((OUT / name).read_bytes()) == sha(data) for name, data in payload.items()), "Written evidence differs from validated bytes")
    print(json.dumps({"mode": "written" if args.write else "read_only_preflight", "bound_commit": COMMIT,
        "runs": len(records), "expected_historical_failures": 2, "unedited_stills": len(PLATES),
        "scoped_committed_inputs": len(binding["committed_sha256"]), "bundled_files": len(payload),
        "bundled_bytes": sum(len(data) for data in payload.values()), "output": str(OUT)}, indent=2))


if __name__ == "__main__":
    main()
