"""Deterministic original S10 score. Python 3 + NumPy; no samples or network.

Run from any directory. Commits the rendered WAVs, not runtime synthesis.
All phases share 120 BPM / 8 bars / D minor so crossfades retain musical time.
"""
from pathlib import Path
import hashlib
import io
import json
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "assets/audio/music/s10"
RATE = 22050
BEAT = 0.5
LENGTH = 16.0


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def tone(track, start, duration, midi, gain, pan=0.0, kind="pluck"):
    count = int(duration * RATE)
    t = np.arange(count) / RATE
    f = hz(midi)
    if kind == "pad":
        signal = np.sin(2 * np.pi * f * t) + .22 * np.sin(2 * np.pi * f * 2 * t)
        env = np.minimum(t / .16, 1) * np.minimum((duration - t) / .20, 1)
    elif kind == "bass":
        signal = np.sin(2 * np.pi * f * t) + .3 * np.sin(2 * np.pi * f * 2 * t)
        env = np.minimum(t / .008, 1) * np.exp(-t * 7) * np.minimum((duration - t) / .035, 1)
    else:
        # Deliberately warm upper-register voice: avoid broad warning-band fizz.
        signal = np.sin(2 * np.pi * f * t) + .18 * np.sin(2 * np.pi * f * 3 * t)
        env = np.minimum(t / .012, 1) * np.exp(-t * 4) * np.minimum((duration - t) / .05, 1)
    add(track, start, signal * np.clip(env, 0, 1) * gain, pan)


def add(track, start, mono, pan=0.0):
    first = int(start * RATE)
    count = min(len(mono), len(track) - first)
    if count <= 0:
        return
    track[first:first + count, 0] += mono[:count] * np.sqrt((1 - pan) / 2)
    track[first:first + count, 1] += mono[:count] * np.sqrt((1 + pan) / 2)


def drum(track, start, kind, gain, rng):
    duration = .20 if kind == "kick" else .10
    t = np.arange(int(duration * RATE)) / RATE
    if kind == "kick":
        phase = 2 * np.pi * (49 * t + 42 * .022 * (1 - np.exp(-t / .022)))
        mono = np.sin(phase) * np.exp(-t * 23)
    else:
        noise = rng.uniform(-1, 1, len(t))
        # Smooth the deterministic noise, leaving room for metal warning attacks.
        noise = np.convolve(noise, np.ones(7) / 7, mode="same")
        mono = (noise + .28 * np.sin(2 * np.pi * 185 * t)) * np.exp(-t * 42)
    add(track, start, mono * gain)


def phase_score(phase):
    track = np.zeros((int(LENGTH * RATE), 2))
    rng = np.random.default_rng(10810 + phase)
    # Eight bars: Dm(add9), Bbmaj7, Gm(add9), Asus -> A minor. Two bars each.
    roots = [38, 38, 34, 34, 31, 31, 33, 33]
    chords = [[50, 53, 57, 64], [50, 53, 57, 64],
              [46, 50, 53, 57], [46, 50, 53, 57],
              [43, 46, 50, 57], [43, 46, 50, 57],
              [45, 50, 52, 57], [45, 48, 52, 57]]
    motif = [74, 69, 72, 65, 70, 65, 69, 64]
    for bar in range(8):
        start = bar * 4 * BEAT
        for i, note in enumerate(chords[bar]):
            tone(track, start, 1.96, note, .032, (i - 1.5) * .36, "pad")
        bass_steps = [0, 2] if phase == 0 else ([0, 1.5, 2, 3.5] if phase == 1 else [0, .75, 1.5, 2, 2.75, 3.5])
        for beat in bass_steps:
            tone(track, start + beat * BEAT, .23, roots[bar], .30 if phase else .25, kind="bass")
        for beat in ([0, 2] if phase == 0 else [0, 1, 2, 3]):
            drum(track, start + beat * BEAT, "kick", .28, rng)
        if phase >= 1:
            for beat in [1, 3]:
                drum(track, start + beat * BEAT, "snare", .19, rng)
            # A composed broken chord part, absent from phase one.
            for step in range(8):
                note = chords[bar][[0, 2, 1, 3, 2, 1, 3, 2][step]] + 12
                tone(track, start + step * .25, .22, note, .075, -.35 if step % 2 else .35)
        tone(track, start + .5, .65, motif[bar], .09, -.12)
        if phase == 2:
            # New answering phrase and syncopated octave bass, not a speed edit.
            for beat, interval in [(1.5, 7), (2.5, 3), (3.25, 2)]:
                tone(track, start + beat * BEAT, .3, motif[bar] + interval - 12, .105, .30)
            tone(track, start + 1.875, .12, roots[bar] + 12, .14, kind="bass")
    # All notes end in silence at the bar line: the fixed sample-exact loop has
    # no MP3 padding or mismatched lengths. 12ms boundary fades prevent clicks.
    edge = int(.012 * RATE)
    track[:edge] *= np.linspace(0, 1, edge)[:, None]
    track[-edge:] *= np.linspace(1, 0, edge)[:, None]
    return track


def release_score():
    duration = 3.2
    track = np.zeros((int(duration * RATE), 2))
    rng = np.random.default_rng(10899)
    drum(track, 0, "kick", .45, rng)
    t = np.arange(int(.7 * RATE)) / RATE
    # Descending machine power-down, followed by a spacious Dm(add9) answer.
    phase = 2 * np.pi * (42 * t + 140 * .11 * (1 - np.exp(-t / .11)))
    add(track, 0, .22 * np.sin(phase) * np.exp(-t * 6))
    for i, note in enumerate([50, 57, 62, 65, 76]):
        tone(track, .24 + i * .08, 2.5, note, .09, (i - 2) * .3, "pad")
    return track


def phase_chime():
    track = np.zeros((int(.72 * RATE), 2))
    # A brief dissonant rising latch: distinct from the long entrance hit and
    # the defeat's falling machine tone. Stable pitch keeps it recognizable.
    for start, midi, pan in [(0, 74, -.4), (.07, 75, 0), (.14, 81, .4)]:
        tone(track, start, .48, midi, .18, pan)
    return track


def write(name, track, peak_db):
    peak = np.max(np.abs(track))
    track *= (10 ** (peak_db / 20)) / peak
    pcm = np.round(np.clip(track, -1, 1) * 32767).astype("<i2")
    path = DEST / name
    encoded = io.BytesIO()
    with wave.open(encoded, "wb") as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(pcm.tobytes())
    # Leave identical deliverables untouched (also avoids editor source locks
    # and unnecessary imports when extending the score with a new cue).
    payload = encoded.getvalue()
    if not path.exists() or path.read_bytes() != payload:
        path.write_bytes(payload)
    return {"file": name, "seconds": len(track) / RATE, "peak_dbfs": round(float(20 * np.log10(np.max(np.abs(pcm)) / 32767)), 3),
            "rms_dbfs": round(float(20 * np.log10(np.sqrt(np.mean((pcm.astype(float) / 32767) ** 2)))), 3),
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


if __name__ == "__main__":
    DEST.mkdir(parents=True, exist_ok=True)
    assets = [write(f"main_phase_{phase + 1}.wav", phase_score(phase), -7 + phase) for phase in range(3)]
    assets.append(write("defeat_release.wav", release_score(), -6))
    assets.append(write("phase_shift.wav", phase_chime(), -7))
    (DEST / "recipe.json").write_text(json.dumps({"origin": "Original procedural composition and synthesis, no third-party samples", "generator": "tools/audio/generate_boss_score.py", "sample_rate": RATE, "bpm": 120, "bars_per_loop": 8, "channels": 2, "assets": assets}, indent=2) + "\n")
    print(json.dumps(assets, indent=2))
