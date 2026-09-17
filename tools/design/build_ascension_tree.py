#!/usr/bin/env python3
"""Validate the Ascension tree data and regenerate every derived artifact.

    python3 tools/design/build_ascension_tree.py

Writes tools/design/ascension_tree.json, re-embeds the JSON into
tools/design/ascension_tree_mockup.html (between the TREE_DATA markers) and
regenerates the node tables inside docs/design/ASCENSION_TREE_SPEC.md (between
the NODE_TABLES markers). Exits non-zero on any validation problem.
"""
import json
import os
import sys
from collections import defaultdict, deque

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import ascension_tree_data as D  # noqa: E402

JSON_PATH = os.path.join(HERE, "ascension_tree.json")
HTML_PATH = os.path.join(HERE, "ascension_tree_mockup.html")
SPEC_PATH = os.path.join(ROOT, "docs", "design", "ASCENSION_TREE_SPEC.md")

RING_NODE_TYPES = {"small", "mechanic", "fork", "keystone", "active", "axiom", "revelation", "capstone", "sink"}


def fmt_cost(value):
    if value >= 1_000_000:
        return f"{value / 1_000_000:g}M"
    if value >= 1000:
        return f"{value / 1000:g}k"
    return str(value)


def base_cost(node):
    cls = D.CLASSES[node["type"]]
    bases = cls["base"]
    index = min(max(node["ring"] - 1, 0), len(bases) - 1)
    return bases[index]


def validate(nodes):
    problems = []
    by_id = {}
    for node in nodes:
        if node["id"] in by_id:
            problems.append(f"duplicate id {node['id']}")
        by_id[node["id"]] = node
    for node in nodes:
        if node["type"] not in D.CLASSES:
            problems.append(f"{node['id']}: unknown type {node['type']}")
        if not 0 <= node["ring"] <= 5:
            problems.append(f"{node['id']}: ring {node['ring']} out of range")
        for key in ("req", "req_all", "excl"):
            for other in node.get(key, []):
                if other not in by_id:
                    problems.append(f"{node['id']}: {key} names missing id {other}")
        for other in node.get("excl", []):
            if other in by_id and node["id"] not in by_id[other].get("excl", []):
                problems.append(f"{node['id']}: exclusivity with {other} is not symmetric")
        if node["type"] == "fork":
            if node.get("side") not in ("A", "B"):
                problems.append(f"{node['id']}: fork without side")
            siblings = [by_id[o] for o in node.get("excl", []) if o in by_id and by_id[o]["type"] == "fork"]
            if len(siblings) != 1:
                problems.append(f"{node['id']}: fork must have exactly one fork sibling")
            elif siblings[0]["subtree"] != node["subtree"] or siblings[0]["ring"] != node["ring"]:
                problems.append(f"{node['id']}: fork sibling in another subtree or ring")
        if node["type"] in ("mutation", "capstone"):
            parent = by_id.get(node.get("parent"))
            if parent is None or parent["type"] != "active":
                problems.append(f"{node['id']}: parent must be an active")
        if node["type"] == "capstone" and node.get("req_min", 1) != 2:
            problems.append(f"{node['id']}: capstone must need 2 of its mutations")
        if node["type"] in ("sink", "witness", "bridge", "ascendant") and node["ring"] != 5:
            problems.append(f"{node['id']}: edge type outside ring 5")
        if node["type"] == "revelation" and (node["ring"] != 4 or node.get("gate_nodes") != 8 or not node.get("op_cost")):
            problems.append(f"{node['id']}: revelation needs ring 4, gate 8 and an operating cost")
        if node["type"] == "keystone" and not node.get("price"):
            problems.append(f"{node['id']}: keystone without a price")
        if node["type"] == "small" and not 1 <= node.get("ranks", 1) <= 3:
            problems.append(f"{node['id']}: small ranks must be 1..3")
    # reachability: a node is reachable when any req is reachable and all req_all are
    reachable = {n["id"] for n in nodes if n["type"] in ("core", "doctrine")}
    changed = True
    while changed:
        changed = False
        for node in nodes:
            if node["id"] in reachable:
                continue
            any_ok = not node.get("req") or any(r in reachable for r in node["req"])
            all_ok = all(r in reachable for r in node.get("req_all", []))
            if any_ok and all_ok:
                reachable.add(node["id"])
                changed = True
    for node in nodes:
        if node["id"] not in reachable:
            problems.append(f"{node['id']}: unreachable from the core")
    # per-subtree composition
    per = defaultdict(lambda: defaultdict(int))
    for node in nodes:
        if node.get("subtree") and node["type"] != "sink":
            per[(node["style"], node["subtree"])][node["type"]] += 1
    for key, counts in sorted(per.items()):
        total = sum(counts.values())
        if not 17 <= total <= 24:
            problems.append(f"{key}: {total} nodes, expected 17..24")
        for t, expected in (("active", 1), ("revelation", 1), ("capstone", 1), ("fork", 2), ("mutation", 3)):
            if counts[t] != expected:
                problems.append(f"{key}: {counts[t]} {t}, expected {expected}")
        if counts["keystone"] > 1 or counts["axiom"] > 1:
            problems.append(f"{key}: more than one keystone or axiom")
    return problems, per


def build():
    nodes = [dict(n) for n in D.NODES]
    problems, per = validate(nodes)
    if problems:
        for p in problems:
            print("PROBLEM:", p)
        sys.exit(1)
    for node in nodes:
        node["base_cost"] = base_cost(node)
    data = {
        "version": 1,
        "rings": D.RINGS,
        "classes": D.CLASSES,
        "peak_gates": D.PEAK_GATES,
        "economy": D.ECONOMY,
        "styles": [{k: v for k, v in s.items()} for s in D.STYLES],
        "subtree_order": D.SUBTREE_ORDER,
        "bridge_open": D.BRIDGE_OPEN,
        "proc_tags": D.PROC_TAGS,
        "nodes": nodes,
    }
    text = json.dumps(data, indent=1, ensure_ascii=False)
    with open(JSON_PATH, "w", encoding="utf-8") as f:
        f.write(text + "\n")
    print(f"wrote {os.path.relpath(JSON_PATH, ROOT)}: {len(nodes)} nodes")
    embed(HTML_PATH, "<!-- TREE_DATA_START -->", "<!-- TREE_DATA_END -->",
          '<script type="application/json" id="tree-data">\n' + text.replace("</script", "<\\/script") + "\n</script>")
    embed(SPEC_PATH, "<!-- NODE_TABLES_START -->", "<!-- NODE_TABLES_END -->", node_tables(nodes, per))
    return data


def embed(path, start, end, body):
    if not os.path.exists(path):
        print(f"skip {os.path.relpath(path, ROOT)}: not present")
        return
    with open(path, encoding="utf-8") as f:
        text = f.read()
    a = text.find(start)
    b = text.find(end)
    if a < 0 or b < 0 or b < a:
        print(f"skip {os.path.relpath(path, ROOT)}: markers missing")
        return
    new = text[: a + len(start)] + "\n" + body + "\n" + text[b:]
    with open(path, "w", encoding="utf-8") as f:
        f.write(new)
    print(f"embedded into {os.path.relpath(path, ROOT)}")


def node_tables(nodes, per):
    by_id = {n["id"]: n for n in nodes}
    subtree_meta = {}
    for style in D.STYLES:
        for sub in style["subtrees"]:
            subtree_meta[(style["id"], sub["id"])] = (style, sub)
    out = []
    out.append("_Generated by `tools/design/build_ascension_tree.py` from `ascension_tree_data.py`; do not edit by hand._\n")
    for style in D.STYLES:
        out.append(f"### {style['name']}\n")
        for sub in style["subtrees"]:
            key = (style["id"], sub["id"])
            out.append(f"#### {style['name']} · {sub['name']} — *{sub['fantasy']}*\n")
            out.append(f"**What the player does differently:** {sub['input']}  ")
            out.append(f"**HUD:** {sub['hud']}\n")
            out.append("| # | id | ring | type | name | effect | needs | excl | base cost |")
            out.append("|---|---|---|---|---|---|---|---|---|")
            i = 0
            for node in nodes:
                if node.get("style") != style["id"] or node.get("subtree") != sub["id"] or node["type"] == "sink":
                    continue
                i += 1
                effect = node["effect"]
                if node.get("ranks", 1) > 1:
                    effect = f"({node['ranks']} ranks) " + effect
                if node.get("price"):
                    effect += f" **Price:** {node['price']}"
                if node.get("bounds"):
                    effect += f" **Bounds:** {node['bounds']}"
                if node.get("op_cost"):
                    effect += f" **Operating cost:** {node['op_cost']}"
                reqs = ", ".join(node.get("req", []))
                if node.get("req_min", 1) > 1:
                    reqs = f"{node['req_min']} of: {reqs}"
                if node.get("req_all"):
                    reqs += " + all of: " + ", ".join(node["req_all"])
                if node.get("gate_nodes"):
                    reqs += f"; ≥{node['gate_nodes']} nodes in subtree"
                needs = ", ".join(node.get("needs", []))
                excl = ", ".join(node.get("excl", []))
                out.append(f"| {i} | `{node['id']}` | {node['ring']} | {node['type']}{' ' + node['side'] if node.get('side') else ''} | {node['name']} | {effect} · *requires* {reqs} | {needs} | {excl} | {fmt_cost(node['base_cost'])} |")
            sinks = [n for n in nodes if n["type"] == "sink" and n.get("style") == style["id"] and n.get("subtree") == sub["id"]]
            if sinks:
                out.append("")
                out.append("Sinks in this wedge (repeatable, geometric):")
                for s in sinks:
                    out.append(f"- `{s['id']}` {s['name']}: {s['effect']} Base {fmt_cost(s['base_cost'])}, ×{s['ratio']} per rank, cap: {s['cap']}.")
            out.append("")
    out.append("### Edge: Witness, bridges, Ascendant (per style tree)\n")
    out.append("| id (as shown on the tree) | type | gutter | name | effect | requires |")
    out.append("|---|---|---|---|---|---|")
    for node in nodes:
        if node["type"] in ("witness", "bridge", "ascendant"):
            reqs = " any of " + ", ".join(node.get("req", [])) if node.get("req") else ""
            if node.get("req_all"):
                reqs += " + all of " + ", ".join(node["req_all"])
            out.append(f"| `{node['id']}` | {node['type']} | {node.get('gutter')} | {node['name']} | {node['effect']} {node.get('bounds', '')} {('**Operating cost:** ' + node['op_cost']) if node.get('op_cost') else ''} | {reqs} |")
    out.append("")
    out.append("Per-subtree composition:\n")
    out.append("| subtree | nodes | small | mechanic | fork | keystone | active | mutation | capstone | axiom | revelation |")
    out.append("|---|---|---|---|---|---|---|---|---|---|---|")
    for key, counts in sorted(per.items()):
        total = sum(counts.values())
        out.append(f"| {key[0]} · {key[1]} | {total} | {counts['small']} | {counts['mechanic']} | {counts['fork']} | {counts['keystone']} | {counts['active']} | {counts['mutation']} | {counts['capstone']} | {counts['axiom']} | {counts['revelation']} |")
    return "\n".join(out)


if __name__ == "__main__":
    build()
