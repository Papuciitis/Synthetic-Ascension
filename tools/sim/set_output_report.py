#!/usr/bin/env python3
"""Controlled set-output probe: the same authored builds fought once per
set (SIM_SET=conduit|lattice|gravemarch, same seed, same crowd streams).

Usage: python3 tools/sim/set_output_report.py <probe_dir> <out.md> [--label "..."]
  <probe_dir> holds one sub-directory per set with builds_*.jsonl.
"""
import argparse, collections, json, os, statistics


def load(run_dir):
    rows = []
    for name in sorted(os.listdir(run_dir)):
        if name.startswith("builds_") and name.endswith(".jsonl"):
            for line in open(os.path.join(run_dir, name)):
                line = line.strip()
                if line:
                    r = json.loads(line)
                    if not r.get("failed"):
                        rows.append(r)
    return rows


def set_share(row):
    total = float(row.get("enemy_hp_removed", 0.0))
    if total <= 0.0:
        return 0.0
    s = 0.0
    for key, entry in row.get("by_origin", {}).items():
        if key.startswith("set:"):
            s += float(entry.get("hp_removed", 0.0))
    return s / total


def med(values):
    return statistics.median(values) if values else 0.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("probe_dir")
    ap.add_argument("out")
    ap.add_argument("--label", default="")
    args = ap.parse_args()
    sets = sorted(d for d in os.listdir(args.probe_dir) if os.path.isdir(os.path.join(args.probe_dir, d)))
    data = {s: {r["job_index"]: r for r in load(os.path.join(args.probe_dir, s))} for s in sets}
    common = set.intersection(*[set(d.keys()) for d in data.values()]) if data else set()
    L = [f"# Set-output probe{(': ' + args.label) if args.label else ''}", ""]
    L.append(f"{len(common)} authored builds (presets, authored builds and routes at their own tiers), each fought once per set with the same seed, gear rank, accessories and crowd streams. Set share is the fraction of enemy HP removed whose origin is the set's own payload; native, tree and status damage make up the rest. One scripted scenario; see the simulator caveats.")
    L.append("")
    tiers = ["seg2", "seg4", "seg6", "seg9", "seg12"]
    cores = ["melee", "ranged", "magic"]
    L.append("## Set share of enemy HP removed (median over builds)")
    L.append("")
    L.append("| Tier | Core | n | " + " | ".join(sets) + " |")
    L.append("|---|---|---:|" + "---:|" * len(sets))
    for tier in tiers:
        for core in cores:
            idx = [j for j in common if data[sets[0]][j]["tier"] == tier and data[sets[0]][j]["core"] == core]
            if not idx:
                continue
            cells = [f"{100 * med([set_share(data[s][j]) for j in idx]):.0f}%" for s in sets]
            L.append(f"| {tier} | {core} | {len(idx)} | " + " | ".join(cells) + " |")
    L.append("")
    L.append("## Output and survivability by set (median over builds)")
    L.append("")
    L.append("| Tier | Core | n | " + " | ".join(f"{s}: HP/s / HP lost / deaths" for s in sets) + " |")
    L.append("|---|---|---:|" + "---|" * len(sets))
    for tier in tiers:
        for core in cores:
            idx = [j for j in common if data[sets[0]][j]["tier"] == tier and data[sets[0]][j]["core"] == core]
            if not idx:
                continue
            cells = []
            for s in sets:
                rows = [data[s][j] for j in idx]
                cells.append(f"{med([r['hp_per_second'] for r in rows]):.0f} / {med([r['player_hp_lost'] for r in rows]):.0f} / {statistics.mean([r['deaths'] for r in rows]):.2f}")
            L.append(f"| {tier} | {core} | {len(idx)} | " + " | ".join(cells) + " |")
    L.append("")
    L.append("## Same build, set to set (HP/s; the set is the only difference)")
    L.append("")
    L.append("| Build | Core | Tier | " + " | ".join(sets) + " | Spread (max/min) |")
    L.append("|---|---|---|" + "---:|" * len(sets) + "---:|")
    spreads = []
    for j in sorted(common, key=lambda j: (data[sets[0]][j]["core"], data[sets[0]][j]["tier"], data[sets[0]][j]["name"])):
        vals = [data[s][j]["hp_per_second"] for s in sets]
        spread = max(vals) / max(1.0, min(vals))
        spreads.append(spread)
        r0 = data[sets[0]][j]
        L.append(f"| {r0['name']} | {r0['core']} | {r0['tier']} | " + " | ".join(f"{v:.0f} ({100 * set_share(data[s][j]):.0f}%)" for v, s in zip(vals, sets)) + f" | {spread:.2f}x |")
    L.append("")
    L.append(f"Median spread between the best and worst set for the same build: {med(spreads):.2f}x; builds whose output changes by 2x or more with the set alone: {sum(1 for x in spreads if x >= 2.0)} of {len(spreads)}.")
    L.append("")
    L.append("## Set payload origins (total enemy HP removed across all builds)")
    L.append("")
    totals = collections.Counter()
    for s in sets:
        for r in data[s].values():
            for key, entry in r["by_origin"].items():
                if key.startswith("set:"):
                    totals[key] += float(entry.get("hp_removed", 0.0))
    L.append("| Origin | HP removed |")
    L.append("|---|---:|")
    for key, v in totals.most_common():
        L.append(f"| {key} | {v:.0f} |")
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w") as f:
        f.write("\n".join(L) + "\n")
    print("wrote", args.out)


if __name__ == "__main__":
    main()
