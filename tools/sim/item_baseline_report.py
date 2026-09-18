#!/usr/bin/env python3
"""Render an ItemBalanceProbe JSON export as markdown.

Usage: python3 tools/sim/item_baseline_report.py <baseline.json> <out.md> [--title <text>]
"""
import argparse, json


def fmt(v):
    if v is None:
        return "-"
    if isinstance(v, float):
        return ("%.4g" % v) if abs(v) < 1000 else ("%.0f" % v)
    return str(v)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("baseline")
    ap.add_argument("out")
    ap.add_argument("--title", default="Item and encounter baseline")
    args = ap.parse_args()
    b = json.load(open(args.baseline))
    int_ranks = [str(int(r)) for r in b["ranks"]]
    ranks = int_ranks + ["6.5"]
    L = [f"# {args.title} (balance revision {b['balance_revision']}, tuning stages {b.get('tuning_stages', [])})\n"]
    L.append(f"Exported by `tools/tests/ItemBalanceProbe.tscn` from the production formulas on the human race, ranged style, neutral positive rolls, no Manifestations, augments, doctrine or Ascension rules, segment {int(b['segment'])}. Tuning hash: `{b['tuning_hash'] or 'empty'}`. Laboratory ranks, not natural rank-to-segment mappings.\n")
    e = b["ehp_fixture"]
    L.append("## Constant-EHP fixture through the real damage path\n")
    L.append("HP %.0f, armour %.0f, one other damage-taken multiplier %.2f, one ordinary %.0f raw hit with evasion, invulnerability and healing disabled: observed HP loss **%.4f**, constant EHP **%.1f**.\n" % (e["max_hp"], e["armor"], e["other_damage_multiplier"], e["raw_hit"], e["observed_hp_loss"], e["constant_ehp"]))
    p = b["primary_hit"]; m = p["by_rank"]["6"]["measured"]
    L.append("## Primary-hit damage by style at Power-item ranks (conduit_lens, neutral roll)\n")
    L.append("Base weapon damage %.0f; style multipliers melee %.2f, ranged %.2f, magic %.2f; luck 0, so no crit. Only the ranged R6 value is a landed hit (measured %.4f against the formula %.4f, match: %s); melee and magic are formula values.\n" % (p["base_weapon_damage"], p["style_multipliers"]["melee"], p["style_multipliers"]["ranged"], p["style_multipliers"]["magic"], m["ranged_landed"], m.get("formula", 0.0), m["matches_formula"]))
    L.append("| Power item rank | Power | Melee | Ranged | Magic |\n|---:|---:|---:|---:|---:|")
    for r in int_ranks:
        row = p["by_rank"][r]; L.append("| %s | %s | %s | %s | %s |" % (r, fmt(row["power"]), fmt(row["melee"]), fmt(row["ranged"]), fmt(row["magic"])))
    L.append("")
    L.append("## Item flat contributions by rank (total from the item, before the roll)\n")
    L.append("| Item | Slot | Set | " + " | ".join("R%s" % r for r in ranks) + " | Value R1 / R6 / R15 / R30 |")
    L.append("|---|---:|---|" + "---|" * len(ranks) + "---|")
    for iid in sorted(b["items"]):
        it = b["items"][iid]; cells = []
        for r in ranks:
            flat = {k: v for k, v in it["by_rank"][r]["flat"].items() if v}
            cells.append(", ".join("%s %s" % (k, fmt(v)) for k, v in flat.items()) or "0")
        vals = " / ".join(str(int(it["by_rank"][r]["value"])) for r in ["1", "6", "15", "30"])
        L.append("| %s | %d | %s | %s | %s |" % (iid, int(it["slot"]), it["set"] or "-", " | ".join(cells), vals))
    L.append("")
    L.append("## Sets with all six core members worn at one rank\n")
    L.append("| Set | Tier bonuses (flat) | " + " | ".join("R%s mean / strength / effects" % r for r in ["1", "6", "15", "30"]) + " |")
    L.append("|---|---|" + "---|" * 4)
    for sid in sorted(b["sets"]):
        s = b["sets"][sid]
        tiers = "; ".join("%s: %s" % (k, ", ".join("%s %s" % (f, fmt(v)) for f, v in t["mods"].items() if v) or "none") for k, t in sorted(s["tiers"].items(), key=lambda kv: int(kv[0])))
        cells = ["%s / %s / %d" % (fmt(s["by_rank"][r]["mean_rank"]), fmt(s["by_rank"][r]["strength"]), int(s["by_rank"][r]["active_effects"])) for r in ["1", "6", "15", "30"]]
        L.append("| %s | %s | %s |" % (sid, tiers, " | ".join(cells)))
    L.append("")
    a = b["attribution"]
    L.append("## Attribution coverage observed by the recorder during the probe\n")
    L.append("Origins observed: %s. Attributed share %s of %.4f enemy HP removed; set origins observed: %s.\n" % (", ".join(a["origins_observed"]) or "none", fmt(a["coverage"]["attributed_share"]), a["coverage"]["hp_removed"], ", ".join(a["set_origins_observed"]) or "none"))
    L.append("## Notes\n")
    for n in b["notes"]:
        L.append("- " + n)
    open(args.out, "w").write("\n".join(L) + "\n")
    print("wrote", args.out)


if __name__ == "__main__":
    main()
