#!/usr/bin/env python3
"""Read-only preflight; --write curates only explicit validated evidence.

No engine, Git, encoder, decoder or image processing is invoked. Final labels
and reviewed commit attestations must be supplied in capture-inputs.json.
Raw frame PNGs are verified against video sidecars but never copied.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import struct

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
BASE = ROOT / ".superpowers/handoff-linux-next-20261020"
START = "<!-- RECORDED_HOUSEHOLD_SUMMARY_START -->"
END = "<!-- RECORDED_HOUSEHOLD_SUMMARY_END -->"
FOOTER = re.compile(r"(?m)^([A-Za-z0-9_]+): (\d+) passed, (\d+) failed")
SAFE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
# Exact original labels are historical identifiers, not success claims.
RUNS = {
    "continuation-import": (None, None, "editor_abort", "Imports completed, then editor layout reopening aborted with double free; process exit -6. Not a clean import/runtime result."),
    "continuation-runtime-smoke": (1300, 0, "clean_check", "Direct runtime kit check after the editor abort."),
    "continuation-mipmap-import": (None, None, "clean_import", "Bounded flower-bed/mat mipmap reimport completed cleanly."),
    "continuation-composition-red": (10, 5, "clean_assertion_red", "Original room separates work from hearth, puts heat beside cot, and has no mat."),
    "continuation-entry-red": (6, 9, "clean_assertion_red", "Broad repeated upper panels and absent entry floor/timber depth."),
    "continuation-DomesticCompositionTest": (51, 0, "clean_check", "Actual two-home sleeping/work grouping and flat-floor mat ownership."),
    "continuation-DomesticEntryFinishTest": (24, 0, "clean_check", "Continuous head courses and shallow full-span domestic entry; no physics additions."),
    "continuation-CityDomesticInteriorTest": (336, 0, "clean_check", "Actual eligibility, source anchors, six physical cells, connectivity, RNG and streaming lifetime."),
    "continuation-DomesticFrontageFinishTest": (45, 0, "clean_check", "Actual upper material sampling, supported opening and excluded ownership."),
    "continuation-DomesticFrontageFadeTest": (26, 0, "clean_check", "Disjoint head courses/jamb caps/timber and fractional cutaway controls."),
    "continuation-DomesticRewardStabilityTest": (43, 0, "clean_check", "Original integrated actual-chance and guaranteed full-factory comparisons; exact rolls retained."),
    "continuation-CityGroundCareTest": (124, 1, "rejected_contact_shift", "Garden moved6px and violated the measured bed/tree contact. Only that world shift was reverted; source PNG untouched."),
    "continuation-final-CityGroundCareTest": (125, 0, "clean_check", "Measured contact restored; bounded material/mipmap changes retained."),
    "continuation-final-CityBlockProceduralTest": (6318, 0, "clean_check", "Actual-outline shadow, paving, doorway and generated layout regression."),
    "continuation-footway-shape-red": (11, 2, "clean_assertion_red", "Square presentation footprint requires a geometry correction."),
    "continuation-footway-shape-green": (13, 0, "clean_check", "Bounded connected footway geometry correction."),
    "continuation-footway-edge": (8, 0, "clean_check", "Native footway edge controls before later road-join correction."),
    "continuation-road-join-red": (9, 1, "clean_assertion_red", "Footway material still paints a light road patch."),
    "continuation-road-join-green": (10, 0, "clean_check", "Road material join correction in native edge control."),
    "continuation-base-road-red": (11, 2, "clean_assertion_red", "Reshaped overlay still leaves the underlying merged rectangular pale substrate."),
    "continuation-base-road-green": (13, 0, "clean_check", "Actual road and short soft shoulder own the city-ground substrate."),
    "continuation-road-scope-red": (13, 1, "clean_assertion_red", "Actual-road substrate correction must opt in only for S2 and preserve other segments."),
    "continuation-road-scope-green": (14, 0, "clean_check", "Explicit S2 material ownership preserves default ground presentation."),
    "continuation-soil-care": (125, 0, "clean_check", "Textured feathered soil keeps the measured bed/tree contact and care ownership."),
    "continuation-pale-red": (51, 19, "mixed_assertion_red", "Intended S2 relief/cache failures plus unrelated V1 autoload-busy/RID/orphan diagnostics. Retained as a mixed failed run, not clean RED."),
    "continuation-pale-green": (76, 0, "clean_check", "Separate stable S2 pale/default S3/warm domestic caches, walls/window/partitions/fills and unchanged physical arrays."),
    "continuation-pale-domestic-control": (68, 0, "clean_check", "Existing domestic/default material ownership regression."),
    "continuation-pale-small": (None, None, "native_iteration", "First matched pale civic material/cutaway control; context predates final road substrate and coherent facade."),
    "continuation-bed-small": (None, None, "native_iteration", "First bed960 iteration with earlier paving/garden state; not final evidence."),
    "continuation-bed-small-final": (None, None, "native_rejected_iteration", "Historical label says final, but visual review found the broad pale city_ground substrate. Retained as an iteration, not final evidence."),
    "continuation-bed-normal-final": (None, None, "native_rejected_iteration", "Same underlay finding at1280. Physical walkthrough passes do not close the visible paving defect."),
    "continuation-facade-cohesion-red": (1, 4, "clean_assertion_red", "User rejected pasted identical whole-window panels, the tinted upper band and oversized bare recess."),
    "continuation-facade-DomesticFacadeCohesionTest": (32, 0, "clean_check", "Distinct proportional original window crops, continuous warm fields/plinth, disjoint folded leaf and genuine north-entry control."),
    "continuation-facade-DomesticFrontageFadeTest": (24, 0, "clean_check", "Actual head/jamb/timber junctions remain disjoint at fractional cutaway."),
    "continuation-facade-DomesticEntryFinishTest": (68, 0, "clean_check", "Full128px physical doorway, human-scale visible recess, original lining/floor sources and no collisions."),
    "continuation-facade-DomesticFrontageFinishTest": (87, 0, "clean_check", "Isotropic continuous wall material, supported header, north entry and excluded S3/nonhome ownership."),
    "continuation-facade-procedural": (6318, 0, "clean_check", "Generated physical layouts, actual-outline shadows, paving and all cardinal door directions after coherent facade."),
    "continuation-facade-early": (None, None, "native_iteration", "One controlled actual bed exterior for early composition judgment; no route/contact/cutaway claim."),
}
HOMES = {
    "bed-small": (16102026, 944996572, (960, 540)),
    "bed-normal": (16102026, 944996572, (1280, 720)),
    "fruit-small": (17, 2128236757, (960, 540)),
    "fruit-normal": (17, 2128236757, (1280, 720)),
}
HOME_PLATES = ("exterior-before-entry.png", "interior-whole.png", "interior-cot-contact.png")
ALL_HOME_PLATES = HOME_PLATES + ("interior-hearth-contact.png", "interior-table-contact.png", "interior-crate-contact.png", "exterior-restored.png")
PALE_PLATES = ("blue-exterior-relief.png", "blue-cutaway-baseline.png", "blue-cutaway-relief.png")
HOUSEHOLD_SOURCE = (
    "scenes/world/buildings/CityDomesticInterior.gd", "scenes/world/buildings/CityBlockFrontages.gd",
    "tools/dev/CityDomesticInteriorPreview.gd", "tools/dev/CityDomesticInteriorPreview.tscn",
    "tools/tests/DomesticCompositionTest.gd", "tools/tests/DomesticCompositionTest.tscn",
    "tools/tests/DomesticEntryFinishTest.gd", "tools/tests/DomesticEntryFinishTest.tscn",
    "tools/tests/DomesticFrontageFinishTest.gd", "tools/tests/DomesticFrontageFinishTest.tscn",
    "tools/tests/DomesticFrontageFadeTest.gd", "tools/tests/DomesticFrontageFadeTest.tscn",
    "tools/tests/DomesticFacadeCohesionTest.gd", "tools/tests/DomesticFacadeCohesionTest.tscn",
)
EXTRA_SOURCE = (
    "scenes/world/buildings/CityBlockKit.gd", "scenes/world/buildings/CityStreetFrontage.gd",
    "scenes/world/buildings/city_footway.gdshader", "scenes/world/buildings/city_ground.gdshader", "scenes/world/buildings/city_stone.gdshader",
    "scenes/world/buildings/domestic_stone.gdshader", "scenes/world/buildings/domestic_plaster.gdshader",
    "core/systems/world/chunks/ChunkBlockRenderer.gd", "core/systems/world/chunks/ChunkBlockVisualCatalog.gd",
    "core/systems/world/proc/SiteParcelsImpl.gd", "core/systems/world/ground/CityGroundCare.gd",
    "tools/dev/CityBlockPlayablePreview.gd", "tools/dev/CityPaleMasonryPreview.gd", "tools/dev/CityPaleMasonryPreview.tscn",
    "tools/tests/CityDomesticInteriorTest.gd", "tools/tests/DomesticRewardStabilityTest.gd",
    "tools/tests/DomesticWallMaterialTest.gd", "tools/tests/S2PaleMasonryTest.gd", "tools/tests/S2PaleMasonryTest.tscn",
    "tools/tests/CityFootwayGeometryTest.gd", "tools/tests/CityFootwayEdgeRenderTest.gd",
)
ORIGINAL_PNG = {
    "assets/world/domestic_interiors/rush_mat_v1/rush_mat.png": "303ba9215cdf470face851a973418f019dab3aa740b844848c93b9b0a052b2dc",
    "assets/world/domestic_gardens/v1/flower_herb_bed.png": "3edf26c408f71668d0977151118a2f978c7d1cfa7bd1b39e19e22e7f1a40f2f7",
    "assets/world/city_block/house_front.png": "075d87a3f85e26df88d4641af0e61b2a226723c8735c16fb03a1d62c723e5780",
    "assets/world/walls/kit/wall34_10.png": "c5ec8ca652f5664a2385f851c35cd420daa66705de95c5f50d1c82c70234fce4",
}


def require(ok: bool, message: str) -> None:
    if not ok: raise ValueError(message)


def load(path: Path) -> dict:
    return json.loads(path.read_bytes())


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def encoded(value: object) -> bytes:
    return (json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False) + "\n").encode()


def png_size(data: bytes) -> tuple[int, int]:
    require(data[:8] == b"\x89PNG\r\n\x1a\n" and data[12:16] == b"IHDR", "Invalid native PNG")
    return struct.unpack(">II", data[16:24])


def run(payload: dict[str, bytes], label: str, rule: tuple) -> tuple[dict, dict]:
    require(bool(SAFE.fullmatch(label)), f"Unsafe run label: {label}")
    folder = BASE / label
    raw = (folder / "run-results.json").read_bytes()
    record = json.loads(raw)
    logs = {name: (folder / "logs" / name).read_bytes() for name in ("stdout.log", "stderr.log", "engine.log")}
    matches = list(FOOTER.finditer(logs["stdout.log"].decode()))
    footer = None if not matches else {"test": matches[-1][1], "passed": int(matches[-1][2]), "failed": int(matches[-1][3])}
    passed, failed, classification, note = rule
    if passed is not None:
        require(footer is not None and (footer["passed"], footer["failed"]) == (passed, failed), f"Wrong assertion result: {label}/{footer}")
    if classification == "editor_abort":
        require(record["actual_exit"] == -6 and b"double free or corruption" in logs["stderr.log"], "Original editor abort changed")
    elif classification == "shader_compile_failure":
        require(record["actual_exit"] == 0 and record["stop_reason"] == "runtime_diagnostics", "Original diagnostic shader failure changed")
        require(record["diagnostics"] == ["SHADER ERROR: Unknown identifier in expression: 'TEXTURE'.", "ERROR: Shader compilation failed."], "Unexpected shader failure diagnostics")
    elif classification == "sampler_compiler_diagnostic":
        require(record["actual_exit"] == 0 and record["stop_reason"] == "runtime_diagnostics", "Original sampler compiler diagnostic changed")
        require(len(record["diagnostics"]) == 1 and "actions.custom_samplers" in record["diagnostics"][0], "Unexpected sampler compiler diagnostics")
    elif failed:
        require(record["actual_exit"] == 1 and record["stop_reason"] == "nonzero_exit" and record["diagnostics"], f"Wrong historical failed process: {label}")
        if classification in ("clean_assertion_red", "rejected_contact_shift"):
            require(all(line.startswith("ERROR: ") and not any(word in line for word in ("SCRIPT ERROR", "Parse Error", "leaked", "resources still", "allocations")) for line in record["diagnostics"]), f"Unexpected non-assertion diagnostics: {label}")
    else:
        require(record["actual_exit"] == 0 and record["stop_reason"] == "completed" and not record["diagnostics"], f"Claimed clean process is not clean: {label}")
    require(record["resource_samples"] and record["command"] and record["source_hashes"], f"Incomplete monitor record: {label}")
    prefix = f"process/runs/{label}"
    payload[f"{prefix}/run-results.json"] = raw
    for name, data in logs.items(): payload[f"{prefix}/logs/{name}"] = data
    return record, {"label": label, "classification": classification, "note": note, "footer": footer,
        "git_head": record["git_head"], "actual_exit": record["actual_exit"], "stop_reason": record["stop_reason"],
        "elapsed_seconds": record["elapsed_seconds"], "diagnostics": record["diagnostics"],
        "peak_sampled_rss_mb": max(row["rss_mb"] for row in record["resource_samples"]), "run_results_sha256": sha(raw)}


def capture(payload: dict[str, bytes], label: str, destination: str, selected: tuple[str, ...], size: tuple[int, int]) -> dict:
    require(bool(SAFE.fullmatch(label)), f"Unsafe capture label: {label}")
    folder = BASE / (label + "-plates")
    raw = (folder / "capture-info.json").read_bytes()
    info = json.loads(raw)
    require(info["failures"] == 0 and info["save_writes"] == 0, f"Failed native fixture or save write: {label}")
    named = [row["file"] for row in info["plates"]]
    require(len(named) == len(set(named)) and set(selected) <= set(named), f"Native selections missing/duplicated: {label}")
    require({p.name for p in folder.glob("*.png")} == set(named), f"Stale/missing named native PNG: {label}")
    hashes = {}
    for name in named:
        require(Path(name).name == name, f"Unsafe plate name: {name}")
        data = (folder / name).read_bytes()
        require(png_size(data) == size, f"Wrong native window size: {label}/{name}")
        hashes[name] = {"sha256": sha(data), "bytes": len(data), "bundled": name in selected}
        if name in selected: payload[f"{destination}/{name}"] = data
    payload[f"{destination}/capture-info.json"] = raw
    return {"label": label, "folder": folder, "info": info, "size": size, "selected": selected,
            "capture_info_sha256": sha(raw), "all_named_stills": hashes, "destination": destination}


def home_contract(captured: dict, fixture: tuple) -> None:
    info = captured["info"]
    seed, building_id, _ = fixture
    require(info["capture_scene"] == "res://tools/dev/CityDomesticInteriorPreview.tscn" and info["attempt_seed"] == seed and info["target_building_id"] == building_id, f"Wrong genuine household: {captured['label']}")
    require({row["file"] for row in info["plates"]} == set(ALL_HOME_PLATES), "Walkthrough must retain all seven original named architecture captures")
    require(info["recording_scope"] == "physical entry, four prop contacts and exit" and not info["occupied_requested"] and info["occupied_seconds"] == 0, "Final clips must record physical walkthroughs, not relabel occupied fights")
    require(len(info["layout"]) == 4 and len(info["furniture_additions"]) == 6 and len(info["contacts"]) == 4, "Missing purposeful layout/six physical additions/four real contacts")
    require(info["flat_decor"]["source_sha256"] == ORIGINAL_PNG["assets/world/domestic_interiors/rush_mat_v1/rush_mat.png"] and not info["flat_decor"]["foreground_registered"], "Wrong source mat or flat-decor coverage")
    require(info["wall_seconds"] > 0 and info["captured_frames"] == len(info["frames"]) > 1, "No measured walkthrough recording")
    goals = [row for row in info["route"] if row.get("event") == "physical_goal_centering"]
    require(goals and all(row["success"] and row["distance"] < 8.0 for row in goals), "Blocked or uncentered physical goal")
    plates = {row["file"]: row for row in info["plates"]}
    require(plates["exterior-before-entry.png"]["roof_alpha"] >= 0.99 and plates["interior-whole.png"]["roof_alpha"] <= 0.01 and plates["exterior-restored.png"]["roof_alpha"] >= 0.99, "Actual roof entry/cutaway/exit failed")
    require(plates["interior-whole.png"]["inside_count"] > 0 and plates["exterior-restored.png"]["inside_count"] == 0, "Actual roof Area2D signals not exercised")


def video(payload: dict[str, bytes], captured: dict, path_text: str) -> None:
    path = Path(path_text)
    if not path.is_absolute(): path = ROOT / path
    encoding = load(path.with_suffix(".encoding.json"))
    decoded = load(path.with_suffix(".decode.json"))
    info = captured["info"]
    require(sha(path.read_bytes()) == encoding["video_sha256"] and encoding["source_metadata_sha256"] == captured["capture_info_sha256"], f"Video/source binding differs: {path}")
    require(encoding["dimensions"] == list(captured["size"]) and encoding["source_frame_count"] == info["captured_frames"] == len(encoding["images"]), "Encoded native dimensions/frame count differs")
    require(math.isclose(encoding["timing"]["combat_wall_seconds"],info["wall_seconds"],abs_tol=0.000001), "Video timing extends beyond measured walkthrough recording interval")
    require(decoded["exit_code"] == 0 and not decoded.get("stderr","").strip(), "Encoded video has not cleanly decoded")
    require(decoded["video_sha256"] == encoding["video_sha256"], "Decoder sidecar names different video bytes")
    decode_command = decoded["command"]
    require("-i" in decode_command and decode_command.index("-i")+1 < len(decode_command), "Decoder command has no recorded video input")
    decoded_path = Path(decode_command[decode_command.index("-i")+1])
    if not decoded_path.is_absolute(): decoded_path = ROOT / decoded_path
    require(decoded_path.resolve() == path.resolve(), "Decoder sidecar names another video")
    for image, frame in zip(encoding["images"],info["frames"]):
        require(math.isclose(image["wall_time"],frame["wall_time"],abs_tol=0.000001), "Video timestamp differs from original frame metadata")
        source = captured["folder"] / image["file"]
        require(source.resolve().is_relative_to(captured["folder"].resolve()) and sha(source.read_bytes()) == image["sha256"], "Raw frame does not match original encoding sidecar")
    for source in (path,path.with_suffix(".encoding.json"),path.with_suffix(".decode.json")):
        payload[f"{captured['destination']}/walkthrough{source.suffix if source == path else '.encoding.json' if source.name.endswith('.encoding.json') else '.decode.json'}"] = source.read_bytes()
    concat = path.with_suffix(".ffconcat")
    if concat.exists():
        require(sha(concat.read_bytes()) == encoding["concat_sha256"], "Encoding concat sidecar differs")
        payload[f"{captured['destination']}/walkthrough.ffconcat"] = concat.read_bytes()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write",action="store_true")
    parser.add_argument("--history-only",action="store_true",help="Validate historical process inputs while final captures are pending; never writes")
    args = parser.parse_args()
    require(not(args.write and args.history_only), "History-only mode cannot populate a partial final packet")
    inputs = load(OUT / "capture-inputs.json")
    payload: dict[str, bytes] = {}
    records, summary = {}, []
    rules = dict(RUNS)
    for label, specification in inputs["additional_runs"].items():
        require(label not in rules, f"Duplicate historical run: {label}")
        rules[label] = tuple(specification)
    for label, rule in rules.items():
        records[label], row = run(payload,label,rule)
        summary.append(row)
    rewards = [json.loads(line.split("evidence: ",1)[1]) for line in payload["process/runs/continuation-DomesticRewardStabilityTest/logs/stdout.log"].decode().splitlines() if line.startswith("DomesticRewardStabilityTest evidence: ")]
    require(len(rewards) == 2 and {row["building_id"] for row in rewards} == {944996572,2128236757}, "Missing exact new-run reward contents")
    for row in rewards:
        for before, after in (("actual_before","actual_furnished"),("factory_before","factory_furnished")):
            require(row[before]["items"] == row[after]["items"] and row[before]["run_state"] == row[after]["run_state"] and row[before]["claimed"] == row[after]["claimed"] and row[before]["secondary_after"] == row[after]["secondary_after"], "Actual/full-factory reward identity, claims or run RNG differ")
    payload["process/reward-comparisons.json"] = encoded(rewards)
    if args.history_only:
        print(json.dumps({"mode":"read_only_history_preflight","runs":len(records),"pending_final_native":True,"no_files_copied":True},indent=2))
        return
    require(bool(re.fullmatch(r"[0-9a-f]{40}",inputs.get("reviewed_runtime_commit") or "")), "Final reviewed runtime commit attestation is pending")
    require(bool(re.fullmatch(r"50a8e64c[0-9a-f]{32}",inputs.get("household_commit") or "")), "Full root-attested household commit SHA is pending")
    stage_commits = inputs.get("stage_commits",{})
    require(stage_commits and all(bool(re.fullmatch(r"[0-9a-f]{40}",value or "")) for value in stage_commits.values()), "Full root-attested stage commit bindings are pending")
    captures = [capture(payload,"continuation-bed-small","iteration-bed-small",(),(960,540))]
    for name,size in (("small",(960,540)),("normal",(1280,720))):
        captures.append(capture(payload,"continuation-bed-"+name+"-final","iteration-underlay-bed-"+name,(),size))
    captures.append(capture(payload,"continuation-pale-small","iteration-pale-small",(),(960,540)))
    captures.append(capture(payload,"continuation-facade-early","iteration-facade-early",(),(960,540)))
    for specification in inputs.get("additional_iteration_captures",[]):
        label = specification["label"]
        require(label in records, f"Iteration capture has no original process record: {label}")
        destination = specification["destination"]
        require(bool(SAFE.fullmatch(destination)), f"Unsafe iteration destination: {destination}")
        captures.append(capture(payload,label,destination,tuple(specification.get("selected",[])),tuple(specification["size"])))
    final_records, home_records, pale_records = [], [], []
    for name, fixture in HOMES.items():
        specification = inputs["homes"].get(name)
        require(isinstance(specification,dict), f"Final household capture input pending: {name}")
        label = specification["label"]
        require(label != "continuation-bed-small", "First bed iteration cannot be relabeled as final")
        record, row = run(payload,label,(None,None,"native_final_walkthrough","Final root-selected physical entry/contact/exit walkthrough."))
        require(label not in records, f"Duplicate native process label: {label}")
        records[label] = record
        summary.append(row)
        captured = capture(payload,label,name,HOME_PLATES,fixture[2])
        home_contract(captured,fixture)
        video(payload,captured,specification["video"])
        captures.append(captured)
        final_records.append(record)
        home_records.append(record)
    for name, size in (("small",(960,540)),("normal",(1280,720))):
        specification = inputs["pale"].get(name)
        require(isinstance(specification,dict), f"Final pale capture input pending: {name}")
        label = specification["label"]
        record, row = run(payload,label,(None,None,"native_pale_control","Actual adjacent slate civic building, matched material controls and physical entry/exit."))
        require(label not in records, f"Duplicate native process label: {label}")
        records[label] = record
        summary.append(row)
        captured = capture(payload,label,"pale-"+name,PALE_PLATES,size)
        info = captured["info"]
        require(info["capture_scene"] == "res://tools/dev/CityPaleMasonryPreview.tscn" and info["segment"] == 2 and info["attempt_seed"] == 16102026 and info["requested_home_id"] == 944996572 and info["physical_unchanged"] is True, "Wrong/physically changed actual pale neighbor control")
        plates = {row["file"]:row for row in info["plates"]}
        require(plates["blue-cutaway-baseline.png"]["source_relief"] == [0.0] and all(value > 0 for value in plates["blue-cutaway-relief.png"]["source_relief"]), "Wrong material A/B values")
        require(plates["blue-cutaway-relief.png"]["roof_alpha"] <= 0.01 and plates["blue-cutaway-relief.png"]["inside_count"] > 0 and plates["blue-exterior-restored.png"]["roof_alpha"] >= 0.99 and plates["blue-exterior-restored.png"]["inside_count"] == 0, "Pale control lacks actual physical roof cutaway/restore")
        captures.append(captured)
        final_records.append(record)
        pale_records.append(record)
    scoped = HOUSEHOLD_SOURCE + EXTRA_SOURCE
    source_hashes = {}
    for path in scoped:
        data = (ROOT/path).read_bytes()
        source_hashes[path] = sha(data)
        relevant = pale_records if path in ("tools/dev/CityPaleMasonryPreview.gd","tools/dev/CityPaleMasonryPreview.tscn","core/systems/world/chunks/ChunkBlockRenderer.gd","scenes/world/buildings/city_stone.gdshader") else home_records
        if not path.startswith("tools/tests/"):
            require(all(record["source_hashes"].get(path) == source_hashes[path] for record in relevant), f"Final captures do not share the packaged runtime source: {path}")
        payload["process/scoped-source/"+path] = data
    asset_hashes = {}
    for path, expected in ORIGINAL_PNG.items():
        require(sha((ROOT/path).read_bytes()) == expected, f"Original PNG bytes changed: {path}")
        for asset in (path,path+".import"):
            data = (ROOT/asset).read_bytes()
            asset_hashes[asset] = sha(data)
            require(all(record["source_hashes"].get(asset) == sha(data) for record in final_records), f"Final native source/import binding differs: {asset}")
            if asset.endswith(".import"): payload["process/scoped-source/"+asset] = data
    payload["process/source-bindings.json"] = encoded({"household_commit":inputs["household_commit"],"stage_commits":stage_commits,"reviewed_runtime_commit":inputs["reviewed_runtime_commit"],"commit_attestation":"Exact commits supplied and reviewed by root, the Git owner. The household commit records the earlier composition stage; later facade and paving/material stages are bound separately. This packager invokes no Git and does not independently reconstruct committed blobs.","household_scope":list(HOUSEHOLD_SOURCE),"scoped_source_sha256":source_hashes,"original_png_and_import_sha256":asset_hashes,"per_run_scoped_hashes":{label:{path:record["source_hashes"].get(path) for path in scoped} for label,record in records.items()}})
    manifests = [{key:value for key,value in item.items() if key not in ("folder","info")} for item in captures]
    payload["process/summary.json"] = encoded({"runs":summary,"captures":manifests,"final_selected_stills":18,"iteration_selected_stills":2,"walkthrough_videos":4})
    text = (OUT/"README.md").read_text()
    require(text.count(START) == 1 and text.count(END) == 1, "Missing README summary markers")
    rows = ["| Original run | Assertions/process | Classification | Seconds | Original launch HEAD |","| --- | --- | --- | ---: | --- |"]
    for row in summary:
        result = f"{row['footer']['passed']} / {row['footer']['failed']}" if row["footer"] else f"process exit {row['actual_exit']}"
        if row["stop_reason"] == "runtime_diagnostics": result += "; monitor diagnostic failure"
        rows.append(f"| [{row['label']}](process/runs/{row['label']}/run-results.json) | {result} | {row['classification']} | {row['elapsed_seconds']:.3f} | `{row['git_head'][:8]}` |")
    before,rest = text.split(START);_,after = rest.split(END)
    payload["README.md"] = (before+START+"\n\n"+"\n".join(rows)+"\n\n"+END+after).encode()
    for name in (".gdignore","capture-inputs.json","package-household.py"): payload[name] = (OUT/name).read_bytes()
    payload["evidence-index.json"] = encoded({"files":{name:{"bytes":len(data),"sha256":sha(data)} for name,data in sorted(payload.items())},"index_policy":"Every bundled file except the index itself. Selected PNGs, metadata, videos, sidecars and original process records/logs are copied unchanged."})
    existing = {str(path.relative_to(OUT)) for path in OUT.rglob("*") if path.is_file()}
    require(existing <= set(payload), f"Unexpected output files; nothing removed: {sorted(existing-set(payload))}")
    if args.write:
        for name,data in payload.items():
            target = OUT/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
        require(all(sha((OUT/name).read_bytes()) == sha(data) for name,data in payload.items()), "Copied evidence differs from validated bytes")
    print(json.dumps({"mode":"written" if args.write else "read_only_preflight","runs":len(records),"final_selected_stills":18,"iteration_selected_stills":2,"walkthrough_videos":4,"bundled_files":len(payload),"bundled_bytes":sum(len(data) for data in payload.values()),"output":str(OUT)},indent=2))


if __name__ == "__main__": main()
