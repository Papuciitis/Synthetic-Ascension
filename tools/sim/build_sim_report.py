#!/usr/bin/env python3
"""Turn BuildSimulator output (builds_*.jsonl + structure.json) into a report.

Usage: python3 tools/sim/build_sim_report.py <run_dir> [--out <dir>] [--label <text>]

Everything here is descriptive. "Lift" columns are correlational (builds with
a node versus builds without it, same core and tier, in one scripted
scenario); they point at what to look at, never at a cause.
"""
import argparse, collections, csv, json, math, os, statistics, sys

TREE = "data/ascension/tree_v4.json"
STATUS = "tools/design/v4_status.json"
ORIGIN_CLASSES = ["native", "ascension", "set", "status", "witness", "mixed", "unknown", "other"]


def pct(values, q):
    if not values:
        return 0.0
    s = sorted(values)
    k = max(0, min(len(s) - 1, int(math.ceil(q * len(s))) - 1))
    return s[k]


def origin_class(key):
    head = key.split(":")[0]
    return head if head in ORIGIN_CLASSES else "other"


def load_rows(run_dir):
    rows = []
    for name in sorted(os.listdir(run_dir)):
        if name.startswith("builds_") and name.endswith(".jsonl"):
            with open(os.path.join(run_dir, name)) as f:
                for line in f:
                    line = line.strip()
                    if line:
                        rows.append(json.loads(line))
    return rows


def fmt(v, digits=1):
    if v is None:
        return "-"
    if isinstance(v, float):
        return f"{v:.{digits}f}"
    return str(v)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("run_dir")
    ap.add_argument("--out", default=None)
    ap.add_argument("--label", default="")
    args = ap.parse_args()
    out_dir = args.out or args.run_dir
    os.makedirs(out_dir, exist_ok=True)
    rows = load_rows(args.run_dir)
    structure = json.load(open(os.path.join(args.run_dir, "structure.json"))) if os.path.exists(os.path.join(args.run_dir, "structure.json")) else {}
    tree = json.load(open(TREE))
    nodes = {n["id"]: n for n in tree["nodes"]}
    status = json.load(open(STATUS)) if os.path.exists(STATUS) else {}
    all_ok = [r for r in rows if not r.get("failed")]
    ok = [r for r in all_ok if r["source"] not in ("ablation", "ablation_base", "ablation_repeat")]
    general = ok
    failed = [r for r in rows if r.get("failed")]
    tiers = sorted({r["tier"] for r in general}, key=lambda t: [r["segment"] for r in general if r["tier"] == t][0])
    cores = ["melee", "ranged", "magic"]
    L = []
    L.append(f"# Build simulator report{(': ' + args.label) if args.label else ''}\n")
    if ok:
        r0 = ok[0]
        L.append(f"{len(rows)} builds ({len(failed)} failed to install), {r0['frames']} frames each at 60 simulated fps against a {r0['crowd']}-body mixed crowd refilled every half second. Player inputs are scripted: a native strike every fourth frame at a random living target, Q whenever it is off recovery, V whenever it charged naturally, a dash every 90 frames. Incoming damage is scripted through the real player damage path: contact ticks from enemies within reach (10 x swarm x enemy damage multiplier every half second), spitter volleys and one sniper shot on their intervals. Every purchase used the real ledger rules; every hit resolved on the real combat services; attribution comes from the balance recorder. Numbers are for this scenario only.\n")
    L.append("## Sources and tiers\n")
    by_src = collections.Counter(r["source"] for r in rows)
    L.append("| Source | Builds |\n|---|---:|")
    for k, v in sorted(by_src.items()):
        L.append(f"| {k} | {v} |")
    L.append("")
    L.append("| Tier | Segment | Budget | Gear rank | Enemy HP x | Enemy damage x | Builds |\n|---|---:|---:|---:|---:|---:|---:|")
    for t in tiers:
        rs = [r for r in ok if r["tier"] == t]
        r = rs[0]
        L.append(f"| {t} | {r['segment']} | {r['budget']} | {r['gear']['rank']} | {r['pressure']['enemy_hp_mul']:.2f} | {r['pressure']['enemy_damage_mul']:.2f} | {len(rs)} |")
    L.append("")
    if failed:
        L.append("Failed installs: " + "; ".join(f"{r['name']} ({r['failed']})" for r in failed[:12]) + ("..." if len(failed) > 12 else "") + "\n")

    # ---- distributions
    L.append("## Outcome distributions per tier (p10 / p50 / p90)\n")
    L.append("| Tier | Core | n | Enemy HP/s | Kills/s | HP lost | Deaths (mean) | Min HP % | Followers/min | Q casts | V casts | HP/s per 1k spent |\n|---|---|---:|---|---|---|---:|---|---|---|---|---|")
    for t in tiers:
        for c in cores + ["all"]:
            rs = [r for r in ok if r["tier"] == t and (c == "all" or r["core"] == c)]
            if not rs:
                continue
            def col(key, digits=1, f=lambda r, k: r[k]):
                v = [f(r, key) for r in rs]
                return f"{pct(v,0.1):.{digits}f} / {pct(v,0.5):.{digits}f} / {pct(v,0.9):.{digits}f}"
            minhp = [100.0 * r["min_hp"] / max(1.0, r["player"]["max_hp"]) for r in rs]
            eff = [r["hp_per_second"] / max(1.0, r["spent"]) * 1000.0 for r in rs]
            L.append(f"| {t} | {c} | {len(rs)} | {col('hp_per_second')} | {col('kills_per_second', 2)} | {col('player_hp_lost', 0)} | {statistics.mean(r['deaths'] for r in rs):.2f} | {pct(minhp,0.1):.0f} / {pct(minhp,0.5):.0f} / {pct(minhp,0.9):.0f} | {col('followers_per_minute', 0)} | {col('q_casts', 0)} | {col('v_casts', 0)} | {pct(eff,0.1):.1f} / {pct(eff,0.5):.1f} / {pct(eff,0.9):.1f} |")
    L.append("")

    # ---- damage by origin class
    L.append("## Where the damage comes from (share of enemy HP removed)\n")
    L.append("| Tier | Core | Native | Tree (ascension) | Sets | Status | Witness | Mixed/unknown |\n|---|---|---:|---:|---:|---:|---:|---:|")
    for t in tiers:
        for c in cores:
            rs = [r for r in ok if r["tier"] == t and r["core"] == c]
            if not rs:
                continue
            tot = collections.Counter()
            for r in rs:
                for k, v in r["by_origin"].items():
                    tot[origin_class(k)] += v["hp_removed"]
            s = sum(tot.values()) or 1.0
            L.append(f"| {t} | {c} | {100*tot['native']/s:.0f}% | {100*tot['ascension']/s:.0f}% | {100*tot['set']/s:.0f}% | {100*tot['status']/s:.0f}% | {100*tot['witness']/s:.0f}% | {100*(tot['mixed']+tot['unknown']+tot['other'])/s:.0f}% |")
    L.append("")

    # ---- node statistics (random builds only for pick rates)
    random_rows = [r for r in ok if r["source"] == "random"]
    node_stats = {}
    for nid, node in nodes.items():
        core = node.get("core")
        st = status.get(nid, {}).get("status", "unknown") if isinstance(status, dict) else "unknown"
        owned_rows = [r for r in ok if nid in r["nodes"]]
        rand_owned = [r for r in random_rows if nid in r["nodes"]]
        rand_core = [r for r in random_rows if (core is None or r["core"] == core or any(("core." + core) in rr for rr in [r["nodes"]]))]
        # affordability: guided unlock within the tier budget
        unlock = (structure.get("nodes", {}).get(nid, {}) or {}).get("guided_unlock")
        affordable = [r for r in rand_core if unlock is not None and unlock <= r["budget"]]
        pick_rate = (len([r for r in affordable if nid in r["nodes"]]) / len(affordable)) if affordable else None
        dmg = [r["by_node"].get(nid, {}).get("hp_removed", 0.0) for r in owned_rows]
        dmg_share = [r["by_node"].get(nid, {}).get("hp_removed", 0.0) / max(1.0, r["enemy_hp_removed"]) for r in owned_rows]
        # lift: same core+tier, with vs without
        lifts = []
        surv_lifts = []
        for t in tiers:
            for c in cores:
                w = [r for r in random_rows if r["tier"] == t and r["core"] == c and nid in r["nodes"]]
                wo = [r for r in random_rows if r["tier"] == t and r["core"] == c and nid not in r["nodes"]]
                if len(w) >= 2 and len(wo) >= 2:
                    a = statistics.median(r["hp_per_second"] for r in w); b = statistics.median(r["hp_per_second"] for r in wo)
                    if b > 0:
                        lifts.append(a / b)
                    la = statistics.median(r["player_hp_lost"] for r in w); lb = statistics.median(r["player_hp_lost"] for r in wo)
                    if lb > 0:
                        surv_lifts.append(la / lb)
        node_stats[nid] = {"id": nid, "kind": node["kind"], "core": core, "discipline": node.get("discipline"), "cost": node["cost_followers"], "status": st,
            "owned_builds": len(owned_rows), "random_owned": len(rand_owned), "pick_rate": pick_rate, "guided_unlock": unlock,
            "mean_damage": statistics.mean(dmg) if dmg else 0.0, "mean_damage_share": statistics.mean(dmg_share) if dmg_share else 0.0,
            "damage_silent": bool(owned_rows) and all(d <= 0.0 for d in dmg),
            "damage_lift": statistics.median(lifts) if lifts else None, "hp_lost_lift": statistics.median(surv_lifts) if surv_lifts else None}
    # near-autopicks and rarely picked
    L.append("## Node pick rates in random walks (affordable = guided unlock within the tier budget)\n")
    L.append("Random walks buy uniformly among buyable nodes weighted only by kind, so a pick rate is a structural fact (how often the node is buyable and how long it stays buyable), not a player preference. High rates mark nodes the rules push everyone through; low rates mark nodes the rules rarely expose.\n")
    autop = sorted([s for s in node_stats.values() if s["pick_rate"] is not None and s["pick_rate"] >= 0.85 and s["kind"] not in ("core",)], key=lambda s: -s["pick_rate"])
    rare = sorted([s for s in node_stats.values() if s["pick_rate"] is not None and s["pick_rate"] <= 0.08 and s["kind"] not in ("core", "sink")], key=lambda s: s["pick_rate"])
    L.append("| Nearly always bought when affordable | Kind | Pick rate | Damage lift |\n|---|---|---:|---:|")
    for s in autop[:25]:
        L.append(f"| {s['id']} | {s['kind']} | {100*s['pick_rate']:.0f}% | {fmt(s['damage_lift'],2)} |")
    L.append("")
    L.append("| Rarely bought when affordable | Kind | Pick rate | Guided unlock | Status |\n|---|---|---:|---:|---|")
    for s in rare[:30]:
        L.append(f"| {s['id']} | {s['kind']} | {100*s['pick_rate']:.0f}% | {fmt(s['guided_unlock'])} | {s['status']} |")
    L.append("")

    # ---- dead / silent nodes
    L.append("## Nodes that never attributed damage while owned\n")
    L.append("A silent node is not necessarily dead: defensive, movement, economy and enabling nodes never emit a payload of their own. Read this with the kind and the lift columns; a damage-kind node (mutation of an attack, fusion, revelation) that stays silent across many builds is the finding.\n")
    silent = sorted([s for s in node_stats.values() if s["damage_silent"] and s["owned_builds"] >= 5 and s["kind"] not in ("core", "choice", "gate", "sink", "axiom", "keystone")], key=lambda s: -s["owned_builds"])
    L.append("| Node | Kind | Discipline | Owned in builds | Damage lift | HP-lost lift | Status |\n|---|---|---|---:|---:|---:|---|")
    for s in silent[:60]:
        L.append(f"| {s['id']} | {s['kind']} | {s['discipline'] or '-'} | {s['owned_builds']} | {fmt(s['damage_lift'],2)} | {fmt(s['hp_lost_lift'],2)} | {s['status']} |")
    L.append("")

    # ---- node contribution leaders
    L.append("## Nodes by mean share of a build's damage while owned\n")
    lead = sorted([s for s in node_stats.values() if s["owned_builds"] >= 3 and s["mean_damage_share"] > 0], key=lambda s: -s["mean_damage_share"])
    L.append("| Node | Kind | Owned in | Mean share | Damage lift | Cost |\n|---|---|---:|---:|---:|---:|")
    for s in lead[:30]:
        L.append(f"| {s['id']} | {s['kind']} | {s['owned_builds']} | {100*s['mean_damage_share']:.1f}% | {fmt(s['damage_lift'],2)} | {s['cost']} |")
    L.append("")

    # ---- outliers / runaway
    L.append("## Outliers within a tier (candidates for runaway synergies)\n")
    L.append("| Build | Core | Tier | Enemy HP/s | z (tier) | Kills/s | HP lost | Deaths | Q/V | Spent | Top origins |\n|---|---|---|---:|---:|---:|---:|---:|---|---:|---|")
    outliers = []
    for t in tiers:
        rs = [r for r in ok if r["tier"] == t]
        vals = [r["hp_per_second"] for r in rs]
        if len(vals) < 4:
            continue
        mu = statistics.mean(vals); sd = statistics.pstdev(vals) or 1.0
        for r in rs:
            z = (r["hp_per_second"] - mu) / sd
            if z >= 2.0:
                outliers.append((z, r))
    for z, r in sorted(outliers, key=lambda x: -x[0])[:20]:
        tops = sorted(r["by_origin"].items(), key=lambda kv: -kv[1]["hp_removed"])[:3]
        L.append(f"| {r['name']} | {r['core']} | {r['tier']} | {r['hp_per_second']:.0f} | {z:.1f} | {r['kills_per_second']:.2f} | {r['player_hp_lost']:.0f} | {r['deaths']} | {r['q_casts']}/{r['v_casts']} | {r['spent']} | {', '.join(f'{k} {v['hp_removed']:.0f}' for k, v in tops)} |")
    L.append("")

    # ---- strongest combinations (pairs enriched in the top decile)
    L.append("## Node pairs enriched among the top decile builds of their tier\n")
    top_ids = set()
    for t in tiers:
        rs = sorted([r for r in ok if r["tier"] == t], key=lambda r: -r["hp_per_second"])
        for r in rs[:max(1, len(rs) // 10)]:
            top_ids.add(r["job_index"])
    pair_top = collections.Counter(); pair_all = collections.Counter()
    for r in ok:
        ids = sorted(n for n in r["nodes"] if not n.startswith("core."))
        top = r["job_index"] in top_ids
        for i in range(len(ids)):
            for j in range(i + 1, len(ids)):
                pair_all[(ids[i], ids[j])] += 1
                if top:
                    pair_top[(ids[i], ids[j])] += 1
    base = len(top_ids) / max(1, len(ok))
    enriched = []
    for pair, n in pair_all.items():
        if n >= 4 and pair_top[pair] >= 3:
            lift = (pair_top[pair] / n) / base
            enriched.append((lift, pair, n, pair_top[pair]))
    L.append("| Pair | Builds with pair | In top decile | Lift |\n|---|---:|---:|---:|")
    for lift, pair, n, k in sorted(enriched, key=lambda x: -x[0])[:25]:
        L.append(f"| {pair[0]} + {pair[1]} | {n} | {k} | {lift:.1f}x |")
    L.append("")

    # ---- presets table
    L.append("## Authored presets and routes\n")
    L.append("| Build | Core | Tier | Nodes | Spent | Enemy HP/s | Kills/s | HP lost | Deaths | Q/V | Native / tree / sets share | Frame p95 ms |\n|---|---|---|---:|---:|---:|---:|---:|---:|---|---|---:|")
    for r in sorted([r for r in ok if r["source"] != "random"], key=lambda r: (r["core"], r["name"])):
        tot = collections.Counter()
        for k, v in r["by_origin"].items():
            tot[origin_class(k)] += v["hp_removed"]
        s = sum(tot.values()) or 1.0
        L.append(f"| {r['name']} | {r['core']} | {r['tier']} | {r['node_count']} | {r['spent']} | {r['hp_per_second']:.0f} | {r['kills_per_second']:.2f} | {r['player_hp_lost']:.0f} | {r['deaths']} | {r['q_casts']}/{r['v_casts']} | {100*tot['native']/s:.0f} / {100*tot['ascension']/s:.0f} / {100*tot['set']/s:.0f}% | {r['frame_p95_ms']:.1f} |")
    L.append("")

    # ---- ablation
    bases = {r["name"].replace("Ablation base: ", ""): r for r in all_ok if r["source"] == "ablation_base"}
    variants = [r for r in all_ok if r["source"] == "ablation"]
    if bases and variants:
        L.append("## Ablation: each node's contribution to its own authored build\n")
        L.append("Every pure preset was fought whole, then once per owned node with that node refunded through the real refund rule (dependents leave with it; a refunded Q or V is replaced by another owned one). Same crowd stream and gear as the base. A change inside the preset's noise floor (the repeat row below) is not a finding, and an HP-lost change against a base under 1 HP is shown as an absolute number; a node whose removal changes neither output nor survivability there is a candidate dead node in that build, not a verdict.\n")
        L.append("| Build | Node removed (with) | Kind | Enemy HP/s | Change | HP lost | Change | Deaths | Casts Q/V | Status |\n|---|---|---|---:|---:|---:|---:|---:|---|---|")
        for v in sorted(variants, key=lambda r: (r["ablation_of"], r["ablate"])):
            b = bases.get(v["ablation_of"])
            if not b:
                continue
            d_out = (v["hp_per_second"] - b["hp_per_second"]) / max(1.0, b["hp_per_second"]) * 100.0
            d_lost = (v["player_hp_lost"] - b["player_hp_lost"]) / max(1.0, b["player_hp_lost"]) * 100.0
            lost_change = (f"{d_lost:+.0f}%" if b["player_hp_lost"] >= 1.0 else f"{v['player_hp_lost'] - b['player_hp_lost']:+.0f} abs")
            extra = [n for n in v.get("removed", []) if n != v["ablate"]]
            st = status.get(v["ablate"], {}).get("status", "unknown") if isinstance(status, dict) else "unknown"
            L.append(f"| {v['ablation_of']} | {v['ablate']}{(' (+' + ', '.join(extra) + ')') if extra else ''} | {nodes.get(v['ablate'], {}).get('kind', '?')} | {v['hp_per_second']:.0f} | {d_out:+.0f}% | {v['player_hp_lost']:.0f} | {lost_change} | {v['deaths']} | {v['q_casts']}/{v['v_casts']} | {st} |")
        L.append("")
        repeats = {r["name"].replace("Ablation repeat: ", ""): r for r in all_ok if r["source"] == "ablation_repeat"}
        L.append("| Build (base) | Enemy HP/s | HP lost | Deaths | Casts Q/V | Repeat on another crowd stream: HP/s, HP lost (noise floor) |\n|---|---:|---:|---:|---|---|")
        for name, b in sorted(bases.items()):
            rep = repeats.get(name)
            noise = f"{rep['hp_per_second']:.0f} ({(rep['hp_per_second'] - b['hp_per_second']) / max(1.0, b['hp_per_second']) * 100:+.0f}%), {rep['player_hp_lost']:.0f} ({((rep['player_hp_lost'] - b['player_hp_lost']) / max(1.0, b['player_hp_lost']) * 100) if b['player_hp_lost'] >= 1.0 else (rep['player_hp_lost'] - b['player_hp_lost']):+.0f}{'%' if b['player_hp_lost'] >= 1.0 else ' abs'})" if rep else "-"
            L.append(f"| {name} | {b['hp_per_second']:.0f} | {b['player_hp_lost']:.0f} | {b['deaths']} | {b['q_casts']}/{b['v_casts']} | {noise} |")
        L.append("")

    # ---- structure
    if structure:
        L.append("## Tree structure (real purchase rules, unlimited wallet, milestones satisfied)\n")
        sn = structure.get("nodes", {})
        unreachable = structure.get("unreachable", [])
        L.append(f"{structure.get('node_count', len(sn))} nodes. Unreachable by the guided walk and by every authored route: {len(unreachable)}" + (" (" + ", ".join(u['id'] for u in unreachable) + ")" if unreachable else "") + ". Guided unlock is what a targeted walk spent before the node became buyable plus its price, an upper bound on the true minimum.\n")
        dear = sorted([(v.get("guided_unlock"), k, v["kind"]) for k, v in sn.items() if v.get("guided_unlock") is not None], key=lambda x: -x[0])[:20]
        L.append("| Dearest nodes to unlock | Kind | Guided unlock |\n|---|---|---:|")
        for cost, k, kind in dear:
            L.append(f"| {k} | {kind} | {cost} |")
        L.append("")
        over = [(k, v.get("guided_unlock")) for k, v in sn.items() if v.get("guided_unlock") is not None and v.get("guided_unlock") > max(r["budget"] for r in ok)] if ok else []
        if over:
            L.append("Beyond the largest simulated budget (" + str(max(r["budget"] for r in ok)) + "): " + ", ".join(f"{k} ({c})" for k, c in sorted(over, key=lambda x: x[1])) + ".\n")
        conflicts = [(k, v["conflicts"]) for k, v in sn.items() if v.get("conflicts")]
        L.append(f"Nodes with conflicts: {len(conflicts)}. Implementation status: " + ", ".join(f"{k} {v}" for k, v in sorted(collections.Counter(v['status'] for v in sn.values()).items())) + ".\n")

    # ---- cost
    L.append("## Simulation cost\n")
    L.append("| Tier | Frame p50 ms (median over builds) | Frame p95 ms | Frame p99 ms |\n|---|---:|---:|---:|")
    for t in tiers:
        rs = [r for r in ok if r["tier"] == t]
        L.append(f"| {t} | {statistics.median(r['frame_p50_ms'] for r in rs):.2f} | {statistics.median(r['frame_p95_ms'] for r in rs):.2f} | {statistics.median(r['frame_p99_ms'] for r in rs):.2f} |")
    L.append("")
    L.append("## Caveats\n")
    L.append("- One scripted scenario: no enemy movement or AI, a fixed crowd mix, scripted inputs. Builds that rely on positioning, kiting or timing are under- or over-served by it.")
    L.append("- Gear is a random set at the tier's rank with two random accessories; item stats are balance revision 1 unless the label says otherwise.")
    L.append("- Lifts and pair enrichments are correlational within this sample; treat them as pointers for the tree audit, not as verdicts.")
    L.append("- Damage-silent nodes include every non-damage node by construction; the list is filtered to kinds that normally emit payloads but still needs reading by hand.")
    open(os.path.join(out_dir, "report.md"), "w").write("\n".join(L) + "\n")
    # compact csv + summary json
    with open(os.path.join(out_dir, "builds.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["job_index", "name", "source", "core", "tier", "spent", "node_count", "hp_per_second", "kills_per_second", "player_hp_lost", "deaths", "min_hp", "followers_per_minute", "q_casts", "v_casts", "generated", "frame_p95_ms", "gear_set", "gear_rank", "q", "v", "nodes"])
        for r in ok:
            w.writerow([r["job_index"], r["name"], r["source"], r["core"], r["tier"], r["spent"], r["node_count"], f"{r['hp_per_second']:.2f}", f"{r['kills_per_second']:.3f}", f"{r['player_hp_lost']:.1f}", r["deaths"], f"{r['min_hp']:.1f}", f"{r['followers_per_minute']:.1f}", r["q_casts"], r["v_casts"], r["generated"], f"{r['frame_p95_ms']:.2f}", r["gear"]["set"], r["gear"]["rank"], r["equipped"].get("q", ""), r["equipped"].get("v", ""), " ".join(r["nodes"])])
    json.dump({"builds": len(rows), "failed": len(failed), "nodes": node_stats}, open(os.path.join(out_dir, "node_stats.json"), "w"), indent=1)
    print(f"report: {os.path.join(out_dir, 'report.md')} ({len(ok)} builds, {len(failed)} failed)")


if __name__ == "__main__":
    main()
