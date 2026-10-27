"""Cloud Chromium visual/interaction review of our own local game, with frame captures."""
import asyncio,json
from pathlib import Path
from playwright.async_api import async_playwright
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'reports'/'web-frames'
OUT.mkdir(parents=True,exist_ok=True)

async def main():
    async with async_playwright() as p:
        browser=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader','--disable-dev-shm-usage'])
        page=await browser.new_page(viewport={'width':720,'height':1120},device_scale_factor=1)
        errors=[]
        page.on('pageerror',lambda e:errors.append(str(e)))
        await page.goto('http://127.0.0.1:4173',wait_until='networkidle')
        await page.wait_for_function('!!window.__bunbreak',timeout=30000)
        await page.screenshot(path=str(OUT/'01-title.png'))
        await page.get_by_role('button',name='Play',exact=True).click()
        await page.evaluate('window.__bunbreak.freeze()')
        await page.evaluate('window.__bunbreak.chooseLevel(4)')
        await page.evaluate('window.__bunbreak.advance(1/60)')
        await page.screenshot(path=str(OUT/'02-play.png'))
        pos=await page.evaluate('window.__bunbreak.screenFor(1)')
        await page.mouse.move(pos['x'],pos['y'])
        await page.mouse.down()
        await page.mouse.move(pos['x']+20,pos['y']+75,steps=10)
        states=[]
        for frame in range(24):
            await page.evaluate('window.__bunbreak.advance(1/120)')
            if frame in [0,5,11,23]:
                await page.screenshot(path=str(OUT/f'03-pull-{frame:02d}.png'))
                states.append({'phase':'pull','frame':frame,'state':await page.evaluate('window.__bunbreak.inspect()')})
        await page.mouse.up()
        for frame in range(84):
            await page.evaluate('window.__bunbreak.advance(1/120)')
            if frame in [0,5,11,23,47,83]:
                await page.screenshot(path=str(OUT/f'04-release-{frame:02d}.png'))
                states.append({'phase':'release','frame':frame,'state':await page.evaluate('window.__bunbreak.inspect()')})
        await page.evaluate('window.__bunbreak.pause()')
        await page.screenshot(path=str(OUT/'05-pause.png'))
        await page.evaluate('window.__bunbreak.showMe()')
        await page.evaluate('''() => { for(let i=0;i<1200;i++){window.__bunbreak.advance(1/30,false);if(window.__bunbreak.inspect().flow==='result')break;} window.__bunbreak.advance(1/60); }''')
        state=await page.evaluate('window.__bunbreak.inspect()')
        for frame in range(12):
            await page.evaluate('window.__bunbreak.advance(1/60)')
        await page.wait_for_timeout(350)
        await page.screenshot(path=str(OUT/'06-result.png'))
        assert state['won'] and state['flow']=='result',state
        for level_index in range(6):
            state = await page.evaluate('''i => { window.__bunbreak.chooseLevel(i);window.__bunbreak.showMe(); for(let f=0;f<1500;f++){window.__bunbreak.advance(1/30,false);if(window.__bunbreak.inspect().flow==='result')break;} return window.__bunbreak.inspect(); }''', level_index)
            assert state['won'] and state['flow']=='result' and state['levelIndex']==level_index, (level_index,state)
        await page.set_viewport_size({'width':390,'height':844})
        await page.wait_for_timeout(300)
        await page.evaluate('window.__bunbreak.start();window.__bunbreak.advance(1/60)')
        await page.wait_for_timeout(200)
        await page.screenshot(path=str(OUT/'07-phone.png'))
        await page.set_viewport_size({'width':1280,'height':800})
        await page.wait_for_timeout(300)
        await page.evaluate('window.__bunbreak.advance(1/60)')
        await page.wait_for_timeout(200)
        await page.screenshot(path=str(OUT/'08-desktop.png'))
        for name in ['07-phone.png','08-desktop.png']:
            with Image.open(OUT/name).convert('RGB') as image:
                pixels = list(image.resize((100,100)).getdata())
                colored = sum(g > r * 1.13 and g > b * 1.05 and g > 65 for r,g,b in pixels)
                assert colored > 300, (name,'board missing after resize',colored)
        result={'passed':not errors,'console_errors':errors,'frames':len(list(OUT.glob('*.png'))),'states':states,'replay_result':state,'browser':'Chromium 147 / SwiftShader software WebGL; physical device performance unmeasured'}
        (ROOT/'reports'/'web-browser-review.json').write_text(json.dumps(result,indent=2))
        print(json.dumps({'passed':not errors,'frames':result['frames'],'won':state['won'],'shots':state['shots'],'errors':errors}))
        assert not errors,errors
        await browser.close()

asyncio.run(main())
