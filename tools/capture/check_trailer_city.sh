#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 2 || $1 != /* || $2 != /* ]]; then
    echo "Usage: bash $0 /absolute/path/to/godot /absolute/new-output-directory" >&2
    exit 2
fi

engine=$1
output=$2
project=$(cd -- "$(dirname -- "$0")/../.." && pwd -P)
if [[ ! -f $engine || ! -x $engine ]]; then
    echo "Godot executable not found: $engine" >&2
    exit 2
fi
for command in xvfb-run timeout python3; do
    command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; exit 2; }
done

# Each candidate needs a fresh directory so stale captures cannot pass.
mkdir -p -- "$(dirname -- "$output")"
mkdir -- "$output"
for review in normal small; do
    case_dir="$output/$review"
    mkdir -p -- "$case_dir/xdg-config" "$case_dir/xdg-data" "$case_dir/xdg-cache" "$case_dir/xdg-state"
    if env -u SA_YARD_SUPPORT_PREVIEW \
        XDG_CONFIG_HOME="$case_dir/xdg-config" XDG_DATA_HOME="$case_dir/xdg-data" \
        XDG_CACHE_HOME="$case_dir/xdg-cache" XDG_STATE_HOME="$case_dir/xdg-state" \
        LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
        timeout --kill-after=15s 180s xvfb-run -a -s '-screen 0 1920x1080x24' \
        "$engine" --path "$project" --display-driver x11 --rendering-method gl_compatibility \
        --audio-driver Dummy --fixed-fps 20 --flush-output \
        res://tools/dev/CityBlockPlayablePreview.tscn -- \
        --visible --segment=7 --world-seed=16102028 --ground-context=-1632,1304 \
        --ground-player=-1184,1312 \
        "--review=$review" "--out=$case_dir" >"$case_dir/stdout.log" 2>&1; then
        :
    else
        status=$?
        echo "$review capture exited $status. See $case_dir/stdout.log" >&2
        exit "$status"
    fi
done

python3 - "$output" <<'PY'
import json
from pathlib import Path
import re
import struct
import sys

output = Path(sys.argv[1])
grounds = []
for review, size in (("normal", (1280, 720)), ("small", (960, 540))):
    case_dir = output / review

    def require(condition, message):
        if not condition:
            raise SystemExit(f"{case_dir}: {message}")

    log = (case_dir / "stdout.log").read_text(encoding="utf-8", errors="replace")
    log = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", log)
    # The Xvfb driver cannot switch V-Sync. The still probe uses fixed steps.
    expected_vsync = "WARNING: Could not set V-Sync mode, as changing V-Sync mode is not supported by the graphics driver."
    other_lines = [line for line in log.splitlines() if line.strip() != expected_vsync]
    require(not any(re.match(r"\s*(?:(?:SCRIPT|SHADER|USER) )?(?:ERROR|WARNING):", line) for line in other_lines),
            "engine diagnostics in stdout.log")
    summary = "CityGroundReview: segment=7 seed=16102028 context=true frames=0 fires=0 hits=0 failures=0"
    require(log.splitlines().count(summary) == 1, "missing clean staged-ground completion summary")

    info = json.loads((case_dir / "capture-info.json").read_text(encoding="utf-8"))
    require(info["scene"] == "res://scenes/game.tscn"
            and info["capture_scene"] == "res://tools/dev/CityBlockPlayablePreview.tscn" and info["review"] == review
            and info["segment"] == 7 and info["attempt_seed"] == 16102028
            and info["district_family"] == "canal_services" and info["ground_review"]
            and info["ground_context_world_px"] == [-1632, 1304]
            and info["camera"]["position"] == "(-1632.0, 1304.0)"
            and info["camera"]["window"] == str(size), "wrong scene, location or window size")
    player_x, player_y = info["player_world_px"]
    require(abs(player_x + 1184) <= 64 and abs(player_y - 1312) <= 64,
            "player did not stage on the selected street")
    require(info["save_writes"] == 0 and info["failures"] == 0 and info["scripted_input"]
            and not info["ambient_spawner"] and not info["occupied_comparison"] and not info["reduced_motion"],
            "unexpected save write, failure or capture mode")
    require(info["fixture"]["renderer"] == "gl_compatibility"
            and "llvmpipe" in info["fixture"]["video_adapter"].lower(), "expected software Mesa OpenGL renderer")
    reloads = [event for event in info["route"] if event["event"] == "ground_context_streamed_reload"]
    require(len(reloads) == 1 and reloads[0]["coord"] == "(-1, 0)"
            and reloads[0]["equal"] and reloads[0]["care_equal"], "streamed ground reload did not match")

    ground = info["ground"]
    require(reloads[0]["care_sha256"] == ground["care_mask"]["sha256"], "capture care bytes differ from reload")
    uniforms = ground["selected_uniforms"]
    require(ground["bound"] and uniforms["policy_enabled"] == "true"
            and ground["chunk_material_counts"].get("6", 0) > 0
            and any(index == 6 and role == 4 for index, role in zip(uniforms["slot_index"], uniforms["slot_role"])),
            "active ground policy did not bind an urban yard")
    require(uniforms["role_sample"][4] == [3, 8, 192, 1], "unexpected bound mossy yard source or repeat")
    grounds.append((ground["chunk_material_counts"], ground["care_mask"]["sha256"]))

    with (case_dir / "ground-before.png").open("rb") as png:
        header = png.read(24)
        png.seek(-12, 2)
        trailer = png.read()
    require(header[:16] == b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR"
            and len(header) == 24 and struct.unpack(">II", header[16:]) == size
            and trailer == b"\x00\x00\x00\x00IEND\xaeB`\x82",
            "missing PNG or wrong native dimensions")
    print(f"{review}: {case_dir / 'ground-before.png'}")

if grounds[0] != grounds[1]:
    raise SystemExit("Normal and small captures disagree on ground materials or care bytes")
PY
