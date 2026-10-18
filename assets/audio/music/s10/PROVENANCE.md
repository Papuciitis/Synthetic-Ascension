# S10: Containment Unravels

Original instrumental composition and procedural synthesis produced for
Synthetic Ascension on 2026-10-18. No third-party recordings, melodies, sample
packs, external services or purchased assets were used. These project-owned
renders may be used, modified and distributed with the game; there is no
third-party attribution or license dependency.

Reproduce with Python 3 + NumPy:

`python tools/audio/generate_boss_score.py`

`recipe.json` records the deterministic seeds via the generator, sample format,
tempo, duration, measured peak/RMS and SHA-256 for each delivered WAV.

All three phase arrangements share 120 BPM, D minor and an eight-bar,
sixteen-second loop. Phase 1 establishes a muted chord bed, sparse bass pulse
and short descending motif. Phase 2 adds broken chords, off-beat bass and a
backbeat. Phase 3 adds a separate answering phrase and syncopated octave bass.
These are separately rendered musical arrangements, rather than pitch/speed
variants of the existing entrance cue. Their common musical timeline allows
phase crossfades at the current loop position.

The separate 3.2-second defeat/release starts with a falling machine tone and
answers with a sustained D-minor-add9 chord. It never loops. Engine integration
plays the score on Music at five dB below the ordinary track setting and ducks
it a further seven dB during major attack warnings. SFX remains unaffected.

The separate 0.72-second phase-shift chime is an original rising three-note
synthetic latch, registered as `boss_phase_shift` on SFX at -14 dB, stable pitch,
without looping. It replaces the entrance cue only at phase changes; ordinary
entrances keep their existing recording. Its conservative level leaves the
major attack warnings above it.

Verification covers asset format/levels, loop timing, phase decisions, player
routing and interruption cleanup. No human listening session, final artistic
mix approval or dense-build warning-intelligibility approval is claimed.
