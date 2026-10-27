"""Capture a real pointer-driven shot as an animated WebP in Chromium."""
import asyncio,io,os
from pathlib import Path
from PIL import Image
from playwright.async_api import async_playwright
OUT=Path(__file__).resolve().parents[2]/'reports'/'tactile-review'; OUT.mkdir(parents=True,exist_ok=True)
async def main():
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path=os.environ.get('CHROMIUM_PATH','/usr/bin/chromium'),headless=True,args=['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader','--disable-dev-shm-usage'])
  page=await browser.new_page(viewport={'width':390,'height':844})
  errors=[]
  page.on('pageerror',lambda e:errors.append(str(e)))
  page.on('console',lambda m:errors.append(m.text) if m.type=='error' and '404' not in m.text else None)
  await page.goto('http://127.0.0.1:4173',wait_until='networkidle'); await page.wait_for_function('!!window.__bunbreak')
  await page.evaluate('window.__bunbreak.freeze();window.__bunbreak.chooseLevel(0);window.__bunbreak.advance(1/60)')
  origin=await page.evaluate('window.__bunbreak.screenFor(1)'); frames=[]
  async def frame():
   await page.evaluate('window.__bunbreak.advance(1/30)')
   frames.append(Image.open(io.BytesIO(await page.screenshot())).convert('RGB'))
  for _ in range(6): await frame()
  await page.mouse.move(origin['x'],origin['y']); await page.mouse.down()
  for n in range(1,15):
   await page.mouse.move(origin['x']+90*n/14,origin['y']); await frame()
  for _ in range(8): await frame()
  assert (await page.evaluate('window.__bunbreak.inspect().motion.buns[0].held'))
  await page.mouse.up()
  for _ in range(30): await frame()
  assert (await page.evaluate('window.__bunbreak.inspect().shots'))==1
  assert not errors,errors
  frames[0].save(OUT/'actual-pointer-pull.webp',save_all=True,append_images=frames[1:],duration=33,loop=0,quality=85,method=4)
  print('Captured',len(frames),'actual pointer-driven rendered frames; shot launched; no browser/shader errors',flush=True)
  await browser.close()
asyncio.run(main())
