# Hit-feel comparison — 2026-09-06

## Report

The same ranged kill was exercised in four configurations:

| Arm | Time scale changes | Camera offset changes |
|---|---:|---:|
| hit-stop + camera punch | yes | yes |
| hit-stop only | yes | no |
| camera punch only | no | yes |
| neither | no | no |

The mechanisms are independent. Hit-stop is the only one that slows world
time; camera punch is the only one that displaces the view.

The comparison also found a concrete camera-punch defect. At the previous
default decay of 16 px per 60 Hz reference frame, the authored ranged (3.5 px),
kill (6 px), and hurt (12 px) kicks all returned to zero in one frame. This
made the view snap away and immediately back, matching the reported impression
of an impact "shake" that looked like a hitch. The default is now 3 px per
reference frame, giving those kicks a short visible decay tail while preserving
the 18 px cap and reduced-motion behavior.

Hit-stop remains unchanged. Its temporal feel still requires a human replay,
but the automated comparison now makes that replay unambiguous: disable camera
punch to judge hit-stop, then disable hit-stop to judge camera motion.

## Verification

`HitFeelTest.tscn` covers the four-arm matrix, independent accessibility gates,
time-scale ownership, rate limiting, and the non-zero decay tail.
