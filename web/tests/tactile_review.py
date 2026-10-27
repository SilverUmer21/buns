"""Render comparable native-phone frames and enlarged detail crops.

Run baseline against a retained old checkout, then after against the working
build. Example: python3 web/tests/tactile_review.py before --port 4174
The screenshots show actual Chromium output. Crops enlarge that output for
inspection; neither the crops nor desktop software rendering measure phone FPS.
"""
import argparse
import asyncio
import json
import math
import os
from pathlib import Path

from PIL import Image, ImageDraw
from playwright.async_api import async_playwright

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'reports' / 'tactile-review'


def sheets(phase, captures):
    for group in ('pull', 'release', 'cancel', 'merge-2', 'merge-3'):
        items = [c for c in captures if c['group'] == group]
        cols, size, label = 4, 260, 28
        result = Image.new('RGB', (cols * size, math.ceil(len(items) / cols) * (size + label)), '#f4f0e4')
        draw = ImageDraw.Draw(result)
        for i, item in enumerate(items):
            image = Image.open(OUT / phase / (item['name'] + '-detail.png')).convert('RGB')
            x, y = i % cols * size, i // cols * (size + label)
            result.paste(image.resize((size, size), Image.Resampling.LANCZOS), (x, y))
            draw.text((x + 5, y + size + 5), item['name'], fill='#244b42')
        result.save(OUT / phase / (group + '-sheet.png'))

    # Keep before/after poses side by side at the same image scale. These are
    # enlarged screenshots, not new renders or evidence of phone performance.
    if phase == 'after' and (OUT / 'before').exists():
        size, label = 260, 28
        result = Image.new('RGB', (size * 4, (size + label) * 3), '#f4f0e4')
        draw = ImageDraw.Draw(result)
        for row, action in enumerate(('right-strong','down-strong','diagonal-strong')):
            for col, (version, pose) in enumerate((('before','rest'),('before','30'),('after','rest'),('after','30'))):
                image = Image.open(OUT / version / f'{action}-{pose}-detail.png').convert('RGB')
                x, y = col * size, row * (size + label)
                result.paste(image.resize((size,size),Image.Resampling.LANCZOS),(x,y))
                draw.text((x+5,y+size+5),f'{version}: {action} {pose}',fill='#244b42')
        result.save(OUT / 'pull-comparison.png')


async def run(phase, port):
    folder = OUT / phase
    folder.mkdir(parents=True, exist_ok=True)
    captures, checks, errors = [], {}, []
    async with async_playwright() as p:
        browser = await p.chromium.launch(executable_path=os.environ.get('CHROMIUM_PATH', '/usr/bin/chromium'), headless=True,
            args=['--no-sandbox', '--enable-unsafe-swiftshader', '--use-angle=swiftshader', '--disable-dev-shm-usage'])
        page = await browser.new_page(viewport={'width': 390, 'height': 844}, device_scale_factor=1)
        page.on('pageerror', lambda e: errors.append(str(e)))
        page.on('console', lambda msg: errors.append(msg.text) if msg.type == 'error' and 'favicon' not in msg.text and '404' not in msg.text else None)
        await page.goto(f'http://127.0.0.1:{port}', wait_until='networkidle')
        await page.wait_for_function('!!window.__bunbreak', timeout=30000)
        await page.evaluate('window.__bunbreak.freeze()')

        async def advance(count=1):
            return await page.evaluate('''n => { for(let i=0;i<n;i++) window.__bunbreak.advance(1/60); return window.__bunbreak.inspect(); }''', count)

        async def capture(name, group, id=1):
            state = await page.evaluate('window.__bunbreak.inspect()')
            pos = await page.evaluate('id => window.__bunbreak.screenFor(id)', id)
            full = folder / (name + '.png')
            await page.screenshot(path=str(full))
            with Image.open(full) as image:
                # Consistent 140 CSS-pixel crop centered on the bun's floor
                # position, biased upward to include crest, face and hop.
                x, y = pos['x'], pos['y'] - 25
                image.crop((int(x-70), int(y-70), int(x+70), int(y+70))).save(folder / (name + '-detail.png'))
            captures.append({'name': name, 'group': group, 'id': id})
            return state

        for label, direction, strength in [('right-weak', [-1,0], .3), ('right-strong', [-1,0], 1),
                ('down-strong', [0,1], 1), ('diagonal-strong', [-.70710678,.70710678], 1)]:
            await page.evaluate('window.__bunbreak.chooseLevel(0);window.__bunbreak.advance(1/60)')
            await capture(label + '-rest', 'pull')
            await page.evaluate('v => window.__bunbreak.aim(1,{x:v[0],y:v[1]},v[2])', [*direction, strength])
            for frame in range(1, 31):
                state = await advance()
                if frame in (4, 10, 30): await capture(f'{label}-{frame:02}', 'pull')
            checks[label] = state
            # Solver must stay completely still while the visual is dragged.
            assert state['shots'] == 0 and not state['won'], state
            if phase == 'after':
                bun = state['motion']['buns'][0]
                assert bun['height'] > 0 and abs(bun['volume'] - 1) < .003, bun

        if phase == 'after':
            weak = checks['right-weak']['motion']['buns'][0]['pullDeformation']
            strong = checks['right-strong']['motion']['buns'][0]['pullDeformation']
            diagonal = checks['diagonal-strong']['motion']['buns'][0]['pullDeformation']
            assert strong['amount'] > weak['amount'] * 2, (weak,strong)
            assert abs(diagonal['amount'] - strong['amount']) < .03, (diagonal,strong)
            # Check the reference field sampled from the uniforms actually
            # installed on the rendered materials, including the prior
            # diagonal-cancellation regression. This is not mesh volume.
            for label in ('right-strong','down-strong','diagonal-strong'):
                field = checks[label]['motion']['buns'][0]['pullDeformation']
                axis, amount = field['axis'], field['amount']
                assert abs(sum(x*x for x in axis) - 1) < .001, field
                center = [0,.84,0]
                expected_anchor = [c - .76*a for c,a in zip(center,axis)]
                assert max(abs(x-y) for x,y in zip(field['anchor'],expected_anchor)) < .001, field
                tip_progress = sum((x-c)*a for x,c,a in zip(field['fingerSide'],center,axis)) - .76
                assert tip_progress > amount*.75, field

        await page.evaluate('window.__bunbreak.cancelAim(1)')
        for frame in range(1, 46):
            state = await advance()
            if frame in (1, 5, 12, 30, 45): await capture(f'cancel-{frame:02}', 'cancel')
        assert state['shots'] == 0 and not state['motion']['buns'][0]['held'], state

        await page.evaluate('window.__bunbreak.chooseLevel(0);window.__bunbreak.aim(1,{x:.4,y:1},1)')
        await advance(30)
        await capture('release-held', 'release')
        before = await page.evaluate('window.__bunbreak.inspect()')
        await page.evaluate('window.__bunbreak.release(1,{x:3,y:8})')
        state = await advance()
        assert state['shots'] == before['shots'] + 1 and state['buns'][0]['position'] != before['buns'][0]['position'], state
        await capture('release-01', 'release')
        for frame in range(2, 46):
            await advance()
            if frame in (3, 6, 10, 16, 25, 35, 45): await capture(f'release-{frame:02}', 'release')

        for stage, tier in ((1,2),(3,3)):
            await page.evaluate('stage => {window.__bunbreak.chooseLevel(stage);window.__bunbreak.release(1,{x:0,y:7});}', stage)
            for _ in range(480):
                state = await advance()
                merged = next((b for b in state['buns'] if b['tier'] == tier), None)
                if merged: break
            else: raise AssertionError(f'no tier {tier} merge')
            await capture(f'merge-{tier}-00', f'merge-{tier}', merged['id'])
            for frame in range(1, 61):
                state = await advance()
                if frame in (3,6,10,15,22,35,50,60): await capture(f'merge-{tier}-{frame:02}', f'merge-{tier}', merged['id'])
            checks[f'merge-{tier}'] = state
        assert not errors, errors
        await browser.close()
    sheets(phase, captures)
    (folder / 'checks.json').write_text(json.dumps({'phase':phase,'frames':len(captures),'errors':errors,'checks':checks},indent=2))
    print(f'{phase}: captured {len(captures)} actual phone frames with detail crops; held solver, cancel, immediate release, both tiers passed', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('phase', choices=['before','after'])
    parser.add_argument('--port', type=int, default=4173)
    args = parser.parse_args()
    asyncio.run(run(args.phase,args.port))
