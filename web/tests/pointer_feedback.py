"""Exercise the real pointer cue in Chromium, including cancellation.

Serve web/dist at http://127.0.0.1:4173 before running. The emulated phone is
not a substitute for a physical touch/performance test.
"""
import asyncio
import os
from playwright.async_api import async_playwright


async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(
            executable_path=os.environ.get('CHROMIUM_PATH', '/usr/bin/chromium'),
            headless=True,
            args=['--no-sandbox', '--enable-unsafe-swiftshader', '--use-angle=swiftshader'])
        page = await browser.new_page(viewport={'width': 390, 'height': 844},
                                      device_scale_factor=1, has_touch=True, is_mobile=True)
        await page.goto('http://127.0.0.1:4173/', wait_until='networkidle')
        await page.wait_for_function('!!window.__bunbreak')

        async def reset():
            await page.evaluate('window.__bunbreak.chooseLevel(0)')
            await page.wait_for_timeout(100)
            return await page.evaluate('window.__bunbreak.screenFor(1)')

        async def cue_visible(visible):
            await page.wait_for_function('''visible => {
              const c = document.querySelector('#aim');
              const pixels = c.getContext('2d').getImageData(0, 0, c.width, c.height).data;
              let count = 0;
              for (let i = 3; i < pixels.length; i += 4) if (pixels[i]) count++;
              return visible ? count > 100 : count === 0;
            }''', arg=visible, timeout=5000)

        pos = await reset()
        await page.mouse.move(pos['x'], pos['y'])
        await page.mouse.down()
        await page.mouse.move(pos['x'], pos['y'] + 85, steps=8)
        await cue_visible(True)
        await page.mouse.up()
        await cue_visible(False)
        assert (await page.evaluate('window.__bunbreak.inspect()'))['shots'] == 1

        pos = await reset()
        cdp = await page.context.new_cdp_session(page)
        await cdp.send('Input.dispatchTouchEvent', {'type': 'touchStart', 'touchPoints': [
            {'x': pos['x'], 'y': pos['y'], 'id': 1}]})
        await cdp.send('Input.dispatchTouchEvent', {'type': 'touchMove', 'touchPoints': [
            {'x': pos['x'] - 65, 'y': pos['y'] + 55, 'id': 1}]})
        await cue_visible(True)
        await cdp.send('Input.dispatchTouchEvent', {'type': 'touchCancel', 'touchPoints': []})
        await cue_visible(False)
        assert (await page.evaluate('window.__bunbreak.inspect()'))['shots'] == 0

        pos = await reset()
        await page.mouse.move(pos['x'], pos['y'])
        await page.mouse.down()
        await page.mouse.move(pos['x'] + 60, pos['y'] + 35, steps=4)
        await cue_visible(True)
        await page.evaluate('window.__bunbreak.pause()')
        await cue_visible(False)
        assert (await page.evaluate('window.__bunbreak.inspect()'))['shots'] == 0
        await page.mouse.up()
        await browser.close()
        print('Pointer feedback: mouse launch, touch cancellation, and pause cancel passed.')


asyncio.run(main())
