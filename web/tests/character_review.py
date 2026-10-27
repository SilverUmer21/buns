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
        page.on('console',lambda message: errors.append(message.text) if message.type == 'error' and 'Failed to load resource' not in message.text else None)
        page.on('response',lambda response: errors.append(f'HTTP {response.status}: {response.url}') if response.status >= 400 and not response.url.endswith('/favicon.ico') else None)
        await page.goto('http://127.0.0.1:4173',wait_until='networkidle')
        await page.wait_for_function('!!window.__bunbreak',timeout=30000)
        await page.evaluate('window.__bunbreak.freeze();window.__bunbreak.chooseLevel(1);window.__bunbreak.advance(1/60)')
        initial=await page.evaluate('window.__bunbreak.inspect()')
        assert all(b['mouthShapes'] >= 2 for b in initial['motion']['buns']), initial
        await page.evaluate('window.__bunbreak.aim(1,{x:1,y:0},1)')
        for i in range(4): await page.evaluate('window.__bunbreak.advance(.08)')
        held=await page.evaluate('window.__bunbreak.inspect()')
        bun=next(b for b in held['motion']['buns'] if b['id']==1)
        deformation = bun['pullDeformation']
        # Pull vector is the launch direction; the field extends toward the
        # finger on its opposite side, and leaves the other edge anchored.
        assert bun['held'] and deformation['amount'] > .45 and deformation['axis'][0] < -.99 and abs(bun['expression']) > .15, bun
        assert abs(deformation['anchor'][0] - .76) < .001 and deformation['fingerSide'][0] < -1.20, deformation
        await page.screenshot(path=str(OUT/'held-right.png'))
        # Reversing the finger should pass through neutral, not teleport the
        # visual in the opposite direction; cancelling should return it home.
        await page.evaluate('window.__bunbreak.aim(1,{x:-1,y:0},1);window.__bunbreak.advance(1/60)')
        reversing=await page.evaluate('window.__bunbreak.inspect().motion.buns.find(b=>b.id===1)')
        assert reversing['offset']['x'] < 0, reversing
        for i in range(6): await page.evaluate('window.__bunbreak.advance(.08)')
        reversed_bun=await page.evaluate('window.__bunbreak.inspect().motion.buns.find(b=>b.id===1)')
        assert reversed_bun['pullDeformation']['axis'][0] > .99 and reversed_bun['pullDeformation']['amount'] > .45, reversed_bun
        await page.evaluate('window.__bunbreak.cancelAim(1)')
        for i in range(9): await page.evaluate('window.__bunbreak.advance(.08)')
        cancelled=await page.evaluate('window.__bunbreak.inspect().motion.buns.find(b=>b.id===1)')
        assert not cancelled['held'] and cancelled['pullDeformation']['amount'] < .01 and abs(cancelled['offset']['x']) < .01, cancelled
        # Check the actual shader field's far edge and finger side in several
        # directions, including a diagonal which used to cancel its stretch.
        for direction in ({'x':0,'y':1}, {'x':0,'y':-1}, {'x':0.70710678,'y':0.70710678}):
            await page.evaluate('d => {const g=window.__bunbreak;g.chooseLevel(0);g.aim(1,d,1);for(let i=0;i<10;i++)g.advance(.08);}',direction)
            sample=await page.evaluate('window.__bunbreak.inspect().motion.buns[0].pullDeformation')
            a=sample['axis']; center=[0,.84,0]
            back=[center[i]-.76*a[i] for i in range(3)]
            front=[center[i]+.76*a[i] for i in range(3)]
            assert max(abs(sample['anchor'][i]-back[i]) for i in range(3)) < .001, sample
            assert sum((sample['fingerSide'][i]-front[i])*a[i] for i in range(3)) > .42, sample
        await page.evaluate('''() => {const g=window.__bunbreak;g.chooseLevel(0);g.aim(1,{x:.70710678,y:.70710678},1);
          for(let i=0;i<30;i++)g.advance(1/60);g.release(1,{x:7,y:7});for(let i=0;i<3;i++)g.advance(1/60);}''')
        diagonal=await page.evaluate('window.__bunbreak.inspect().motion.buns[0]')
        assert abs(diagonal['directional']) > .005 and abs(diagonal['bodyMatrix'][2]) > .005, diagonal
        assert abs(diagonal['volume'] - 1) < .002, diagonal # Body bone determinant only, not the nonlinear mesh field.
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
        print('Character browser checks passed: anchored held pull, reversal, cancel, and both rendered merge arrivals.')
        await browser.close()

asyncio.run(main())
