"""Exercise cloned deformation-resource cleanup, Undo and gentle motion."""
import asyncio, os
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        browser=await p.chromium.launch(executable_path=os.environ.get('CHROMIUM_PATH','/usr/bin/chromium'),headless=True,args=['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader','--disable-dev-shm-usage'])
        page=await browser.new_page(viewport={'width':390,'height':844})
        errors=[]
        page.on('pageerror',lambda e:errors.append(str(e)))
        page.on('console',lambda m:errors.append(m.text) if m.type=='error' and '404' not in m.text else None)
        await page.goto('http://127.0.0.1:4173',wait_until='networkidle')
        await page.wait_for_function('!!window.__bunbreak')
        await page.evaluate('window.__bunbreak.freeze()')
        resources=[]
        for _ in range(4):
            state=await page.evaluate('''()=>{
                const g=window.__bunbreak;g.chooseLevel(1);g.release(1,{x:0,y:7});
                for(let i=0;i<240;i++){g.advance(1/60,false);if(g.inspect().buns.some(b=>b.tier===2))break;}
                g.advance(1/60);g.undo();for(let i=0;i<8;i++)g.advance(1/60);
                return g.inspect();
            }''')
            assert state['shots']==0 and len(state['buns'])==2 and all(b['tier']==1 for b in state['buns']),state
            resources.append(state['motion']['resources'])
        assert resources[-1]==resources[-2]==resources[-3],resources
        await page.evaluate('window.__bunbreak.aim(1,{x:-1,y:0},1);window.__bunbreak.advance(.1);window.__bunbreak.pause()')
        await page.get_by_role('button',name='Motion: full',exact=True).click()
        await page.get_by_role('button',name='Keep playing',exact=True).click()
        state=await page.evaluate('''()=>{const g=window.__bunbreak;g.aim(1,{x:-1,y:0},1);for(let i=0;i<12;i++)g.advance(1/30);return g.inspect();}''')
        assert state['motion']['reducedMotion'] and state['motion']['buns'][0]['pullDeformation']['amount']<=.101,state
        await page.evaluate('window.__bunbreak.pause()')
        await page.get_by_role('button',name='Start over',exact=True).click()
        state=await page.evaluate('window.__bunbreak.advance(1/60);window.__bunbreak.inspect()')
        assert state['shots']==0 and not any(b['held'] for b in state['motion']['buns']),state
        assert not errors,errors
        print('Browser recovery passed: merge Undo, stable cloned-resource counts, gentle motion and Retry.')
        await browser.close()

asyncio.run(main())
