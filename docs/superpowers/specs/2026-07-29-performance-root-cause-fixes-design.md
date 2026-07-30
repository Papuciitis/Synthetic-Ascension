# Performance Root-Cause Fixes Design

## Evidence

The completed segment produced 8,086 unique frame samples. Projectile population
remained near 540 while enemy population increased. Average frame time rose from
19 ms at 0–9 enemies to 55 ms at 50–99 and 85 ms at 150–180. Flow navigation
started 288 builds but completed only two. Chunk generation reached 88 ms for a
single chunk and loaded multiple chunks synchronously.

## Changes

### Flow rebuild coalescing

An active flow build is never cancelled merely because the player moved. Player
movement updates one pending destination, and the current build completes first.
A navigation-revision change may invalidate the current build, but repeated
requests for the same revision are coalesced. Completion immediately leaves the
latest queued destination available for the normal rebuild interval.

### Population-aware ambient simulation

Ordinary ambient chase/splitter/leech actors retain full simulation close to the
player. As ambient population rises above 48, near and mid distance thresholds
shrink smoothly. Under heavy population pressure, mid-tier ambient actors run
movement/collision at 30 Hz with accumulated motion, while far-tier actors retain
their existing reduced rate.

Elites, bosses, minibosses, objectives, authored encounter actors, and snipers
remain exempt from population throttling. Hitboxes remain active for mid-tier
actors.

### Allocation-free projectile hit results

Projectile enemy queries continue to use `EnemyIndex` spatial buckets and exact
segment-circle resolution. The per-projectile result dictionary is replaced by
reusable manager fields, removing tens of thousands of temporary dictionaries
per second without changing hit order, piercing, damage, or visuals.

### Staggered chunk streaming

Chunk discovery updates a deduplicated generation queue instead of generating an
entire missing row synchronously. The central chunk is created immediately on an
empty world; remaining chunks are sorted nearest-first and generated at a
configurable default of one per frame. Obsolete queued chunks are discarded
when the player moves.

## Validation

Tests cover flow coalescing, protected LOD behavior, mid-tier scheduling,
allocation-free projectile hit selection, nearest-first bounded chunk queueing,
and existing lifecycle rules. Existing recorder and overlay tests remain green.
The grunt and projectile benchmarks are rerun, followed by a full project parse.

Runtime success is measured by repeating the same 550-projectile/180-grunt
segment and comparing recorder bins, flow completion ratio, and chunk peaks.
