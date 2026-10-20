#!/usr/bin/env python3
"""Curate explicit atmosphere evidence; default preflight is read-only.

No engine, Git, codec, pixel modification, or raw fight-frame traversal. All
eight reviewed capture labels must be supplied before --write is accepted.
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
OUT = ROOT / "docs/art/reference/2026-10-20-linux-theme-atmosphere"
START = "<!-- RECORDED_ATMOSPHERE_SUMMARY_START -->"
END = "<!-- RECORDED_ATMOSPHERE_SUMMARY_END -->"
SAFE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
PROFILE = "core/systems/world/atmosphere/ThemeAtmosphereProfiles.gd"
RUNTIME = (
    PROFILE, "core/systems/world/atmosphere/GameAtmosphereBinder.gd",
    "core/systems/world/atmosphere/WorldAtmosphere.gd",
    "core/systems/world/atmosphere/world_atmosphere.gdshader",
    "core/systems/world/atmosphere/ground_air.gdshader", "scenes/game.tscn",
)
SCOPED = RUNTIME + (
    "scenes/world/buildings/RoofOverlay.gd", "scenes/world/buildings/roof.gdshader",
    "scenes/world/buildings/CityBlockRoofForms.gd", "scenes/world/buildings/CityBlockKit.gd",
    "scenes/world/buildings/CityBlockFrontages.gd", "scenes/world/buildings/CityDomesticInterior.gd",
    "core/systems/world/ground/GroundSplatRenderer.gd", "core/systems/world/ground/ground_splat.gdshader",
    "core/systems/vision/VisionRig.gd", "scenes/hub/HubWorld.gd",
    "tools/dev/ThemeAtmospherePreview.gd", "tools/dev/ThemeAtmospherePreview.tscn",
    "tools/dev/theme_atmosphere_legacy.gdshader", "tools/dev/CityBlockPlayablePreview.gd",
    "tools/dev/AuthoredAtmospherePreview.gd", "tools/dev/AuthoredAtmospherePreview.tscn",
    "tools/tests/ThemeAtmosphereTest.gd", "tools/tests/ThemeAtmosphereReceiversTest.gd",
    "tools/tests/ThemeAtmosphereDryReceiverTest.gd",
)
FIXTURES = {
    "s2-small": (2, 16102026, "service_courtyards", (960, 540)),
    "s2-normal": (2, 16102026, "service_courtyards", (1280, 720)),
    "s3-small": (3, 1, "checkpoint_lanes", (960, 540)),
    "s3-normal": (3, 1, "checkpoint_lanes", (1280, 720)),
    "s7-small": (7, 4, "canal_services", (960, 540)),
    "s7-normal": (7, 4, "canal_services", (1280, 720)),
    "s7-reduced-fight": (7, 4, "canal_services", (960, 540)),
    "authored-contexts": (None, None, None, (960, 540)),
}
SEGMENTS = {
    "service_courtyards": "S2; S11+ fallback", "checkpoint_lanes": "S3",
    "collapsed_ward": "S4", "civilian_cutthrough": "S4", "inner_district_gate": "S5",
    "industrial_cutthrough": "S6", "ruined_services": "S6", "underpass_veins": "S7",
    "canal_services": "S7", "rail_yard": "S8", "military_staging": "S8",
    "outer_wall": "S9", "siege_services": "S9", "gate_district": "S10",
}
# Labels describe history, never imply success. Counts bind the retained footer.
RUNS = {
    "atmosphere-uid-baseline": ("clean_check", (1300, 0), "Prepared same-machine Linux class/UID/import-cache baseline; not a fresh-clone proof."),
    "atmosphere-uid-red": ("clean_feature_red", (0, 1), "Expected absent physical profile API."),
    "atmosphere-core-green": ("failed_runtime_attempt", (84, 0), "Invalid SubViewport.own_world_2d fixture and shutdown leaks despite exit0; not GREEN."),
    "atmosphere-core-green2": ("clean_check", (87, 0), "Repaired real World2D fixture; complete profile/reset/scoping assertions."),
    "atmosphere-native-green2": ("clean_check", (92, 0), "Native world-anchor, reduced motion and indoor control."),
    "atmosphere-receivers-red": ("clean_feature_red", (0, 1), "Expected absent physical ground/roof/shadow receiver API."),
    "atmo-receivers-green": ("clean_check", (20, 0), "Initial actual direct-light and wet/moss/stain receiver contract."),
    "atmo-receivers-native-green": ("failed_stain_probe", (25, 1), "Fixed cell centre was legitimately outside visible stain; no production eligibility relaxation."),
    "atmo-receivers-native-green2": ("clean_check", (26, 0), "225-pixel actual stain-on/off scan isolates visible stain contribution."),
    "atmo-core-receivers-headless": ("clean_check", (87, 0), "Core after physical receiver integration."),
    "atmo-core-receivers-native": ("failed_runtime_attempt", (91, 1), "Pure-wet host with unset stain uniform exposed float(null), followed by low-air assertion failure."),
    "atmo-default-headless-ThemeAtmosphereReceiversTest": ("clean_check", (29, 0), "Actual shader defaults and raw-null reset cases."),
    "atmo-default-headless-ThemeAtmosphereTest": ("clean_check", (87, 0), "Core after actual shader-default handling."),
    "atmo-default-native-ThemeAtmosphereReceiversTest": ("clean_check", (35, 0), "Native default/receiver/material reset controls."),
    "atmo-default-native-ThemeAtmosphereTest": ("clean_check", (92, 0), "Native core after shader-default handling."),
    "atmo-dry-guard-red": ("insufficient_probe", (6, 0), "False G0 term at .038 rounded below an 8-bit step. Passing footer did not demonstrate a valid RED."),
    "atmo-dry-guard-valid-red": ("clean_feature_red", (5, 1), "Allowed .06 diagnostic ceiling exposes invented G0 air at real noise peak; profile remains .038."),
    "atmo-final-dry-guard": ("clean_check", (6, 0), "Exact host stainG>.01 guard; real stained positive control retained."),
    "atmo-final-receivers": ("clean_check", (35, 0), "Final focused native physical receiver/default/scoping/reset check."),
    "atmo-final-core": ("clean_check", (92, 0), "Final focused native complete profile and render controls."),
    "atmo-s2-small": ("failed_pan_probe", None, "Actual Game roof restore completed, but boundary-floor pan probe selected row269 instead of270. Retained as failed diagnostic, not accepted final."),
}


def require(ok: bool, message: str) -> None:
    if not ok:
        raise ValueError(message)


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False).encode()


def save(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False) + "\n")


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as stream:
        header = stream.read(24)
    require(header[:8] == b"\x89PNG\r\n\x1a\n" and header[12:16] == b"IHDR", f"Not PNG: {path}")
    return struct.unpack(">II", header[16:24])


def vector(value: object) -> tuple[float, ...]:
    if isinstance(value, list):
        return tuple(float(v) for v in value)
    require(isinstance(value, str) and value.startswith("(") and value.endswith(")"), f"Not recorded vector: {value}")
    return tuple(float(v.strip()) for v in value[1:-1].split(","))


def split_top(text: str) -> list[str]:
    result, start, depth, quoted = [], 0, 0, False
    for index, char in enumerate(text):
        if char == '"': quoted = not quoted
        elif not quoted:
            if char == "(": depth += 1
            elif char == ")": depth -= 1
            elif char == "," and depth == 0:
                result.append(text[start:index].strip()); start = index + 1
    result.append(text[start:].strip())
    return result


def literal(text: str) -> object:
    text = text.strip()
    if text == "true": return True
    if text == "false": return False
    if text == "Color.WHITE": return [1.0] * 4
    if text == "Vector2.ZERO": return [0.0, 0.0]
    if text.startswith(('"', '&"')): return text.lstrip("&")[1:-1]
    match = re.fullmatch(r"(Color|Vector2)\(([^)]+)\)", text)
    if match:
        result = [float(v) for v in match[2].split(",")]
        if match[1] == "Color" and len(result) == 3: result.append(1.0)
        return result
    return float(text)


def catalogue(source_root: Path) -> dict:
    path = source_root / PROFILE
    source = path.read_text()
    body = source.split("static func _base(", 1)[1].split("return {", 1)[1].split("}", 1)[0]
    defaults = {}
    for item in split_top(body):
        key, value = item.split(":", 1)
        if value.strip() not in ("id", "context"): defaults[json.loads(key)] = literal(value)
    profiles = []
    branches = re.findall(r'(?ms)^\t\t&"([^"]+)":\n(.*?)(?=^\t\t(?:&"|_:))', source)
    require({name for name, _ in branches} == set(SEGMENTS), "Profile source no longer matches fourteen explicit physical families")
    for name, branch in branches:
        row = copy.deepcopy(defaults)
        for key, value in re.findall(r'profile\["([^"]+)"\] = ([^\n]+)', branch): row[key] = literal(value)
        row.update(id=name, context="procedural", segment_ownership=SEGMENTS[name])
        row["wind"] = [value / 15.0 for value in row["cloud_velocity"]]
        require(row["particle_kind"] == "none" and row["particle_density"] == row["vignette_strength"] == 0, "Unexpected particles/vignette in physical catalogue")
        profiles.append(row)
    return {"source": PROFILE, "source_sha256": digest(path), "method":"Literal source extraction, not a new engine evaluation or theme selection.",
            "profiles": profiles, "authored_contexts":{"institution":"Actual S1 Game: disabled, full reset; VisionRig retains its own indoor vignette.", "hub":"Actual Hub: no procedural binder/atmosphere; authored CanvasModulate/practicals."}}


def footer(label: str) -> dict | None:
    text = (BASE / label / "logs/stdout.log").read_text()
    matches = list(re.finditer(r"(?m)^([A-Za-z0-9_]+)(?:: (\d+) passed, (\d+) failed| passes=(\d+) failures=(\d+))", text))
    if not matches: return None
    m = matches[-1]
    return {"test":m[1], "passed":int(m[2] or m[4]), "failed":int(m[3] or m[5])}


def run_record(label: str, rule: tuple) -> dict:
    require(bool(SAFE.fullmatch(label)), f"Unsafe run label: {label}")
    record = load(BASE / label / "run-results.json")
    for name in ("stdout.log", "stderr.log", "engine.log"):
        require((BASE / label / "logs" / name).is_file(), f"Missing full log {label}/{name}")
    kind, counts, note = rule
    actual = footer(label)
    if counts is not None:
        require(actual is not None and (actual["passed"], actual["failed"]) == counts, f"Unexpected assertion footer {label}: {actual}")
    diagnostics = record["diagnostics"]
    if kind in ("clean_check", "insufficient_probe", "native_capture"):
        require(record["actual_exit"] == 0 and record["stop_reason"] == "completed" and not diagnostics, f"Not clean: {label}")
    elif kind == "failed_runtime_attempt":
        require(bool(diagnostics) and any("SCRIPT ERROR" in d for d in diagnostics), f"Historical runtime failure changed: {label}")
    else:
        require(record["actual_exit"] == 1 and record["stop_reason"] == "nonzero_exit" and bool(diagnostics), f"Historical assertion failure changed: {label}")
        require(all(d.startswith("ERROR: ") and "SCRIPT ERROR" not in d and "Parse Error" not in d for d in diagnostics), f"Unexpected non-assertion failure: {label}")
    return {"label":label, "classification":kind, "note":note, "footer":actual, "record":record}


def named_png(folder: Path, filename: str, size: tuple[int, int]) -> Path:
    require(not Path(filename).is_absolute() and ".." not in Path(filename).parts, f"Unsafe image name: {filename}")
    path = folder / filename
    require(png_size(path) == size, f"Wrong native image dimensions: {path}")
    return path


def capture(name: str, label: str, weather_samples: bool) -> dict:
    segment, seed, theme, size = FIXTURES[name]
    folder = BASE / (label + "-plates")
    if name == "authored-contexts": return authored(label, folder, size)
    info = load(folder / "atmosphere-info.json")
    require(info["failures"] == 0 and info["scene"] == "res://scenes/game.tscn" and info["tool"] == "res://tools/dev/ThemeAtmospherePreview.tscn", f"Wrong/failed actual Game capture: {label}")
    parents = [file for file in ("entry-info.json", "still-info.json", "capture-info.json") if (folder / file).is_file()]
    require(len(parents) == 1, f"Expected one real parent metadata file: {label}")
    parent_name, parent = parents[0], load(folder / parents[0])
    require(parent["failures"] == 0 and parent["save_writes"] == 0, f"Parent fixture failed/wrote save: {label}")
    require(parent.get("attempt_seed", parent.get("seed")) == seed and parent["segment"] == segment and parent.get("district_family", parent.get("theme")) == theme, f"Wrong actual parent identity: {label}")
    if name.startswith("s2-"): require(parent["building_id"] == 944996572 and vector(parent["coord"]) == (0, 3), f"Wrong S2 home: {label}")
    if name.startswith("s3-"): require(parent["building_id"] == 1517657286 and vector(parent["coord"]) == (2, -5), f"Wrong S3 checkpoint: {label}")
    if name.startswith("s7-"):
        require(parent["ground_review"] and parent["ground_context_world_px"] == [-2016.0, 96.0], f"Wrong real S7 ground: {label}")
        require(parent["reduced_motion"] == (name == "s7-reduced-fight"), f"Reduced Motion mismatch: {label}")
    files = [folder / "atmosphere-info.json", folder / parent_name]
    require(info["plates"], f"No actual paired stills: {label}")
    for plate in info["plates"]:
        require(plate["actual_theme"] == theme and plate["seed"] == seed and plate["segment"] == segment, f"Paired actual theme differs: {label}")
        require(plate["rng_unchanged_during_pair"] and plate["save_writes_during_pair"] == 0, f"Pair changed run RNG/save: {label}")
        diagnostic = plate["profile"]; profile = diagnostic["profile"]
        require(profile["id"] == theme and profile["context"] == "procedural" and profile["enabled"], f"Wrong applied physical profile: {label}")
        require(diagnostic["particle_count"] == 0 and diagnostic["vignette_strength"] == 0 and diagnostic["air_z"] == -8, f"Unexpected overlay ownership: {label}")
        require(diagnostic["reduced_motion"] == (name == "s7-reduced-fight"), f"Wrong actual accessibility state: {label}")
        probe = plate["world_anchor_probe"]
        require(probe["delta"] <= probe["tolerance"] == .012 and probe.get("selection") == "initial rendered texel centre through inverse canvas transform", f"Missing corrected actual world-anchor probe: {label}")
        require(all(abs(v) < .01 for k in ("first_centre_residual", "moved_centre_residual") for v in probe[k]), f"Pan sample was not the corresponding texel centre: {label}")
        for suffix in ("profile", "legacy-daylight", "profile-pan"):
            files.append(named_png(folder, plate["plate"] + "-" + suffix + ".png", size))
        if "weather_frames" in plate:
            require(name == "s7-normal" and plate["weather_frames"] == 25 and plate["weather_frame_step_seconds"] == .125, f"Unexpected weather-only diagnostic cadence: {label}")
            if weather_samples:
                for index in range(25): files.append(named_png(folder, "weather-%s/frame-%03d.png" % (plate["plate"], index), size))
    if name == "s2-small":
        require(parent["native_entry_only"] and parent["inside_alpha"] <= .01 and parent["outside_alpha"] >= .99, f"No actual entry/restore: {label}")
        plates = {p["plate"]:p for p in info["plates"]}
        require(plates["interior"]["roof_inside_count"] > 0 and plates["restored-exterior"]["roof_inside_count"] == 0, f"No actual indoor-volume transition: {label}")
    if name == "s7-reduced-fight":
        require(parent["occupied_comparison"] and parent["captured_frames"] == len(parent["frames"]) > 1 and parent["weapon_fires"] > 0 and parent["hits"] > 0 and parent["max_projectiles"] > 0, f"No actual reduced-motion occupied combat: {label}")
    return {"name":name,"label":label,"folder":folder,"info":info,"parent":parent,"parent_name":parent_name,"size":size,"files":files}


def authored(label: str, folder: Path, size: tuple[int, int]) -> dict:
    path = folder / "authored-atmosphere-info.json"; info = load(path)
    require(info["tool"] == "res://tools/dev/AuthoredAtmospherePreview.tscn" and info["passes"] == 13 and info["failures"] == info["save_writes"] == 0, f"Authored context fixture failed: {label}")
    contexts = {row["context"]:row for row in info["contexts"]}
    require(set(contexts) == {"institution", "authored_hub"}, "Missing actual authored space")
    s1, hub = contexts["institution"], contexts["authored_hub"]
    require(s1["actual_segment"] == 1 and s1["level_owner"]["script"].endswith("/Level1Builder.gd"), "S1 is not actual authored Game")
    require(len(s1["atmosphere_nodes"]["atmospheres"]) == len(s1["atmosphere_nodes"]["binders"]) == 1 and not s1["atmosphere_owner"]["visible_in_tree"], "S1 atmosphere owner/context changed")
    require(s1["atmosphere"]["profile"]["context"] == "institution" and s1["atmosphere"]["profile"]["enabled"] is False, "S1 physical profiles not bypassed")
    vision = s1["vision"]
    require(all(vision[k] for k in ("same_scene_shader","owns_material_copy","rite_signal_connected","actual_indoors","lightweight","vignette_visible")) and vision["owner"]["processing"] and abs(vision["strength"] - .22) < .00001 and not vision["fog_visible"], "Actual VisionRig ownership/indoor state changed")
    require(hub["actual_segment"] == 3 and hub["completed_segment_fixture"] == 2 and hub["station_count"] == 6, "Wrong actual Hub arrival")
    require(not hub["atmosphere_nodes"]["atmospheres"] and not hub["atmosphere_nodes"]["binders"] and len(hub["canvas_modulates"]) == 1, "Hub has procedural/stale atmosphere owner")
    require(all(abs(a-b) < .00001 for a,b in zip(hub["canvas_modulates"][0]["color"], [.58,.54,.62,1])), "Authored Hub dusk changed")
    lights = [p for p in hub["practical_lights"] if p["centre_in_view"] and p["enabled"] and p["energy"] > 0 and p["texture_present"]]
    require(len(lights) == hub["visible_light_centres"] > 0, "No actual authored practical light centres in view")
    files = [path] + [named_png(folder, row["screenshot"]["file"], size) for row in info["contexts"]]
    return {"name":"authored-contexts","label":label,"folder":folder,"info":info,"parent":info,"parent_name":path.name,"size":size,"files":files}


def video_record(path: Path, captured: dict) -> dict:
    path = path.resolve()
    encoding_path, decode_path = path.with_suffix(".encoding.json"), path.with_suffix(".decode.json")
    encoding, decoded = load(encoding_path), load(decode_path); parent = captured["parent"]
    require(digest(path) == encoding["video_sha256"] and digest(captured["folder"] / captured["parent_name"]) == encoding["source_metadata_sha256"], "Occupied video/source digest differs")
    require(encoding["dimensions"] == list(captured["size"]) and encoding["source_frame_count"] == parent["captured_frames"] == len(encoding["images"]), "Occupied frame/dimension count differs")
    require(abs(encoding["timing"]["combat_wall_seconds"] - parent["wall_seconds"]) < .000001, "Video duration differs from actual measured interval")
    require(all(abs(a["wall_time"] - b["wall_time"]) < .000001 for a,b in zip(encoding["images"], parent["frames"])), "Video timestamps differ from real recording")
    require(decoded["exit"] == 0 and not decoded.get("stderr", "").strip(), "Existing video does not have clean full decode")
    decoded_video = Path(decoded["video"])
    if not decoded_video.is_absolute(): decoded_video = ROOT / decoded_video
    require(decoded_video.resolve() == path, "Decode sidecar names another video")
    files = [path, encoding_path, decode_path]
    concat = path.with_suffix(".ffconcat")
    if concat.is_file():
        require(digest(concat) == encoding["concat_sha256"], "Historical concat digest differs"); files.append(concat)
    return {"files":files,"encoding":encoding,"decode":decoded}


def mapping(text: str) -> tuple[str, str]:
    require("=" in text, f"Expected DESTINATION=RUN_LABEL: {text}")
    name, label = text.split("=", 1)
    require(name in FIXTURES and bool(SAFE.fullmatch(label)), f"Unknown/unsafe capture: {text}")
    return name, label


def sources_binding(records: dict, captures: dict, source_root: Path) -> dict:
    result = {}
    for path in SCOPED:
        values = {name:records[c["label"]]["record"]["source_hashes"].get(path) for name,c in captures.items()}
        # The authored run loaded before the bounded pixel-centre correction;
        # it does not instantiate the procedural ThemeAtmospherePreview tool.
        comparable = {name:value for name,value in values.items() if not (name == "authored-contexts" and path == "tools/dev/ThemeAtmospherePreview.gd")}
        require(all(comparable.values()) and len(set(comparable.values())) <= 1, f"Final scoped snapshots differ: {path}")
        require(all(v == digest(source_root / path) for v in comparable.values()), f"Final scoped input differs from supplied current source root: {path}")
        result[path] = {"current_sha256":digest(source_root / path) if (source_root / path).is_file() else None,"final_captures":values}
    return {"source_root":str(source_root),"note":"Earlier focused histories retain their own exact snapshots; not relabeled integrated-main regressions. Authored capture precedes the procedural preview's bounded texel-centre correction; that unused procedural tool hash remains recorded separately.","inputs":result}


def summary(records: dict, captures: dict, media: dict, weather_samples: bool) -> str:
    lines = [START, "", "Counts below are read from retained monitor results/assertion footers.", "", "| Final focused native check | Passed / failed |", "| --- | --- |"]
    for label in ("atmo-final-dry-guard", "atmo-final-receivers", "atmo-final-core"):
        f = records[label]["footer"]; lines.append(f"| {f['test']} | {f['passed']} / {f['failed']} |")
    lines += ["", "All eight explicitly selected actual-Game/authored runs have exit0, no monitor diagnostics, zero fixture failures and zero saves.", "", "| Native sample | Run label | PNG size |", "| --- | --- | --- |"]
    for name, c in captures.items():
        png = next(p for p in c["files"] if p.suffix == ".png")
        lines.append(f"| [{name}]({name}/{png.relative_to(c['folder']).as_posix()}) | {c['label']} | {c['size'][0]}×{c['size'][1]} |")
    lines += ["", "Fourteen physical profiles are data/test coverage. Native district art samples are only S2 service courtyards, S3 checkpoint lanes and S7 canal services, plus the separately authored S1 and Hub controls.", "", "Weather-only diagnostic PNGs are " + ("retained explicitly at8samples/second; actors/Game remain paused." if weather_samples else "not bundled; their counts remain in the unaltered metadata."), "", END]
    parent = captures["s7-reduced-fight"]["parent"]
    lines[-1:-1] = [f"The [Reduced Motion occupied video](s7-reduced-fight/{media['files'][0].name}) uses {parent['captured_frames']} captured frames over {parent['wall_seconds']:.3f} measured wall seconds, with {parent['weapon_fires']} real weapon fires, {parent['hits']} hits and {parent['max_projectiles']} maximum active projectiles. Inspection pauses remain disclosed; full decode is clean.", ""]
    return "\n".join(lines)


def package(records: dict, captures: dict, profiles: dict, binding: dict, media: dict, weather_samples: bool) -> None:
    copies, generated = {}, {}
    def retain(path: Path, destination: str) -> None:
        require(path.is_file() and destination not in copies and destination not in generated, f"Missing/duplicate artifact: {destination}")
        copies[destination] = path
    process = []
    for label, item in records.items():
        original = item["record"]; record = copy.deepcopy(original)
        source = {"source_hashes":record.pop("source_hashes"),"source_untracked":record.pop("source_untracked", [])}
        source_id = hashlib.sha256(canonical(source)).hexdigest()
        source_path = f"process/sources/{source_id}.json"; generated[source_path] = source
        record.pop("git_status_porcelain", None)
        record.update(original_run_results_sha256=digest(BASE / label / "run-results.json"),source_record=source_path,packet_classification=item["classification"],packet_note=item["note"])
        generated[f"process/{label}/run-results.json"] = record
        for filename in ("stdout.log","stderr.log","engine.log"): retain(BASE / label / "logs" / filename, f"process/{label}/logs/{filename}")
        process.append({"label":label,"classification":item["classification"],"note":item["note"],"assertions":item["footer"],"actual_exit":original["actual_exit"],"stop_reason":original["stop_reason"],"diagnostics":original["diagnostics"]})
    for name, c in captures.items():
        for path in c["files"]: retain(path, name + "/" + path.relative_to(c["folder"]).as_posix())
    # Preserve failed pan source/metadata and its exact misleading pixel pair;
    # retain no raw fight frames or unbounded directory copies.
    failed = BASE / "atmo-s2-small-plates"
    for filename in ("atmosphere-info.json","entry-info.json","restored-exterior-profile.png","restored-exterior-profile-pan.png"):
        retain(failed / filename, "diagnostics/failed-boundary-pan/" + filename)
    for path in media["files"]: retain(path, "s7-reduced-fight/" + path.name)
    retain(Path(__file__).resolve(), "process/package-atmosphere.py")
    generated.update({"profile-catalogue.json":profiles,"process/summary.json":process,"process/scoped-inputs.json":binding,
        "capture-catalogue.json":{name:{"run_label":c["label"],"original_folder":str(c["folder"]),"files":[p.relative_to(c["folder"]).as_posix() for p in c["files"]]} for name,c in captures.items()}})
    expected = set(copies) | set(generated) | {"README.md", ".gdignore", "evidence-index.json"}
    existing = {p.relative_to(OUT).as_posix() for p in OUT.rglob("*") if p.is_file()}
    require(not existing - expected, f"Unexpected existing packet files: {sorted(existing - expected)}")
    text = (OUT / "README.md").read_text(); before, tail = text.split(START); _, after = tail.split(END)
    for relative, source in copies.items():
        target = OUT / relative; target.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(source, target)
        require(digest(source) == digest(target), f"Copy digest differs: {relative}")
    for relative, value in generated.items(): save(OUT / relative, value)
    (OUT / ".gdignore").touch()
    (OUT / "README.md").write_text(before + summary(records, captures, media, weather_samples) + after)
    save(OUT / "evidence-index.json", [{"file":p.relative_to(OUT).as_posix(),"sha256":digest(p),"bytes":p.stat().st_size} for p in sorted(OUT.rglob("*")) if p.is_file() and p.name != "evidence-index.json"])
    print(f"Packaged {len(records)} monitored histories, eight native samples, and existing encoded/decoded occupied video. No raw fight frames.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture", action="append", default=[], metavar="DESTINATION=RUN_LABEL", help="Eight explicit final mappings; omitted destinations remain pending.")
    parser.add_argument("--source-root", type=Path, default=ROOT, help="Exact final source checkout; default main.")
    parser.add_argument("--video", type=Path, help="Existing S7 Reduced Motion occupied.mp4 plus encoding/decode sidecars.")
    parser.add_argument("--include-weather-samples", action="store_true", help="Retain explicit25 weather-only diagnostic PNGs per declared still; no fight-frame reads.")
    parser.add_argument("--write", action="store_true", help="Write only after all eight finals/video validate; default never writes.")
    args = parser.parse_args(); source_root = args.source_root.resolve()
    rules = dict(RUNS); records = {label:run_record(label, rule) for label,rule in rules.items()}
    profiles = catalogue(source_root)
    selected_pairs = [mapping(text) for text in args.capture]; selected = dict(selected_pairs)
    require(len(selected) == len(selected_pairs) and len(set(selected.values())) == len(selected), "Duplicate final destination/run label")
    captures = {}
    for name, label in selected.items():
        require(label not in records, f"Final label is a known historical attempt: {label}")
        records[label] = run_record(label, ("native_capture", (13,0) if name == "authored-contexts" else None, "Explicit root-selected actual native final; controlled fixture qualifications retained."))
        captures[name] = capture(name, label, args.include_weather_samples)
    binding = sources_binding(records, captures, source_root)
    readme = (OUT / "README.md").read_text()
    require(readme.count(START) == readme.count(END) == 1, "README needs one generated summary block")
    pending = sorted(set(FIXTURES) - set(selected)); media = None
    if "s7-reduced-fight" in captures:
        path = args.video or BASE / "videos" / (selected["s7-reduced-fight"] + ".mp4")
        if path.is_file(): media = video_record(path, captures["s7-reduced-fight"])
        else: pending.append("s7-reduced-fight encoded/decoded video")
    elif args.video: require(False, "Video needs the explicit Reduced Motion capture mapping")
    print(f"Validated {len(RUNS)} explicit process records, fourteen source profiles and {len(captures)} selected native captures. No files written.")
    if pending:
        print("PENDING: " + ", ".join(pending))
        require(not args.write, "Cannot write a passing packet with pending actual results")
        return 2
    require(media is not None, "Missing reviewed occupied media")
    print("All eight selected samples/media/source bindings validate; this is a packet preflight, not human visual acceptance.")
    if args.write: package(records, captures, profiles, binding, media, args.include_weather_samples)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise SystemExit(f"Atmosphere packet validation failed: {error}")
