# Original test logs copied for Linux handoff

Copied 20 October 2026 from the exact `runtime` folders named by the adjacent
result JSON records. The JSON retains original Windows paths for provenance;
these copies make stdout/stderr available in a fresh clone. Each prefix matches
its result record in the parent directory.

- `regressions-red`: expected initial failure, 8 fixtures / 6 failures.
- `loot-fixed-upper-still-red`: intermediate failure, 8 fixtures / 2 failures.
- `regressions-green`: final source, 8 fixtures / 0 failures.
- `natural-survey`: final source, 12 chunks / 0 failures.
- `planned-buildings`: final source, 20 chunks / 62 styled buildings / 0 failures.
- `parse`: final source, 549 scripts / 8 roots / 0 failures.

Red stderr is intentionally retained. Final passing stderr is empty. These are
headless structural/parse results, not native visual or gameplay approval.
Source coverage and earlier-versus-final check timing are documented in
`../../RECOVERY_STATUS.md`; the strict audit's separate JSON remains in the
parent directory.
