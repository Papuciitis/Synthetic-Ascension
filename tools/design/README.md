# Ascension tree design tools

Design-time only; nothing here runs in the game.

- `ascension_tree_mockup.html` — interactive mock-up of the Follower-funded Ascension tree. Open it in any browser (double-click; no server). Style tabs, segment slider (drives Reach, the reconstruction floor and the refund share), editable Followers, Hub / Wardstone mode, hover for path and cost, click to buy, right-click to renounce, wheel zoom, drag pan, arrows walk, `/` searches, `F` fits. URL hash presets exist for screenshots, e.g. `#style=ranged&seg=20&balance=1500000&buy=rng_bar_rev&focus=rng_ord_act&zoom=1.5&mode=pulpit`.
- `ascension_tree_data.py` — the one source of truth for every node (id, ring, type, effect, prerequisites, exclusivity, needs). Edit this.
- `build_ascension_tree.py` — validates the graph (reachability, symmetric forks, parents, per-wedge composition) and regenerates `ascension_tree.json`, the data block inside the mock-up and the node tables inside `docs/design/ASCENSION_TREE_SPEC.md`. Run `python3 tools/design/build_ascension_tree.py` after every edit.
- `ascension_tree.json` — generated. The future Godot `AscensionNodeDef` resources are meant to be generated from it (one `.tres` per node, `data/ascension/<style>/<id>.tres`); the layout there is computed from the same (subtree, ring, order) fields, never stored.
