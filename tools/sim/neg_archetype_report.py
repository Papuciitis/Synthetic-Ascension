#!/usr/bin/env python3
"""Compare NEG archetype wardrobes against a POS baseline, same builds and seed.

Usage: python3 tools/sim/neg_archetype_report.py <campaign_dir> <out.md> [--baseline pos]
  <campaign_dir> holds one sub-directory per configuration with builds_*.jsonl
  (produced with SIM_SET / SIM_GEAR_POLARITY / SIM_CURSES / SIM_AUGMENTS).
"""
import argparse, json, os, statistics

CORES = ["melee", "ranged", "magic"]


def load(run_dir):
    rows = {}
    for name in sorted(os.listdir(run_dir)):
        if name.startswith("builds_") and name.endswith(".jsonl"):
            for line in open(os.path.join(run_dir, name)):
                line = line.strip()
                if line:
                    r = json.loads(line)
                    if not r.get("failed"):
                        rows[r["job_index"]] = r
    return rows


def med(values):
    return statistics.median(values) if values else 0.0


def pct(a, b):
    return (b / a - 1.0) * 100.0 if a else 0.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("campaign_dir")
    ap.add_argument("out")
    ap.add_argument("--baseline", default="pos")
    ap.add_argument("--label", default="")
    args = ap.parse_args()
    configs = sorted(d for d in os.listdir(args.campaign_dir) if os.path.isdir(os.path.join(args.campaign_dir, d)))
    data = {c: load(os.path.join(args.campaign_dir, c)) for c in configs}
    base = data[args.baseline]
    L = [f"# NEG archetype wardrobes versus the POS baseline{(': ' + args.label) if args.label else ''}", ""]
    L.append(f"{len(base)} authored builds (presets, authored builds and routes at their own tiers) fought once per configuration with the same seed and crowd streams; only the wardrobe and the slotted augment differ. Medians over builds; per-build changes are the same build under both wardrobes. One scripted scenario: see the simulator caveats (no positioning, ranged and magic set payloads are lower bounds).")
    L.append("")
    for c in configs:
        if c == args.baseline:
            continue
        sample = next(iter(data[c].values()))
        gear = sample.get("gear", {})
        L.append(f"- **{c}**: set {gear.get('set')}, cursed slots {gear.get('cursed_slots')}, relics {gear.get('relics')}, augments `{gear.get('augments') or '-'}`")
    L.append("")
    L.append("## Per Core medians (baseline -> configuration)")
    L.append("")
    L.append("| Configuration | Core | n | Enemy HP/s | HP lost | Deaths (mean) | Min HP | Power worn | Armour worn | Max HP worn |")
    L.append("|---|---|---:|---|---|---|---|---|---|---|")
    for c in configs:
        if c == args.baseline:
            continue
        for core in CORES:
            idx = [j for j in base if j in data[c] and base[j]["core"] == core]
            if not idx:
                continue
            b_rows = [base[j] for j in idx]
            c_rows = [data[c][j] for j in idx]
            def cell(key, digits=0):
                a = med([r[key] for r in b_rows]); b = med([r[key] for r in c_rows])
                return f"{a:.{digits}f} -> {b:.{digits}f} ({pct(a, b):+.0f}%)"
            def stat(key, digits=2):
                a = med([float(r.get("player", {}).get(key, 0.0)) for r in b_rows]); b = med([float(r.get("player", {}).get(key, 0.0)) for r in c_rows])
                return f"{a:.{digits}f} -> {b:.{digits}f}"
            deaths = f"{statistics.mean(r['deaths'] for r in b_rows):.2f} -> {statistics.mean(r['deaths'] for r in c_rows):.2f}"
            L.append(f"| {c} | {core} | {len(idx)} | {cell('hp_per_second')} | {cell('player_hp_lost')} | {deaths} | {cell('min_hp')} | {stat('power')} | {stat('armor', 1)} | {stat('max_hp', 0)} |")
    L.append("")
    L.append("## Pure presets, same build under each wardrobe (Enemy HP/s, HP lost)")
    L.append("")
    others = [c for c in configs if c != args.baseline]
    L.append("| Build | Core | " + " | ".join([args.baseline] + others) + " |")
    L.append("|---|---|" + "---|" * (len(others) + 1))
    for j in sorted(base, key=lambda j: (base[j]["core"], base[j]["name"])):
        r = base[j]
        if not r["name"].endswith(" pure"):
            continue
        cells = [f"{r['hp_per_second']:.0f} / {r['player_hp_lost']:.0f}"]
        for c in others:
            rc = data[c].get(j)
            cells.append(f"{rc['hp_per_second']:.0f} ({pct(r['hp_per_second'], rc['hp_per_second']):+.0f}%) / {rc['player_hp_lost']:.0f}" if rc else "-")
        L.append(f"| {r['name']} | {r['core']} | " + " | ".join(cells) + " |")
    L.append("")
    L.append("## Largest per-build swings (Enemy HP/s)")
    L.append("")
    L.append("| Configuration | Build | Core | Tier | Baseline | Configuration | Change | HP lost |")
    L.append("|---|---|---|---|---:|---:|---:|---|")
    swings = []
    for c in others:
        for j in base:
            rc = data[c].get(j)
            if rc:
                swings.append((abs(pct(base[j]["hp_per_second"], rc["hp_per_second"])), c, j, rc))
    swings.sort(reverse=True)
    for _, c, j, rc in swings[:20]:
        r = base[j]
        L.append(f"| {c} | {r['name']} | {r['core']} | {r['tier']} | {r['hp_per_second']:.0f} | {rc['hp_per_second']:.0f} | {pct(r['hp_per_second'], rc['hp_per_second']):+.0f}% | {r['player_hp_lost']:.0f} -> {rc['player_hp_lost']:.0f} |")
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w") as f:
        f.write("\n".join(L) + "\n")
    print("wrote", args.out)


if __name__ == "__main__":
    main()
