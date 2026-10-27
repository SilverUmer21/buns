"""Render and inspect real pull, expression and both merge tiers in Chromium."""
import asyncio, json
from pathlib import Path
from playwright.async_api import async_playwright

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'reports'/'character-frames'
OUT.mkdir(parents=True,exist_ok=True)

async def main():
    async with async_playwright() as p:
        browser=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader','--disable-dev-shm-usage'])
        page=await browser.new_page(viewport={'width':720,'height':1120})
        errors=[]
        page.on('pageerror',lambda e:errors.append(str(e)))
        await page.goto('http://127.0.0.1:4173',wait_until='networkidle')
        await page.wait_for_function('!!window.__bunbreak',timeout=30000)
        await page.evaluate('window.__bunbreak.freeze();window.__bunbreak.chooseLevel(1);window.__bunbreak.advance(1/60)')
        initial=await page.evaluate('window.__bunbreak.inspect()')
        assert all(b['mouthShapes'] >= 2 for b in initial['motion']['buns']), initial
        await page.evaluate('window.__bunbreak.aim(1,{x:1,y:0},1)')
        for i in range(4): await page.evaluate('window.__bunbreak.advance(.08)')
        held=await page.evaluate('window.__bunbreak.inspect()')
        bun=next(b for b in held['motion']['buns'] if b['id']==1)
        assert bun['held'] and bun['height'] < .9 and bun['directional'] < -.08 and abs(bun['expression'])>.15 and abs(bun['volume']-1)<.001, bun
        await page.screenshot(path=str(OUT/'held-right.png'))
        # Reversing the finger should pass through neutral, not teleport the
        # visual in the opposite direction; cancelling should return it home.
        await page.evaluate('window.__bunbreak.aim(1,{x:-1,y:0},1);window.__bunbreak.advance(1/60)')
        reversing=await page.evaluate('window.__bunbreak.inspect().motion.buns.find(b=>b.id===1)')
        assert reversing['offset']['x'] < 0, reversing
        for i in range(6): await page.evaluate('window.__bunbreak.advance(.08)')
        reversed_bun=await page.evaluate('window.__bunbreak.inspect().motion.buns.find(b=>b.id===1)')
        assert reversed_bun['offset']['x'] > .1, reversed_bun
        await page.evaluate('window.__bunbreak.cancelAim(1)')
        for i in range(9): await page.evaluate('window.__bunbreak.advance(.08)')
        cancelled=await page.evaluate('window.__bunbreak.inspect().motion.buns.find(b=>b.id===1)')
        assert not cancelled['held'] and abs(cancelled['offset']['x']) < .01, cancelled
        for stage,tier,vy in [(1,2,7),(3,3,7)]:
            await page.evaluate('''([stage,vy])=>{
                const g=window.__bunbreak;g.chooseLevel(stage);g.release(1,{x:0,y:vy});
                for(let i=0;i<400;i++){g.advance(1/120,false);if(g.inspect().buns.some(b=>b.id===3))break;}
                g.advance(1/60);
            }''',[stage,vy])
            snap=await page.evaluate('window.__bunbreak.inspect()')
            new=next((b for b in snap['motion']['buns'] if b['id']==3),None)
            assert new and new['tier']==tier and new['mouthShapes']>=2 and abs(new['expression'])>.15, snap
            await page.screenshot(path=str(OUT/f'merge-{tier}-arrival.png'))
            for i in range(4): await page.evaluate('window.__bunbreak.advance(.08)')
            await page.screenshot(path=str(OUT/f'merge-{tier}-settling.png'))
            settled=await page.evaluate('window.__bunbreak.inspect()')
            for b in settled['motion']['buns']: assert abs(b['volume']-1)<.001 and b['height']>0, b
        assert not errors,errors
        (ROOT/'reports'/'character-browser.json').write_text(json.dumps({'passed':True,'held':bun,'errors':errors,'rendered_tiers':[2,3]},indent=2))
        print('Character browser checks passed: held expression and volume; Berry and Mango merge arrivals rendered.')
        await browser.close()

asyncio.run(main())
