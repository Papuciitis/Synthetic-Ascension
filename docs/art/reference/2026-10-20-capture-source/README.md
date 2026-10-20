# Historical capture helper sources

Preserved 20 October 2026 from Windows scratch state so the Linux handoff does
not lose the capture protocol. This folder is source evidence, excluded from
Godot import. These files still contain their original scratch paths and are
**not portable launch targets**. `manifest.json` records original paths and copy
hashes; hashes identify these copies, not every historical engine run.

- `StreetEnvironmentCapture.tscn` → `StreetEnvironmentCapture.gd`: the isolated
  production ChunkManager protocol behind environment-v2. One frozen chunk,
  no Game/HUD/player/combat. It cannot prove a complete playable street.
- `CityNeighborhoodCapture.tscn` → `CityNeighborhoodCapture.gd` →
  `CityActualGenerationCapture.gd` → `CityConceptCapture.gd` → committed
  `tools/dev/S10BossTelegraphPreview.gd`: actual Game environment sampling
  protocol used for the earlier native plates, with controlled/frozen state.
- The additional original `.tscn` wrappers are retained alongside their scripts.

To reuse a helper, promote it to an appropriate committed tools location, repair
its inheritance/scene references, add Linux isolation/monitoring, and label all
new captures with current source, seed, conditions and limits. The committed
`tools/dev/CityBlockPlayablePreview.tscn` is the existing portable GDScript starting
point for gameplay/entry checks. Never treat a new run against edited code as an
exact reproduction of older evidence.
