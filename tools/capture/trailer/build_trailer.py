#!/usr/bin/env python3
"""Build the first gameplay trailer from a cut list (the editable project).

usage: build_trailer.py <cutlist.json> <work dir> <out.mp4>

The cut list names Movie Maker takes (MJPEG AVI + PCM audio, 1920x1080 at
60 FPS) and frame-accurate source ranges. Each cut is rendered to a visually
lossless intermediate (straight cuts; 10 ms audio fades stop clicks), cards
(title, placeholders) are rendered from PNGs, everything is concatenated, the
cleared S10 score is laid on bar lines under the game audio and ducked by it,
loudness is normalised (two-pass EBU R128) and the result is encoded as
H.264 High / AAC-LC MP4 with BT.709 tags. A Markdown cut list is written next
to the output. Edit the JSON and rerun to rebuild.

cutlist.json:
{
  "fps": 60,
  "ffmpeg": "<abs path>",
  "sources": {"street": "<abs .avi>"},
  "cuts": [
    {"id": "1a", "source": "street", "in": 812, "out": 1172, "section": "Hook",
     "what": "Charger wind-up, dash, kill", "gain_db": 0.0, "tail": 0.0,
     "crop": [x, y, w, h]},
    {"id": "P1", "card": "<abs png>", "seconds": 3.0, "section": "...", "what": "PLACEHOLDER ..."}
  ],
  "title": {"card": "<abs png>", "seconds": 7.0, "fade_in": 0.35},
  "music": [{"file": "<abs wav>", "start": 0.0, "end": 38.0, "gain_db": 0.0, "loop_seconds": 16.0}],
  "mix": {"music_gain_db": -9.0, "duck": true, "target_lufs": -14.0, "true_peak": -1.0}
}
"in"/"out" are movie frame numbers (out exclusive). A cut's "tail" lets its
game audio run on under the next cut (used for the impact under the title).
"""
import json
import subprocess
import sys
from pathlib import Path

VIDEO = ["-c:v", "libx264", "-preset", "veryfast", "-crf", "8", "-pix_fmt", "yuv420p",
         "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709", "-color_range", "tv"]
AUDIO = ["-c:a", "pcm_s16le", "-ar", "48000", "-ac", "2"]
# Movie Maker writes JPEG frames (BT.601, full range); PNG cards are RGB.
TO_709 = "scale=in_color_matrix=bt601:in_range=pc:out_color_matrix=bt709:out_range=tv,format=yuv420p"
CARD_709 = "scale=out_color_matrix=bt709:out_range=tv,format=yuv420p"


def run(cmd: list) -> str:
    done = subprocess.run(cmd, capture_output=True, text=True)
    if done.returncode != 0:
        sys.exit("ffmpeg failed:\n" + " ".join(map(str, cmd)) + "\n" + done.stderr[-3000:])
    return done.stderr


def piece_key(cut: dict, source: str, fps: int) -> str:
    src = Path(source)
    stat = src.stat()
    return json.dumps({"cut": cut, "source": str(src), "bytes": stat.st_size, "mtime": int(stat.st_mtime),
                       "fps": fps, "video": VIDEO, "audio": AUDIO, "matrix": [TO_709, CARD_709]}, sort_keys=True)


def timecode(seconds: float) -> str:
    return f"{int(seconds // 60)}:{seconds % 60:05.2f}"


def main() -> None:
    spec = json.loads(Path(sys.argv[1]).read_text())
    work, out = Path(sys.argv[2]), Path(sys.argv[3])
    work.mkdir(parents=True, exist_ok=True)
    ff, fps = spec["ffmpeg"], spec.get("fps", 60)
    pieces, rows, clock = [], [], 0.0
    tails = []  # (timeline start, wav) of audio that runs on past its cut
    entries = list(spec["cuts"]) + [dict(spec["title"], id="T", section="Title", what="SYNTHETIC ASCENSION")]
    for index, cut in enumerate(entries):
        piece = work / f"{index:02d}-{cut['id']}.mkv"
        # Re-render a piece only when its cut or source changed.
        key = piece_key(cut, cut["card"] if "card" in cut else spec["sources"][cut["source"]], fps)
        stamp = piece.with_suffix(".key")
        fresh = piece.exists() and stamp.exists() and stamp.read_text() == key
        if "card" in cut:
            seconds = float(cut["seconds"])
            fade = float(cut.get("fade_in", 0.0))
            vf = CARD_709 + (f",fade=t=in:st=0:d={fade}" if fade else "")
            if not fresh:
                run([ff, "-y", "-loop", "1", "-framerate", str(fps), "-i", cut["card"], "-f", "lavfi",
                     "-i", "anullsrc=r=48000:cl=stereo", "-t", f"{seconds}", "-vf", vf, "-r", str(fps), *VIDEO, *AUDIO, str(piece)])
            rows.append((cut, clock, seconds, cut.get("card"), None, None))
        else:
            source = spec["sources"][cut["source"]]
            first, last = int(cut["in"]), int(cut["out"])
            seconds = (last - first) / fps
            start = first / fps
            gain = float(cut.get("gain_db", 0.0))
            af = (f"atrim=start={start}:end={start + seconds},asetpts=PTS-STARTPTS,volume={gain}dB,"
                  f"afade=t=in:d=0.01,afade=t=out:st={seconds - 0.01:.4f}:d=0.01")
            graph = f"[0:v]trim=start_frame={first}:end_frame={last},setpts=PTS-STARTPTS"
            if "crop" in cut:
                # A hard punch-in on part of the real frame (e.g. the item card).
                x, y, w, h = cut["crop"]
                graph += f",crop={w}:{h}:{x}:{y},scale=1920:1080:flags=lanczos"
            graph += "[base]"
            label = "base"
            inputs = ["-i", source]
            if "overlay" in cut:
                # A caption PNG (transparent, 1920x1080) fading over the cut.
                fade = float(cut.get("overlay_fade", 0.25))
                inputs += ["-loop", "1", "-framerate", str(fps), "-i", cut["overlay"]]
                graph += (f";[1:v]format=rgba,fade=t=in:st=0:d={fade}:alpha=1,"
                          f"fade=t=out:st={seconds - fade:.4f}:d={fade}:alpha=1[ov];[base][ov]overlay=0:0:shortest=1[comp]")
                label = "comp"
            graph += f";[{label}]{TO_709}[v];[0:a]{af}[a]"
            if not fresh:
                run([ff, "-y", *inputs, "-filter_complex", graph, "-map", "[v]", "-map", "[a]",
                     "-r", str(fps), *VIDEO, *AUDIO, str(piece)])
            tail = float(cut.get("tail", 0.0))
            if tail > 0:
                tail_wav = work / f"{index:02d}-{cut['id']}-tail.wav"
                end = start + seconds
                if not (fresh and tail_wav.exists()):
                    run([ff, "-y", "-i", source, "-vn", "-af",
                         f"atrim=start={end}:end={end + tail},asetpts=PTS-STARTPTS,volume={gain}dB,afade=t=out:st=0:d={tail}",
                         *AUDIO, str(tail_wav)])
                tails.append((clock + seconds, tail_wav))
            rows.append((cut, clock, seconds, source, first, last))
        stamp.write_text(key)
        pieces.append(piece)
        clock += seconds
    total = clock

    listing = work / "concat.txt"
    listing.write_text("".join(f"file '{p}'\n" for p in pieces))
    joined = work / "joined.mkv"
    run([ff, "-y", "-f", "concat", "-safe", "0", "-i", str(listing), "-c", "copy", str(joined)])

    # Music bed: each cue loops its file from the cue start (all S10 phases
    # share one 16 s, 120 BPM timeline, so cues meeting on a bar line join).
    mix = spec.get("mix", {})
    inputs, filters, labels = [], [], []
    for n, cue in enumerate(spec.get("music", [])):
        length = float(cue["end"]) - float(cue["start"])
        inputs += ["-stream_loop", "-1", "-i", cue["file"]]
        fade_in = float(cue.get("fade_in", 0.0))
        fade_out = float(cue.get("fade_out", 0.02))
        # Phases sharing one loop timeline enter at the current loop position.
        offset = float(cue["start"]) % float(cue["loop_seconds"]) if cue.get("loop_seconds") else 0.0
        chain = (f"[{n + 1}:a]aresample=48000,aformat=channel_layouts=stereo,"
                 f"atrim={offset}:{offset + length},asetpts=PTS-STARTPTS,"
                 f"volume={float(cue.get('gain_db', 0.0)) + float(mix.get('music_gain_db', -9.0))}dB,"
                 + (f"afade=t=in:d={fade_in}," if fade_in else "")
                 + f"afade=t=out:st={max(0.0, length - fade_out):.4f}:d={fade_out},"
                 f"adelay={int(float(cue['start']) * 1000)}:all=1[m{n}]")
        filters.append(chain)
        labels.append(f"[m{n}]")
    tail_inputs = []
    for t, (at, wav) in enumerate(tails):
        tail_inputs += ["-i", str(wav)]
        k = len(spec.get("music", [])) + 1 + t
        filters.append(f"[{k}:a]adelay={int(at * 1000)}:all=1[t{t}]")
    game = "[0:a]" + "".join(f"[t{t}]" for t in range(len(tails)))
    filters.append(f"{game}amix=inputs={1 + len(tails)}:normalize=0:duration=first[game]")
    if labels:
        filters.append("".join(labels) + f"amix=inputs={len(labels)}:normalize=0:duration=longest,apad,atrim=0:{total}[bed]")
        if mix.get("duck", True):
            filters.append("[game]asplit=2[g1][key]")
            filters.append("[bed][key]sidechaincompress=threshold=0.05:ratio=4:attack=15:release=350:makeup=1[ducked]")
            filters.append("[g1][ducked]amix=inputs=2:normalize=0:duration=first[premix]")
        else:
            filters.append("[game][bed]amix=inputs=2:normalize=0:duration=first[premix]")
    else:
        filters.append("[game]anull[premix]")
    premix = work / "premix.wav"
    run([ff, "-y", "-i", str(joined), *inputs, *tail_inputs, "-filter_complex", ";".join(filters),
         "-map", "[premix]", *AUDIO, str(premix)])

    target, peak = float(mix.get("target_lufs", -14.0)), float(mix.get("true_peak", -1.0))
    probe = run([ff, "-hide_banner", "-i", str(premix), "-af",
                 f"loudnorm=I={target}:TP={peak}:LRA=11:print_format=json", "-f", "null", "-"])
    measured = json.loads(probe[probe.rindex("{"):probe.rindex("}") + 1])
    norm = (f"loudnorm=I={target}:TP={peak}:LRA=11:measured_I={measured['input_i']}:"
            f"measured_TP={measured['input_tp']}:measured_LRA={measured['input_lra']}:"
            f"measured_thresh={measured['input_thresh']}:offset={measured['target_offset']}:linear=true")
    run([ff, "-y", "-i", str(joined), "-i", str(premix), "-map", "0:v", "-map", "1:a",
         "-c:v", "libx264", "-preset", "slow", "-crf", "16", "-profile:v", "high", "-level", "4.2",
         "-pix_fmt", "yuv420p", "-r", str(fps), "-g", str(fps * 2), "-bf", "2",
         "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709", "-color_range", "tv",
         # The limiter keeps true peaks under the target after normalisation.
         "-af", norm + ",alimiter=limit=0.85:attack=5:release=60:level=disabled,aresample=48000",
         "-c:a", "aac", "-b:a", "320k", "-ar", "48000",
         "-movflags", "+faststart", "-t", f"{total}", str(out)])

    lines = ["# First trailer cut list", "",
             f"Built from `{Path(sys.argv[1]).name}`; {len(entries)} pieces, {timecode(total)} total ({total:.3f} s).", "",
             "| # | Timeline | Section | What | Source | Source frames (s) |", "| --- | --- | --- | --- | --- | --- |"]
    for cut, at, seconds, source, first, last in rows:
        where = f"{first}–{last} ({first / fps:.2f}–{last / fps:.2f} s)" if first is not None else "card"
        lines.append(f"| {cut['id']} | {timecode(at)}–{timecode(at + seconds)} | {cut.get('section', '')} | "
                     f"{cut.get('what', '')} | `{Path(source).name}` | {where} |")
    out.with_suffix(".cutlist.md").write_text("\n".join(lines) + "\n")
    print(f"{out} {total:.3f} s; loudness in {measured['input_i']} LUFS -> {target}")


if __name__ == "__main__":
    main()
