# Prop uploaded-transform acceptance: native execution correction

The actual `9b7-r1` headless fixture failed **25 passed / 15 failed**, with 40 checks executed. This remains a failed run. The original fixture `1c22d005`, driver `c6bed6ce`, metadata `34a1c6af`, and failed JSON outputs are preserved here without modifying their original paths. `source.json` binds the original raw/guard/acceptance hashes.

The raw engine banner identifies `v4.7.2.stable.official.ed1daf0bf`; its command contains `--headless`. In that exact [Godot commit's dummy mesh storage](https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf/servers/rendering/dummy/storage/mesh_storage.h), line174 ignores the per-instance setter and line183 returns identity from its getter:

```cpp
virtual void _multimesh_instance_set_transform_2d(RID p_multimesh, int p_index, const Transform2D &p_transform) override {}
virtual Transform2D _multimesh_instance_get_transform_2d(RID p_multimesh, int p_index) const override { return Transform2D(); }
```

The renderer's `_sync_batch` sets individual transforms; the external fixture reads their uploaded getters. All four actual anchors differ from identity, every suppressed shadow requires zero basis rather than identity, and the four ground contacts cannot lie inside an identity-sized rectangle at origin. These explain the12 per-prop failures. Their early-continue skips two further checks per prop (48−8=40); absent reaches cause the tall/crate failure, and identity also fails both S1 projection controls. The owner33 test reads CPU `batch.transforms`/`shadow_transforms`, so its clean result tests a different boundary. The headless survivor check can pass on identical identity values and establishes no uploaded-transform preservation. The original acceptance JSON records check booleans, not observed matrices; identity behavior is established by exact engine source, not invented observations.

`queue.py` launches **one** fresh native fixture after revalidating and reusing the existing clean exact-source six-source parser `city22-prop-shadow-parse-9b7-r1`. No duplicate parser engine or canary engine is added. The driver is dry-run by default:

```sh
python3 -B .superpowers/continuation-20261022/prop-shadow-native-r2/queue.py
python3 -B .superpowers/continuation-20261022/prop-shadow-native-r2/queue.py --execute
```

Root reviews before executing. The default fresh label is `city22-prop-shadow-fixture-9b7-native-r2`; outputs go to `/var/tmp/sa-city22/prop-shadow-acceptance/9b7-native-r2`.

The command explicitly requests OpenGL3/gl_compatibility, Dummy audio, windowed640×360 and max-fps20. CLI cap/window alone are insufficient: `SettingsManager._ready` applies saved frame limits and display state after [Godot main.cpp lines2123–2125](https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf/main/main.cpp) set the CLI FPS cap. Therefore a tiny inherited `NativePropShadowAcceptance.gd` sets only actual cap/window after autoloads, writes one bounded backend/cap/window/physics observation, then invokes unchanged parent `_ready`. It overrides no `_run`, `_check`, city/S1/retirement/ground assertion, transform, shader, material or renderer code. All48 original predicates remain byte-identical in the preserved parent. The extra envelope parses in the same native engine; any parser/runtime diagnostic rejects its result.

The functional guard remains65°C start,25% duty,900s maximum wait,300s timeout, unchanged90°C/85°C×3 stops, no release marker. Acceptance requires the actual hardware OpenGL banner, actual boot state20FPS/640×360/windowed/OpenGL3/physics60, raw source bindings, all48 checks clean and source restoration/equality. This is functional uploaded-transform evidence; no performance claim. Actual native/parser results remain pending root execution.
