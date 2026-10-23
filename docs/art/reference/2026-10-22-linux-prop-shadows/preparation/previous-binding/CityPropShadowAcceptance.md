# External S2 prop acceptance

`CityPropShadowAcceptance.gd/.tscn` runs the actual project renderer without Game,
generation, native rendering, screenshots, or source substitution. Runtime and
Claude-owned files are unchanged. The initial binding is Claude's reported
`f0fe86b5`, with renderer SHA `c0d916b8b8d22d8cc641ac0e8fb8860ebc243f4bfaf9791f882fe5ed1f2033b9`
and ObjectiveWorldArt SHA `a5873b7bc7b0d9ad9617a6ade4bb72355c269d1ac2e31e2755131cf7a0790cbd`.

The 48 expected checks cover:

- S2 dressed Atlas crate/statue and both rotated legacy table paths across two
  chunks, using real catalog textures and uploaded MultiMesh transforms.
- Actual drawn feet at the blocked half-cell anchors, one cast containing each
  contact, a bounded orthogonal footprint along the shared sun, and farther
  reach for the tall statue than the low crate. Expectations use WorldDepthStyle
  and physical cell anchors; the test never reads `PROP_CASTS` or `PROP_BASE_LIFT`.
- Shared full-strength sun material on its absolute ground layer, suppression of
  old silhouettes, and no recursive shadow on the new ground cast.
- First-chunk retirement preserving both second-chunk casts/transforms/visuals,
  then final retirement removing every batch node.
- S1 preserving its reviewed Atlas projection and legacy offset, with no city
  ground-cast batch.
- Cast absence and ground layering for exit rite, vigil, breach, and vault.

The fixture checks geometry and ownership. It does not claim alpha-pixel contact,
native visual quality, live objective tell readability, collision simulation,
performance, or an observed save-write count.

`prop-shadow-acceptance-source.json` binds 43 scoped project inputs (including
the actual atlas, selected prop assets, objective forms and import inputs) and
five external files. This is a scoped inventory; the guarded runner also records
full provenance. The queue rejects a changed bound source before or after each
case. A later legitimate integration needs an explicitly reviewed new binding.

Root invocation, dry-run first:

```sh
python3 .superpowers/continuation-20261022/prop-shadow-acceptance-queue.py --suffix f0fe-r1
```

Only root starts engines:

```sh
python3 .superpowers/continuation-20261022/prop-shadow-acceptance-queue.py --suffix f0fe-r1 --execute
```

The queue uses fresh labels, the existing functional 70 C start gate, 900-second
guarded slot wait, 10% duty, and a 120-second engine timeout per short case. The
original runtime thermal stops remain active. Cases are serial with a 3-second
yield: six-source scoped parser, then fixture. Any failure stops the queue and
preserves raw output. A clean footer plus zero diagnostics, a complete 48/0 JSON
manifest, and unchanged sources are required before `queue.json` says passed.
Artifacts are in `/var/tmp/sa-city22/prop-shadow-acceptance/<suffix>/`; raw runs and
thermal records remain in the existing harness locations.

Preparation verification: Python AST and dry-run succeeded; a synthetic stale
renderer hash was rejected. **No Godot parser or acceptance engine has run yet.**
