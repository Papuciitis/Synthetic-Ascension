# Bed discovery and actual-Game capture

Source-only preparation. Root must scoped-parse BOTH absolute .gd files with the existing source_parse_probe.tscn first. No whole PlazaPresentationTest rerun is needed.

```sh
python3 .superpowers/continuation-20261022/guarded_engine.py --label city22-plaza-bed-discovery --project /tmp/sa-wp2-plazas --start-temperature 70 --timeout 600 -- --headless /home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/PlazaBedDiscovery.tscn -- --out=/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/plaza-bed-discovery.json
```

Discovery is bounded to8naturally matching seeds per family (search1..400), first sorted coord per existing planned plaza role, stops at first actual Polygon2D bed per family. It calls the original `_fixture(theme,plan,coord,true)` once at a time, frees each manager immediately, clears the fixture refs and yields. It restores PLAZA.enabled=true and uses no HUD. Results include attemptseed, distinct planseed, coord, role, state, actual fixture node bounds, plan bed rect and candidate camera. This is not native visual proof; fixture splat is disabled just like the original test.

For each returned family, run a fresh native target; its exact real segment/attemptseed/camera come from discovery, never from forced styles:

```sh
python3 .superpowers/continuation-20261022/guarded_engine.py --label city22-plaza-bed-native-s6 --project /tmp/sa-wp2-plazas --start-temperature 70 --timeout 420 -- --rendering-driver opengl3 --audio-driver Dummy /home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/PlazaBedGamePreview.tscn -- --visible --review=normal --render-fps=20 --discovery=/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/plaza-bed-discovery.json --family=industrial_cutthrough --out=/var/tmp/sa-city22/plaza-beds/s6
```

Use canal_services and military_staging with fresh labels/outputs for the other families. The inherited actual Game ground-context fixture streams the selected chunk out/back, freezes streaming after reload, keeps normal optional props/HUD, and captures ground-before.png. Before capture the helper requires actual family/state/role, exact planned bed rect, and an actual bed node whose bounds contain the focus. If any is absent, it fails. It adds no nodes or forced styles.

Read `bed-validation.json`, parent `capture-info.json`, guard diagnostics and the actual PNG. Default render cap20FPS, physics remain60Hz. Ambient spawner/encounter beats are disabled by the parent; this is frozen visual/reload evidence, not live traversal or performance proof. Source hashes and original fixture/preview identities are in the metadata and runtime manifests. Nothing is an actual bed success until root executes and inspects it.
