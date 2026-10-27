"""Compare actual rendered rig state across 30, 60 and 120 frame schedules."""
import asyncio
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        browser=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader','--disable-dev-shm-usage'])
        page=await browser.new_page(viewport={'width':240,'height':360})
        await page.goto('http://127.0.0.1:4173',wait_until='networkidle')
        await page.wait_for_function('!!window.__bunbreak',timeout=30000)
        await page.evaluate('window.__bunbreak.freeze()')
        states=[]
        for fps in [30,60,120]:
            state=await page.evaluate('''fps=>{
                const g=window.__bunbreak;g.chooseLevel(0);g.aim(1,{x:.6,y:.8},.9);
                for(let i=0;i<fps*.4;i++)g.advance(1/fps);
                const held=g.inspect();g.release(1,{x:3,y:6});
                for(let i=0;i<fps*.6;i++)g.advance(1/fps);
                return {held,release:g.inspect()};
            }''',fps)
            states.append(state)
        def flatten(state):
            out=[]
            for key in ['held','release']:
                b=state[key]['motion']['buns'][0]
                out.extend([b['height'],b['volume'],b['directional'],b['expression'],*b['crest'],*b['limbs'],b['offset']['x'],b['offset']['y']])
            return out
        baseline=flatten(states[0])
        for fps,state in zip([30,60,120],states):
            assert max(abs(a-b) for a,b in zip(baseline,flatten(state)))<.0001,(fps,state)
            assert abs(state['held']['motion']['buns'][0]['volume']-1)<.001
        print('Rendered rig motion passed at 30, 60 and 120 FPS; volume remains stable.')
        await browser.close()

asyncio.run(main())
