"""Check phone-size layouts and touch targets in an actual Chromium render.

Run with the built-in server serving web/dist on 127.0.0.1:4173. These are
emulated viewports, not device performance or notch/safe-area measurements.
"""
import asyncio
import os
from playwright.async_api import async_playwright


async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(
            executable_path=os.environ.get('CHROMIUM_PATH', '/usr/bin/chromium'), headless=True,
            args=['--no-sandbox', '--enable-unsafe-swiftshader', '--use-angle=swiftshader', '--disable-dev-shm-usage'])
        for width, height in [(320, 568), (390, 844), (844, 390)]:
            page = await browser.new_page(viewport={'width': width, 'height': height}, device_scale_factor=2, has_touch=True, is_mobile=True)
            errors = []
            page.on('pageerror', lambda e: errors.append(str(e)))
            await page.goto('http://127.0.0.1:4173', wait_until='networkidle')
            await page.wait_for_function('!!window.__bunbreak', timeout=30000)
            await page.get_by_role('button', name='Play', exact=True).tap()
            rect = await page.locator('#world').bounding_box()
            assert rect and rect['width'] > 0 and rect['height'] > 0
            assert rect['x'] >= 0 and rect['y'] >= 0 and rect['x'] + rect['width'] <= width + 1 and rect['y'] + rect['height'] <= height + 1, (width, height, rect)
            for name in ['Undo last shot', 'Pause game']:
                target = await page.get_by_role('button', name=name).bounding_box()
                assert target['width'] >= 48 and target['height'] >= 48, (width, height, name, target)
            await page.get_by_role('button', name='Pause game').tap()
            await page.get_by_role('button', name='Adjust board angle').tap()
            for role, name in [('slider', 'Board camera angle'), ('button', 'Reset angle'), ('button', 'Done')]:
                element = page.get_by_role(role, name=name)
                await element.scroll_into_view_if_needed()
                target = await element.bounding_box()
                assert target['width'] >= 48 and target['height'] >= 48, (width, height, name, target)
            await page.get_by_role('button', name='Done').tap()
            assert not errors, errors
            print(f'{width}x{height}: visible board, accessible 48px HUD and camera targets')
            await page.close()
        await browser.close()


asyncio.run(main())
