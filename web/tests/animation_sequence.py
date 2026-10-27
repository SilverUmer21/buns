"""Capture rendered action sequences for visual review, with continuity checks.

Start the game with `python3 -m http.server 4173 --directory web/dist`, then run
this script. Images are real Chromium/Three.js frames, not Blender renders.
"""
import asyncio
import json
import os
from pathlib import Path

from PIL import Image, ImageDraw
from playwright.async_api import async_playwright

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'reports' / 'animation-sequence'
OUT.mkdir(parents=True, exist_ok=True)


async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(executable_path=os.environ.get('CHROMIUM_PATH', '/usr/bin/chromium'), headless=True,
            args=['--no-sandbox', '--enable-unsafe-swiftshader', '--use-angle=swiftshader', '--disable-dev-shm-usage'])
        page = await browser.new_page(viewport={'width': 390, 'height': 844})
        errors = []
        page.on('pageerror', lambda e: errors.append(str(e)))
        await page.goto('http://127.0.0.1:4173', wait_until='networkidle')
        await page.wait_for_function('!!window.__bunbreak', timeout=30000)
        await page.evaluate('window.__bunbreak.freeze()')
        captures = []

        async def capture(label, frame):
            name = f'{label}-{frame:02d}.png'
            await page.screenshot(path=str(OUT / name))
            captures.append(name)

        async def advance(frames=1):
            return await page.evaluate('''n => {
                for (let i = 0; i < n; ++i) window.__bunbreak.advance(1/60);
                return window.__bunbreak.inspect();
            }''', frames)

        # The player may reverse direction while pulling. Compare adjacent
        # samples of the real rig to detect snaps, and save visible poses.
        await page.evaluate('window.__bunbreak.chooseLevel(0); window.__bunbreak.advance(1/60)')
        await page.evaluate('window.__bunbreak.aim(1,{x:1,y:0},1)')
        states = []
        for frame in range(54):
            if frame == 24:
                await page.evaluate('window.__bunbreak.aim(1,{x:-1,y:0},1)')
            state = await advance()
            bun = state['motion']['buns'][0]
            states.append(bun)
            assert bun['height'] > 0 and abs(bun['volume'] - 1) < .002, bun
            if frame in (0, 4, 12, 23, 24, 28, 36, 53):
                await capture('pull-reverse', frame)
        for a, b in zip(states, states[1:]):
            assert abs(b['height'] - a['height']) < .08, (a, b)
            assert abs(b['offset']['x'] - a['offset']['x']) < .08, (a, b)
        assert states[20]['offset']['x'] * states[-1]['offset']['x'] < 0, states
        before = await page.evaluate('window.__bunbreak.inspect()')
        await page.evaluate('window.__bunbreak.release(1,{x:0,y:10})')
        state = await advance()
        assert state['shots'] == before['shots'] + 1, state
        assert state['buns'][0]['position']['y'] > before['buns'][0]['position']['y'], state
        for frame in range(42):
            state = await advance()
            if frame in (0, 3, 7, 12, 20, 30, 41):
                await capture('release', frame)

        # Stop at each merge and render through arrival/settle in real time.
        for stage, tier in ((1, 2), (3, 3)):
            await page.evaluate('stage => { window.__bunbreak.chooseLevel(stage); window.__bunbreak.release(1,{x:0,y:7}); }', stage)
            for _ in range(480):
                state = await advance()
                if any(b['tier'] == tier for b in state['motion']['buns']):
                    break
            else:
                raise AssertionError(f'no tier {tier} merge')
            await capture(f'merge-{tier}', 0)
            for frame in range(1, 37):
                state = await advance()
                bun = next(b for b in state['motion']['buns'] if b['tier'] == tier)
                assert bun['height'] > 0 and abs(bun['volume'] - 1) < .002, bun
                if frame in (2, 5, 9, 15, 24, 36):
                    await capture(f'merge-{tier}', frame)

        # Render the complete escape and result transition instead of skipping
        # the animation with no-draw simulation as the old smoke test did.
        await page.evaluate('window.__bunbreak.chooseLevel(0); window.__bunbreak.release(1,{x:0,y:10})')
        for _ in range(480):
            state = await advance()
            if state['won']:
                break
        else:
            raise AssertionError('escape did not win')
        await capture('win', 0)
        for frame in range(1, 91):
            state = await advance()
            if frame in (3, 7, 12, 20, 30, 45, 60, 90):
                await capture('win', frame)
        assert state['flow'] == 'result', state
        assert not errors, errors

        # Contact sheets make it practical to inspect intermediate poses, not
        # merely whether the browser test managed to produce image files.
        for phase in ('pull-reverse', 'release', 'merge-2', 'merge-3', 'win'):
            files = [OUT / name for name in captures if name.startswith(phase + '-')]
            thumb_w, thumb_h = 195, 422
            sheet = Image.new('RGB', (thumb_w * 4, (thumb_h + 24) * ((len(files) + 3) // 4)), '#f5f1e6')
            draw = ImageDraw.Draw(sheet)
            for i, file in enumerate(files):
                with Image.open(file) as image:
                    thumb = image.convert('RGB').resize((thumb_w, thumb_h))
                x, y = (i % 4) * thumb_w, (i // 4) * (thumb_h + 24)
                sheet.paste(thumb, (x, y))
                draw.text((x + 4, y + thumb_h + 3), file.stem, fill='#263b37')
            sheet.save(OUT / f'{phase}-contact.png')
        (OUT / 'checks.json').write_text(json.dumps({'frames': len(captures), 'errors': errors, 'result': state['flow']}, indent=2))
        print(f'Rendered {len(captures)} action frames; reversal, immediate release, both merges and escape passed.')
        await browser.close()


asyncio.run(main())
