#!/usr/bin/env python3
"""Package captured Game PNGs as silent VFR MP4 without changing their dimensions.

Usage: python tools/capture/encode_s5_teaching_capture.py --capture-dir CAPTURE
       --ffmpeg /absolute/path/to/ffmpeg --output review.mp4
Only Python's standard library is required; FFmpeg must provide libx264.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import statistics
import struct
import subprocess
import sys


def _number(value, label):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"{label} must be a finite number")
    try:
        result = float(value)
    except OverflowError as error:
        raise ValueError(f"{label} is out of range") from error
    if not math.isfinite(result):
        raise ValueError(f"{label} must be finite")
    return result


def _png_dimensions(path):
    with path.open("rb") as source:
        header = source.read(24)
    if len(header) != 24 or header[:16] != b"\x89PNG\r\n\x1a\n\0\0\0\rIHDR":
        raise ValueError(f"Invalid PNG header: {path}")
    width, height = struct.unpack(">II", header[16:24])
    if width <= 0 or height <= 0 or width % 2 or height % 2:
        raise ValueError(f"yuv420p requires positive even dimensions, without resizing: {path}")
    return [width, height]


def load_capture(directory):
    directory = Path(directory).resolve()
    info_path = directory / "capture-info.json"
    info = json.loads(info_path.read_text(encoding="utf-8-sig"))
    if not isinstance(info, dict) or not isinstance(info.get("frames"), list) or len(info["frames"]) < 2:
        raise ValueError("capture-info.json must contain at least two frame samples")
    samples = info["frames"]
    declared = info.get("captured_frames", len(samples))
    if isinstance(declared, bool) or not isinstance(declared, int) or declared != len(samples):
        raise ValueError("captured_frames does not match the frame samples")
    timestamps = []
    for index, sample in enumerate(samples):
        if not isinstance(sample, dict):
            raise ValueError(f"frames[{index}] must be an object")
        value = _number(sample.get("wall_time"), f"frames[{index}].wall_time")
        if value < 0.0 or (timestamps and value <= timestamps[-1]):
            raise ValueError("frame wall_time values must be nonnegative and strictly increasing")
        timestamps.append(value)
    wall_seconds = _number(info.get("wall_seconds"), "wall_seconds")
    if wall_seconds <= timestamps[-1]:
        raise ValueError("wall_seconds must leave a positive final frame hold")
    microseconds = [round(value * 1_000_000) for value in timestamps + [wall_seconds]]
    if any(right <= left for left, right in zip(microseconds, microseconds[1:])):
        raise ValueError("Frame/end intervals must remain positive at the capture's microsecond precision")
    paths = [directory / f"frames/frame-{index:04d}.png" for index in range(len(samples))]
    found = set((directory / "frames").glob("frame-*.png"))
    if found != set(paths) or any(not path.is_file() for path in paths):
        raise ValueError("PNG frame count/names must exactly match contiguous frame samples starting at 0000")
    dimensions = _png_dimensions(paths[0])
    for path in paths[1:]:
        if _png_dimensions(path) != dimensions:
            raise ValueError(f"Capture dimensions changed; resizing is forbidden: {path}")
    # The first observed image also covers the unrecorded leading gap. Every
    # subsequent boundary keeps its measured combat wall timestamp.
    durations = [timestamps[1]]
    durations.extend(right - left for left, right in zip(timestamps[1:], timestamps[2:]))
    durations.append(wall_seconds - timestamps[-1])
    if any(not math.isfinite(value) or value <= 0.0 for value in durations):
        raise ValueError("Every encoded frame interval must be finite and positive")
    return {"directory": directory, "info_path": info_path, "info": info,
            "frame_paths": paths, "timestamps": timestamps, "durations": durations,
            "wall_seconds": wall_seconds, "dimensions": dimensions}


def _concat_path(path):
    text = path.as_posix()
    if "\n" in text or "\r" in text:
        raise ValueError("A frame path cannot contain a newline")
    return "'" + text.replace("'", "'\\''") + "'"


def concat_text(capture):
    lines = ["ffconcat version 1.0"]
    boundaries = [0.0] + capture["timestamps"][1:] + [capture["wall_seconds"]]
    for index, path in enumerate(capture["frame_paths"]):
        duration_us = round(boundaries[index + 1] * 1_000_000) - round(boundaries[index] * 1_000_000)
        if index == len(capture["frame_paths"]) - 1:
            # A duplicate exactly at -t is discarded and MP4 otherwise assigns
            # only 1us to the previous final packet, losing the whole last hold.
            # An identical sample 1us before -t retains that hold with no tail.
            duration_us = max(1, duration_us - 1)
        duration = duration_us / 1_000_000
        lines.extend(["file " + _concat_path(path), "option framerate 1000000", f"duration {duration:.9f}"])
    lines.extend(["file " + _concat_path(capture["frame_paths"][-1]), "option framerate 1000000"])
    return "\n".join(lines) + "\n"


def build_command(ffmpeg, manifest, output, duration):
    return [str(ffmpeg), "-hide_banner", "-loglevel", "error", "-nostdin", "-y",
            "-threads", "1", "-filter_threads", "1", "-filter_complex_threads", "1",
            "-f", "concat", "-safe", "0", "-i", str(manifest), "-map", "0:v:0", "-an",
            "-fps_mode", "vfr", "-c:v", "libx264", "-preset", "ultrafast", "-crf", "18",
            "-threads", "1", "-pix_fmt", "yuv420p", "-enc_time_base", "1:1000000",
            "-video_track_timescale", "1000000", "-movflags", "+faststart",
            "-t", f"{duration:.9f}", str(output)]


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def encode(capture_dir, ffmpeg, output):
    capture = load_capture(capture_dir)
    ffmpeg, output = Path(ffmpeg).resolve(), Path(output).resolve()
    if not ffmpeg.is_file():
        raise ValueError(f"FFmpeg executable does not exist: {ffmpeg}")
    if output.suffix.lower() != ".mp4":
        raise ValueError("Output must have an .mp4 extension")
    output.parent.mkdir(parents=True, exist_ok=True)
    manifest = output.with_suffix(".ffconcat")
    manifest.write_text(concat_text(capture), encoding="utf-8")
    command = build_command(ffmpeg, manifest, output, capture["wall_seconds"])
    subprocess.run(command, check=True)
    if not output.is_file() or output.stat().st_size == 0:
        raise ValueError("FFmpeg did not produce a nonempty video")
    intervals = [right - left for left, right in zip(capture["timestamps"], capture["timestamps"][1:])]
    report = {
        "source_metadata": str(capture["info_path"]),
        "source_metadata_sha256": sha256(capture["info_path"]),
        "video": str(output), "video_sha256": sha256(output),
        "dimensions": capture["dimensions"], "source_frame_count": len(capture["frame_paths"]),
        "timing": {"source": "measured frames[].wall_time; target_capture_fps is not an encoding rate",
                   "combat_wall_seconds": capture["wall_seconds"],
                   "first_frame_wall_seconds": capture["timestamps"][0],
                   "last_frame_wall_seconds": capture["timestamps"][-1],
                   "leading_hold_seconds": capture["timestamps"][0],
                   "last_hold_seconds": capture["durations"][-1],
                   "observed_interval_min_seconds": min(intervals),
                   "observed_interval_max_seconds": max(intervals),
                   "observed_interval_mean_seconds": statistics.mean(intervals),
                   "requested_sample_fps": capture["info"].get("target_capture_fps")},
        "disclosure": "Actual captured PNG frames; silent lossy H.264/yuv420p, no resize/repaint/interpolation. "
                      "First observed frame covers the leading uncaptured gap; final frame holds to combat wall_seconds. "
                      "A terminal identical last-image sample within 1us of combat end preserves the final MP4 hold; "
                      "output is capped to measured combat wall_seconds. "
                      "Timestamps use a microsecond time base; encoding/input/filter threads are limited to one.",
        "ffmpeg": str(ffmpeg), "command": command,
        "concat": str(manifest), "concat_sha256": sha256(manifest),
        "images": [{"file": str(path.relative_to(capture["directory"])), "sha256": sha256(path),
                    "wall_time": timestamp, "display_seconds": duration}
                   for path, timestamp, duration in zip(capture["frame_paths"], capture["timestamps"], capture["durations"])],
    }
    sidecar = output.with_suffix(".encoding.json")
    sidecar.write_text(json.dumps(report, indent=2, ensure_ascii=False, allow_nan=False) + "\n", encoding="utf-8")
    return sidecar


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture-dir", required=True, type=Path)
    parser.add_argument("--ffmpeg", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    arguments = parser.parse_args(argv)
    try:
        sidecar = encode(arguments.capture_dir, arguments.ffmpeg, arguments.output)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Capture encoding failed: {error}\n")
    print(json.dumps({"video": str(arguments.output.resolve()), "sidecar": str(sidecar)}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
