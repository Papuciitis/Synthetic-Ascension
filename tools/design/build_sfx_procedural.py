#!/usr/bin/env python3
"""Procedural combat-feel sounds (2026-10-04 feel pass).

The audit's juice inventory found the moments the player most needs to hear
silent: no heartbeat at low health, nothing for a multi-kill, nothing for an
elite falling. No asset existed for these, so they are synthesized here, the
same way tools/design/build_ranged_vfx.py bakes textures: deterministic
(fixed noise seeds, so a re-run writes identical files), 16-bit mono
44.1 kHz WAV, peak-normalized so the in-game level is set in
assets/audio/sfx/sfx_manifest.txt and at the call site, never in the file.

  heartbeat        player/heartbeat.wav        a "lub-dub": two low thumps,
                                               ~0.6 s; the HUD plays it once
                                               per low-health vignette pulse
  multikill_thump  enemies/multikill_thump.wav one deep thump with a soft
                                               transient, ~0.4 s (15+ kills
                                               inside 0.6 s)
  elite_down       enemies/elite_down.wav      a short bell-like sting over a
                                               small low hit, ~0.75 s

Every sound is a sum of decaying partials (sine with an exponential envelope
and a fast attack, a downward pitch glide for weight) plus a few ms of
low-passed noise for the contact click. Change a recipe, re-run, then
`godot --headless --path . --import` so Godot picks up the new file.

Run:  python3 tools/design/build_sfx_procedural.py [--only NAME ...] [--list]
Provenance: docs/art/asset-manifest.md, "Procedural combat-feel SFX".
"""

import argparse
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SFX = ROOT / "assets/audio/sfx"
RATE = 44100
PEAK = 0.89  # -1 dBFS: headroom for the mixer, level set in the manifest


def _time(seconds: float) -> np.ndarray:
    return np.arange(int(round(seconds * RATE))) / RATE


def _envelope(t: np.ndarray, attack: float, decay: float) -> np.ndarray:
    """Linear attack to 1, then exponential decay with time constant `decay`."""
    rise = np.clip(t / max(attack, 1e-6), 0.0, 1.0)
    fall = np.exp(-np.maximum(t - attack, 0.0) / decay)
    return rise * fall


def _glide_sine(t: np.ndarray, start_hz: float, end_hz: float, glide: float) -> np.ndarray:
    """A sine whose frequency falls exponentially from start to end over
    `glide` seconds: the drop is what makes a thump read as weight."""
    freq = end_hz + (start_hz - end_hz) * np.exp(-t / max(glide, 1e-6))
    phase = 2.0 * np.pi * np.cumsum(freq) / RATE
    return np.sin(phase)


def _lowpass(signal: np.ndarray, cutoff_hz: float) -> np.ndarray:
    """One-pole low-pass, enough to turn white noise into a soft click."""
    alpha = 1.0 - np.exp(-2.0 * np.pi * cutoff_hz / RATE)
    out = np.empty_like(signal)
    acc = 0.0
    for i, x in enumerate(signal):
        acc += alpha * (x - acc)
        out[i] = acc
    return out


def _click(t: np.ndarray, seed: int, cutoff_hz: float, length: float) -> np.ndarray:
    rng = np.random.default_rng(seed)
    noise = rng.uniform(-1.0, 1.0, t.size)
    return _lowpass(noise, cutoff_hz) * _envelope(t, 0.0008, length)


def _place(total: np.ndarray, part: np.ndarray, at_seconds: float) -> None:
    start = int(round(at_seconds * RATE))
    end = min(total.size, start + part.size)
    total[start:end] += part[: end - start]


def _thump(seconds: float, start_hz: float, end_hz: float, glide: float, decay: float, seed: int, click_gain: float) -> np.ndarray:
    t = _time(seconds)
    body = _glide_sine(t, start_hz, end_hz, glide) * _envelope(t, 0.004, decay)
    # The 55-120 Hz fundamental is mostly felt; laptop speakers roll off
    # below ~150 Hz, so the second and third harmonics carry the thump there.
    body += 0.38 * _glide_sine(t, start_hz * 2.0, end_hz * 2.0, glide) * _envelope(t, 0.003, decay * 0.55)
    body += 0.12 * _glide_sine(t, start_hz * 3.0, end_hz * 3.0, glide) * _envelope(t, 0.002, decay * 0.35)
    body += click_gain * _click(t, seed, 1800.0, 0.006)
    return body


def heartbeat() -> np.ndarray:
    total = np.zeros(_time(0.62).size)
    # Lub: the louder, longer beat. Dub follows ~0.21 s later, higher and softer.
    _place(total, _thump(0.30, 92.0, 58.0, 0.030, 0.060, 11, 0.12), 0.0)
    _place(total, 0.72 * _thump(0.26, 104.0, 68.0, 0.025, 0.048, 12, 0.10), 0.21)
    return total


def multikill_thump() -> np.ndarray:
    t = _time(0.42)
    total = _thump(0.42, 120.0, 50.0, 0.045, 0.110, 21, 0.18)
    # A breath of low air under the tail, so it lands as a weight, not a click.
    rng = np.random.default_rng(22)
    air = _lowpass(rng.uniform(-1.0, 1.0, t.size), 260.0) * _envelope(t, 0.010, 0.140)
    return total + 0.9 * air


def elite_down() -> np.ndarray:
    t = _time(0.78)
    total = 0.55 * _thump(0.78, 140.0, 70.0, 0.030, 0.070, 31, 0.10)
    # Bell partials (inharmonic ratios), each a little shorter than the last.
    base = 740.0
    for ratio, gain, decay in ((1.0, 0.55, 0.30), (2.76, 0.28, 0.18), (5.40, 0.14, 0.10), (8.93, 0.07, 0.06)):
        total += gain * np.sin(2.0 * np.pi * base * ratio * t) * _envelope(t, 0.002, decay)
    total += 0.10 * _click(t, 32, 4200.0, 0.004)
    return total


SOUNDS = {
    "heartbeat": ("player/heartbeat.wav", heartbeat),
    "multikill_thump": ("enemies/multikill_thump.wav", multikill_thump),
    "elite_down": ("enemies/elite_down.wav", elite_down),
}


def write_wav(path: Path, samples: np.ndarray) -> None:
    peak = float(np.max(np.abs(samples)))
    if peak > 0.0:
        samples = samples * (PEAK / peak)
    # Fade the last 4 ms so no file ends on a step.
    fade = min(samples.size, int(0.004 * RATE))
    samples[-fade:] *= np.linspace(1.0, 0.0, fade)
    pcm = np.clip(np.round(samples * 32767.0), -32768, 32767).astype("<i2")
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(pcm.tobytes())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--only", nargs="*", choices=sorted(SOUNDS), help="build only these sounds")
    parser.add_argument("--list", action="store_true", help="list the sounds and exit")
    args = parser.parse_args()
    if args.list:
        for name, (rel, _builder) in SOUNDS.items():
            print(f"{name}: {rel}")
        return
    for name in args.only or SOUNDS:
        rel, builder = SOUNDS[name]
        samples = builder()
        write_wav(SFX / rel, samples)
        print(f"wrote {rel} ({samples.size / RATE:.2f} s)")


if __name__ == "__main__":
    main()
