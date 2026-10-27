"""Capture every stage in real Chromium/WebGL, using fresh browser storage."""
import asyncio
from pathlib import Path
from PIL import Image
from playwright.async_api import async_playwright

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'reports' / 'web-levels'
OUT.mkdir(parents=True, exist_ok=True)

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(executable_path='/usr/bin/chromium', headless=True,
            args=['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader','--disable-dev-shm-usage'])
        page = await browser.new_page(viewport={'width':390,'height':844}, device_scale_factor=1)
        errors=[]
        page.on('pageerror', lambda error: errors.append(str(error)))
        await page.goto('http://127.0.0.1:4173', wait_until='networkidle')
        await page.wait_for_function('!!window.__bunbreak', timeout=30000)
        await page.evaluate('window.__bunbreak.freeze()')
        expected_counts=[1,2,1,2,4,3]
        expected_badges=['PIP','BERRY','PIP','MANGO','MANGO','MANGO']
        for index in range(6):
            state=await page.evaluate('''i=>{window.__bunbreak.chooseLevel(i);window.__bunbreak.advance(1/60);return window.__bunbreak.inspect()}''', index)
            assert len(state['buns'])==expected_counts[index], (index,state)
            assert await page.locator('#gate-badge').inner_text()==expected_badges[index]
            path=OUT / f'level-{index+1}.png'
            await page.screenshot(path=str(path))
            with Image.open(path).convert('RGB') as image:
                pixels=image.resize((100,100)).get_flattened_data()
                assert sum(g>r*1.13 and g>b*1.05 and g>65 for r,g,b in pixels)>300, (index,'board missing')
        assert not errors, errors
        print('Six actual Chromium stage renders passed:', ', '.join(str(i+1) for i in range(6)))
        await browser.close()

asyncio.run(main())
