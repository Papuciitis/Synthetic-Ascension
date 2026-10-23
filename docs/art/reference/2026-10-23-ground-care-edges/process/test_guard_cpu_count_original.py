import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

GUARD = Path('/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261023-ground/guard-before-cpu-option.py')


class GuardCpuCountTest(unittest.TestCase):
    def check_affinity(self, count):
        # Exercise taskset with a Python stub, never a Godot executable. This
        # checks OS affinity and recorded provenance, not thermal/owned cleanup.
        with tempfile.TemporaryDirectory(prefix='sa-guard-affinity-') as name:
            root = Path(name)
            launcher = root / '.superpowers/claude-city-20261021/sa_engine.py'
            launcher.parent.mkdir(parents=True)
            launcher.write_text('import json,os\nprint(json.dumps(sorted(os.sched_getaffinity(0))))\n')
            script = root / 'guard_probe.py'
            source = GUARD.read_text().replace("ROOT = Path('/home/user/Nauris/Synthetic-Ascension')", 'ROOT = Path(' + repr(str(root)) + ')')
            script.write_text(source)
            command = [sys.executable, str(script), '--label', 'affinity', '--project', str(root)]
            if count is not None:
                command += ['--cpu-count', str(count)]
            result = subprocess.run(command, text=True, capture_output=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stderr)
            expected = [0] if count == 1 else [0, 1]
            record = json.loads((root / 'affinity-thermal.json').read_text())
            self.assertEqual(record['cpu_affinity'], expected)
            self.assertEqual(record['command'][:3], ['taskset', '-c', ','.join(map(str, expected))])
            self.assertEqual(json.loads((root / 'affinity-wrapper.log').read_text()), expected)
            self.assertEqual(record['runtime_temperature_stop_c'], 90)
            self.assertEqual(record['sustained_temperature_stop_c'], 85)
            self.assertEqual(record['sustained_temperature_samples'], 3)
            self.assertEqual(record['owned_pids'], [])

    def test_default_keeps_two_cpus(self):
        self.check_affinity(None)

    def test_one_cpu_is_applied_and_recorded(self):
        self.check_affinity(1)


if __name__ == '__main__':
    unittest.main()
