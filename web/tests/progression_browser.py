"""Check a real browser completion unlocks the next stage and persists it."""
import asyncio
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(executable_path='/usr/bin/chromium', headless=True,
            args=['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader','--disable-dev-shm-usage'])
        page = await browser.new_page(viewport={'width':390,'height':844}, has_touch=True)
        await page.goto('http://127.0.0.1:4173', wait_until='networkidle')
        await page.wait_for_function('!!window.__bunbreak',timeout=30000)
        await page.get_by_role('button',name='Play',exact=True).click()
        state = await page.evaluate('''() => {
            window.__bunbreak.freeze();
            window.__bunbreak.release(1,{x:0,y:10});
            for(let i=0;i<1500;i++) { window.__bunbreak.advance(1/30,false); if(window.__bunbreak.inspect().flow==='result') break; }
            return window.__bunbreak.inspect();
        }''')
        assert state['won'] and state['shots']==1 and state['levelIndex']==0, state
        assert await page.evaluate("JSON.parse(localStorage.getItem('bunbreak-web')).completed['hello-bun']")
        await page.get_by_role('button',name='Next puzzle',exact=True).click()
        assert (await page.evaluate('window.__bunbreak.inspect()'))['levelIndex']==1
        await page.evaluate('window.__bunbreak.pause()')
        await page.get_by_role('button',name='Kitchen trail',exact=True).click()
        assert await page.get_by_role('button',name='2  Better together · Play').is_enabled()
        assert await page.get_by_role('button',name='3  Jelly belly · Locked').is_disabled()
        await page.reload(wait_until='networkidle')
        await page.wait_for_function('!!window.__bunbreak')
        assert await page.evaluate("JSON.parse(localStorage.getItem('bunbreak-web')).completed['hello-bun']")
        print('Browser progression passed: real win, reward save, next stage, locked trail and reload.')
        await browser.close()

asyncio.run(main())
