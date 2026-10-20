#!/usr/bin/env python3
"""Curate explicit domestic evidence. Default validation is read-only.

Root supplies four inspected capture labels and existing encoded videos. This
script invokes no engine, Git, encoder, decoder or image processing. It never
copies or traverses raw fight frame directories.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import struct

BASE = Path(__file__).resolve().parent
ROOT = BASE.parent.parent
OUT = ROOT / "docs/art/reference/2026-10-20-linux-domestic-interiors"
START = "<!-- RECORDED_DOMESTIC_SUMMARY_START -->"
END = "<!-- RECORDED_DOMESTIC_SUMMARY_END -->"
PURPOSE_COMMIT = "4c4a6cb2"
FINISH_COMMIT = "276e5e152e2a4d718149e044c16dcc21d938c514"
FINISH_INPUTS = (
    "scenes/world/buildings/CityBlockFrontages.gd",
    "scenes/world/buildings/domestic_plaster.gdshader",
    "tools/dev/CityDomesticInteriorPreview.gd",
    "tools/dev/CityDomesticInteriorPreview.tscn",
    "tools/tests/DomesticFrontageFinishTest.gd",
    "tools/tests/DomesticFrontageFinishTest.tscn",
    "tools/tests/DomesticFrontageFadeTest.gd",
    "tools/tests/DomesticFrontageFadeTest.tscn",
)
FOOTER = re.compile(r"(?m)^([A-Za-z0-9_]+): (\d+) passed, (\d+) failed")
SAFE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
ARCHITECTURE = (
    "exterior-before-entry.png", "interior-whole.png",
    "interior-cot-contact.png", "interior-hearth-contact.png",
    "interior-table-contact.png", "interior-crate-contact.png",
    "exterior-restored.png",
)
OCCUPIED = ("interior-occupied-start.png", "interior-occupied-ending.png")
FIXTURES = {
    "bed-small": (16102026, 944996572, (960, 540)),
    "bed-normal": (16102026, 944996572, (1280, 720)),
    "fruit-small": (17, 2128236757, (960, 540)),
    "fruit-normal": (17, 2128236757, (1280, 720)),
}
# Labels are historical identifiers, never evidence of success by themselves.
RUNS = {
    "domestic-baseline-runtime": ("failed_setup", None, "Missing imported autoload/UID setup; timed out. No baseline or feature assertion result."),
    "domestic-uid-baseline": ("clean_check", (1300, 0), "Prepared same-machine Linux cache/class/UID-map runtime baseline; not a fresh-clone import proof."),
    "domestic-plan-uid-red": ("clean_feature_red", (0, 1), "Expected missing domestic adapter assertion before furnishing source changes."),
    "domestic-wall-uid-red": ("clean_feature_red", (0, 1), "Expected absent wall-ownership adapter assertion before material changes."),
    "domestic-interior-green": ("failed_import_attempt", (229, 52), "Original cot/hearth PNGs existed, but Linux .png.import sidecars were absent in the fresh worktree. Missing-loader cascade; not GREEN."),
    "domestic-interior-green-imported": ("clean_check", (313, 0), "Same-source Linux cot/hearth import sidecars supplied; measured real-home layout, physics and lifetime checks pass."),
    "domestic-wall-green": ("clean_check", (67, 0), "Initial explicit domestic envelope/partition/window/fill material ownership."),
    "domestic-frontage-red": ("clean_feature_red", (30, 8), "Real broad-field UV density/isotropy and supported doorway header failures."),
    "domestic-frontage-green": ("failed_parse_attempt", None, "Unannotated metadata bool could not infer a type; interrupted after61.828s. Not valid feature RED or GREEN."),
    "domestic-reward-policy-red": ("clean_feature_red", (321, 15), "Multi-item/security eligibility and missing actual connected-volume policy handoff."),
    "domestic-policy-green": ("clean_check", (336, 0), "Known single-item ambient furnishing only; unknown/multi-item/encounter/large owners omitted independently of wall presentation."),
    "domestic-frontage-fade-red": ("clean_feature_red", (2, 6), "Both new piers and the new header/lintel junction doubled fractional opaque coverage."),
    "domestic-final-DomesticFrontageFinishTest": ("clean_check", (55, 0), "Disjoint new details, isotropic regional plaster sampling, unchanged cardinal openings and cutaway controls; before inherited jamb correction."),
    "domestic-final-DomesticFrontageFadeTest": ("clean_check", (8, 0), "Three new detail points fade once; this earlier check did not cover inherited jamb/field junctions."),
    "domestic-final-DomesticWallMaterialTest": ("clean_check", (68, 0), "Mixed wall/window/partition/corner material ownership; multi-item wall presentation remains eligible."),
    "domestic-final-DomesticRewardStabilityTest": ("clean_check", (43, 0), "Actual chance/claims plus full single-item factory identity/mods/run RNG comparison for both kept homes."),
    "domestic-jamb-fade-red": ("clean_feature_red", (8, 4), "Literal inherited bed jamb/field points(504,930),(647,930) each double coverage at half fade."),
    "domestic-jamb-fade-green": ("clean_check", (16, 0), "Exact domestic jamb subtraction with preserved8px upper caps; original3 detail points,2 jamb points and2 cap controls."),
    "domestic-frontage-final": ("clean_check", (55, 0), "Final frontage rerun after inherited jamb correction; isotropic sampling, retained opening/cardinal ownership and cutaway controls."),
    "domestic-bed-first": ("native_revision1", None, "First seven-plate architecture run. Physical contacts/roof restore pass, but inherited same-cell route return remained about23px off the goal center; about41px is the separate valid support-contact distance."),
}
SCOPED_INPUTS = (
    "scenes/world/buildings/CityDomesticInterior.gd",
    "scenes/world/buildings/CityBlockFrontages.gd",
    "scenes/world/buildings/domestic_stone.gdshader",
    "scenes/world/buildings/domestic_plaster.gdshader",
    "core/systems/world/chunks/ChunkBlockVisualCatalog.gd",
    "core/systems/world/chunks/ChunkBlockRenderer.gd",
    "core/systems/world/proc/SiteParcelsImpl.gd",
    "scenes/world/buildings/CityBlockKit.gd",
    "scenes/world/buildings/RoofOverlay.gd",
    "scenes/world/buildings/CityBlockRoofForms.gd",
    "scenes/world/buildings/roof.gdshader",
    "core/systems/world/visibility/WorldCover.gd",
    "tools/dev/CityDomesticInteriorPreview.gd",
    "tools/dev/CityDomesticInteriorPreview.tscn",
    "tools/dev/CityBlockPlayablePreview.gd",
    "tools/tests/CityDomesticInteriorTest.gd",
    "tools/tests/DomesticWallMaterialTest.gd",
    "tools/tests/DomesticRewardStabilityTest.gd",
    "tools/tests/DomesticFrontageFinishTest.gd",
    "tools/tests/DomesticFrontageFadeTest.gd",
)
PNG_HASHES = {
    "assets/world/domestic_interiors/v1/timber_cot.png": "22549e75329ee9164f9f41fbefcdea2e6b028309a7c358362b4c11a2fc69c143",
    "assets/world/domestic_interiors/v1/cooking_hearth.png": "fd6a6434311135e5c7b09ca6b2c3c3ca47333c33b78fed69f826527c9bc7e26b",
    "assets/world/props/prop_table_small_01.png": "61b668a60495ae87f6a68c03ed10682c5188431ba221bbe306436b82688f5c0e",
    "assets/world/dressing/generated/dressing_set_v2.png": "78dc5e917b3c0eac0903baa2a40816c84a90c069ccc8f405772ca9b7e5b5e9b3",
}
ASSET_PATHS = tuple(PNG_HASHES) + (
    "assets/world/domestic_interiors/v1/timber_cot.png.import",
    "assets/world/domestic_interiors/v1/cooking_hearth.png.import",
    "assets/world/domestic_interiors/v1/manifest.json",
    "assets/world/dressing/generated/crate.tres",
)


def require(ok: bool, message: str) -> None:
    if not ok:
        raise ValueError(message)


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def save(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False) + "\n")


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as source:
        header = source.read(26)
    require(header[:8] == b"\x89PNG\r\n\x1a\n" and header[12:16] == b"IHDR", f"Not a PNG: {path}")
    return struct.unpack(">II", header[16:24])


def footer(label: str) -> dict | None:
    matches = list(FOOTER.finditer((BASE / label / "logs/stdout.log").read_text()))
    if not matches:
        return None
    match = matches[-1]
    return {"test": match[1], "passed": int(match[2]), "failed": int(match[3])}


def run_record(label: str, rule: tuple) -> dict:
    require(bool(SAFE.fullmatch(label)), f"Unsafe run label: {label}")
    record = load(BASE / label / "run-results.json")
    for name in ("stdout.log", "stderr.log", "engine.log"):
        require((BASE / label / "logs" / name).is_file(), f"Missing full log: {label}/{name}")
    classification, expected, _ = rule
    observed = footer(label)
    if expected is not None:
        require(observed is not None and (observed["passed"], observed["failed"]) == expected, f"Unexpected assertion footer: {label}: {observed}")
    diagnostics = record["diagnostics"]
    if classification in ("clean_check", "native_revision1", "native_revision2"):
        require(record["actual_exit"] == 0 and record["stop_reason"] == "completed" and not diagnostics, f"Claimed clean run is not clean: {label}")
    elif classification == "clean_feature_red":
        require(record["actual_exit"] == 1 and record["stop_reason"] == "nonzero_exit" and bool(diagnostics), f"Feature RED lacks its expected exit/diagnostics: {label}")
        require(all(line.startswith("ERROR: ") and not any(word in line for word in ("SCRIPT ERROR", "Parse Error", "leaked", "resources still")) for line in diagnostics), f"Feature RED contains non-assertion diagnostics: {label}")
    else:
        require(bool(diagnostics) and record["actual_exit"] != 0, f"Historical failed attempt changed classification: {label}")
    return record


def vector(text: str) -> tuple[float, float]:
    match = re.fullmatch(r"\(([-+0-9.eE]+),\s*([-+0-9.eE]+)\)", text)
    require(match is not None, f"Invalid recorded Vector2: {text}")
    return float(match[1]), float(match[2])


def capture(label: str, destination: str, revision: int) -> dict:
    folder = BASE / (label + "-plates")
    info = load(folder / "capture-info.json")
    expected_files = ARCHITECTURE + (OCCUPIED if revision == 2 else ())
    require({p.name for p in folder.glob("*.png")} == set(expected_files), f"Unexpected/stale named stills: {label}")
    require([p["file"] for p in info["plates"]] == list(ARCHITECTURE[:-1] + (OCCUPIED if revision == 2 else ()) + ARCHITECTURE[-1:]), f"Plate manifest order differs: {label}")
    seed, building, size = FIXTURES[destination] if revision == 2 else FIXTURES["bed-small"]
    # This tool's captured metadata does not export Global.attempt_segment.
    # Its hashed source rejects non-S2 review; bind its explicit argument or
    # documented default rather than inventing a captured numeric field.
    segment = next((int(arg.split("=", 1)[1]) for arg in info["args"] if arg.startswith("--segment=")), 2)
    require(info.get("attempt_seed") == seed and info.get("target_building_id") == building and segment == 2 and info.get("capture_scene") == "res://tools/dev/CityDomesticInteriorPreview.tscn", f"Wrong actual household identity: {label}")
    require(info.get("failures") == 0 and info.get("save_writes") == 0, f"Fixture failure or save write: {label}")
    require(len(info["layout"]) == 4 and len(info["furniture_additions"]) == 6 and len(info["contacts"]) == 4, f"Expected four measured props/six added cells/four contacts: {label}")
    require({p["kind"] for p in info["layout"]} == {"cot", "hearth", "table", "crate"}, f"Wrong purpose groups: {label}")
    for name in expected_files:
        require(png_size(folder / name) == size, f"Wrong native PNG dimensions: {label}/{name}")
    for cell in info["furniture_additions"]:
        require(cell["kind"] == 4 and cell["variant"] & 32 and cell["walkable"] is False, f"Missing explicit low-cover physical addition: {label}")
    for contact in info["contacts"]:
        require(39.0 <= contact["support_distance"] <= 60.0 and 0.0 <= contact["projectile_hit_t"] <= 1.0, f"Invalid physical contact/projectile evidence: {label}")
        require(math.dist(vector(contact["actual_art_contact"]), vector(contact["measured_art_contact"])) < 0.02, f"Artwork source datum drifted: {label}")
    plates = {p["file"]: p for p in info["plates"]}
    require(plates["exterior-before-entry.png"]["roof_alpha"] >= 0.99 and plates["interior-whole.png"]["roof_alpha"] <= 0.01 and plates["exterior-restored.png"]["roof_alpha"] >= 0.99, f"Roof entry/exit sequence failed: {label}")
    require(plates["interior-whole.png"]["inside_count"] > 0 and plates["exterior-restored.png"]["inside_count"] == 0, f"Actual roof signals not exercised: {label}")
    require(any(row.get("event") == "streamed_reload" and row.get("equal") for row in info["route"]), f"No actual stable streamed reload: {label}")
    if revision == 2:
        require(info.get("movement_fixture_revision") == 2 and info.get("goal_tolerance_px") == 8.0, f"Final capture lacks revision2 centering contract: {label}")
        goals = [row for row in info["route"] if row.get("event") == "physical_goal_centering"]
        require(len(goals) >= 11 and all(row["success"] and row["distance"] < 8.0 for row in goals), f"Uncentered/blocked final physical goal: {label}")
        require(info.get("occupied_requested") is True and info["wall_seconds"] > 0 and info["captured_frames"] == len(info["frames"]) > 1 and info["weapon_fires"] > 0 and info["max_projectiles"] > 0, f"Final capture did not exercise bounded real occupied movement/attacks: {label}")
    else:
        require(info["captured_frames"] == 0 and info["wall_seconds"] == 0 and not info["frames"], "Revision1 architecture is still evidence, not a zero-second video")
    return {"label": label, "destination": destination, "revision": revision, "folder": folder, "info": info, "files": expected_files, "size": size, "segment_binding":"Validated capture tool rejects non-S2; explicit --segment argument or its documented default2. Global.attempt_segment is not separately exported by this tool."}


def video_record(path: Path, captured: dict) -> dict:
    path = path.resolve()
    encoding_path, decode_path = path.with_suffix(".encoding.json"), path.with_suffix(".decode.json")
    encoding, decoded = load(encoding_path), load(decode_path)
    info = captured["info"]
    require(digest(path) == encoding["video_sha256"] and digest(captured["folder"] / "capture-info.json") == encoding["source_metadata_sha256"], f"Video/source binding mismatch: {path}")
    require(encoding["dimensions"] == list(captured["size"]) and encoding["source_frame_count"] == info["captured_frames"] == len(encoding["images"]), f"Video dimensions/frame count mismatch: {path}")
    require(abs(encoding["timing"]["combat_wall_seconds"] - info["wall_seconds"]) < 0.000001, f"Video extends beyond measured recording interval: {path}")
    require(all(abs(a["wall_time"] - b["wall_time"]) < 0.000001 for a, b in zip(encoding["images"], info["frames"])), f"Video timestamps mismatch: {path}")
    require(decoded.get("exit") == 0 and not decoded.get("stderr", "").strip(), f"Video has not cleanly decoded: {path}")
    decoded_video = Path(decoded["video"])
    if not decoded_video.is_absolute(): decoded_video = ROOT / decoded_video
    require(decoded_video.resolve() == path, f"Decoder sidecar names another video: {path}")
    files = [path, encoding_path, decode_path]
    concat = path.with_suffix(".ffconcat")
    if concat.is_file():
        require(digest(concat) == encoding["concat_sha256"], f"Encoding concat mismatch: {concat}")
        files.append(concat)
    return {"files": files, "encoding": encoding, "decode": decoded}


def rewards() -> list[dict]:
    path = BASE / "domestic-final-DomesticRewardStabilityTest/logs/stdout.log"
    records = [json.loads(line.split("evidence: ", 1)[1]) for line in path.read_text().splitlines() if "DomesticRewardStabilityTest evidence: " in line]
    require({row["building_id"] for row in records} == {944996572, 2128236757} and len(records) == 2, "Missing exact kept-home reward comparisons")
    for row in records:
        for left, right in (("actual_before", "actual_furnished"), ("factory_before", "factory_furnished")):
            a, b = row[left], row[right]
            require(a["items"] == b["items"] and a["run_state"] == b["run_state"], "Actual full reward roll/RNG mismatch")
        require(row["actual_before"]["claimed"] == row["actual_furnished"]["claimed"] and row["actual_before"]["secondary_after"] == row["actual_furnished"]["secondary_after"], "Reward ownership transition mismatch")
    return records


def finish_binding(records: dict, captures: dict, commit: str) -> dict:
    require(commit == FINISH_COMMIT, "Only the exact root-verified finish commit has an attestation in this packet")
    labels = [item["label"] for item in captures.values() if item["revision"] == 2]
    files = {}
    for path in FINISH_INPUTS:
        hashes = [records[label]["source_hashes"].get(path) for label in labels]
        require(all(hashes) and len(set(hashes)) == 1, f"Finish input differs between final native launches: {path}")
        current = digest(ROOT / path)
        require(current == hashes[0], f"Current finish source differs from the captured launch input: {path}")
        files[path] = {"recorded_launch_sha256":hashes[0], "packaging_file_sha256":current}
    return {"commit":commit, "files":files, "capture_launches":{label:records[label]["git_head"] for label in labels},
            "root_attestation":"Root staged the eight exact finish/tool/test paths, checked each SHA256 against all four final native launch records, committed276e5e152e2a4d718149e044c16dcc21d938c514, and fast-forwarded main before packaging.",
            "packager_check":"The current eight source files match all four recorded launch SHA256 values. The packager invokes no Git; the commit association is root's explicit verification above.",
            "scope":"These eight finish/tool/test files only. Other integrated scene/ground sources retain their launch records and separate packets; no later whole-tree or complete asset reproducibility claim is made."}


def parse_mapping(value: str) -> tuple[str, str]:
    key, separator, target = value.partition("=")
    require(bool(separator) and bool(SAFE.fullmatch(key)) and bool(target), f"Expected NAME=VALUE: {value}")
    return key, target


def summary(records: dict, captures: dict) -> str:
    lines = [START, "", "Packaged recorded checks and inspected capture labels:", "", "| Check | Passed / failed |", "| --- | --- |"]
    for label in records:
        if label in ("domestic-policy-green", "domestic-final-DomesticWallMaterialTest", "domestic-final-DomesticRewardStabilityTest", "domestic-jamb-fade-green", "domestic-frontage-final") or label not in RUNS and records[label]["packet_classification"] == "clean_check":
            count = footer(label)
            lines.append(f"| {count['test']} ({label}) | {count['passed']} / {count['failed']} |")
    lines += ["", "| Native capture | Monitor seconds | Stills / fight frames | Occupied recording seconds |", "| --- | --- | --- | --- |"]
    for name, item in captures.items():
        info = item["info"]
        lines.append(f"| [{name}]({name}/interior-whole.png), revision{item['revision']} | {records[item['label']]['elapsed_seconds']} | {len(item['files'])} / {info['captured_frames']} | {info['wall_seconds']} |")
    lines += ["", "All listed native runs have exit0, no monitor diagnostics, zero fixture failures and zero saves. Earlier checks retain their own exact source snapshots; they are not relabeled final integrated-source regressions.", "", END]
    return "\n".join(lines)


def package(rules: dict, records: dict, captures: dict, media: dict, reward_records: list, binding: dict) -> None:
    expected = {"README.md", ".gdignore", "evidence-index.json"}
    generated, copies = {}, {}
    def emit(relative: str, value: object) -> None:
        generated[relative] = value
        expected.add(relative)
    def retain(source: Path, relative: str) -> None:
        copies[relative] = source
        expected.add(relative)
    rows, scoped = [], {}
    for label, source in records.items():
        result = copy.deepcopy(source)
        provenance = {key: result.pop(key) for key in ("source_hashes", "source_untracked")}
        key = hashlib.sha256(canonical(provenance)).hexdigest()
        emit(f"process/sources/{key}.json", provenance)
        result.pop("git_status_porcelain", None)
        result["original_run_results_sha256"] = digest(BASE / label / "run-results.json")
        result["source_provenance"] = f"../sources/{key}.json"
        result["packet_note"] = rules[label][2] + " Exact command/exits/diagnostics/resources/logs retained; input hashes/untracked paths moved losslessly. Only machine-wide Git status omitted. Original local paths are historical provenance, not bundled-file claims."
        emit(f"process/runs/{label}.json", result)
        for name in ("stdout.log", "stderr.log", "engine.log"):
            retain(BASE / label / "logs" / name, f"process/logs/{label}/{name}")
        rows.append({"label":label, "classification":rules[label][0], "note":rules[label][2], "assertions":footer(label), "actual_exit":source["actual_exit"], "stop_reason":source["stop_reason"], "elapsed_seconds":source["elapsed_seconds"], "diagnostics":source["diagnostics"], "peak_rss_mb":max((sample["rss_mb"] for sample in source["resource_samples"]), default=None), "command":source["command"], "source_provenance":f"sources/{key}.json"})
        scoped[label] = {"monitor_git_head":source["git_head"], "original_run_results_sha256":result["original_run_results_sha256"], "hashes":{path:source["source_hashes"].get(path) for path in SCOPED_INPUTS + ASSET_PATHS}}
    measured, media_bindings = {}, {}
    for name, item in captures.items():
        for filename in item["files"] + ("capture-info.json",):
            retain(item["folder"] / filename, f"{name}/{filename}")
        info = item["info"]
        measured[name] = {key:info.get(key) for key in ("attempt_seed", "target_building_id", "target_chunk", "layout", "layout_sha256", "furniture_additions", "contacts", "plates", "route", "movement_fixture_revision", "prior_evidence_qualification", "limits")}
        measured[name]["segment_binding"] = item["segment_binding"]
        if item["revision"] == 1:
            measured[name]["same_cell_goal_error_px"] = [math.dist(vector(row["resolved"]),vector(row["arrived"])) for row in info["route"] if row.get("event") == "walk" and row.get("path_cells") == 0]
            measured[name]["qualification"] = "Recorded zero-path goal errors are about23px; valid collision contact distances are separately about41px. Original capture-info is unchanged."
        if name in media:
            for path in media[name]["files"]:
                retain(path, f"{name}/occupied{''.join(path.suffixes)}")
            media_bindings[name] = {"video_sha256":media[name]["encoding"]["video_sha256"], "capture_info_sha256":digest(item["folder"] / "capture-info.json"), "raw_frames_bundled":False, "note":"Original encoding/clean decode sidecars are unchanged. Their scratch paths and raw-image hashes document provenance; raw fight PNGs remain outside this packet."}
    asset_bindings = {}
    for path in ASSET_PATHS:
        actual = digest(ROOT / path)
        if path in PNG_HASHES: require(actual == PNG_HASHES[path], f"Original PNG hash changed: {path}")
        asset_bindings[path] = {"current_file_sha256":actual, "png_dimensions":png_size(ROOT / path) if path.endswith(".png") else None, "recorded_launch_hashes":{label:record["source_hashes"].get(path) for label, record in records.items()}, "meaning":"Current-file identity is separate from recorded launch hashes; null means unrecorded, not unchanged."}
    for path in ASSET_PATHS:
        if path.endswith(".import") or path.endswith("manifest.json") or path.endswith("crate.tres"):
            retain(ROOT / path, "assets/" + Path(path).name)
    comparisons = []
    for a, b in (("revision1-bed-small", "bed-small"), ("bed-small", "bed-normal"), ("fruit-small", "fruit-normal")):
        x, y = captures[a], captures[b]
        hx, hy = scoped[x["label"]]["hashes"], scoped[y["label"]]["hashes"]
        comparisons.append({"first":a, "second":b, "layout_equal":x["info"]["layout_sha256"] == y["info"]["layout_sha256"], "same_camera_record":x["info"].get("camera") == y["info"].get("camera"), "changed_scoped_inputs":[path for path in SCOPED_INPUTS if hx[path] != hy[path]], "limits":"Revision1 predates final jamb/scene roof integration and physical goal-centering revision2. Different native sizes are separate samples. These records are not an isolated material, lighting or performance ablation."})
    emit("process/summary.json", rows)
    emit("process/scoped-inputs.json", {"scope":list(SCOPED_INPUTS), "assets":list(ASSET_PATHS), "runs":scoped, "meaning":"Launch-time monitor inputs, not a later commit binding. Full source records remain separately deduplicated."})
    emit("assets/source-bindings.json", asset_bindings)
    emit("measured-households.json", measured)
    first = captures["revision1-bed-small"]
    emit("metadata-qualifications.json", {
        "subject":"Historical first-run goal-center wording repeated in revision2 prior_evidence_qualification",
        "correction":"Revision1 zero-path return goal errors are22.933–22.998px, about23px. About41px is the separate correct player-to-support collision distance; it is not the goal-center error.",
        "revision1_zero_path_goal_errors_px":measured["revision1-bed-small"]["same_cell_goal_error_px"],
        "derived_from_capture_info_sha256":digest(first["folder"] / "capture-info.json"),
        "affected_raw_capture_metadata":{name:digest(item["folder"] / "capture-info.json") for name,item in captures.items()},
        "raw_capture_files_rewritten":False,
        "meaning":"Original PNGs, capture-info, source hashes and encoding/decode sidecars remain byte-identical. This separate correction prevents a prose range from being mistaken for the actual recorded physical measurements. Final revision2 physical centering checks use their own successful under8px events.",
    })
    emit("reward-comparison.json", reward_records)
    emit("media-bindings.json", media_bindings)
    emit("comparisons.json", comparisons)
    emit("process/finish-commit-binding.json", binding)
    emit("packet-provenance.json", {"purpose_masonry_reward_commit":PURPOSE_COMMIT, "finish_tool_commit":binding["commit"], "finish_binding":"process/finish-commit-binding.json", "commit_note":"Root verified the eight finish/tool/test files against all four captured launch snapshots before commit. This packager rechecks those exact file hashes; it invokes no Git and makes no later whole-tree/asset binding claim.", "packager_sha256":digest(Path(__file__)), "final_capture_labels":{name:item["label"] for name,item in captures.items() if item["revision"] == 2}, "raw_fight_frame_pngs_bundled":False})
    for name in ("cache-bootstrap.json", "uid-bootstrap.json"):
        retain(BASE / name, "process/setup/" + name)
    retain(BASE / "pre-merge-sidecars/record.json", "process/setup/pre-merge-sidecars.json")
    retain(Path(__file__).resolve(), "process/package-domestic.py")
    actual_files = {p.relative_to(OUT).as_posix() for p in OUT.rglob("*") if p.is_file()}
    require(not actual_files - expected, f"Unexpected existing packet files: {sorted(actual_files-expected)}")
    for relative, source in copies.items():
        target = OUT / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        require(digest(source) == digest(target), f"Copy hash mismatch: {relative}")
    for relative, value in generated.items(): save(OUT / relative, value)
    (OUT / ".gdignore").touch()
    readme = OUT / "README.md"
    before, tail = readme.read_text().split(START)
    _, after = tail.split(END)
    readme.write_text(before + summary(records, captures) + after)
    index = [{"file":p.relative_to(OUT).as_posix(), "sha256":digest(p), "bytes":p.stat().st_size} for p in sorted(OUT.rglob("*")) if p.is_file() and p.name != "evidence-index.json"]
    save(OUT / "evidence-index.json", index)
    print(f"Packaged {len(records)} monitored runs, {sum(len(item['files']) for item in captures.values())} unedited stills and {len(media)} encoded occupied videos -> {OUT}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture", action="append", default=[], metavar="DESTINATION=RUN_LABEL", help="Supply each of bed-small/bed-normal/fruit-small/fruit-normal; input folder is RUN_LABEL-plates")
    parser.add_argument("--video", action="append", default=[], metavar="DESTINATION=MP4_PATH", help="Existing video with matching .encoding.json/.decode.json; defaults to scratch/videos/RUN_LABEL.mp4")
    parser.add_argument("--final-check", action="append", default=[], metavar="RUN_LABEL=PASSED,FAILED", help="Additional explicitly reviewed clean final check; no directory discovery")
    parser.add_argument("--finish-commit", default=FINISH_COMMIT, help="Exact root-verified finish/tool commit; defaults to the recorded276e5e15 commit")
    parser.add_argument("--history-only", action="store_true", help="Read-only historical record/reward validation while final capture labels are pending")
    parser.add_argument("--write", action="store_true", help="Write the packet only after full validation; default reads only")
    args = parser.parse_args()
    require(not (args.history_only and args.write), "--history-only cannot write a final packet")
    rules = RUNS.copy()
    for value in args.final_check:
        label, counts = parse_mapping(value)
        passed, failed = (int(n) for n in counts.split(","))
        require(failed == 0 and label not in rules, "Additional final check must be new and clean")
        rules[label] = ("clean_check", (passed, failed), "Root-selected additional final-source check.")
    records = {label:run_record(label, rule) for label,rule in rules.items()}
    for label, record in records.items(): record["packet_classification"] = rules[label][0]
    reward_records = rewards()
    for path, expected in PNG_HASHES.items():
        require(digest(ROOT / path) == expected, f"Original PNG hash changed: {path}")
    readme = (OUT / "README.md").read_text()
    require(readme.count(START) == readme.count(END) == 1, "README requires exactly one generated-summary block")
    if args.history_only:
        print(f"Validated {len(records)} explicit historical monitored records and 2 actual/full-factory reward comparisons plus original PNG hashes; final captures/media remain pending. No files written.")
        return
    selected = dict(parse_mapping(value) for value in args.capture)
    require(set(selected) == set(FIXTURES), "Supply all four explicit --capture mappings; pending captures are not silently omitted")
    require(len(set(selected.values())) == 4, "Each final capture must have its own monitored run label")
    captures = {"revision1-bed-small":capture("domestic-bed-first", "revision1-bed-small", 1)}
    for name, label in selected.items():
        rules[label] = ("native_revision2", None, "Inspected actual generated home; physically centered revision2 goals, real occupied input/AI/projectiles, roof restore and zero saves. Controlled evidence, not human play or acceptance of all layouts.")
        records[label] = run_record(label, rules[label])
        records[label]["packet_classification"] = "native_revision2"
        captures[name] = capture(label, name, 2)
    for path in SCOPED_INPUTS + ASSET_PATHS:
        values = [records[label]["source_hashes"].get(path) for label in selected.values()]
        require(all(values) and len(set(values)) == 1, f"Final captures do not share recorded scoped input: {path}")
    for a, b in (("bed-small", "bed-normal"), ("fruit-small", "fruit-normal")):
        require(captures[a]["info"]["layout_sha256"] == captures[b]["info"]["layout_sha256"], f"Same household changed its deterministic layout across sizes: {a}/{b}")
    videos = dict(parse_mapping(value) for value in args.video)
    require(not set(videos)-set(FIXTURES), "Video destination has no final capture")
    media = {name:video_record(Path(videos.get(name, str(BASE / "videos" / (label+".mp4")))), captures[name]) for name,label in selected.items()}
    binding = finish_binding(records, captures, args.finish_commit)
    print(f"Validated {len(records)} recorded runs, 5 captures and 4 hash-bound encoded/clean-decoded videos. No raw fight PNGs selected.")
    if args.write: package(rules, records, captures, media, reward_records, binding)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise SystemExit(f"Domestic packet validation failed: {error}")
