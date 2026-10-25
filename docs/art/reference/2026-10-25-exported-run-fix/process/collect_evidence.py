#!/usr/bin/env python3
"""Collect the finite menu25 proof packet AFTER root declares the engine idle.

Preparation only until invoked. No engines, Git, build tools or image editing.
Usage: python3 collect_evidence.py --bindings /absolute/final-bindings.json

Bindings JSON (paths absolute):
  engine_queue_idle: true
  source_checkpoint: FINAL_COMMIT
  sources_fixed: {PROJECT_RELATIVE_SOURCE_OR_TEST: SHA, ...}
  readme: PATH (the finished root-written README.md)
  baseline_files: {"autoload/global.gd": PATH,
                   "core/systems/major_choice/MajorChoiceDB.gd": PATH}
  new_inspection: PATH (same schema as old-playtest-pack-inspection.json)
  build_manifest: PATH (must contain the new artifact SHA256)
  historical_inspections: [PATH_TO_FAILED_R2_INSPECTION, ...]
  artifact_observations: [{"phase": ACTUAL_PHASE_TEXT, "observed_utc": TIME,
                          "sha256": SHA},
                         {same fields, role="native-before"},
                         {same fields, role="native-after"}]
    Phase/time describe actual observations, NEVER a reconstructed pre-launch pin.
  cases: [{"label": LABEL, "classification": "accepted" | "expected_red" |
           "intermediate_failure" | "diagnostic", "role": "export" | "functional" |
           "native" | "focused" | "historical", "artifact_sha256": SHA_OR_NULL,
           "script_pin": {"path": PATH, "sha256": SHA},
           "expected": {"actual_exit": N, "runner_exit": N,
             "stop_reason": TEXT, "guard_reason": TEXT,
             "guard_wrapper_exit": N, "guard_received_signal": N_OR_NULL,
             "diagnostics_sha256": SHA_OF_COMPACT_JSON_ARRAY},
           "summary": [TEST_NAME, PASSED, FAILED], "source_pins": {RELATIVE: SHA}}]
    source_pins defaults to final pins for accepted cases, initial checkpoint
    pins for intermediate/diagnostic cases, and original pins for expected_red.
    summary/script_pin are optional where the run has neither. Every terminal
    outcome is checked against its explicit expected fields, including stops.
  preparation_case_labels: [ACTUAL_PREPARATION_CANCELLATION_TEST_LABEL, ...]
  native_wrapper: {"path": PATH, "sha256": SHA} (pin recorded before native run)
  originals: {"base-populated.png": PATH, "augment-three-cards.png": PATH}
  reviews: {"root": PATH, "independent": PATH}
Each review JSON must have accepted=true, artifact_sha256=FINAL_EXE_SHA,
run_label=the accepted native label, and originals={both filenames: SHA}.

Optional paths: project (default /var/tmp/sa-menu25), output (default
PROJECT/docs/art/reference/2026-10-25-exported-run-fix), and extra_metadata
(finite list of paths for any additional source-pin/queue/artifact receipts).
The collector copies its bindings and complete reviews; it does not create
review decisions or infer missing test results. Existing output is refused.
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
GUARDS = REPO / ".superpowers/continuation-20261022"
RUNS = REPO / ".superpowers/claude-city-20261021/runs"
BASE = "6bdd4cc0bdb9a3a85fae068cd84c0e9ef65fac11"
BASE_PROJECT = "46713b6ec35b5e2bbeb460c2bfd99e096499518cb8cc0d135ca8e9b2665b2f79"
BASE_PRESETS = "834ea03606d73a6fcc7320154170fbf08b5811723dabb02af8ab3c66c2e08391"
FROZEN = "21b0e0aff690ef81d2e271ef36fe8389144842e495bcfc36077b7e7b5ebd3892"
OLD_EXE = "e314d407876adef7e749168773b3c2806d96d0ed9d7860c88b2da55da4abc310"
CHANGED = ["autoload/global.gd", "core/systems/major_choice/MajorChoiceDB.gd",
           "tools/tests/FrontEndFlowTest.gd", "tools/tests/PackedFrontEndFlowTest.gd"]
HISTORICAL_LABELS = {"menu25-packed-red-r1", "menu25-frontend-source-r1",
    "menu25-binding-source-r1", "menu25-offer-source-r1", "menu25-doctrine-source-r1",
    "menu25-export-fixed-r1", "menu25-packed-green-r1",
    "menu25-packed-load-diagnostic-r1", "menu25-packed-script-warm-diagnostic-r1",
    "menu25-export-fixed-r2", "menu25-packed-green-r2",
    "menu25-packed-progress-diagnostic-r2", "menu25-packed-scene-sync-diagnostic-r1",
    "menu25-export-fixed-r3", "menu25-packed-green-r3", "menu25-script-graph-diagnostic-r1",
    "menu25-preparation-menu-r4"}
RED_DIAGNOSTICS = [
    "ERROR: FAIL: race_db contains the authored IDs; actual=[]",
    "ERROR: FAIL: style_db contains the authored IDs; actual=[]",
    "ERROR: FAIL: augment_db contains the authored IDs; actual=[]",
    "ERROR: FAIL: spell_db is nonempty (count=0)",
    "ERROR: FAIL: weapon_db is nonempty (count=0)",
    "ERROR: FAIL: item_db is nonempty (count=0)",
    "ERROR: FAIL: set_db is nonempty (count=0)",
    "ERROR: FAIL: major-choice catalog is nonempty",
    "ERROR: FAIL: packed New Chronicle shows four ancestry choices",
    "ERROR: FAIL: packed New Chronicle shows three path choices",
    "ERROR: FAIL: a named vessel can Begin in the exported game",
    "ERROR: FAIL: nondefault Elf and Magic choices exist",
]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def main(bindings_path: Path) -> None:
    bindings = load(bindings_path)
    require(bindings.get("engine_queue_idle") is True, "root has not declared engine queue idle")
    project = Path(bindings.get("project", "/var/tmp/sa-menu25")).resolve()
    output = Path(bindings.get("output", project / "docs/art/reference/2026-10-25-exported-run-fix")).resolve()
    require(not output.exists(), "output already exists; preserve it and choose a fresh destination")
    execution = load(WORK / "execution.json")
    require(execution["base"] == BASE, "unexpected baseline")
    checkpoint = bindings["source_checkpoint"]
    require(re.fullmatch(r"[0-9a-f]{40}", checkpoint) is not None, "final checkpoint must be a full commit ID")
    fixed = bindings["sources_fixed"]
    require(set(CHANGED + ["project.godot", "export_presets.cfg", "assets/vfx/ui/AugmentFlyVfx.gd", "tools/tests/PreparationCancellationTest.gd"]) <= set(fixed), "final source pins omit changed files/export/headless/preparation controls")
    require(fixed["project.godot"] == BASE_PROJECT, "final project.godot differs from exact 6bdd baseline")
    require(fixed["export_presets.cfg"] == BASE_PRESETS, "final export presets differ from exact 6bdd baseline")
    require(fixed["tools/tests/PackedFrontEndFlowTest.gd"] == FROZEN, "frozen functional-test pin changed")

    # Validate and buffer the finite source list before creating any packet file.
    pending: dict[str, tuple[Path, bytes, bool]] = {}

    def add(source: Path, destination: str, compress: bool = False) -> bytes:
        source = source.resolve()
        relative = Path(destination)
        require(not relative.is_absolute() and ".." not in relative.parts, "unsafe packet destination")
        require(destination not in pending, "duplicate packet destination: " + destination)
        require(source.suffix.lower() not in {".exe", ".pck", ".zip"}, "binary artifacts are referenced, not copied")
        data = source.read_bytes()
        pending[destination] = (source, data, compress)
        return data

    for relative in fixed:
        data = add(project / relative, "source/fixed/" + relative)
        require(sha(data) == fixed[relative], "fixed source changed: " + relative)
    for relative in CHANGED[:2]:
        data = add(Path(bindings["baseline_files"][relative]), "source/baseline/" + relative)
        require(sha(data) == execution["sources_before"][relative], "baseline body mismatch: " + relative)
    add(project / "docs/superpowers/plans/2026-10-25-exported-run-discovery.md", "source/plan.md")
    add(Path(bindings["readme"]), "README.md")
    add(bindings_path, "process/final-bindings.json")
    for name in ["execution.json", "checks-r1.json", "execution-r3.json", "checks-r3.json", "execution-r4.json", "inspect_embedded_pack.py", "old-playtest-pack-inspection.json"]:
        add(WORK / name, "process/" + name)
    add(Path(__file__), "process/collect_evidence.py")
    for index, path in enumerate(bindings.get("extra_metadata", [])):
        source = Path(path)
        add(source, "process/extra/%02d-%s" % (index, source.name))
    for name in ["failed-r1-new-playtest-pack-inspection.json", "failed-r1-scene-dependencies.json", "artifact-first-observation.json", "load-diagnostic-stop.json", "script-warm-diagnostic-stop.json", "progress-diagnostic-stop.json", "r3-stop.json", "execution-r2.json", "checks-r2.json", "PackedLoadDiagnostic.gd", "PackedScriptWarmDiagnostic.gd", "PackedProgressDiagnostic.gd", "PackedSceneSyncDiagnostic.gd", "PackedScriptGraphDiagnostic.gd"]:
        add(WORK / name, "process/intermediate/" + name)
    historical_inspections = []
    for index, path in enumerate(bindings["historical_inspections"]):
        source = Path(path)
        historical_inspections.append(json.loads(add(source, "process/intermediate/inspection-%02d-%s" % (index, source.name))))
    require(any("playtest-20261025-r2" in row["build"]["path"] for row in historical_inspections), "failed r2 artifact inspection must be retained")

    old = load(WORK / "old-playtest-pack-inspection.json")
    new_path = Path(bindings["new_inspection"])
    new = json.loads(add(new_path, "process/new-playtest-pack-inspection.json"))
    require(old["build"]["sha256"] == OLD_EXE, "old inspection pin mismatch")
    new_sha = new["build"]["sha256"]
    require(new_sha != OLD_EXE, "new inspection references the old build")
    for inspection in [old, new]:
        artifact = Path(inspection["build"]["path"])
        before = artifact.stat()
        require(before.st_size == inspection["build"]["bytes"], "artifact size mismatch")
        require(before.st_mtime_ns == inspection["build"]["mtime_ns"], "artifact timestamp changed")
        require(file_sha(artifact) == inspection["build"]["sha256"], "artifact bytes changed")
        after = artifact.stat()
        require((before.st_size, before.st_mtime_ns, before.st_ino) == (after.st_size, after.st_mtime_ns, after.st_ino), "artifact changed during collection")
        for db, count in [("race_db", 4), ("style_db", 3), ("augment_db", 16)]:
            group = inspection["databases"][db]
            require(group["physical_remap_count"] == count and not group["raw_tres_res_paths"], "unexpected binary-remap catalogue: " + db)
            require(all(row["target_present"] and row["remap_payload"]["stored_md5_verified"] and row["target_payload"]["stored_md5_verified"] for row in group["remaps"]), "unverified remap target")
    manifest_text = add(Path(bindings["build_manifest"]), "process/build-manifest.json").decode()
    require(new_sha in manifest_text, "build manifest does not bind the new EXE")
    observations = bindings["artifact_observations"]
    require(all(row.get("observed_utc") and row.get("sha256") == new_sha for row in observations), "artifact observation lacks time or has different bytes")
    roles = {row.get("role") for row in observations}
    require(all(row.get("phase") for row in observations) and {"native-before", "native-after"} <= roles, "missing actual native artifact observation roles/phases")
    wrapper_pin = bindings["native_wrapper"]
    native_wrapper = Path(wrapper_pin["path"]).resolve()
    native_source = add(native_wrapper, "process/PackedNativeProof.gd")
    require(sha(native_source) == wrapper_pin["sha256"], "native wrapper changed from launch pin")
    require(native_source.decode().splitlines()[0] == 'extends "' + str(project / CHANGED[3]) + '"', "native wrapper does not inherit frozen functional test")

    cases = bindings["cases"]
    labels = [case["label"] for case in cases]
    require(len(labels) == len(set(labels)) and HISTORICAL_LABELS <= set(labels), "missing/duplicate finite historical cases")
    accepted = [case for case in cases if case["classification"] == "accepted"]
    preparation_labels = bindings["preparation_case_labels"]
    require(preparation_labels and set(preparation_labels) <= {case["label"] for case in accepted}, "actual clean preparation/cancellation cases are missing")
    require({"menu25-preparation-menu-r4b", "menu25-preparation-terminal-r4b"} <= set(preparation_labels), "both corrected preparation cancellation cases must be retained")
    require({"menu25-frontend-source-r4", "menu25-interruption-source-r4"} <= set(labels), "source r4 flow/interruption evidence is missing")
    for role in ["export", "functional", "native"]:
        require(sum(case["role"] == role for case in accepted) == 1, "one final accepted " + role + " case is required")
    native_label = next(case["label"] for case in accepted if case["role"] == "native")
    failed_r1_sha = load(WORK / "failed-r1-new-playtest-pack-inspection.json")["build"]["sha256"]
    known_artifacts = {OLD_EXE, failed_r1_sha, new_sha} | {row["build"]["sha256"] for row in historical_inspections}
    outcomes = []
    for case in cases:
        label = case["label"]
        classification = case["classification"]
        require(classification in {"accepted", "expected_red", "intermediate_failure", "diagnostic"}, "unknown outcome classification")
        require(re.fullmatch(r"menu25-[a-z0-9-]+", label) is not None, "unsafe run label")
        if label == "menu25-packed-red-r1":
            require(classification == "expected_red", "original RED must remain expected_red")
        if label in {"menu25-packed-green-r1", "menu25-packed-green-r2"}:
            require(classification == "intermediate_failure", "failed r1/r2 must remain intermediate failures")
        if "diagnostic" in label:
            require(classification == "diagnostic", "diagnostic attempts cannot become acceptance runs")
        if label == "menu25-preparation-menu-r4":
            require(classification == "diagnostic" and "tools/tests/PreparationCancellationTest.gd" in case.get("source_pins", {}), "first preparation harness diagnostic needs its actual original draft pin")
        expected = case["expected"]
        run = Path(case.get("run_root", RUNS / (label + "-1")))
        raw = json.loads(add(run / "run-results.json", "runs/" + label + "/run-results.json.gz", True))
        guard = json.loads(add(GUARDS / (label + "-thermal.json"), "runs/" + label + "/guard.json"))
        wrapper = add(GUARDS / (label + "-wrapper.log"), "runs/" + label + "/wrapper.log").decode()
        launcher = json.loads(add(Path(str(run) + ".launcher.json"), "runs/" + label + "/launcher.json"))
        interrupted_diagnostic = classification == "diagnostic" and guard["reason"] == "external_sigint"
        # A guard interrupted before its final print can leave a genuine empty
        # wrapper log. Keep those bytes; launcher/raw/guard remain authoritative.
        wrapper_summary = None if interrupted_diagnostic else json.JSONDecoder().raw_decode(wrapper.lstrip())[0]
        logs = {}
        for name in ["stdout.log", "stderr.log", "engine.log"]:
            logs[name] = add(run / "logs" / name, "runs/" + label + "/logs/" + name)
        is_red = label == "menu25-packed-red-r1"
        diagnostics = raw["diagnostics"]
        require(raw["ended_utc"] and raw["actual_exit"] == expected["actual_exit"] and raw["runner_exit"] == expected["runner_exit"], "nonterminal or wrong actual result: " + label)
        require(raw["stop_reason"] == expected["stop_reason"] and not raw["other_godot_pids"], "wrong termination/foreign engine: " + label)
        require(sha(json.dumps(diagnostics, separators=(",", ":")).encode()) == expected["diagnostics_sha256"], "diagnostics changed from classified observation: " + label)
        require(guard["reason"] == expected["guard_reason"] and guard["received_signal"] == expected["guard_received_signal"] and guard["wrapper_exit"] == expected["guard_wrapper_exit"], "guard result changed from classified observation: " + label)
        if is_red:
            require(raw["actual_exit"] == 1 and diagnostics == RED_DIAGNOSTICS and guard["reason"] == "completed", "original RED differs from its exact expected assertions")
        if classification == "accepted":
            require(raw["actual_exit"] == raw["runner_exit"] == 0 and raw["stop_reason"] == "completed" and diagnostics == [] and guard["reason"] == "completed" and guard["received_signal"] is None and guard["wrapper_exit"] == 0, "accepted case is not clean: " + label)
        if classification == "intermediate_failure":
            require(raw["actual_exit"] != 0 or bool(diagnostics), "intermediate failure has no actual failure")
        if wrapper_summary is not None:
            require(wrapper_summary["actual_exit"] == raw["actual_exit"] and wrapper_summary["diagnostic_count"] == len(diagnostics), "wrapper result disagrees: " + label)
            require(Path(wrapper_summary["run_root"]).resolve() == run.resolve(), "wrapper identifies another run")
        require(launcher["command"] == raw["command"] and launcher["actual_exit"] == raw["actual_exit"], "launcher result disagrees")
        default_pins = execution["sources_before"] if is_red else execution["sources_fixed"] if label in HISTORICAL_LABELS else fixed
        if label in {"menu25-frontend-source-r4", "menu25-interruption-source-r4"}:
            # These passed before the corrected cancellation fixture existed;
            # retain the runtime controls without inventing a later test pin.
            default_pins = {relative: value for relative, value in fixed.items() if relative != "tools/tests/PreparationCancellationTest.gd"}
        pins = case.get("source_pins", default_pins)
        require(all(raw["source_hashes"].get(relative) == digest for relative, digest in pins.items()), "actual source provenance mismatch: " + label)
        if "--main-pack" in raw["command"]:
            actual_pack = raw["command"][raw["command"].index("--main-pack") + 1]
            # Interrupted historical experiments may have only an actual command,
            # not a contemporaneous artifact hash. Preserve that honest gap.
            if case.get("artifact_sha256") is not None:
                require(case["artifact_sha256"] in known_artifacts, "packed run references an unbound artifact hash")
            if is_red:
                require(case.get("artifact_sha256") == OLD_EXE and Path(actual_pack).resolve() == Path(old["build"]["path"]).resolve(), "original RED identifies another artifact")
            if classification == "accepted":
                require(case["artifact_sha256"] == new_sha and Path(actual_pack).resolve() == Path(new["build"]["path"]).resolve(), "accepted run used another package")
        if is_red or case["role"] in {"functional", "native"}:
            require("--main-pack" in raw["command"] and "--script" in raw["command"], "packed case was not a package test")
            test_path = raw["command"][raw["command"].index("--script") + 1]
            wanted_script = native_wrapper if case["role"] == "native" else project / CHANGED[3]
            require(Path(test_path).resolve() == wanted_script.resolve(), "another packed test script was used")
        if "script_pin" in case:
            script_pin = case["script_pin"]
            script_path = Path(script_pin["path"]).resolve()
            require("--script" in raw["command"] and Path(raw["command"][raw["command"].index("--script") + 1]).resolve() == script_path, "script pin identifies another invocation")
            require(sha(add(script_path, "process/run-scripts/" + label + "/" + script_path.name)) == script_pin["sha256"], "external script changed from observation pin")
        summary = None
        if "summary" in case:
            test, passed, failed = case["summary"]
            matches = re.findall(re.escape(test) + r": (\d+) passed, (\d+) failed", logs["stdout.log"].decode())
            require(len(matches) == 1, "missing or duplicate test summary: " + label)
            summary = tuple(map(int, matches[0]))
            require(summary == (passed, failed), "wrong assertion totals: " + label)
        if is_red:
            require(summary == (5, 12), "original RED assertion totals changed")
        if classification == "accepted" and case["role"] in {"functional", "native"}:
            require(summary is not None and summary[0] > 0 and summary[1] == 0, "accepted functional/native case lacks passing summary")
        if classification == "accepted" and case["role"] == "export":
            require("--export-debug" in raw["command"] and case.get("artifact_sha256") == new_sha and Path(raw["command"][-1]).resolve() == Path(new["build"]["path"]).resolve(), "accepted exporter does not identify final artifact")
        outcomes.append({"label": label, "actual_exit": raw["actual_exit"], "runner_exit": raw["runner_exit"], "stop_reason": raw["stop_reason"], "guard_reason": guard["reason"], "diagnostics": diagnostics, "assertions": summary, "classification": classification, "role": case["role"], "run_root": str(run), "artifact_sha256": case.get("artifact_sha256")})

    image_hashes = {}
    require(set(bindings["originals"]) == {"base-populated.png", "augment-three-cards.png"}, "exactly two originals required")
    for name, path in bindings["originals"].items():
        image_hashes[name] = sha(add(Path(path), "originals/" + name))
        metadata = json.loads(add(Path(str(path) + ".json"), "originals/" + name + ".json"))
        require(metadata.get("file") == name and metadata.get("normal_flags") is True, "native metadata identifies another image/flow")
        require(metadata.get("catalogues") == {"race_db": 4, "style_db": 3, "weapon_db": 3, "spell_db": 1, "item_db": 40, "set_db": 3, "augment_db": 16, "major_choices": 28}, "native catalogue controls differ")
    require(set(bindings["reviews"]) == {"root", "independent"}, "both original reviews required")
    for owner, path in bindings["reviews"].items():
        review = json.loads(add(Path(path), "reviews/" + owner + ".json"))
        require(review.get("accepted") is True and review.get("artifact_sha256") == new_sha and review.get("run_label") == native_label and review.get("originals") == image_hashes, "review is not accepted/bound to originals: " + owner)

    # All requirements resolved. .gdignore is the first file created.
    output.mkdir(parents=True)
    (output / ".gdignore").write_bytes(b"")
    inventory = [{"path": ".gdignore", "bytes": 0, "sha256": sha(b""), "source": "generated before payloads"}]
    for relative, (source, data, compress) in pending.items():
        stored = gzip.compress(data, mtime=0) if compress else data
        if compress:
            require(gzip.decompress(stored) == data, "full gzip round trip failed")
        target = output / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(stored)
        inventory.append({"path": relative, "bytes": len(stored), "sha256": sha(stored), "source": str(source), "source_bytes": len(data), "source_sha256": sha(data), "compression": "gzip-full-unfiltered" if compress else None})
    manifest = {"schema": 3, "base_commit": BASE, "source_checkpoint": checkpoint, "frozen_functional_test_sha256": FROZEN, "pack_layout": {"old": "compiled scripts and binary resource targets/remaps", "final": "original compiled-script/binary-resource export configuration", "project_godot_sha256_matches_baseline": BASE_PROJECT, "export_presets_sha256_matches_baseline": BASE_PRESETS, "runtime_catalogue_controls": metadata["catalogues"]}, "artifacts_referenced_not_copied": {"old": old["build"], "failed_r1": load(WORK / "failed-r1-new-playtest-pack-inspection.json")["build"], "other_classified_intermediates": [row["build"] for row in historical_inspections], "final": new["build"]}, "artifact_observations": observations, "outcomes": outcomes, "originals": image_hashes, "limits": "Linux Godot 4.7.2 executes the Windows package; actual Windows OS launch remains user playtest. Full normal opening entry and a separately staged first Binding are covered, not cinematic completion or evidence-store traversal. Historical failures, rejected format experiments and diagnostic interruptions remain classified separately from final architecture acceptance.", "payload_file_count": len(inventory), "manifest_is_additional_file": True, "files": inventory}
    body = (json.dumps(manifest, indent=2) + "\n").encode()
    (output / "manifest.json").write_bytes(body)
    print(json.dumps({"output": str(output), "payload_files": len(inventory), "total_files": len(inventory) + 1, "manifest_sha256": sha(body), "raw_gzip_round_trips": len(cases)}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bindings", type=Path, required=True)
    main(parser.parse_args().bindings.resolve())
