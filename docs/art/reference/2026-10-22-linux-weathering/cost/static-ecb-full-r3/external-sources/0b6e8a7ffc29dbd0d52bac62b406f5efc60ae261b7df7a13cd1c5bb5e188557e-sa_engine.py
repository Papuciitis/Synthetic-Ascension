#!/usr/bin/env python3
"""Queue one monitored Godot run behind every other agent's run.

Wraps tools/capture/run_city_linux.py (which refuses when its own lock is busy)
with a blocking queue lock, waits while any other Godot process (e.g. the
user's editor or playtest) is alive, and prints a compact summary instead of
the full resource-sample JSON.

Usage:
  python3 .superpowers/claude-city-20261021/sa_engine.py --name my-test [--timeout 300] -- <godot args>
  e.g. -- --headless res://tools/tests/CityBlockKitTest.tscn
       -- --rendering-driver opengl3 --audio-driver Dummy res://tools/dev/CityBlockPlayablePreview.tscn -- --review=small ...
Run roots land in .superpowers/claude-city-20261021/runs/<name>-<n>/ (logs/, run-results.json).
"""
import argparse
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[1]
GODOT = Path("/home/user/Downloads/Godot_v4.7.2-stable_linux.x86_64")
LAUNCHER = PROJECT / "tools/capture/run_city_linux.py"
QUEUE = Path("/tmp") / f"sa-engine-queue-{os.getuid()}.lock"
SLOT_LAUNCHER = ROOT / "run_engine_slot.py"
# Concurrent engines of this lane (the user is away); --exclusive takes them all
# for timing-sensitive measurements. Foreign Godot processes still block runs.
SLOTS = max(1, int(os.environ.get("SA_ENGINE_SLOTS", "1")))
TICKETS = Path("/tmp") / f"sa-engine-tickets-{os.getuid()}"


def take_ticket():
    """FIFO fairness: callers are served in arrival order, so a worker that
    loops many runs back to back cannot starve a waiting caller."""
    TICKETS.mkdir(exist_ok=True)
    with open(TICKETS / "counter.lock", "a+") as counter:
        fcntl.flock(counter, fcntl.LOCK_EX)
        counter.seek(0)
        text = counter.read().strip()
        number = int(text) + 1 if text.isdigit() else 1
        counter.seek(0)
        counter.truncate()
        counter.write(str(number))
        counter.flush()
    ticket = TICKETS / f"{number:012d}-{os.getpid()}"
    ticket.touch()
    return ticket


def my_turn(ticket):
    for other in sorted(TICKETS.glob("*-*")):
        if other == ticket:
            return True
        try:
            os.kill(int(other.name.split("-")[1]), 0)
        except (ProcessLookupError, ValueError):
            other.unlink(missing_ok=True)  # stale ticket of a dead caller
            continue
        except PermissionError:
            pass
        return False
    return True


def other_godot():
    """Godot processes that are not this lane's own monitored runs."""
    own_runs = str(ROOT / "runs") + "/"
    found = []
    for d in Path("/proc").iterdir():
        if not d.name.isdigit():
            continue
        try:
            exe = os.readlink(d / "exe")
            args = (d / "cmdline").read_bytes().decode(errors="replace").split("\0")
        except OSError:
            continue
        if Path(exe).name.lower().startswith("godot") and not any(arg.startswith(own_runs) for arg in args):
            found.append(int(d.name))
    return found


# The host is a ThinkPad T480 laptop. On 2026-10-21 sustained parallel runs
# held the CPU package at 96 C and unrelated processes began to segfault, so a
# run only starts while the package is below this temperature.
THERMAL_LIMIT_C = float(os.environ.get("SA_ENGINE_THERMAL_LIMIT_C", "80"))


def package_temp_c():
    for hwmon in Path("/sys/class/hwmon").glob("hwmon*"):
        try:
            if (hwmon / "name").read_text().strip() != "coretemp":
                continue
            for label in hwmon.glob("temp*_label"):
                if label.read_text().strip().startswith("Package"):
                    return int((hwmon / label.name.replace("_label", "_input")).read_text()) / 1000.0
        except (OSError, ValueError):
            continue
    return 0.0


def wait_until_cool(deadline):
    while package_temp_c() >= THERMAL_LIMIT_C:
        if time.monotonic() > deadline:
            return False
        time.sleep(5)
    return True


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--name", required=True)
    p.add_argument("--timeout", type=float, default=240)
    p.add_argument("--max-wait", type=float, default=7200, help="seconds to wait for the queue")
    p.add_argument("--tail", type=int, default=40)
    p.add_argument("--project", default=str(PROJECT), help="project root (a worktree path for isolated agents)")
    p.add_argument("--exclusive", action="store_true", help="take every slot (timing-sensitive runs)")
    p.add_argument("engine_args", nargs=argparse.REMAINDER)
    a = p.parse_args()
    engine_args = a.engine_args[1:] if a.engine_args[:1] == ["--"] else a.engine_args
    runs = ROOT / "runs"
    runs.mkdir(parents=True, exist_ok=True)
    n = 1
    while (runs / f"{a.name}-{n}").exists():
        n += 1
    run_root = runs / f"{a.name}-{n}"
    waited = time.monotonic()
    ticket = take_ticket()
    held = []
    try:
        # FIFO: only the oldest waiting ticket may claim slots; it drops its
        # ticket once it holds them, so the next caller can use a free slot.
        while True:
            if time.monotonic() - waited > a.max_wait:
                print(json.dumps({"stop_reason": "queue_wait_timeout", "run_root": str(run_root)}))
                return 2
            if my_turn(ticket):
                held = claim_slots(SLOTS if a.exclusive else 1)
                if held:
                    break
            time.sleep(1)
        ticket.unlink(missing_ok=True)
        return run_locked(a, engine_args, run_root, waited)
    finally:
        ticket.unlink(missing_ok=True)
        for handle in held:
            handle.close()


def claim_slots(count):
    handles = []
    for index in range(SLOTS):
        handle = open(Path("/tmp") / f"sa-engine-slot-{os.getuid()}-{index}.lock", "a+")
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            handle.close()
            continue
        handles.append(handle)
        if len(handles) == count:
            return handles
    for handle in handles:
        handle.close()
    return []


def run_locked(a, engine_args, run_root, waited):
    if True:
        while other_godot():
            if time.monotonic() - waited > a.max_wait:
                print(json.dumps({"stop_reason": "other_godot_wait_timeout", "pids": other_godot()}))
                return 2
            time.sleep(5)
        if not wait_until_cool(waited + a.max_wait):
            print(json.dumps({"stop_reason": "thermal_wait_timeout", "package_c": package_temp_c()}))
            return 2
        queued = round(time.monotonic() - waited, 1)
        out = run_root.parent / f"{run_root.name}.launcher.json"
        project = Path(a.project).resolve()
        launcher = SLOT_LAUNCHER
        cmd = [sys.executable, str(launcher), "--godot", str(GODOT), "--run-root", str(run_root),
               "--project-root", str(project), "--timeout-seconds", str(a.timeout), "--", *engine_args]
        env = os.environ.copy()
        # Runs keep isolated profiles, but share Mesa's compiled-shader cache so
        # every native launch does not recompile the whole material set cold.
        env.setdefault("MESA_SHADER_CACHE_DIR", str(ROOT / "mesa-shader-cache"))
        with open(out, "w") as fh:
            rc = subprocess.call(cmd, cwd=project, stdout=fh, stderr=subprocess.STDOUT, env=env)
    try:
        res = json.loads((run_root / "run-results.json").read_text())
    except Exception as e:  # launcher refused before writing results
        print(json.dumps({"stop_reason": "no_results", "error": str(e), "launcher_rc": rc,
                          "launcher_output": out.read_text()[-2000:]}))
        return 1
    peak = max((s.get("rss_mb", 0) for s in res.get("resource_samples", [])), default=0)
    summary = {"run_root": str(run_root), "queued_seconds": queued, "stop_reason": res.get("stop_reason"),
               "actual_exit": res.get("actual_exit"), "elapsed_seconds": res.get("elapsed_seconds"),
               "peak_rss_mb": round(peak), "diagnostic_count": len(res.get("diagnostics", [])),
               "diagnostics_head": res.get("diagnostics", [])[:15]}
    print(json.dumps(summary, indent=1))
    log = run_root / "logs/stdout.log"
    if log.exists() and a.tail > 0:
        lines = log.read_text(errors="replace").splitlines()
        print(f"--- stdout tail ({min(a.tail, len(lines))}/{len(lines)} lines) ---")
        print("\n".join(lines[-a.tail:]))
    return 0 if res.get("stop_reason") == "completed" else 1


if __name__ == "__main__":
    sys.exit(main())
