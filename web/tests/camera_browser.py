"""Verify real camera control, projection and persistence in Chromium."""
import asyncio
from pathlib import Path
from playwright.async_api import async_playwright

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'reports'/'camera-frames'
OUT.mkdir(parents=True,exist_ok=True)

async def main():
    async with async_playwright() as p:
        browser=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader','--disable-dev-shm-usage'])
        page=await browser.new_page(viewport={'width':390,'height':844},device_scale_factor=1,has_touch=True)
        errors=[]
        page.on('pageerror',lambda e:errors.append(str(e)))
        await page.goto('http://127.0.0.1:4173',wait_until='networkidle')
        await page.wait_for_function('!!window.__bunbreak',timeout=30000)
        await page.get_by_role('button',name='Play',exact=True).click()
        await page.evaluate('window.__bunbreak.freeze();window.__bunbreak.pause()')
        await page.get_by_role('button',name='Adjust board angle').click()
        slider=page.get_by_role('slider',name='Board camera angle')
        before=await page.evaluate('window.__bunbreak.inspect()')
        assert before['cameraAngle']==45
        for angle in [35,45,55,75]:
            await slider.evaluate('(el,value)=>{el.value=value;el.dispatchEvent(new Event("input",{bubbles:true}))}',str(angle))
            info=await page.evaluate('''() => {const g=window.__bunbreak;const s=g.inspect();const p=g.screenFor(1);return {state:s,point:p,world:g.worldFor(p.x,p.y),corners:[[-3.83,-5.63],[-3.83,5.63],[3.83,-5.63],[3.83,5.63]].map(([x,y])=>g.screenForWorld({x,y})),rect:document.querySelector('#world').getBoundingClientRect().toJSON()};}''')
            assert info['state']['cameraAngle']==angle and info['state']['motion']['cameraAngle']==angle
            assert info['state']['buns']==before['buns'], 'Changing the view changed simulation state'
            assert abs(info['world']['x']-before['buns'][0]['position']['x'])<1e-4
            assert abs(info['world']['y']-before['buns'][0]['position']['y'])<1e-4
            rect=info['rect']
            for point in info['corners']:
                assert rect['left']-1<=point['x']<=rect['right']+1 and rect['top']-1<=point['y']<=rect['bottom']+1, (angle,point,rect)
            await page.screenshot(path=str(OUT/f'angle-{angle}.png'))
        assert await page.evaluate("JSON.parse(localStorage.getItem('bunbreak-web')).cameraAngle") == 75
        await page.get_by_role('button',name='Done').click()
        await page.get_by_role('button',name='Keep playing').click()
        await page.reload(wait_until='networkidle')
        await page.wait_for_function('!!window.__bunbreak')
        assert (await page.evaluate('window.__bunbreak.inspect()'))['cameraAngle']==75
        # A previously saved choice must survive a reload, while Reset returns
        # to the owner-selected default and persists that new choice.
        await page.get_by_role('button',name='Play',exact=True).click()
        await page.evaluate('window.__bunbreak.freeze();window.__bunbreak.pause()')
        await page.get_by_role('button',name='Adjust board angle').click()
        await page.get_by_role('button',name='Reset angle').click()
        assert (await page.evaluate('window.__bunbreak.inspect()'))['cameraAngle']==45
        assert await page.evaluate("JSON.parse(localStorage.getItem('bunbreak-web')).cameraAngle") == 45
        await page.reload(wait_until='networkidle')
        await page.wait_for_function('!!window.__bunbreak')
        assert (await page.evaluate('window.__bunbreak.inspect()'))['cameraAngle']==45
        assert not errors,errors
        print('Camera browser checks passed: live 35–75°, no physics changes, board fit, input projection, saved preference and 45° reset.')
        await browser.close()

asyncio.run(main())
