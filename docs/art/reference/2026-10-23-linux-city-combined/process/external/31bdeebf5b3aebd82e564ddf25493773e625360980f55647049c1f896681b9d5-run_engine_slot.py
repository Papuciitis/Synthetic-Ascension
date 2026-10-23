#!/usr/bin/env python3
"""Bound one Linux Godot run; preserve command, provenance, logs and real exits.

Local slot variant of tools/capture/run_city_linux.py for the claude-city lane:
sa_engine.py owns the concurrency slots, so this copy takes no lock of its own
and ignores only this lane's own monitored engines (their --log-file lives under
OWN_RUNS) when checking for other Godot processes; any foreign Godot (the
user's editor or a playtest) still refuses the run.

Example: python3 tools/capture/run_city_linux.py --godot /opt/Godot \
    --run-root .superpowers/handoff-linux/version -- --version
No address-space limit is applied: GPU drivers reserve large virtual mappings.
"""
import argparse
from datetime import datetime, timezone
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import shlex
import subprocess
import sys
import time

PROC = Path("/proc")
OWN_RUNS = str(Path(__file__).resolve().parent / "runs") + "/"
CGROUP = Path("/sys/fs/cgroup")
MB = 1024 * 1024
DIAGNOSTIC = re.compile(r"SCRIPT ERROR|\bERROR:|\bWARNING:|Parse Error|\bleaked\b|\bOrphan", re.I)


class MonitorInterrupted(Exception):
    """Keep control signals distinct from transient /proc I/O failures."""


def available_memory_mb():
    """Use the tighter of host MemAvailable and every inherited cgroup limit."""
    meminfo = dict(line.split(":", 1) for line in (PROC / "meminfo").read_text().splitlines())
    available = int(meminfo["MemAvailable"].split()[0]) * 1024
    for entry in (PROC / "self/cgroup").read_text().splitlines():
        _, controllers, group = entry.split(":", 2)
        if controllers and "memory" not in controllers.split(","):
            continue
        base = CGROUP / "memory" if controllers else CGROUP
        current = base / group.lstrip("/")
        while current == base or base in current.parents:
            try:
                limit = (current / ("memory.limit_in_bytes" if controllers else "memory.max")).read_text().strip()
                used = int((current / ("memory.usage_in_bytes" if controllers else "memory.current")).read_text())
                if limit != "max":
                    available = min(available, max(0, int(limit) - used))
            except FileNotFoundError:
                pass  # Some hosts expose limits only on an ancestor.
            if current == base:
                break
            current = current.parent
    return available / MB


def process_table():
    """Read Linux identity and resources without spawning monitoring programs."""
    result = []
    for directory in PROC.iterdir():
        if not directory.name.isdigit():
            continue
        try:
            stat = (directory / "stat").read_text()
            fields = stat.rsplit(") ", 1)[1].split()
            args = (directory / "cmdline").read_bytes().decode(errors="replace").split("\0")
            names = [stat.split("(", 1)[1].rsplit(")", 1)[0], *args[:2]]
            try:
                names.append(os.readlink(directory / "exe"))
            except OSError:
                pass
            own = any(arg.startswith(OWN_RUNS) for arg in args)
            result.append({"pid": int(directory.name), "pgid": int(fields[2]), "own_run": own,
                           "session": int(fields[3]), "state": fields[0],
                           "rss_mb": int(fields[21]) * os.sysconf("SC_PAGE_SIZE") / MB,
                           "cpu_seconds": (int(fields[11]) + int(fields[12])) / os.sysconf("SC_CLK_TCK"),
                           "godot": any(Path(name).name.lower().startswith("godot") for name in names)})
        except (OSError, ValueError, IndexError):
            continue  # A process can exit during /proc inspection.
    return result


def owned_processes(pgid):
    return [p for p in process_table() if p["pgid"] == pgid and p["session"] == pgid and p["state"] != "Z"]


def cleanup(process):
    """Signal only the new session/process group created by this launch."""
    for sig, allowance in ((signal.SIGTERM, 0.5), (signal.SIGKILL, 0.5)):
        if not owned_processes(process.pid):
            break
        try:
            os.killpg(process.pid, sig)
        except ProcessLookupError:
            break
        until = time.monotonic() + allowance
        while owned_processes(process.pid) and time.monotonic() < until:
            process.poll()
            time.sleep(0.02)
    process.wait(timeout=2)


def provenance(project):
    result = {"git_head": None, "git_status_porcelain": None, "source_hashes": {}}
    try:
        def git(*args):
            return subprocess.check_output(["git", "-C", str(project), *args], stderr=subprocess.PIPE, timeout=15).decode()
        result["git_head"] = git("rev-parse", "HEAD").strip()
        result["git_status_porcelain"] = git("status", "--porcelain=v1", "--untracked-files=no")
        paths = git("ls-files", "-co", "--exclude-standard", "-z").split("\0")
        tracked = set(git("ls-files", "-z").split("\0"))
        result["source_untracked"] = []
        for relative in paths:
            path = project / relative
            if relative and path.is_file() and (relative == "project.godot" or
                    path.suffix in {".gd", ".gdshader", ".gdshaderinc", ".tscn", ".tres", ".res", ".py", ".ps1"} or
                    (relative.startswith("assets/") and path.suffix == ".json") or
                    (relative.startswith("assets/world/") and path.suffix.lower() in
                     {".png", ".jpg", ".jpeg", ".webp", ".svg", ".exr", ".hdr", ".import"})):
                result["source_hashes"][relative] = hashlib.sha256(path.read_bytes()).hexdigest()
                if relative not in tracked:
                    result["source_untracked"].append(relative)
    except (OSError, subprocess.SubprocessError) as error:
        result["git_error"] = str(error)
    for path in (Path(__file__), Path(__file__).with_name("test_run_city_linux.py")):
        if path.is_file():
            key = str(path.resolve().relative_to(project)) if project in path.resolve().parents else str(path.resolve())
            result["source_hashes"][key] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def positive(value):
    number = float(value)
    if not 0 < number < float("inf"):
        raise argparse.ArgumentTypeError("must be a finite positive number")
    return number


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--run-root", required=True, type=Path, help="new or empty evidence directory")
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--timeout-seconds", type=positive, default=120)
    parser.add_argument("--max-rss-mb", type=positive, default=6144)
    parser.add_argument("--min-available-mb", type=positive, default=4096)
    parser.add_argument("engine_args", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    engine_args = args.engine_args[1:] if args.engine_args[:1] == ["--"] else args.engine_args
    # Ownership of project/log paths is essential to reproducible isolated runs.
    for arg in engine_args[:engine_args.index("--") if "--" in engine_args else len(engine_args)]:
        if arg in {"--path", "-p", "--log-file"} or arg.startswith(("--path=", "--log-file=")):
            parser.error("--path and --log-file are supplied by the monitor; use --project-root")
    project, run_root, executable = args.project_root.resolve(), args.run_root.resolve(), args.godot.resolve()
    command = [str(executable), "--path", str(project), "--log-file", str(run_root / "logs/engine.log"),
               "--flush-output", *engine_args]
    result = {"command": command, "command_shell": shlex.join(command),
              "project_root": str(project), "run_root": str(run_root), "actual_exit": None,
              "stop_reason": None, "resource_samples": [], "diagnostics": [], "other_godot_pids": [],
              "started_utc": datetime.now(timezone.utc).isoformat(),
              "limits": {"timeout_seconds": args.timeout_seconds, "max_rss_mb": args.max_rss_mb,
                         "min_available_mb": args.min_available_mb}}
    process = None
    lock = None
    write_result = False
    started = time.monotonic()
    previous_handlers = {}
    try:
        if run_root.exists() and any(run_root.iterdir()):
            result["stop_reason"] = "run_root_not_empty"
            return 1
        run_root.mkdir(parents=True, exist_ok=True)
        write_result = True
        for name in ("data", "config", "cache", "logs"):
            (run_root / name).mkdir()
        for name in ("engine.log", "stdout.log", "stderr.log"):
            (run_root / "logs" / name).touch()
        result["other_godot_pids"] = [p["pid"] for p in process_table() if p["godot"] and not p["own_run"] and p["pid"] != os.getpid()]
        if result["other_godot_pids"]:
            result["stop_reason"] = "other_godot_running"
            return 1
        available = available_memory_mb()
        result["resource_samples"].append({"elapsed_seconds": 0, "rss_mb": 0, "cpu_seconds": 0,
                                           "available_mb": available, "pids": []})
        if available < args.min_available_mb:
            result["stop_reason"] = "preflight_memory_headroom"
            return 1
        if not (project / "project.godot").is_file():
            raise ValueError("project root must contain project.godot")
        if os.environ.get("SA_FULL_PROVENANCE") == "1":
            result.update(provenance(project))
        else:
            try:
                result["git_head"] = subprocess.check_output(["git", "-C", str(project), "rev-parse", "HEAD"], timeout=15).decode().strip()
            except (OSError, subprocess.SubprocessError) as error:
                result["git_error"] = str(error)
        environment = os.environ.copy()
        environment.update({"XDG_DATA_HOME": str(run_root / "data"), "XDG_CONFIG_HOME": str(run_root / "config"),
                            "XDG_CACHE_HOME": str(run_root / "cache")})
        def interrupted(signum, frame):
            raise MonitorInterrupted(f"received signal {signum}")
        for sig in (signal.SIGINT, signal.SIGTERM):
            previous_handlers[sig] = signal.signal(sig, interrupted)
        with (run_root / "logs/stdout.log").open("w") as stdout, (run_root / "logs/stderr.log").open("w") as stderr:
            process = subprocess.Popen(command, cwd=project, env=environment, stdout=stdout, stderr=stderr,
                                       stdin=subprocess.DEVNULL, start_new_session=True)
            result["pid"] = process.pid
            engine_started = time.monotonic()
            while True:
                elapsed = time.monotonic() - engine_started
                owned = owned_processes(process.pid)
                sample = {"elapsed_seconds": round(elapsed, 3), "rss_mb": sum(p["rss_mb"] for p in owned),
                          "cpu_seconds": sum(p["cpu_seconds"] for p in owned),
                          "available_mb": available_memory_mb(), "pids": [p["pid"] for p in owned]}
                result["resource_samples"].append(sample)
                if process.poll() is not None:
                    break
                if elapsed >= args.timeout_seconds:
                    result["stop_reason"] = "timeout"
                elif sample["rss_mb"] > args.max_rss_mb:
                    result["stop_reason"] = "engine_rss_limit"
                elif sample["available_mb"] < args.min_available_mb:
                    result["stop_reason"] = "system_memory_headroom"
                if result["stop_reason"]:
                    break
                time.sleep(min(0.5, max(0, args.timeout_seconds - elapsed)))
    except (OSError, ValueError, subprocess.SubprocessError, MonitorInterrupted) as error:
        result["stop_reason"] = "interrupted" if isinstance(error, MonitorInterrupted) else "launcher_error"
        result["error"] = str(error)
    finally:
        for sig in previous_handlers:
            signal.signal(sig, signal.SIG_IGN)  # Finish bounded cleanup despite repeated interrupts.
        if process is not None:
            try:
                cleanup(process)
                result["actual_exit"] = process.returncode
            except (OSError, subprocess.SubprocessError) as error:
                result["stop_reason"] = "cleanup_failed"
                result["error"] = str(error)
            for name in ("stdout.log", "stderr.log", "engine.log"):
                with (run_root / "logs" / name).open(errors="replace") as log:
                    for line in log:
                        line = line.rstrip("\r\n")
                        if DIAGNOSTIC.search(line) and line not in result["diagnostics"]:
                            result["diagnostics"].append(line)
        for sig, handler in previous_handlers.items():
            signal.signal(sig, handler)
        if result["stop_reason"] is None:
            result["stop_reason"] = ("nonzero_exit" if result["actual_exit"] != 0 else
                                     "runtime_diagnostics" if result["diagnostics"] else "completed")
        result["elapsed_seconds"] = round(time.monotonic() - started, 3)
        result["ended_utc"] = datetime.now(timezone.utc).isoformat()
        result["runner_exit"] = int(result["stop_reason"] != "completed")
        output = json.dumps(result, indent=2) + "\n"
        if write_result:
            (run_root / "run-results.json").write_text(output)
        if lock is not None:
            lock.close()
        print(output, end="")
    return result["runner_exit"]


if __name__ == "__main__":
    sys.exit(main())
