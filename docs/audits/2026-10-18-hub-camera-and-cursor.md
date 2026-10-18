# Hub camera and cursor feedback

The hub no longer shows View Beka or zoom buttons. Explicit interactions focus the relevant person, and closing or leaving the interaction returns to the previous view. Beka has a timed closeup. Mouse wheel still controls zoom and takes over from the currently displayed closeup, so wheel direction remains consistent. Reduced Motion suppresses automatic camera movement. Existing service panels cover most of the courtyard while open; the transition and return remain visible.

Three native hardware cursors replace the default white pointer: a dark and ivory outlined arrow, hand and crosshair, with an amber accent. UI scale adjusts both the asset size and its hotspot. These are existing-system SVG assets; they do not add input interception or a per-frame cursor renderer.

The focused camera regression reproduced missing focus behavior and an incorrect wheel-up direction before the fix. Final native tests passed 326 checks: HubCameraFocus 18, HubLibrary 216, HubWorld 54 and HubCrowd 38. Each returned exit 0. Library assertions retain interaction and modal coverage while replacing the obsolete toolbar expectation.

[Verification and source hashes](../art/reference/2026-10-18-hub-camera-cursor/verification.json), logs and selected native captures are committed alongside the [clean hub](../art/reference/2026-10-18-hub-camera-cursor/hub-clean-1280x720.png), [Beka interaction](../art/reference/2026-10-18-hub-camera-cursor/beka-interaction-1280x720.png) and [cursor size samples](../art/reference/2026-10-18-hub-camera-cursor/cursor-native-size-samples-960x540.png).

The cursor sample renders the exact hardware assets at their intended sizes on dark, bright and painted game ground. The operating system cursor itself was not verified in a desktop screenshot: that capture returned a different foreground surface. Native 1280 and fresh 960 captures were inspected; the 960 process exited normally, while the 1280 process was intentionally stopped after all four images were written. An earlier overlapping-renderer failure was excluded. Busy-combat human tracking and exported-build validation remain untested.

All engine runs used isolated profiles. The user's existing save and settings were not used for execution. The project configuration change adds only the CursorManager autoload; the pre-existing icon ordering edit is preserved outside this commit.
