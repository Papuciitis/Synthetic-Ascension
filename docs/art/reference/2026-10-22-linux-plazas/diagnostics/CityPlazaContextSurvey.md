# Read-only plaza context survey

External derivative of the frozen CitySegmentSurvey. Root must first run the scoped parser against the absolute .gd, then use the scene through guarded_engine.py. Preparation ran no engines.

```sh
python3 .superpowers/continuation-20261022/guarded_engine.py --label city22-plaza-context-s6 --project /tmp/sa-wp2-plazas --start-temperature 70 --timeout 420 -- --rendering-driver opengl3 --audio-driver Dummy /home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/CityPlazaContextSurvey.tscn -- --visible --segment=6 --world-seed=16102026 --theme=industrial_cutthrough --route-points=0 --kit-points=0 --plaza-points=1 --out=/var/tmp/sa-city22/plazas-context/s6
```

Use fresh output/label for each run. Seed selection remains the inherited real theme-picker search; read the resulting survey.json seed. Parent survey has Player/Spawner frozen, disables encounter beats and uses a 60 FPS cap: visual evidence only. The helper adds no points, camera moves, generation calls, nodes, styles or collisions.

Each inherited PNG save writes plaza-context.json with the exact capture filename/frame/canvas bounds, loaded plaza metadata and plans, actual piece/bed/kerb/edge node counts, and existing bed vertex alpha/source texture. Framing counts mean world-AABB intersection and visible-in-tree; they do not prove unoccluded pixels. Recommended bed focus is drawn only from a real already loaded bed node and is not visited automatically.

S2 service_courtyards seed16102026 landmark(-2,3) is a valid tended carriageway context control. Its inspected play/overview show lamps/stall/bench but no visible bed. Landmark selection alone is weak maintenance-art coverage: successful square-frame house placement suppresses low ring walls, island creation is optional and route-clearance can remove its bed. Do not claim bed/feather/worn-edge rendering from a view until an actual planned/node feature and visible pixels agree.
