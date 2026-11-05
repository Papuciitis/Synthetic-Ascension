import argparse
import hashlib
import json
from pathlib import Path
import subprocess


FPS = 30
CANVAS = '1920:1080'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('ffmpeg', type=Path)
    parser.add_argument('edit', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--cut-one', type=Path, required=True, help='Exact first-cut MP4 used for the S7 footage')
    parser.add_argument('--check', action='store_true', help='Validate input paths, source hash and runtime without rendering')
    args = parser.parse_args()
    args.ffmpeg.resolve(strict=True)
    edit = json.loads(args.edit.read_text(encoding='utf-8-sig'))
    edit_dir = args.edit.resolve().parent
    repo = Path(__file__).resolve().parents[3]

    def source_path(name):
        if name == '@cut-one':
            return args.cut_one.resolve(strict=True)
        if name.startswith('repo:'):
            return (repo / name.removeprefix('repo:')).resolve(strict=True)
        return (edit_dir / name).resolve(strict=True)

    with args.cut_one.open('rb') as original:
        if hashlib.file_digest(original, 'sha256').hexdigest() != edit['cut_one_sha256']:
            raise SystemExit('The first-cut MP4 differs from the edit recipe source')
    sources = [source_path(cut['source']) for cut in edit['cuts']]
    audio = edit['audio']
    menu, game = source_path(audio['menu']), source_path(audio['game'])
    cut_frames = [round(cut['duration'] * FPS) for cut in edit['cuts']]
    seconds = sum(cut_frames) / FPS
    if not cut_frames or min(cut_frames) <= 0 or seconds > 120:
        raise ValueError('Cut list must contain positive durations and fit within two minutes')
    if args.check:
        print(f'Validated {len(sources)} shots, both music stems and first-cut source. {seconds:.3f}s.')
        return
    root = args.output.parent
    if args.output.exists():
        raise SystemExit(f'Refusing to replace {args.output}')
    parts = root / 'parts'
    parts.mkdir(parents=True)
    ffmpeg = [str(args.ffmpeg.resolve(strict=True)), '-hide_banner', '-nostdin',
              '-loglevel', 'error', '-filter_threads', '1', '-filter_complex_threads', '1']
    encoder = ['-c:v', 'libx264', '-preset', 'veryfast', '-tune', 'zerolatency',
               '-crf', '19', '-threads', '2', '-pix_fmt', 'yuv420p',
               '-color_primaries', 'bt709', '-color_trc', 'bt709', '-colorspace', 'bt709']
    timeline = []
    for i, (cut, source, frames) in enumerate(zip(edit['cuts'], sources, cut_frames, strict=True)):
        target = parts / f'{i:02d}.mp4'
        if cut.get('still'):
            # Small camera move on documented stills. The frames remain still-photo inserts.
            effect = ("scale=2560:1440:flags=lanczos,"
                      f"zoompan=z='1+0.033*on/{frames}':x='iw/2-iw/zoom/2':"
                      f"y='ih/2-ih/zoom/2':d={frames}:s=1920x1080:fps={FPS}")
            source_args = ['-i', str(source)]
        else:
            source_args = ['-ss', str(cut.get('start', 0)), '-threads', '2', '-i', str(source)]
            effect = (f'scale={CANVAS}:force_original_aspect_ratio=decrease:flags=lanczos,'
                      f'pad={CANVAS}:(ow-iw)/2:(oh-ih)/2,fps={FPS}')
        print(f"{i+1:02d} {cut['beat']} ({frames/FPS:.2f}s)", flush=True)
        pending = target.with_suffix('.pending.mp4')
        subprocess.run(ffmpeg + ['-n'] + source_args + ['-map', '0:v:0', '-an', '-sn',
                       '-vf', effect + ',setsar=1', '-frames:v', str(frames)]
                       + encoder + [str(pending)], check=True)
        pending.rename(target)
        timeline.append((target.name, frames))
    manifest = parts / 'concat.txt'
    manifest.write_text(''.join(f"file '{name}'\n" for name, _ in timeline), encoding='ascii')
    transition = audio['crossfade_seconds']
    first = audio['menu_seconds']
    game_seconds = seconds - first + transition
    mix = (f"[1:a]atrim=duration={first},asetpts=PTS-STARTPTS[menu];"
           f"[2:a]atrim=start={audio['game_start']}:duration={game_seconds},asetpts=PTS-STARTPTS[game];"
           f"[menu][game]acrossfade=d={transition}:c1=tri:c2=tri,"
           f"afade=t=out:st={seconds-1.7}:d=1.7,loudnorm=I=-15:LRA=9:TP=-1.4,aresample=48000[mix]")
    pending_output = args.output.with_suffix('.pending.mp4')
    subprocess.run(ffmpeg + ['-n', '-f', 'concat', '-safe', '0', '-i', str(manifest),
                    '-i', str(menu), '-stream_loop', '-1',
                    '-i', str(game), '-filter_complex', mix,
                    '-map', '0:v:0', '-map', '[mix]', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '256k',
                    '-t', str(seconds), '-movflags', '+faststart', '-metadata',
                    "title=The Ascension of Syn'Tek — gameplay trailer recut", str(pending_output)], check=True)
    pending_output.rename(args.output)
    print(f'{args.output} ({seconds:.3f}s; {sum(frames for _, frames in timeline)} frames)', flush=True)


if __name__ == '__main__':
    main()
