"""Standard-library tests; optional real encoding uses S5_TEST_FFMPEG."""
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib

sys.dont_write_bytecode = True
ENCODER_PATH = Path(__file__).resolve().parents[1] / "capture/encode_s5_teaching_capture.py"
ENCODER = None
if ENCODER_PATH.is_file():
    spec = importlib.util.spec_from_file_location("s5_capture_encoder", ENCODER_PATH)
    ENCODER = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(ENCODER)


def png(width=2, height=2, value=90):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    scanlines = b"".join(b"\0" + bytes([value, value, value]) * width for _ in range(height))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(scanlines)) + chunk(b"IEND", b""))


class CaptureEncoderTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="s5 capture ' timing ")
        self.addCleanup(self.temp.cleanup)
        self.capture = Path(self.temp.name)
        (self.capture / "frames").mkdir()
        self.info = {"wall_seconds": 1.5, "target_capture_fps": 99, "captured_frames": 3,
                     "frames": [{"wall_time": value} for value in [0.125, 0.375, 1.125]]}
        for index in range(3):
            (self.capture / f"frames/frame-{index:04d}.png").write_bytes(png(value=40 + index * 50))
        self.write_info()

    def encoder(self):
        self.assertIsNotNone(ENCODER, "capture encoder is not implemented")
        return ENCODER

    def write_info(self):
        (self.capture / "capture-info.json").write_text(json.dumps(self.info), encoding="utf-8")

    def test_measured_intervals_preserve_initial_and_final_holds(self):
        capture = self.encoder().load_capture(self.capture)
        self.assertEqual(capture["durations"], [0.375, 0.75, 0.375])
        self.assertAlmostEqual(sum(capture["durations"]), 1.5)
        self.assertEqual(capture["timestamps"], [0.125, 0.375, 1.125])
        self.assertEqual(capture["dimensions"], [2, 2])

    def test_rejects_nonmonotonic_nonfinite_or_nonnumeric_times(self):
        encoder = self.encoder()
        for values in [[0.1, 0.1, 1.1], [0.3, 0.2, 1.1], [-0.1, 0.3, 1.1],
                       [0.1, math.nan, 1.1], [0.1, math.inf, 1.1], [False, 0.3, 1.1], ["0.1", 0.3, 1.1],
                       [0.1, 0.10000000001, 1.1]]:
            with self.subTest(times=values):
                self.info["frames"] = [{"wall_time": value} for value in values]
                self.write_info()
                with self.assertRaises(ValueError):
                    encoder.load_capture(self.capture)

    def test_rejects_invalid_combat_end_or_frame_declaration(self):
        encoder = self.encoder()
        for wall_end in [1.125, 1.0, math.inf, math.nan, True]:
            with self.subTest(wall_seconds=wall_end):
                self.info["wall_seconds"] = wall_end
                self.write_info()
                with self.assertRaises(ValueError):
                    encoder.load_capture(self.capture)
        self.info["wall_seconds"] = 1.5
        self.info["captured_frames"] = 4
        self.write_info()
        with self.assertRaises(ValueError):
            encoder.load_capture(self.capture)

    def test_requires_matching_contiguous_images_and_multiple_frames(self):
        encoder = self.encoder()
        last = self.capture / "frames/frame-0002.png"
        last.rename(self.capture / "frames/frame-0003.png")
        with self.assertRaises(ValueError):
            encoder.load_capture(self.capture)
        self.info["frames"] = self.info["frames"][:1]
        self.info["captured_frames"] = 1
        self.write_info()
        with self.assertRaises(ValueError):
            encoder.load_capture(self.capture)

    def test_rejects_odd_mixed_or_invalid_png_dimensions(self):
        encoder = self.encoder()
        for data in [png(3, 2), png(4, 2), b"invalid png"]:
            with self.subTest(data=data[:24]):
                (self.capture / "frames/frame-0001.png").write_bytes(data)
                with self.assertRaises(ValueError):
                    encoder.load_capture(self.capture)

    def test_concat_escapes_paths_and_does_not_use_requested_fps(self):
        encoder = self.encoder()
        capture = encoder.load_capture(self.capture)
        text = encoder.concat_text(capture)
        self.assertTrue(text.startswith("ffconcat version 1.0\n"))
        self.assertIn("'\\''", text)
        self.assertIn("duration 0.750000000", text)
        capture["info"]["target_capture_fps"] = 4
        self.assertEqual(text, encoder.concat_text(capture))
        self.assertEqual(text.count("file "), 4)

    def test_command_is_silent_single_thread_vfr_and_capped_without_resize(self):
        command = self.encoder().build_command(Path("ffmpeg.exe"), Path("input.ffconcat"), Path("output.mp4"), 1.5)
        self.assertEqual(command[command.index("-c:v") + 1], "libx264")
        self.assertEqual(command[command.index("-pix_fmt") + 1], "yuv420p")
        self.assertEqual(command[command.index("-fps_mode") + 1], "vfr")
        self.assertEqual(command[command.index("-t") + 1], "1.500000000")
        self.assertIn("-an", command)
        self.assertIn("+faststart", command)
        for index, value in enumerate(command):
            if value in ["-threads", "-filter_threads", "-filter_complex_threads"]:
                self.assertEqual(command[index + 1], "1")
        self.assertTrue("-threads" in command and "-filter_threads" in command)
        self.assertFalse(any(value in command for value in ["-vf", "-s", "-r", "-framerate"]))

    @unittest.skipUnless(os.environ.get("S5_TEST_FFMPEG"), "set S5_TEST_FFMPEG for tiny real-video packaging test")
    def test_real_ffmpeg_timestamps_end_duration_and_hash_disclosure(self):
        ffmpeg = Path(os.environ["S5_TEST_FFMPEG"])
        output = self.capture / "encoded.mp4"
        sidecar = self.encoder().encode(self.capture, ffmpeg, output)
        report = json.loads(sidecar.read_text(encoding="utf-8"))
        self.assertEqual(report["video_sha256"], hashlib.sha256(output.read_bytes()).hexdigest())
        self.assertEqual(len(report["images"]), 3)
        self.assertEqual(report["images"][0]["sha256"], hashlib.sha256((self.capture / "frames/frame-0000.png").read_bytes()).hexdigest())
        self.assertEqual(report["source_metadata_sha256"], hashlib.sha256((self.capture / "capture-info.json").read_bytes()).hexdigest())
        self.assertEqual(report["timing"]["leading_hold_seconds"], 0.125)
        self.assertEqual(report["timing"]["last_hold_seconds"], 0.375)
        result = subprocess.run([str(ffmpeg), "-v", "error", "-i", str(output), "-map", "0:v:0",
                                 "-c", "copy", "-f", "framecrc", "-"], check=True, capture_output=True, text=True)
        base = next(line.split()[-1] for line in result.stdout.splitlines() if line.startswith("#tb"))
        numerator, denominator = map(int, base.split("/"))
        time_base = numerator / denominator
        packets = [line.split(",") for line in result.stdout.splitlines() if line and not line.startswith("#")]
        times = [int(packet[2]) * time_base for packet in packets]
        for observed, expected in zip(times[:3], [0.0, 0.375, 1.125]):
            self.assertAlmostEqual(observed, expected, delta=0.00001)
        end = max((int(packet[2]) + int(packet[3])) * time_base for packet in packets)
        self.assertAlmostEqual(end, 1.5, delta=0.001)


if __name__ == "__main__":
    unittest.main()
