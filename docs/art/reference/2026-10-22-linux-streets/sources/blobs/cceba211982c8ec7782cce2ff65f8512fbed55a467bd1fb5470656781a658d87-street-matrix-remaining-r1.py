from pathlib import Path
import json
import subprocess
import time

ROOT = Path('/home/user/Nauris/Synthetic-Ascension')
BASE = ROOT / '.superpowers/continuation-20261022'
MATRIX = Path('/var/tmp/sa-city22/streets/continuity-matrix/matrix.json')
DRIVER = BASE / 'street-continuity-matrix.py'
HOLD = BASE / 'street-matrix-hold'

def read_matrix():
    return json.loads(MATRIX.read_text())

while True:
    state = read_matrix()
    if '0' in state['parts']:
        break
    attempt = next(a for a in reversed(state['attempts']) if a['theme_index'] == 0)
    if attempt['status'] == 'incomplete':
        raise SystemExit('Index0 incomplete; inspect the retained raw attempt.')
    time.sleep(1)

for index in range(1, 14):
    while HOLD.exists():
        time.sleep(1)
    if str(index) in read_matrix()['parts']:
        continue
    command = ['python3', '-B', str(DRIVER), '--execute', '--theme-index', str(index),
               '--suffix', f'part{index:02d}-v1', '--matrix', str(MATRIX),
               '--guard-arg=--duty-percent', '--guard-arg=25', '--timeout', '900']
    result = subprocess.run(command, cwd=ROOT)
    if result.returncode:
        raise SystemExit(result.returncode)
    time.sleep(3)

result = subprocess.run(['python3', '-B', str(DRIVER), '--execute', '--aggregate',
                         '--matrix', str(MATRIX)], cwd=ROOT)
raise SystemExit(result.returncode)
