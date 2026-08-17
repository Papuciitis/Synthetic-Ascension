# Developer Flight Recorder Auto-Arm Design

## Goal

Capture startup and early-game frame drops for every developer-launched run without enabling the recorder for ordinary runs.

## Decision

`MainMenu` will arm developer performance capture before changing scenes. Every developer run, including the direct-game, isolated-segment, and developer-hub paths, enables `PerformanceFlightRecorder`. Each launch path continues to control whether the performance overlay is shown; overlay visibility no longer controls whether samples are recorded.

Returning to the main menu and ordinary run paths continue to disable the recorder. Existing automatic thresholds, ten-second history, five-second aftermath, recovery/rearm behavior, and report directory remain unchanged.

## Interface

`MainMenu` gains one small method that applies the developer-capture policy:

```gdscript
func arm_developer_flight_recorder() -> void
```

It enables the recorder without changing overlay state. Both committed developer launch paths call it before navigating away from the menu; the isolated-segment path delegates to the direct-game path and therefore inherits the same behavior.

## Verification

A focused integration test instantiates the real main menu and verifies:

- the menu starts with capture disabled;
- arming a developer run enables automatic recording while leaving overlay state unchanged;
- both hidden and visible overlay states remain intact after arming.

The existing flight-recorder and developer-console suites remain green.
