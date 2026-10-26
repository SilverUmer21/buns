"""Create a small portable Godot project ZIP without editor caches or toolchains."""
from pathlib import Path
import hashlib
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'builds'
OUT.mkdir(exist_ok=True)
target = OUT / 'Bunbreak-v0.3-godot.zip'
files = [p for p in sorted((ROOT / 'godot').rglob('*'))
         if p.is_file() and '.godot' not in p.parts and not p.name.endswith('.log')]
with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for path in files:
        z.write(path, 'Bunbreak/' + str(path.relative_to(ROOT / 'godot')))
    z.writestr('Bunbreak/PLAY.txt', 'Godot 4.6.3 Standard: import project.godot, allow assets to import, then press F5.\nMouse/touch: select a bun, pull backwards, hold, release.\nThis slice contains The Big Escape. Other trail stages are upcoming.\nResearch, editable Blender sources and validation: https://github.com/SilverUmer21/buns\n')
with zipfile.ZipFile(target) as z:
    assert z.testzip() is None
    assert 'Bunbreak/project.godot' in z.namelist()
    assert 'Bunbreak/data/solution.json' in z.namelist()
sums = []
for path in sorted(OUT.iterdir()):
    if path.is_file() and path.name != 'SHA256SUMS' and path.suffix != '.avi':
        sums.append(hashlib.sha256(path.read_bytes()).hexdigest() + '  ' + path.name)
(OUT / 'SHA256SUMS').write_text('\n'.join(sums) + '\n')
print('PACKAGED', target, target.stat().st_size)
