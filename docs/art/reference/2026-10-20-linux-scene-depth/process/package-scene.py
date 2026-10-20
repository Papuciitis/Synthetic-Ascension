#!/usr/bin/env python3
"""Curate explicit scene-depth evidence; default is read-only validation.

Root owns execution after both final captures are confirmed. No engine, Git,
image processing, raw frame traversal, or recursive directory copying occurs.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct

BASE = Path(__file__).resolve().parent
ROOT = BASE.parent.parent
OUT = ROOT / "docs/art/reference/2026-10-20-linux-scene-depth"
FINAL_LABELS = ("roof-depth-pair-small", "roof-depth-pair-normal")
STATUS_START = "<!-- RECORDED_RUN_SUMMARY_START -->"
STATUS_END = "<!-- RECORDED_RUN_SUMMARY_END -->"

# Explicitly reviewed selection. A label containing 'green' or 'valid' is not
# sufficient: the monitor exit/diagnostics and expected assertion footer matter.
RUNS = {
    "scene-baseline-import": ("failed_setup", None, "Cold import timed out with missing imported resources and parser diagnostics; not a fresh-clone success."),
    "scene-warm-import": ("failed_setup", None, "Warm editor import exited0 with parser diagnostics; not GREEN."),
    "scene-baseline-runtime": ("clean_check", (1300, 0), "Actual runtime baseline after cache/class setup."),
    "scene-shadow-red": ("clean_feature_red", (8, 5), "Actual bed L phantom/notch/neighbor shadow failures."),
    "scene-footway-red": ("clean_feature_red", (8, 2), "Actual north-facing inner-L landing and phantom box-top approach failures."),
    "scene-edge-red": ("invalid_fixture", None, "Invalid SubViewport own_world_2d property; interrupted without a feature result."),
    "scene-edge-red-valid": ("feature_red_with_fixture_diagnostics", (5, 2), "Corrected native viewport shows1px transitions, but2ObjectDB/1resource shutdown leaks mean this is not clean RED."),
    "scene-green-CityFootprintShadowTest": ("clean_check", (13, 0), "Exact S2 caster/neighbor geometry."),
    "scene-green-CityFootwayGeometryTest": ("failed_runtime_attempt", (10, 0), "Exit0/footer10/0 with Array-to-Array[float] runtime error; not GREEN."),
    "scene-geometry-green2": ("clean_check", (10, 0), "Explicit typed array branch construction resolves the runtime error."),
    "scene-edge-green2": ("clean_check", (7, 0), "Native external transition12/11partial pixels and opaque core; verbose shutdown clean."),
    "scene-kit-green": ("clean_check", (1300, 0), "Existing kit regression after the first scene slice."),
    "scene-procedural-check": ("clean_check", (5430, 0), "Existing20-layout procedural city regression."),
    "scene-bed-small": ("native_plate", None, "Pre-connected-roof baseline, already containing exact S2 shadows and softened footway."),
    "scene-roof-plane-red": ("clean_feature_red", (14, 4), "Missing connected planes/618gaps and independent main/front lighting failures."),
    "scene-roof-plane-green": ("clean_check", (21, 0), "Fitted union, slope, fractional alpha and live WorldCover controls; before UV rework."),
    "roof-CityBlockKitTest": ("clean_check", (1300, 0), "Existing kit regression after connected planes, before UV rework."),
    "roof-CityBlockProceduralTest": ("clean_check", (5430, 0), "Existing procedural regression after connected planes, before UV rework."),
    "roof-DungeonRoofContractTest": ("clean_check", (99, 0), "Existing roof contract before UV rework."),
    "roof-CheckpointOfficeRefinementTest": ("clean_check", (174, 0), "Accepted guard/S3 refinement before UV rework."),
    "roof-WorldCoverTest": ("clean_check", (25, 0), "Shared cover, actual World2D/canvas isolation before UV rework."),
    "roof-bed-small": ("rejected_native_interim", None, "Connected lighting/fascia; rejected unturned tile courses on the NS ridge."),
    "roof-bed-normal": ("rejected_native_interim", None, "Normal-size version of the same rejected texture-direction state."),
    "scene-roof-texture-red": ("feature_red_with_fixture_diagnostics", (15, 2), "Correct UV-axis/native variation failures plus menu AudioStreamMP3/Playback shutdown leaks; not clean RED."),
    "scene-roof-texture-valid-red": ("clean_feature_red", (15, 2), "Early audio stop/server-frame fixture cleanup; exactly the two UV-direction failures remain."),
    "scene-later-shadow-red": ("clean_feature_red", (16, 8), "Actual S4/S7 south/east-door Ls show50phantom and40/41missing samples per fixture."),
    "scene-final-CityIrregularRoofTextureRenderTest": ("clean_check", (17, 0), "Actual mesh axes/density plus source-Y native calibration; S3 direction preserved."),
    "scene-final-CityIrregularRoofPlaneRenderTest": ("clean_check", (21, 0), "Final UV change preserves fitted union, lighting and fractional cover/fade controls."),
    "scene-final-CityNonGuardFootprintShadowTest": ("clean_check", (24, 0), "Exact real S4/S7 non-guard caster/trim; finite-ray independent reference."),
    "scene-final-CityFootprintShadowTest": ("clean_check", (13, 0), "S2 exact caster/trim remains correct after non-guard scope extension."),
    "scene-final-CheckpointOfficeRefinementTest": ("clean_check", (174, 0), "Accepted guard refinement after final shadow/UV changes."),
    "roof-uv-final-small": ("native_plate", None, "Supplemental ordinary unpaused960x540 actual Game plate with selected ground/domestic integration and turned ridge UV."),
    "roof-depth-pair-small": ("native_plate", None, "Same frozen actual Game960x540: legacy whole roof and exactly restored connected roof."),
    "roof-depth-pair-normal": ("native_plate", None, "Same frozen actual Game1280x720: legacy whole roof and exactly restored connected roof."),
    "l2-seam-core": ("native_plate", None, "Old footway/cast at seam camera(0,7136); unchanged sampled care/stain/material grid across the pair."),
    "l2-seam-after-paving": ("native_plate", None, "New footway/cast at the same seam camera; wet source changed, but sampled seam has stain0 and no material5."),
}

CAPTURES = {
    "scene-bed-small": (BASE / "scene-bed-small-plates", "baseline-small", ("ground-before.png",), "home"),
    "roof-bed-small": (BASE / "roof-bed-small-plates", "rejected-lighting-only-small", ("ground-before.png",), "home"),
    "roof-bed-normal": (BASE / "roof-bed-normal-plates", "rejected-lighting-only-normal", ("ground-before.png",), "home"),
    "roof-uv-final-small": (BASE / "roof-uv-final-small-plates", "supplemental-final-small", ("ground-before.png",), "home"),
    "roof-depth-pair-small": (BASE / "roof-depth-pair-small-plates", "roof-pair-small", ("legacy-whole-roof.png", "connected-roof-planes.png"), "roof_pair"),
    "roof-depth-pair-normal": (BASE / "roof-depth-pair-normal-plates", "roof-pair-normal", ("legacy-whole-roof.png", "connected-roof-planes.png"), "roof_pair"),
    "l2-seam-core": (ROOT / ".superpowers/handoff-linux-l2-correction-20261020/seam-core", "paving-before", ("ground-before.png",), "seam"),
    "l2-seam-after-paving": (ROOT / ".superpowers/handoff-linux-l2-correction-20261020/seam-after-paving", "paving-after", ("ground-before.png",), "seam"),
}

# This bounded binding explains the scene slice and its final integrated context.
# Full monitor source_hashes/source_untracked also remain losslessly available.
SCOPED_INPUTS = (
    "scenes/world/buildings/CityBlockKit.gd",
    "scenes/world/buildings/CityFootprintGeometry.gd",
    "scenes/world/buildings/CityStreetFrontage.gd",
    "scenes/world/buildings/city_footway.gdshader",
    "scenes/world/buildings/CityBlockRoofForms.gd",
    "scenes/world/buildings/RoofOverlay.gd",
    "scenes/world/buildings/RoofOverlay.tscn",
    "scenes/world/buildings/roof.gdshader",
    "scenes/world/buildings/CityBlockFrontages.gd",
    "scenes/world/buildings/CityDomesticInterior.gd",
    "scenes/world/buildings/domestic_plaster.gdshader",
    "scenes/world/buildings/domestic_stone.gdshader",
    "core/systems/world/WorldDepthStyle.gd",
    "core/systems/world/WorldArt.gd",
    "core/systems/world/visibility/WorldCover.gd",
    "core/systems/world/visibility/world_cover.gdshaderinc",
    "tools/tests/CitySceneDepthFixture.gd",
    "tools/tests/CityFootprintShadowTest.gd",
    "tools/tests/CityFootprintShadowTest.tscn",
    "tools/tests/CityFootwayGeometryTest.gd",
    "tools/tests/CityFootwayGeometryTest.tscn",
    "tools/tests/CityFootwayEdgeRenderTest.gd",
    "tools/tests/CityFootwayEdgeRenderTest.tscn",
    "tools/tests/CityIrregularRoofPlaneRenderTest.gd",
    "tools/tests/CityIrregularRoofPlaneRenderTest.tscn",
    "tools/tests/CityIrregularRoofTextureRenderTest.gd",
    "tools/tests/CityIrregularRoofTextureRenderTest.tscn",
    "tools/tests/CityNonGuardFootprintShadowTest.gd",
    "tools/tests/CityNonGuardFootprintShadowTest.tscn",
    "tools/dev/CityBlockPlayablePreview.gd",
    "tools/dev/CityBlockPlayablePreview.tscn",
    "tools/dev/CityRoofDepthPreview.gd",
    "tools/dev/CityRoofDepthPreview.tscn",
    "tools/dev/CityGroundCorrectionPreview.gd",
    "tools/dev/CityGroundCorrectionPreview.tscn",
    "tools/capture/run_city_linux.py",
)
FOOTER = re.compile(r"(?m)^([A-Za-z0-9_]+): (\d+) passed, (\d+) failed")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def save(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def copy_file(source: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    if digest(source) != digest(target):
        raise ValueError(f"Copy hash mismatch: {source}")


def png_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()[:24]
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError(f"Not a PNG: {path}")
    return struct.unpack(">II", data[16:24])


def footer_for(label: str) -> dict | None:
    log = (BASE / label / "logs/stdout.log").read_text()
    matches = list(FOOTER.finditer(log))
    if not matches:
        return None
    match = matches[-1]
    return {"test": match[1], "passed": int(match[2]), "failed": int(match[3])}


def preflight() -> tuple[dict, dict]:
    records, captures = {}, {}
    for label, (classification, expected, _) in RUNS.items():
        folder = BASE / label
        result = json.loads((folder / "run-results.json").read_text())
        for name in ("engine.log", "stdout.log", "stderr.log"):
            if not (folder / "logs" / name).is_file():
                raise ValueError(f"Missing full log: {label}/{name}")
        footer = footer_for(label)
        if expected is not None and (footer is None or (footer["passed"], footer["failed"]) != expected):
            raise ValueError(f"Unexpected assertion footer for {label}: {footer}")
        if classification in ("clean_check", "native_plate", "rejected_native_interim"):
            if result["actual_exit"] != 0 or result["stop_reason"] != "completed" or result["diagnostics"]:
                raise ValueError(f"Claimed clean run has diagnostics/exit failure: {label}")
        if classification == "clean_feature_red":
            diagnostics = result["diagnostics"]
            # Assertion pushes begin ERROR; parser/runtime/leak errors are not
            # allowed to be relabeled clean feature RED.
            if result["actual_exit"] != 1 or not diagnostics or any(
                not line.startswith("ERROR: ") or any(word in line for word in ("SCRIPT ERROR", "Parse Error", "leaked", "resources still"))
                for line in diagnostics
            ):
                raise ValueError(f"Feature RED has unexpected diagnostics/exit: {label}")
        records[label] = result
    for label, (folder, destination, files, kind) in CAPTURES.items():
        info = json.loads((folder / "capture-info.json").read_text())
        sizes = [png_size(folder / name) for name in files]
        expected_size = (1280, 720) if label.endswith("normal") else (960, 540)
        if any(size != expected_size for size in sizes) or info.get("image_size") != f"({expected_size[0]}, {expected_size[1]})":
            raise ValueError(f"Unexpected plate dimensions: {label}: {sizes}")
        if info.get("failures") != 0 or info.get("save_writes") != 0 or not info.get("fixed_camera"):
            raise ValueError(f"Plate failure/save/unfixed camera: {label}")
        if info.get("frames") or info.get("captured_frames") != 0:
            raise ValueError(f"This packet expects named stills, not fight frames: {label}")
        if kind == "roof_pair":
            if not info.get("same_state_pair") or not info.get("physical_signature_preserved") or not info.get("scene_tree_paused") or info.get("engine_time_scale") != 0.0:
                raise ValueError(f"Missing frozen same-state controls: {label}")
            if info["original_host"] != info["restored_host"] or info["original_host"]["alpha"] != 0.0 or info["legacy_host"]["alpha"] != 1.0:
                raise ValueError(f"Roof state failed restoration: {label}")
            cover = info["cover_probe"]
            if not (cover["before"] > 0.99 and cover["before"] == cover["legacy"] == cover["restored"]):
                raise ValueError(f"Roof control changed shared coverage: {label}")
            if [plate["file"] for plate in info["plates"]] != list(files):
                raise ValueError(f"Roof plate names do not resolve inside packet: {label}")
            if info.get("checks",0) < 11 or digest(folder / files[0]) == digest(folder / files[1]):
                raise ValueError(f"Roof pair lacks its state checks or a distinct rendered control: {label}")
            original, legacy = info["original_host"].copy(), info["legacy_host"].copy()
            original.pop("alpha")
            legacy.pop("alpha")
            if original != legacy:
                raise ValueError(f"Legacy control changed host data beyond draw alpha: {label}")
        captures[label] = {"destination": destination, "info": info, "files": files, "source": folder, "kind": kind, "png_size": expected_size}
    # The two final sizes must share all scoped captured input hashes. This is
    # source equality at launch, not a later commit/whole-asset binding.
    for path in SCOPED_INPUTS:
        first = records[FINAL_LABELS[0]]["source_hashes"].get(path)
        second = records[FINAL_LABELS[1]]["source_hashes"].get(path)
        if first != second:
            raise ValueError(f"Final capture code snapshots differ: {path}")
    for label in CAPTURES:
        info = captures[label]["info"]
        camera = info["camera"]
        expected_id = 0 if captures[label]["kind"] == "seam" else 944996572
        expected_position = "(0.0, 7136.0)" if captures[label]["kind"] == "seam" else "(544.0, 6936.0)"
        if (info.get("building_id"), info.get("seed"), info.get("segment"), camera.get("position"), camera.get("rotation"), camera.get("zoom")) != (expected_id, 16102026, 2, expected_position, 0.0, "(1.0, 1.0)"):
            raise ValueError(f"Unexpected comparison house/camera: {label}")
    seam_before = captures["l2-seam-core"]["info"]["ground_correction"]["seam_after"]
    seam_after = captures["l2-seam-after-paving"]["info"]["ground_correction"]["seam_after"]
    if seam_before != seam_after or any(cell["stain_byte"] != 0 or cell["material"] == 5 for cell in seam_before):
        raise ValueError("Paving comparison requires identical sampled seam grids, stain0 and no material5")
    readme = (OUT / "README.md").read_text()
    if readme.count(STATUS_START) != 1 or readme.count(STATUS_END) != 1:
        raise ValueError("README needs its single generated-summary block")
    return records, captures


def run_summary(records: dict) -> str:
    lines = [STATUS_START, "", "The following counts are read from retained assertion footers and monitor results:", "", "| Final focused check | Passed / failed |", "| --- | --- |"]
    for label in ("scene-final-CityIrregularRoofTextureRenderTest", "scene-final-CityIrregularRoofPlaneRenderTest", "scene-final-CityNonGuardFootprintShadowTest", "scene-final-CityFootprintShadowTest", "scene-final-CheckpointOfficeRefinementTest"):
        footer = footer_for(label)
        lines.append(f"| {footer['test']} | {footer['passed']} / {footer['failed']} |")
    lines += ["", "Both frozen native pairs completed with actual exit0, no monitor diagnostics, zero fixture failures and zero saves:", "", "| Capture | Elapsed seconds | PNG size |", "| --- | --- | --- |"]
    for label in FINAL_LABELS:
        lines.append(f"| [{label}]({CAPTURES[label][1]}/connected-roof-planes.png) | {records[label]['elapsed_seconds']} | {'960×540' if label.endswith('small') else '1280×720'} |")
    lines += ["", STATUS_END]
    return "\n".join(lines)


def package(records: dict, captures: dict) -> None:
    (OUT / ".gdignore").touch()
    expected = {"README.md", ".gdignore"}
    # A separately verified commit binding belongs to the packet, but is not
    # invented from the running checkout or regenerated by this Git-free tool.
    if (OUT / "code-commit-bindings.json").is_file():
        expected.add("code-commit-bindings.json")

    def save_evidence(relative: str, value: object) -> None:
        save(OUT / relative, value)
        expected.add(relative)

    def copy_evidence(source: Path, relative: str) -> None:
        copy_file(source, OUT / relative)
        expected.add(relative)

    rows, scoped = [], {}
    for label, source in records.items():
        classification, _, note = RUNS[label]
        result = copy.deepcopy(source)
        provenance = {key: result.pop(key) for key in ("source_hashes", "source_untracked")}
        key = hashlib.sha256(canonical(provenance)).hexdigest()
        save_evidence(f"process/sources/{key}.json", provenance)
        result.pop("git_status_porcelain", None)
        result["original_run_results_sha256"] = digest(BASE / label / "run-results.json")
        result["source_provenance"] = f"../sources/{key}.json"
        result["packet_classification"] = classification
        result["packet_note"] = note + " Full command/exits/resources/logs retained; source records moved losslessly. Machine-wide Git status omitted. Local command/output paths are historical provenance, not a bundled-file claim."
        save_evidence(f"process/runs/{label}.json", result)
        for name in ("stdout.log", "stderr.log", "engine.log"):
            copy_evidence(BASE / label / "logs" / name, f"process/logs/{label}/{name}")
        samples = source["resource_samples"]
        rows.append({"name": label, "classification": classification, "note": note, "assertions": footer_for(label), "actual_exit": source["actual_exit"], "runner_exit": source.get("runner_exit"), "stop_reason": source["stop_reason"], "elapsed_seconds": source["elapsed_seconds"], "diagnostics": source["diagnostics"], "peak_rss_mb": max((sample["rss_mb"] for sample in samples), default=None), "minimum_available_mb": min((sample["available_mb"] for sample in samples), default=None), "command": source["command"], "source_provenance": f"sources/{key}.json"})
        scoped[label] = {"monitor_git_head": source["git_head"], "original_run_results_sha256": result["original_run_results_sha256"], "source_hashes": {path: source["source_hashes"].get(path) for path in SCOPED_INPUTS}, "source_untracked_in_scope": [path for path in provenance["source_untracked"] if path in SCOPED_INPUTS]}
    for label, capture in captures.items():
        for name in (*capture["files"], "capture-info.json"):
            copy_evidence(capture["source"] / name, f"{capture['destination']}/{name}")
    comparisons = []
    for first, second in (("scene-bed-small", "roof-bed-small"), ("roof-bed-small", "roof-uv-final-small"), FINAL_LABELS):
        first_info, second_info = captures[first]["info"], captures[second]["info"]
        a, b = scoped[first]["source_hashes"], scoped[second]["source_hashes"]
        comparisons.append({"first": first, "second": second, "same_camera_record": first_info["camera"] == second_info["camera"], "same_physical_footprint_record": first_info["footprint"] == second_info["footprint"], "changed_scoped_inputs": [path for path in SCOPED_INPUTS if a[path] != b[path]], "limits": "Final integrated plates also include selected ground/domestic work. Same camera/house does not isolate every changed material, moving particle or time-dependent pixel. Different window sizes are separate native samples."})
    for label in FINAL_LABELS:
        info = captures[label]["info"]
        comparisons.append({"run": label, "pair": list(captures[label]["files"]), "same_frozen_scene": info["same_state_pair"], "exact_host_restoration": info["original_host"] == info["restored_host"], "physical_signature_preserved": info["physical_signature_preserved"], "cover_probe": info["cover_probe"], "limits": "Within one frozen actual Game: only connected-composition visibility and duplicate base draw alpha change. The common chimney, ground, domestic purpose and HUD remain. The whole-mesh control recreates its original shader orientation, not every historical runtime source."})
    seam_a, seam_b = captures["l2-seam-core"]["info"], captures["l2-seam-after-paving"]["info"]
    comparisons.append({"first":"l2-seam-core","second":"l2-seam-after-paving","same_camera_record":seam_a["camera"] == seam_b["camera"],"same_sampled_seam_grid":seam_a["ground_correction"]["seam_after"] == seam_b["ground_correction"]["seam_after"],"sampled_stain_bytes":[0],"sampled_material5_count":0,"care_hashes":[seam_a["ground"]["care_mask"]["sha256"],seam_b["ground"]["care_mask"]["sha256"]],"ground_cache_hashes":[seam_a["ground"]["cache_sha256"],seam_b["ground"]["cache_sha256"]],"limits":"Wet source/cache changed between runs. The recorded70-cell seam grid is identical, has stainG0 and no material5, with identical care masks; this qualifies a local paving/cast view, not complete source equality for the whole image."})
    save_evidence("process/summary.json", rows)
    save_evidence("process/scoped-inputs.json", {"scope": list(SCOPED_INPUTS), "meaning": "Recorded launch-time code/test/tool hashes only. Null means the monitor did not record that path at that revision, not a claim of absence or unchanged content. Full original source records remain separately deduplicated. No later commit or full asset binding is implied.", "runs": scoped})
    save_evidence("comparisons.json", comparisons)
    copy_evidence(Path(__file__).resolve(), "process/package-scene.py")
    readme_path = OUT / "README.md"
    before, tail = readme_path.read_text().split(STATUS_START)
    _, after = tail.split(STATUS_END)
    readme_path.write_text(before + run_summary(records) + after)
    actual = {path.relative_to(OUT).as_posix() for path in OUT.rglob("*") if path.is_file()}
    if actual - expected - {"evidence-index.json"}:
        raise ValueError(f"Unreviewed files in evidence folder: {sorted(actual - expected - {'evidence-index.json'})}")
    png_count = sum(len(capture["files"]) for capture in captures.values())
    save(OUT / "evidence-index.json", {"packet": OUT.name, "runs": len(records), "pngs": png_count, "scope": "Explicit named native plates, capture records, monitored process records and logs only; no raw fight frames/cache/userdata.", "files": [{"path": name, "bytes": (OUT / name).stat().st_size, "sha256": digest(OUT / name)} for name in sorted(expected)]})
    print(f"Packaged {len(records)} recorded runs and {png_count} unedited PNGs into {OUT}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="Write only after root has confirmed both final capture labels")
    parser.add_argument("--confirmed-final", nargs=2, metavar=("SMALL_LABEL", "NORMAL_LABEL"))
    args = parser.parse_args()
    if args.write and tuple(args.confirmed_final or ()) != FINAL_LABELS:
        parser.error("--write requires --confirmed-final roof-depth-pair-small roof-depth-pair-normal")
    records, captures = preflight()
    if args.write:
        package(records, captures)
    else:
        print(f"Read-only preflight passed: {len(records)} runs, {sum(len(capture['files']) for capture in captures.values())} named PNGs; nothing packaged")


if __name__ == "__main__":
    main()
