# Sustained-combat profile — 2026-09-06

## Result

The captured FPS drops are real and primarily scale with live combat population, especially active physics bodies and projectiles. The recorder can occasionally hitch, but it does not explain the sustained degradation in these captures. The next optimization target should be the process-side cost of materialized enemies under 80–130-enemy pressure, not the flow worker or report writer.

## Recorder cost

`PerformanceFlightRecorderBenchmark` ingested 100,000 synthetic samples in 1,498.08 ms: 14.981 microseconds per sample, with the history correctly bounded at 600 samples. This isolates ring-buffer/incident bookkeeping, not the half-second world snapshot.

The deterministic 120-enemy pressure benchmark now accepts `BENCHMARK_RECORDER_ENABLED=0|1` and records recorder status in its JSON. Identical workload results were:

| Arm | Frames | Process mean / p95 | Physics-step mean / p95 | Maximum recorder sample |
| --- | ---: | ---: | ---: | ---: |
| recorder off | 1,200 | 3.24 / 6.03 ms | 2.96 / 6.45 ms | 0 ms |
| recorder on, first run | 1,130 | 6.46 / 20.98 ms | 5.79 / 9.76 ms | 32.89 ms |
| recorder on, repeat | 1,200 | 2.50 / 4.16 ms | 4.56 / 7.27 ms | 3.08 ms |

The first on-run reproduced a visible recorder-sized hitch; the immediate repeat did not and was cheaper than the off-run on process p95. A hard maximum gate would therefore be an OS/load-sensitive flaky test. Production recorder behavior is unchanged. The play-session captures still show maxima of 9.96 ms and 15.59 ms, so rare snapshot tail cost remains worth watching, but it is not a stable explanation for the whole slowdown.

## Deduplicated play sessions

The 106 JSON incidents are overlapping windows, not 106 independent episodes. Samples were deduplicated by world seed and `t_usec`, yielding:

| Session seed | Incidents | Unique samples | Captured elapsed span | Process-dominant incidents | Physics-dominant incidents | Frame p50 / p95 / p99 / max |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1790782969715 | 76 | 39,850 | 1,063.8 s | 69 | 7 | 16.67 / 29.77 / 53.11 / 82.00 ms |
| 1789355614907 | 30 | 14,869 | 322.5 s | 28 | 2 | 16.67 / 25.93 / 40.11 / 77.51 ms |

The longer session provides the cleanest population curve:

| Live enemies | Samples | Frame p95 |
| --- | ---: | ---: |
| 0–39 | 24,777 | 16.67 ms |
| 40–79 | 5,776 | 25.21 ms |
| 80–119 | 8,105 | 44.93 ms |
| 120+ | 1,192 | 55.56 ms |

In that session, frame-time correlations were enemies `0.286`, active physics objects `0.284`, simulation-physics-enabled `0.273`, full-tier count `0.252`, and projectiles `0.241`. Node count was effectively unrelated (`0.005`). The shorter session had the same direction but a smaller population range: enemies `0.136`, physics objects `0.152`, and projectiles `0.119`.

Flow-field work is secondary. `flow_building` frames averaged 18.53 ms versus 17.41 ms when idle in the long session; in the shorter session they averaged 17.07 ms versus 16.67 ms. Flow snapshot correlation reached `0.131` in the long run, below combat-population signals. Recorder-overhead correlation was weak (`0.058` and `0.039`).

## Ranked diagnosis

1. **Materialized combat population / active bodies.** Frame p95 rises monotonically and steeply after 80 live enemies, while 97 of 106 incident summaries identify the process side as dominant.
2. **Projectile and full/mid-tier work coupled to the same population.** These rise with enemy count and remain plausible contributors inside the process-dominant bucket.
3. **Flow rebuild/publish work.** Measurable in one session, but too small and inconsistent to explain the sustained drops alone.
4. **Recorder world snapshots.** Capable of a rare 10–33 ms hitch, but low correlation and a clean controlled repeat rule it out as the sustained root cause.
5. **Raw node count.** No useful relationship in the longer session.

## Limits of the evidence

- Incident capture intentionally over-samples bad periods; the population curve is diagnostic, not a whole-run FPS distribution.
- `process_ms` describes the previous frame, so same-row correlations use true `frame_ms`; incident-level dominant-thread classification remains valid.
- The headless pressure benchmark's physics `delta` is fixed, so its `frame_ms` column cannot expose wall-time stalls. Its process and scheduler step timings are the comparison metrics.
- The two recorder-on benchmark results demonstrate tail variance. More repetitions or per-stage snapshot timings are needed before changing recorder production code.
