"""Validate and package native city-block review runs, without resizing."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

from encode_s5_teaching_capture import encode


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--ffmpeg", type=Path, required=True)
    parser.add_argument("--evidence-root", type=Path, help="New revision directory; original evidence remains untouched")
    parser.add_argument("--runs", nargs="+", default=["normal-final", "small", "reduced", "before"])
    args = parser.parse_args()
    evidence = args.evidence_root or args.root / "docs/art/reference/2026-10-18-city-block"
    summaries = []
    expected_sources = None
    for directory in args.runs:
        folder = evidence / directory
        info = json.loads((folder / "capture-info.json").read_text(encoding="utf-8-sig"))
        run = json.loads((folder / "run-results.json").read_text(encoding="utf-8-sig"))
        if info["failures"] or info["save_writes"] or run["native_exit"] or run["timeout"] or run["diagnostics"]:
            raise ValueError(f"{directory}: native run did not complete cleanly")
        sources = {item["path"]: item["sha256"].lower() for item in run["source_hashes"]}
        if expected_sources is None:
            expected_sources = sources
        if sources != expected_sources:
            raise ValueError(f"{directory}: capture source versions differ")
        for name, digest in sources.items():
            if sha256(args.root / name) != digest:
                raise ValueError(f"{directory}: current source changed since capture: {name}")
        events = {note["event"]: note for note in info["route"] if note["event"] != "walk"}
        if not events["streamed_reload"]["equal"] or events["streamed_reload"]["unloaded_visual_instances"] != 0:
            raise ValueError(f"{directory}: streamed reload acceptance failed")
        if events["entered"]["alpha"] > 0.01 or events["entered"]["inside_count"] == 0:
            raise ValueError(f"{directory}: physical interior entry acceptance failed")
        if events["exited"]["alpha"] < 0.99 or events["exited"]["inside_count"] != 0:
            raise ValueError(f"{directory}: physical roof restoration acceptance failed")
        perimeter = [note for note in info["route"] if note.get("strict_perimeter")]
        if len(perimeter) != 5 or any(note["resolution_distance"] > 64 for note in perimeter):
            raise ValueError(f"{directory}: perimeter traversal acceptance failed")
        if info["simulation_fight_seconds"] < 11.99 or info["hits"] == 0 or info["max_projectiles"] == 0:
            raise ValueError(f"{directory}: moving fight acceptance failed")
        outside = [frame for frame in info["frames"] if frame["phase"] == "fight"]
        outside_peak_projectiles = max(frame["projectiles"] for frame in outside)
        outside_population_drop = outside[0]["enemies"] - outside[-1]["enemies"]
        if outside_peak_projectiles == 0 or outside_population_drop <= 0:
            raise ValueError(f"{directory}: outdoor frame evidence lacks projectiles or population decrease")
        video = folder / "walkthrough.mp4"
        encode(folder, args.ffmpeg, video)
        fight_start = min(frame["wall_time"] for frame in info["frames"] if frame["phase"] == "fight")
        fight_duration = info["wall_seconds"] - fight_start
        fight = folder / "fight.mp4"
        subprocess.run([str(args.ffmpeg), "-hide_banner", "-loglevel", "error", "-nostdin", "-y",
                        "-threads", "1", "-i", str(video), "-ss", str(fight_start),
                        "-t", str(fight_duration), "-an", "-c:v", "libx264", "-preset", "fast",
                        "-crf", "18", "-threads", "1", "-pix_fmt", "yuv420p", "-fps_mode", "vfr",
                        "-enc_time_base", "1:1000000", "-video_track_timescale", "1000000", "-movflags", "+faststart", str(fight)], check=True)
        clip = {"source": "walkthrough.mp4", "source_sha256": sha256(video),
                "start_wall_seconds": fight_start, "duration_wall_seconds": fight_duration,
                "file": "fight.mp4", "sha256": sha256(fight),
                "disclosure": "Native captured fight excerpt, silent H.264, no resize, interpolation or speed change. God mode and scripted input; production attacks, collision, AI and stats."}
        (folder / "fight.encoding.json").write_text(json.dumps(clip, indent=2), encoding="utf-8")
        summaries.append({"directory": directory, "review": info["review"], "size": info["image_size"],
                          "frames": info["captured_frames"], "fires": info["weapon_fires"],
                          "hits": info["hits"], "deaths": info["deaths"],
                          "initial_outside_population": info["initial_fight_population"],
                          "outside_frame_population_drop": outside_population_drop,
                          "outside_frame_projectile_peak": outside_peak_projectiles,
                          "interior_fight_seconds": info["interior_fight_seconds"],
                          "outside_fight_simulation_seconds": info["simulation_fight_seconds"],
                          "outside_fight_wall_seconds": fight_duration,
                          "process_frame_ms_median": info["process_frame_ms_median"],
                          "process_frame_ms_p95": info["process_frame_ms_p95"],
                          "reduced_motion": info["reduced_motion"], "combat_flashes": info["combat_flashes"],
                          "save_writes": info["save_writes"], "native_exit": run["native_exit"],
                          "failures": info["failures"], "diagnostics": run["diagnostics"],
                          "walkthrough": f"{directory}/walkthrough.mp4", "fight": f"{directory}/fight.mp4"})
        print(f"Packaged {directory}: {info['captured_frames']} native frames, {info['hits']} hits")
    report = {"source_hashes_match_current_files": True, "runs": summaries,
              "counter_limits": "Fires, hits and deaths count the entire walkthrough, including interior clearance. Outdoor-only projectile/population assertions use the outdoor phase's own frame samples; player attack evidence is also visible in its native footage.",
              "performance_limits": "60 fps cap; native Intel UHD Compatibility renderer with viewport readback and scripted controls. These are visual review observations, not a benchmark or evidence of an improvement in full-run loading stalls."}
    (evidence / "review-summary.json").write_text(json.dumps(report, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
