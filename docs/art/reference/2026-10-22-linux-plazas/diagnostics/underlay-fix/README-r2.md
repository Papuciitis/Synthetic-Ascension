# Fresh executor after cancelled pre-runtime attempt

The original queued RED attempt was cancelled before any Godot or runtime write. Its original driver, manifest and README remain unchanged and have exact archived copies under `executor-r1-preserved/`; `root-underlay-execution.json` and `pre-runtime-executor-cancellation.json` retain that cancellation. There is no logical RED verdict from the first attempt.

Use only the fresh executor:

```bash
python3 -B /home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/plaza-bed-underlay-fix/root-underlay-red-green-r2.py
python3 -B /home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/plaza-bed-underlay-fix/root-underlay-red-green-r2.py --execute
```

The installed focused test, proposed runtime bytes, assertion manifest, discovery helper and native observer are unchanged. The executor reads `manifest-r2.json`, uses fresh `city22-plaza-underlay-red-r2` / `green-r2` labels and `underlay-red-r2.json` / `green-r2.json` outputs, and writes `root-underlay-execution-r2.json`. The unused tools-parse-r2 and discovery-r2 labels stay unchanged for the separate native driver's exact bindings.

Before any automatic rollback after unclean GREEN, the fresh driver requires the last guard's final JSON to be newer than that exact launch, from the same reviewed guard source, for the same label/project/engine arguments, with a recognized final completed/thermal/INT/TERM result. Missing or uncertain cleanup leaves the fixed runtime bytes intact and records `cleanup_error` for root's owned-process investigation. The raw launch SHA loop now checks both installed test files as well as all seven runtime scripts. Ten tiny JSON/byte fixture checks validate those cleanup gates; no process or engine was launched by those checks.

Predictions remain strict RED 29 passed / 8 failed, then GREEN 37 passed / 0 failed, with no extra errors or saves. All setup runs retain 65 C start and 25% duty. Fresh discovery and r2 native/visual gates remain as documented in the original causal README; original full-audit diagnostics remain qualified separately.
