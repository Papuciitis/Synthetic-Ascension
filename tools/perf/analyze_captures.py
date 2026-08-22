#!/usr/bin/env python3
"""Summarize performance flight-recorder captures.

Usage:
  python3 tools/perf/analyze_captures.py                 # group by day
  python3 tools/perf/analyze_captures.py --group session # split per play session
  python3 tools/perf/analyze_captures.py --days 2026-08-21 2026-08-22

Reads performance_results/*.csv (segment-02 by default), deduplicates the
overlapping recorder windows by t_usec, and prints frame-time percentiles,
enemy-count buckets, and the simulation LOD telemetry columns when present.
"""
import argparse
import csv
import glob
import os
import re
import statistics as st

FILENAME_RE = re.compile(r"(\d{4}-\d{2}-\d{2})_(\d{2})-(\d{2})-(\d{2})_segment-(\d+)_")
SIM_KEYS = (
    "sim_full", "sim_mid", "sim_far", "sim_protected", "sim_physics_enabled",
    "sim_pressure", "sim_spatial_demotions", "tier_changes_total",
    "tier_reversals_total", "world_materialized", "world_data_only",
)
# A gap this large between capture timestamps starts a new play session.
SESSION_GAP_MINUTES = 10.0


def percentile(values, p):
    if not values:
        return 0.0
    ordered = sorted(values)
    k = (len(ordered) - 1) * p / 100.0
    lower = int(k)
    upper = min(lower + 1, len(ordered) - 1)
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (k - lower)


def file_minute(path):
    match = FILENAME_RE.search(os.path.basename(path))
    if match is None:
        return None
    _, hh, mm, ss, _ = match.groups()
    return int(hh) * 60 + int(mm) + int(ss) / 60.0


def group_key(path, mode):
    match = FILENAME_RE.search(os.path.basename(path))
    if match is None:
        return None
    return match.group(1)


def load_groups(directory, mode, days, segment):
    paths = sorted(glob.glob(os.path.join(directory, "*_segment-%02d_*.csv" % segment)))
    groups = {}
    previous_minute = None
    session_index = 0
    for path in paths:
        day = group_key(path, mode)
        if day is None or (days and day not in days):
            continue
        key = day
        if mode == "session":
            minute = file_minute(path)
            if previous_minute is None or minute is None or minute - previous_minute > SESSION_GAP_MINUTES or key not in {
                k.split(" ")[0] for k in groups
            }:
                session_index += 1
            previous_minute = minute
            key = "%s session-%d" % (day, session_index)
        groups.setdefault(key, {})
        rows = groups[key]
        with open(path, newline="") as handle:
            for row in csv.DictReader(handle):
                try:
                    rows[int(row["t_usec"])] = row
                except (KeyError, ValueError):
                    continue
    return groups


def to_float(row, key):
    try:
        return float(row.get(key, ""))
    except (TypeError, ValueError):
        return None


def summarize(label, rows_by_t):
    rows = []
    for _, raw in sorted(rows_by_t.items()):
        frame = to_float(raw, "frame_ms")
        enemies = to_float(raw, "enemies")
        if frame is None or enemies is None or enemies <= 0:
            continue
        entry = {
            "frame": frame,
            "physics": to_float(raw, "physics_ms") or 0.0,
            "enemies": enemies,
            "projectiles": to_float(raw, "projectiles") or 0.0,
        }
        for key in SIM_KEYS:
            entry[key] = to_float(raw, key)
        rows.append(entry)
    if not rows:
        print("%s: no usable frames" % label)
        return
    frames = [r["frame"] for r in rows]
    print("\n=== %s (%d unique frames) ===" % (label, len(rows)))
    print(
        "frame avg %6.2f  p95 %6.2f  p99 %6.2f  >33.3ms %5.2f%%  >50ms %5.2f%%"
        % (
            st.mean(frames),
            percentile(frames, 95),
            percentile(frames, 99),
            100.0 * sum(f > 33.3 for f in frames) / len(frames),
            100.0 * sum(f > 50.0 for f in frames) / len(frames),
        )
    )
    print(
        "physics avg %5.2f p95 %5.2f | enemies avg %5.1f max %4.0f | proj avg %5.1f"
        % (
            st.mean([r["physics"] for r in rows]),
            percentile([r["physics"] for r in rows], 95),
            st.mean([r["enemies"] for r in rows]),
            max(r["enemies"] for r in rows),
            st.mean([r["projectiles"] for r in rows]),
        )
    )
    buckets = ((70, 89), (90, 109), (110, 129), (130, 200), (200, 999))
    parts = []
    for low, high in buckets:
        bucket = [r["frame"] for r in rows if low <= r["enemies"] <= high]
        if bucket:
            parts.append("[%d-%d] %5.1fms (n=%d)" % (low, high, percentile(bucket, 95), len(bucket)))
    if parts:
        print("p95 frame by enemies: " + "  ".join(parts))
    sim_rows = [r for r in rows if r["sim_full"] is not None]
    if sim_rows:
        reversals = max(r["tier_reversals_total"] or 0 for r in sim_rows)
        changes = max(r["tier_changes_total"] or 0 for r in sim_rows)
        print(
            "sim: full %4.1f mid %4.1f far %4.1f prot %3.1f | phys_enabled %5.1f | "
            "pressure %4.1f%% | changes %.0f reversals %.0f"
            % (
                st.mean([r["sim_full"] for r in sim_rows]),
                st.mean([r["sim_mid"] for r in sim_rows]),
                st.mean([r["sim_far"] for r in sim_rows]),
                st.mean([r["sim_protected"] or 0 for r in sim_rows]),
                st.mean([r["sim_physics_enabled"] or 0 for r in sim_rows]),
                100.0 * st.mean([r["sim_pressure"] or 0 for r in sim_rows]),
                changes,
                reversals,
            )
        )
        print(
            "world: materialized %5.1f  data_only %5.1f  logical max %4.0f"
            % (
                st.mean([r["world_materialized"] or 0 for r in sim_rows]),
                st.mean([r["world_data_only"] or 0 for r in sim_rows]),
                max((r["world_materialized"] or 0) + (r["world_data_only"] or 0) for r in sim_rows),
            )
        )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dir", default="performance_results")
    parser.add_argument("--group", choices=("day", "session"), default="day")
    parser.add_argument("--segment", type=int, default=2)
    parser.add_argument("--days", nargs="*", default=None)
    args = parser.parse_args()
    groups = load_groups(args.dir, args.group, args.days, args.segment)
    if not groups:
        print("No captures found in %s" % args.dir)
        return
    for label in sorted(groups):
        summarize(label, groups[label])


if __name__ == "__main__":
    main()
