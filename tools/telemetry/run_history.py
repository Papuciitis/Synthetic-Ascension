#!/usr/bin/env python3
"""Read balance recorder captures across runs.

One row per capture (newest first) from `balance_captures/YYYY-MM-DD/<id>/summary.json`:
when, build, start and last segment, outcome, gameplay and hub minutes, kills,
deaths, Followers earned / spent / closing, HP lost and healing per gameplay
minute, enemy HP removed per second, the balance revision and tuning stages
the capture declares, and whether the recording was healthy. Schema 1 and 2
captures both read; fields a capture does not carry print as "-".

Usage:
  python3 tools/telemetry/run_history.py                  # table of every capture
  python3 tools/telemetry/run_history.py --segments       # one row per segment per capture
  python3 tools/telemetry/run_history.py --csv out.csv    # also write a CSV
  python3 tools/telemetry/run_history.py --dir <path> --days 2026-09-18 --min-minutes 2
"""
import argparse
import csv
import glob
import json
import os


def load_captures(root):
    rows = []
    for path in glob.glob(os.path.join(root, "**", "summary.json"), recursive=True):
        try:
            with open(path) as f:
                data = json.load(f)
        except (OSError, ValueError):
            continue
        if not isinstance(data, dict) or "totals" not in data:
            continue
        data["_path"] = os.path.dirname(path)
        data["_mtime"] = os.path.getmtime(path)
        rows.append(data)
    rows.sort(key=lambda d: d["_mtime"], reverse=True)
    return rows


def num(value, default=0.0):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def per_minute(value, seconds):
    return value / (seconds / 60.0) if seconds > 0 else 0.0


def fmt(value, digits=1):
    if value is None:
        return "-"
    if isinstance(value, float):
        return f"{value:.{digits}f}"
    return str(value)


def capture_row(d):
    meta = d.get("metadata", {}) or {}
    totals = d.get("totals", {}) or {}
    segments = d.get("segments", []) or []
    gameplay = num(totals.get("seconds_gameplay"))
    hub = num(totals.get("seconds_hub"))
    seg_indices = [int(s.get("segment", 0)) for s in segments if isinstance(s, dict)]
    health = d.get("health") if isinstance(d.get("health"), dict) else None
    healthy = d.get("artifacts_complete", True) and int(d.get("dropped_records", 0)) == 0 and int(d.get("writer_failures", 0)) == 0 and int(d.get("wallet_discontinuities", 0)) == 0
    build = meta.get("build")
    if isinstance(build, dict):
        build = build.get("commit") or build.get("id") or build.get("version") or ""
    row = {
        "capture": meta.get("capture_id") or os.path.basename(d["_path"]),
        "build": str(build or "-")[:12],
        "schema": d.get("schema_version", "-"),
        "balance_rev": meta.get("balance_revision", "-"),
        "stages": ",".join(meta.get("tuning_stages", [])) if meta.get("tuning_stages") else "-",
        "start_seg": meta.get("start_segment", "-"),
        "last_seg": max(seg_indices) if seg_indices else "-",
        "segments": len(seg_indices),
        "outcome": d.get("outcome", "-"),
        "gameplay_min": gameplay / 60.0,
        "hub_min": hub / 60.0,
        "kills": int(num(totals.get("kills"))),
        "kills_per_min": per_minute(num(totals.get("kills")), gameplay),
        "deaths": int(num(totals.get("deaths"))),
        "followers_earned": int(num(totals.get("followers_earned"))),
        "followers_spent": int(num(totals.get("followers_spent"))),
        "followers_close": int(num(totals.get("followers_close"))),
        "income_per_min": per_minute(num(totals.get("followers_earned")), gameplay),
        "hp_lost_per_min": per_minute(num(totals.get("player_hp_lost")), gameplay),
        "healing_per_min": per_minute(num(totals.get("healing")), gameplay),
        "enemy_hp_per_sec": num(totals.get("enemy_hp_removed")) / gameplay if gameplay > 0 else 0.0,
        "health_residual": fmt(num(health.get("totals", {}).get("residual")) if health and isinstance(health.get("totals"), dict) else None, 2) if health else "-",
        "healthy": "yes" if healthy else "NO",
        "path": d["_path"],
    }
    return row


def segment_rows(d):
    meta = d.get("metadata", {}) or {}
    out = []
    for s in d.get("segments", []) or []:
        if not isinstance(s, dict):
            continue
        gameplay = num(s.get("seconds_gameplay"))
        out.append({
            "capture": meta.get("capture_id") or os.path.basename(d["_path"]),
            "segment": int(s.get("segment", 0)),
            "status": s.get("status", "-"),
            "gameplay_min": gameplay / 60.0,
            "kills": int(num(s.get("kills"))),
            "deaths": int(num(s.get("deaths"))),
            "followers_earned": int(num(s.get("followers_earned"))),
            "followers_spent": int(num(s.get("followers_spent"))),
            "hp_lost": int(num(s.get("player_hp_lost"))),
            "healing": int(num(s.get("healing"))),
            "enemy_hp_per_sec": num(s.get("enemy_hp_removed")) / gameplay if gameplay > 0 else 0.0,
            "attacks": int(num(s.get("attacks"))),
        })
    return out


CAPTURE_COLUMNS = ["capture", "build", "balance_rev", "stages", "start_seg", "last_seg", "outcome", "gameplay_min", "hub_min", "kills", "kills_per_min", "deaths", "followers_earned", "followers_spent", "followers_close", "income_per_min", "hp_lost_per_min", "healing_per_min", "enemy_hp_per_sec", "healthy"]
SEGMENT_COLUMNS = ["capture", "segment", "status", "gameplay_min", "kills", "deaths", "followers_earned", "followers_spent", "hp_lost", "healing", "enemy_hp_per_sec", "attacks"]


def print_table(rows, columns):
    if not rows:
        print("(no captures)")
        return
    print("| " + " | ".join(columns) + " |")
    print("|" + "|".join("---" for _ in columns) + "|")
    for r in rows:
        print("| " + " | ".join(fmt(r.get(c)) for c in columns) + " |")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dir", default="balance_captures", help="capture root (default: balance_captures in the project)")
    ap.add_argument("--days", nargs="*", default=None, help="only captures under these YYYY-MM-DD folders")
    ap.add_argument("--min-minutes", type=float, default=0.0, help="skip captures with less gameplay than this")
    ap.add_argument("--segments", action="store_true", help="one row per segment per capture")
    ap.add_argument("--csv", default=None, help="also write the printed rows to this CSV")
    args = ap.parse_args()
    captures = load_captures(args.dir)
    if args.days:
        captures = [d for d in captures if any(os.sep + day + os.sep in d["_path"] + os.sep for day in args.days)]
    captures = [d for d in captures if num((d.get("totals") or {}).get("seconds_gameplay")) >= args.min_minutes * 60.0]
    if args.segments:
        rows = [r for d in captures for r in segment_rows(d)]
        columns = SEGMENT_COLUMNS
    else:
        rows = [capture_row(d) for d in captures]
        columns = CAPTURE_COLUMNS
    print(f"{len(captures)} capture(s) under {args.dir}")
    print_table(rows, columns)
    if args.csv:
        with open(args.csv, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=columns + (["path"] if not args.segments else []))
            writer.writeheader()
            for r in rows:
                writer.writerow({k: r.get(k) for k in writer.fieldnames})
        print(f"wrote {args.csv}")


if __name__ == "__main__":
    main()
