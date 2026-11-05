# First trailer: resumed Windows checks, 4 November 2026

The current upstream tip was still `d7cfb52f`. This pass left the local yard
preview off by default and changed the [first-trailer shot plan](../../art/2026-11-04-first-trailer-shot-plan.md)
to start with one ordinary street-combat recording. No new footage was captured.

| Check | Observed result | Raw record |
| --- | --- | --- |
| One-house asset-only import | Passed the 832 MiB start floor with 1016.54 MiB free. The guard stopped the owned engine after 11.7 s at 410 MiB sampled private memory against the 384 MiB cap. Exit −1; no imported textures or qualified overlay. | [Receipt](house-import-receipt.json), [stdout](house-import-stdout.log), [stderr](house-import-stderr.log) |
| Whole-project parse | Refused before launch at 1387 MiB available RAM against the 1536 MiB start floor. Commit headroom passed. The 1389 MiB figure in the receipt is a separate reading before the decisive check. | [Receipt](project-parse-result.json), [selected source pins](project-parse-source-pins.json) |

No limits were changed. Both attempts ended with no Godot process left running.
The house fixture preparation is committed at `feb91746`. The import launcher,
parse harness and one-house native comparison remain local experiments: the
import failure prevented the parse and native runs. Their working files and
the full run records remain in this worktree (`.rh/i-03` and the existing
`.superpowers/sdd/2026-11-04-trailer-yard-preview` workspace). Do not treat host
verification or an incomplete import as evidence of the house's appearance.

For the trailer, rehearse with the current source on the production machine.
Judge the yard separately in the generated city before deciding to film with
the preview. The older repair ZIP is a separate build and is absent from this
Windows worktree.
