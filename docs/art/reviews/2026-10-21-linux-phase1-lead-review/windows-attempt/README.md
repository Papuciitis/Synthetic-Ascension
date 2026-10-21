# Guarded Windows attempt — no Game capture

The user authorized running Godot locally and asked the lead to free its own
idle helpers. Cleanup stopped 19 older Codex browser/tool helper processes;
roughly 1.2 GiB of commit headroom was recovered. Current chat/tools were kept.
Physical headroom remained variable on the 7.69 GiB machine.

[Launcher](run_native.ps1) preserves human-playtest exclusion, isolated per-process
APPDATA, exact owned-process cleanup, 150 s timeout, 900 MB private-memory ceiling,
768MB running RAM floor and 1536 MB running commit floor. Start floors are 1536 MB
RAM/3072 MB commit. These are stricter than the committed guard's defaults.

[Import record](import-run-result.json) is a real headless editor/import launch
at e4a1a8ba in the isolated managed checkout, using installed Godot 4.7.1.
It stopped for `engine_private_memory_limit`, exit-1, after 44.69 s;
peak private memory 905 MB, lowest sampled available RAM 856 MB, commit 3404 MB.
[Engine log](import-engine.log), [stdout](import-stdout.log) and
[stderr](import-stderr.log) are unchanged process outputs. Cold-start logs include
theme-load and dependent-script/type-inference errors before import completed.
Their cause was not resolved; do not relabel this as a clean import or as a
diagnosed defect in the subsequently received phase1 source.

[Prepared-prefix record](prefix-home-preflight.json) records a separate request
to run the already integrated prefix's household preview. It was not started:
available RAM 1031 MB was below the start floor. No walkthrough/capture result is
claimed. Earlier preflight-only scratch records remain local.

No Godot process was left running. These records provide a reproducible failure
limit, not Windows rendering, fresh-import, gameplay or performance acceptance.
