#!/usr/bin/env python3
"""Inspect an unencrypted Godot PCK4 offline; never launch or modify a build.

Run from any directory. JSON goes to stdout. Source IDs are explicitly a
separate catalogue: this tool does not deserialize exported Resource bodies.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
from datetime import datetime, timezone
from pathlib import Path

ROOTS = {
    "race_db": "data/races/",
    "style_db": "data/styles/",
    "weapon_db": "data/weapons/",
    "spell_db": "spells/data/",
    "item_db": "data/items/defs/",
    "set_db": "data/sets/",
    "augment_db": "data/augments/",
    "major_choice_db": "data/major_choices/",
}


def utc_ns(value: int) -> str:
    return datetime.fromtimestamp(value / 1e9, timezone.utc).isoformat()


def file_identity(path: Path) -> dict:
    stat = path.stat()
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return {
        "path": str(path.resolve()),
        "bytes": stat.st_size,
        "mtime_ns": stat.st_mtime_ns,
        "mtime_utc": utc_ns(stat.st_mtime_ns),
        "ctime_ns": stat.st_ctime_ns,
        "ctime_utc": utc_ns(stat.st_ctime_ns),
        "sha256": digest.hexdigest(),
    }


def source_catalogue(project: Path, name: str, directory: str) -> dict:
    rows = []
    for path in sorted((project / directory).rglob("*.tres")):
        text = path.read_text()
        main = text.split("[resource]", 1)[-1]
        declared = re.search(r'^id\s*=\s*&?"([^"]*)"', main, re.M)
        source_id = declared.group(1) if declared else ""
        effective = source_id
        rule = "authored id"
        enabled = not re.search(r"^runtime_enabled\s*=\s*false", main, re.M)
        if name == "weapon_db":
            effective = effective or re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "_", path.stem).lower()
            effective = effective.removeprefix("starter_")
            rule = "Global._load_weapons filename fallback / prefix normalization"
        elif name == "spell_db":
            effective = effective or "spell_" + re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "_", path.stem).lower()
            if not effective.startswith("spell_"):
                effective = "spell_" + effective
            rule = "Global._load_spells id normalization"
        eligible = bool(effective) and (name != "item_db" or bool(enabled))
        rows.append({
            "logical_resource": "res://" + path.relative_to(project).as_posix(),
            "authored_id": source_id,
            "expected_loader_id": effective,
            "id_rule": rule,
            "runtime_enabled": bool(enabled),
            "expected_loader_eligible": eligible,
            "source_file": file_identity(path),
        })
    ids = sorted(row["expected_loader_id"] for row in rows if row["expected_loader_eligible"])
    return {"resource_count": len(rows), "expected_db_count": len(set(ids)), "expected_db_ids": ids, "resources": rows}


def inspect(pack: Path, project: Path) -> dict:
    before = pack.stat()
    identity = file_identity(pack)
    with pack.open("rb") as handle:
        def read_exact(size: int) -> bytes:
            value = handle.read(size)
            if len(value) != size:
                raise ValueError("unexpected end of pack")
            return value

        handle.seek(0)
        embedded = read_exact(4) != b"GDPC"
        base = 0
        if embedded:
            handle.seek(-12, 2)
            size, magic = struct.unpack("<Q4s", read_exact(12))
            if magic != b"GDPC":
                raise ValueError("no embedded PCK footer")
            base = before.st_size - 12 - size
            if base < 0:
                raise ValueError("invalid embedded PCK size")
        handle.seek(base)
        magic, version, major, minor, patch, flags, data_start, index = struct.unpack("<4sIIIIIQQ", read_exact(40))
        if magic != b"GDPC" or version != 4 or flags != 2:
            raise ValueError("this inspector supports only unencrypted relative-offset PCK4 (flags=2)")
        handle.seek(base + index)
        count = struct.unpack("<I", read_exact(4))[0]
        files = {}
        for _ in range(count):
            length = struct.unpack("<I", read_exact(4))[0]
            if length == 0 or length > 1024 * 1024:
                raise ValueError("invalid PCK directory path length")
            path = read_exact(length).rstrip(b"\0").decode("utf-8")
            offset, size = struct.unpack("<QQ", read_exact(16))
            md5 = read_exact(16).hex()
            entry_flags = struct.unpack("<I", read_exact(4))[0]
            if path in files or offset + data_start + size > index:
                raise ValueError("duplicate path or out-of-range pack payload: " + path)
            files[path] = {"offset": offset, "bytes": size, "stored_md5": md5, "flags": entry_flags}

        def payload(path: str) -> tuple[bytes, dict]:
            entry = files[path]
            if entry["flags"] != 0:
                raise ValueError("unsupported payload flags: " + path)
            handle.seek(base + data_start + entry["offset"])
            data = read_exact(entry["bytes"])
            if hashlib.md5(data).hexdigest() != entry["stored_md5"]:
                raise ValueError("PCK directory MD5 mismatch: " + path)
            return data, {**entry, "absolute_file_offset": base + data_start + entry["offset"], "sha256": hashlib.sha256(data).hexdigest(), "stored_md5_verified": True}

        databases = {}
        for name, directory in ROOTS.items():
            remaps = []
            for path in sorted(files):
                if not path.startswith(directory) or not path.endswith((".tres.remap", ".res.remap")):
                    continue
                data, remap_identity = payload(path)
                match = re.search(r'^path="res://([^"]+)"$', data.decode("utf-8"), re.M)
                if not match:
                    raise ValueError("unrecognized remap body: " + path)
                target = match.group(1)
                _, target_identity = payload(target)
                remaps.append({
                    "logical_resource": "res://" + path.removesuffix(".remap"),
                    "physical_remap": "res://" + path,
                    "remap_payload": remap_identity,
                    "remap_target": "res://" + target,
                    "target_present": True,
                    "target_payload": target_identity,
                })
            raw = sorted(path for path in files if path.startswith(directory) and path.endswith((".tres", ".res")))
            databases[name] = {
                "root": "res://" + directory,
                "physical_remap_count": len(remaps),
                "raw_tres_res_paths": raw,
                "old_DirAccess_suffix_scanner_accepted_count": len(raw),
                "remaps": remaps,
                "current_checkout_source_catalogue": source_catalogue(project, name, directory),
            }
    after = pack.stat()
    if (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns) != (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns):
        raise ValueError("build changed during inspection")
    return {
        "schema": 1,
        "inspected_utc": datetime.now(timezone.utc).isoformat(),
        "method": "Python stdlib offline PCK4 directory and payload inspection; no engine or build mutation",
        "limitations": [
            "Pack path, payload, hash and remap-target evidence are direct observations.",
            "Source IDs and expected DB counts come from separately hashed current-checkout .tres files and loader rules; exported Resource bodies are not deserialized.",
            "File timestamps identify the artifact observed, not the time or exact copy the user executed.",
        ],
        "build": identity,
        "inspector": file_identity(Path(__file__)),
        "project_source_root": str(project.resolve()),
        "pack": {"embedded": embedded, "base_offset": base, "format_version": version, "godot_version": [major, minor, patch], "flags": flags, "data_start_relative": data_start, "directory_offset_relative": index, "entry_count": count},
        "databases": databases,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--pack", type=Path)
    args = parser.parse_args()
    pack = args.pack or args.project / "build/playtest/SyntheticAscension-playtest.exe"
    print(json.dumps(inspect(pack.resolve(), args.project.resolve()), indent=2) + "\n", end="")
