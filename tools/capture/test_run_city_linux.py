"""Linux monitor contract tests; only harmless Python executables are launched."""
import importlib.util
import json
import os
import signal
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

RUNNER = Path(__file__).with_name("run_city_linux.py")


class LinuxRunnerTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.project = self.root / "project"
        self.project.mkdir()
        (self.project / "project.godot").write_text("config_version=5\n")
        self.engine = self.root / "fake_engine.py"

    def fake(self, source):
        self.engine.write_text("#!" + sys.executable + "\n" + source)
        self.engine.chmod(0o755)

    def command(self, name="run", *options, engine_args=()):
        return [sys.executable, str(RUNNER), "--godot", str(self.engine),
                "--project-root", str(self.project), "--run-root", str(self.root / name),
                "--timeout-seconds", "2", "--min-available-mb", "1", *options,
                "--", *engine_args]

    def run_monitor(self, *options, engine_args=()):
        completed = subprocess.run(self.command("run", *options, engine_args=engine_args),
                                   capture_output=True, text=True, timeout=8)
        self.assertTrue(completed.stdout.strip(), completed.stderr)
        return completed, json.loads(completed.stdout)

    def test_success_records_command_isolated_environment_and_logs(self):
        # Missing environment isolation or --path/--log-file wiring breaks this test.
        self.fake("import json, os, sys\nfrom pathlib import Path\n"
                  "print(json.dumps({k: os.environ[k] for k in "
                  "['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']}))\n"
                  "Path(sys.argv[sys.argv.index('--log-file')+1]).write_text('engine ok\\n')\n")
        completed, result = self.run_monitor(engine_args=("--version",))
        self.assertEqual(completed.returncode, 0, result)
        self.assertEqual(result["actual_exit"], 0)
        self.assertEqual(result["stop_reason"], "completed")
        self.assertEqual(result["command"][-1], "--version")
        self.assertEqual(result["command"][1:3], ["--path", str(self.project)])
        paths = json.loads((self.root / "run/logs/stdout.log").read_text())
        for variable, suffix in [("XDG_DATA_HOME", "data"),
                                 ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")]:
            self.assertEqual(paths[variable], str(self.root / "run" / suffix))
            self.assertTrue(Path(paths[variable]).is_dir())
        self.assertEqual((self.root / "run/logs/engine.log").read_text(), "engine ok\n")
        self.assertTrue(result["resource_samples"])
        self.assertEqual(json.loads((self.root / "run/run-results.json").read_text()), result)

    def test_existing_evidence_is_never_overwritten(self):
        self.fake("print('should never run')\n")
        evidence = self.root / "run"
        evidence.mkdir()
        previous = evidence / "run-results.json"
        previous.write_text("original evidence\n")
        completed, result = self.run_monitor()
        self.assertEqual(completed.returncode, 1)
        self.assertEqual(result["stop_reason"], "run_root_not_empty")
        self.assertEqual(previous.read_text(), "original evidence\n")

    def test_warning_in_engine_log_fails_even_when_stdout_is_clean(self):
        self.fake("from pathlib import Path\nimport sys\n"
                  "Path(sys.argv[sys.argv.index('--log-file')+1]).write_text('WARNING: fake warning\\n')\n")
        completed, result = self.run_monitor()
        self.assertEqual(completed.returncode, 1)
        self.assertEqual(result["actual_exit"], 0)
        self.assertEqual(result["stop_reason"], "runtime_diagnostics")
        self.assertEqual(result["diagnostics"], ["WARNING: fake warning"])

    def test_sigterm_ignoring_fake_is_killed_after_timeout(self):
        self.fake("import signal, time\nsignal.signal(signal.SIGTERM, signal.SIG_IGN)\ntime.sleep(30)\n")
        completed, result = self.run_monitor("--timeout-seconds", "0.3")
        self.assertEqual(completed.returncode, 1)
        self.assertEqual(result["stop_reason"], "timeout")
        self.assertEqual(result["actual_exit"], -9)

    def test_sigterm_to_monitor_cleans_owned_engine(self):
        marker = self.root / "engine.pid"
        self.fake(f"import os, time\nfrom pathlib import Path\nPath({str(marker)!r}).write_text(str(os.getpid()))\ntime.sleep(30)\n")
        monitor = subprocess.Popen(self.command("signalled", "--timeout-seconds", "30"),
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.addCleanup(self.stop_process, monitor)
        for _ in range(100):
            if marker.exists():
                break
            time.sleep(0.02)
        self.assertTrue(marker.exists(), "Monitor never started its owned executable")
        monitor.terminate()
        output, errors = monitor.communicate(timeout=4)
        self.assertEqual(monitor.returncode, 1, errors)
        result = json.loads(output)
        self.assertEqual(result["stop_reason"], "interrupted")
        self.assertLess(result["actual_exit"], 0)
        self.assert_process_stopped(int(marker.read_text()))

    def test_repeated_sigterm_cannot_interrupt_owned_group_cleanup(self):
        marker = self.root / "engine.pid"
        self.fake("import os, signal, time\nfrom pathlib import Path\n"
                  "signal.signal(signal.SIGTERM, signal.SIG_IGN)\n"
                  f"Path({str(marker)!r}).write_text(str(os.getpid()))\n"
                  "time.sleep(30)\n")
        monitor = subprocess.Popen(self.command("repeated", "--timeout-seconds", "30"),
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.addCleanup(self.stop_process, monitor)
        for _ in range(100):
            if marker.exists():
                break
            time.sleep(0.02)
        self.assertTrue(marker.exists(), "Monitor never started its owned executable")
        engine_pid = int(marker.read_text())
        self.addCleanup(self.kill_fake_pid, engine_pid)
        for _ in range(6):
            if monitor.poll() is not None:
                break
            monitor.terminate()
            time.sleep(0.06)
        output, errors = monitor.communicate(timeout=4)
        result = json.loads(output)
        self.assertEqual(result["stop_reason"], "interrupted", errors)
        self.assertEqual(result["actual_exit"], -9)
        self.assert_process_stopped(engine_pid)

    @staticmethod
    def kill_fake_pid(pid):
        try:
            os.kill(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass

    def test_lock_is_shared_even_when_tmpdir_environment_differs(self):
        marker = self.root / "started"
        self.fake(f"import time\nfrom pathlib import Path\nPath({str(marker)!r}).touch()\ntime.sleep(30)\n")
        first = subprocess.Popen(self.command("first", "--timeout-seconds", "1"),
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.addCleanup(self.stop_process, first)
        for _ in range(100):
            if marker.exists():
                break
            time.sleep(0.02)
        self.assertTrue(marker.exists(), "First monitor never launched")
        alternate_temp = self.root / "different-tmp"
        alternate_temp.mkdir()
        second = subprocess.run(self.command("second"), capture_output=True, text=True, timeout=4,
                                env={**os.environ, "TMPDIR": str(alternate_temp)})
        self.assertEqual(second.returncode, 1, second.stderr)
        self.assertEqual(json.loads(second.stdout)["stop_reason"], "monitor_lock_busy")
        first.communicate(timeout=4)

    def test_nonzero_exit_is_preserved(self):
        self.fake("raise SystemExit(7)\n")
        completed, result = self.run_monitor()
        self.assertEqual(completed.returncode, 1)
        self.assertEqual(result["actual_exit"], 7)
        self.assertEqual(result["stop_reason"], "nonzero_exit")

    def test_error_with_successful_exit_fails_the_run(self):
        self.fake("print('SCRIPT ERROR: deliberate fake runtime failure')\n")
        completed, result = self.run_monitor()
        self.assertEqual(completed.returncode, 1)
        self.assertEqual(result["actual_exit"], 0)
        self.assertEqual(result["stop_reason"], "runtime_diagnostics")
        self.assertIn("SCRIPT ERROR", result["diagnostics"][0])

    def test_low_memory_refuses_before_executable_starts(self):
        marker = self.root / "started"
        self.fake(f"from pathlib import Path\nPath({str(marker)!r}).touch()\n")
        completed, result = self.run_monitor("--min-available-mb", "1000000000")
        self.assertEqual(completed.returncode, 1)
        self.assertIsNone(result["actual_exit"])
        self.assertEqual(result["stop_reason"], "preflight_memory_headroom")
        self.assertFalse(marker.exists())

    def test_timeout_cleans_owned_descendant_and_leaves_unrelated_process(self):
        # Killing only the leader leaks its child; broad process killing harms the bystander.
        child_file = self.root / "child.pid"
        self.fake("import subprocess, sys, time\nfrom pathlib import Path\n"
                  "child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)'])\n"
                  f"Path({str(child_file)!r}).write_text(str(child.pid))\n"
                  "time.sleep(30)\n")
        bystander = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"])
        self.addCleanup(self.stop_process, bystander)
        completed, result = self.run_monitor("--timeout-seconds", "0.3")
        self.assertEqual(completed.returncode, 1)
        self.assertEqual(result["stop_reason"], "timeout")
        self.assertLess(result["actual_exit"], 0)
        self.assertIsNone(bystander.poll())
        self.assert_process_stopped(int(child_file.read_text()))
        bystander.terminate()
        bystander.wait()

    @staticmethod
    def stop_process(process):
        if process.poll() is None:
            process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=3)

    def assert_process_stopped(self, pid):
        for _ in range(50):
            try:
                state = Path(f"/proc/{pid}/stat").read_text().rsplit(") ", 1)[1].split()[0]
                if state == "Z":  # The OS init reaps orphan zombies, not this launcher.
                    return
            except FileNotFoundError:
                return
            time.sleep(0.02)
        self.fail(f"Owned descendant {pid} is still running")

    def test_successful_parent_does_not_leave_running_child(self):
        child_file = self.root / "child.pid"
        self.fake("import subprocess, sys\nfrom pathlib import Path\n"
                  "child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)'])\n"
                  f"Path({str(child_file)!r}).write_text(str(child.pid))\n")
        completed, result = self.run_monitor()
        self.assertEqual(completed.returncode, 0, result)
        self.assert_process_stopped(int(child_file.read_text()))

    def test_shared_lock_rejects_overlapping_run_with_different_run_root(self):
        marker = self.root / "started"
        self.fake(f"import time\nfrom pathlib import Path\nPath({str(marker)!r}).touch()\ntime.sleep(30)\n")
        first = subprocess.Popen(self.command("first", "--timeout-seconds", "1"),
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.addCleanup(self.stop_process, first)
        for _ in range(100):
            if marker.exists():
                break
            time.sleep(0.02)
        self.assertTrue(marker.exists(), "First monitor did not launch")
        second = subprocess.run(self.command("second"), capture_output=True, text=True, timeout=4)
        self.assertEqual(second.returncode, 1, second.stderr)
        self.assertEqual(json.loads(second.stdout)["stop_reason"], "monitor_lock_busy")
        first.communicate(timeout=5)

    def test_existing_godot_named_fake_is_refused_and_left_untouched(self):
        self.fake("print('safe fake')\n")
        sentinel = self.root / "Godot_harmless_sentinel.py"
        sentinel.write_text("import time\ntime.sleep(30)\n")
        other = subprocess.Popen([sys.executable, str(sentinel)])
        self.addCleanup(self.stop_process, other)
        completed, result = self.run_monitor()
        self.assertEqual(completed.returncode, 1)
        self.assertEqual(result["stop_reason"], "other_godot_running")
        self.assertIn(other.pid, result["other_godot_pids"])
        self.assertIsNone(other.poll())
        other.terminate()
        other.wait()

    def test_rss_limit_stops_a_memory_hungry_fake(self):
        self.fake("import time\nallocation = bytearray(32 * 1024 * 1024)\ntime.sleep(30)\n")
        completed, result = self.run_monitor("--max-rss-mb", "20")
        self.assertEqual(completed.returncode, 1)
        self.assertEqual(result["stop_reason"], "engine_rss_limit")
        self.assertGreater(max(s["rss_mb"] for s in result["resource_samples"]), 20)


class MemoryAndProvenanceTest(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location("run_city_linux", RUNNER)
        self.runner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.runner)
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)

    def memory_fixture(self, membership):
        proc = self.root / "proc"
        (proc / "self").mkdir(parents=True)
        (proc / "meminfo").write_text("MemAvailable: 16384000 kB\n")
        (proc / "self/cgroup").write_text(membership)
        cgroup = self.root / "cgroup"
        cgroup.mkdir()
        return proc, cgroup

    def test_cgroup_v2_parent_limit_restricts_host_available_memory(self):
        proc, cgroup = self.memory_fixture("0::/user.slice/session.scope\n")
        leaf = cgroup / "user.slice/session.scope"
        leaf.mkdir(parents=True)
        (leaf / "memory.max").write_text("max")
        (leaf / "memory.current").write_text("1048576")
        (leaf.parent / "memory.max").write_text("6291456000")
        (leaf.parent / "memory.current").write_text("4194304000")
        with mock.patch.object(self.runner, "PROC", proc), mock.patch.object(self.runner, "CGROUP", cgroup):
            self.assertEqual(self.runner.available_memory_mb(), 2000)

    def test_cgroup_v1_memory_controller_limits_are_respected(self):
        proc, cgroup = self.memory_fixture("2:cpu,cpuacct:/session\n3:memory:/session\n")
        group = cgroup / "memory/session"
        group.mkdir(parents=True)
        (group / "memory.limit_in_bytes").write_text("3145728000")
        (group / "memory.usage_in_bytes").write_text("2621440000")
        with mock.patch.object(self.runner, "PROC", proc), mock.patch.object(self.runner, "CGROUP", cgroup):
            self.assertEqual(self.runner.available_memory_mb(), 500)

    def test_host_memory_is_used_when_hierarchy_has_no_memory_controller(self):
        proc, cgroup = self.memory_fixture("0::/session\n")
        with mock.patch.object(self.runner, "PROC", proc), mock.patch.object(self.runner, "CGROUP", cgroup):
            self.assertEqual(self.runner.available_memory_mb(), 16000)

    def test_provenance_hashes_untracked_runtime_and_world_image_pixels(self):
        # A tracked-only or text-only manifest misses source used by this run.
        (self.root / "tools/tests").mkdir(parents=True)
        (self.root / "assets/world").mkdir(parents=True)
        (self.root / "tools/tests/NewTest.gd").write_text("extends SceneTree\n")
        (self.root / "tools/tests/shared.gdshaderinc").write_text("float shared_cover() { return 1.0; }\n")
        (self.root / "assets/world/ground.png").write_bytes(b"source pixels")
        (self.root / "assets/world/ground.png.import").write_text("filter=false\n")
        def git_output(command, **kwargs):
            if "rev-parse" in command:
                return b"0123456789abcdef\n"
            if "status" in command:
                return b"?? tools/tests/NewTest.gd\n"
            if "--others" in command or "-co" in command:
                return b"tools/tests/NewTest.gd\0assets/world/ground.png\0assets/world/ground.png.import\0tools/tests/shared.gdshaderinc\0"
            return b"assets/world/ground.png\0"
        with mock.patch.object(self.runner.subprocess, "check_output", side_effect=git_output):
            result = self.runner.provenance(self.root)
        self.assertEqual(result["git_head"], "0123456789abcdef")
        self.assertEqual(result["source_untracked"], ["tools/tests/NewTest.gd", "assets/world/ground.png.import", "tools/tests/shared.gdshaderinc"])
        self.assertIn("assets/world/ground.png.import", result["source_hashes"])
        self.assertIn("tools/tests/NewTest.gd", result["source_hashes"])
        self.assertIn("tools/tests/shared.gdshaderinc", result["source_hashes"])
        self.assertEqual(result["source_hashes"]["assets/world/ground.png"],
                         "698963b4b559dd76e612eb2ea91bc82098bc644be414832d9ebb21084cd663b0")


if __name__ == "__main__":
    unittest.main()
