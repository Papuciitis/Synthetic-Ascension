#!/usr/bin/env python3
"""Compare two BuildSimulator runs made with the same seed and job list
(for example balance revision 1 versus 2).

Usage: python3 tools/sim/compare_runs.py <run_a> <run_b> <out.md> [--labels "A" "B"]
"""
import argparse, collections, json, os, statistics


def load(run_dir):
    rows = {}
    for name in sorted(os.listdir(run_dir)):
        if name.startswith("builds_") and name.endswith(".jsonl"):
            for line in open(os.path.join(run_dir, name)):
                line = line.strip()
                if line:
                    r = json.loads(line)
                    if not r.get("failed") and r["source"] not in ("ablation", "ablation_base", "ablation_repeat"):
                        rows[r["job_index"]] = r
    return rows


def med(vals):
    return statistics.median(vals) if vals else 0.0


def share(r, cls):
    tot = sum(v["hp_removed"] for v in r["by_origin"].values()) or 1.0
    return sum(v["hp_removed"] for k, v in r["by_origin"].items() if k.split(":")[0] == cls) / tot


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("run_a"); ap.add_argument("run_b"); ap.add_argument("out")
    ap.add_argument("--labels", nargs=2, default=["A", "B"])
    a = ap.parse_args()
    A = load(a.run_a); B = load(a.run_b)
    common = sorted(set(A) & set(B))
    la, lb = a.labels
    L = [f"# Simulator comparison: {la} vs {lb}\n", f"{len(common)} builds present in both runs (same seed, same job list, same scenario). Medians per tier and Core; per-build changes are the same build under both rule sets.\n"]
    tiers = sorted({A[j]["tier"] for j in common}, key=lambda t: A[[j for j in common if A[j]["tier"] == t][0]]["segment"])
    cores = ["melee", "ranged", "magic"]
    L.append("| Tier | Core | n | Enemy HP/s | HP lost | Deaths (mean) | Min HP % | Native share | Tree share | Set share |\n|---|---|---:|---|---|---|---|---|---|---|")
    for t in tiers:
        for c in cores + ["all"]:
            js = [j for j in common if A[j]["tier"] == t and (c == "all" or A[j]["core"] == c)]
            if not js:
                continue
            def pair(f, fmt="%.0f"):
                va = med([f(A[j]) for j in js]); vb = med([f(B[j]) for j in js])
                delta = ((vb - va) / va * 100.0) if va else 0.0
                return (fmt % va) + " -> " + (fmt % vb) + (f" ({delta:+.0f}%)" if va else "")
            deaths_a = statistics.mean(A[j]["deaths"] for j in js); deaths_b = statistics.mean(B[j]["deaths"] for j in js)
            L.append(f"| {t} | {c} | {len(js)} | {pair(lambda r: r['hp_per_second'])} | {pair(lambda r: r['player_hp_lost'])} | {deaths_a:.2f} -> {deaths_b:.2f} | {pair(lambda r: 100.0 * r['min_hp'] / max(1.0, r['player']['max_hp']))} | {pair(lambda r: 100 * share(r, 'native'))} | {pair(lambda r: 100 * share(r, 'ascension'))} | {pair(lambda r: 100 * share(r, 'set'))} |")
    L.append("")
    L.append("## Player stats worn (median over builds, per tier)\n")
    L.append("| Tier | Max HP | Armour | Power | Move speed |\n|---|---|---|---|---|")
    for t in tiers:
        js = [j for j in common if A[j]["tier"] == t]
        def pair(k, fmt="%.0f"):
            va = med([A[j]["player"][k] for j in js]); vb = med([B[j]["player"][k] for j in js])
            return (fmt % va) + " -> " + (fmt % vb)
        L.append(f"| {t} | {pair('max_hp')} | {pair('armor', '%.1f')} | {pair('power', '%.2f')} | {pair('move_speed')} |")
    L.append("")
    L.append("## Authored builds, same build under both rule sets\n")
    L.append("| Build | Tier | Enemy HP/s | HP lost | Deaths |\n|---|---|---|---|---|")
    for j in common:
        r = A[j]
        if r["source"] == "random":
            continue
        s = B[j]
        L.append(f"| {r['name']} | {r['tier']} | {r['hp_per_second']:.0f} -> {s['hp_per_second']:.0f} ({(s['hp_per_second'] - r['hp_per_second']) / max(1.0, r['hp_per_second']) * 100:+.0f}%) | {r['player_hp_lost']:.0f} -> {s['player_hp_lost']:.0f} | {r['deaths']} -> {s['deaths']} |")
    L.append("")
    L.append("## Largest per-build changes\n")
    changes = sorted(common, key=lambda j: (B[j]["hp_per_second"] - A[j]["hp_per_second"]) / max(1.0, A[j]["hp_per_second"]))
    L.append("| Build | Tier | Gear set | Enemy HP/s | HP lost |\n|---|---|---|---|---|")
    for j in changes[:8] + changes[-8:]:
        r, s = A[j], B[j]
        L.append(f"| {r['name']} | {r['tier']} | {r['gear']['set']} | {r['hp_per_second']:.0f} -> {s['hp_per_second']:.0f} ({(s['hp_per_second'] - r['hp_per_second']) / max(1.0, r['hp_per_second']) * 100:+.0f}%) | {r['player_hp_lost']:.0f} -> {s['player_hp_lost']:.0f} |")
    open(a.out, "w").write("\n".join(L) + "\n")
    print("wrote", a.out)


if __name__ == "__main__":
    main()
