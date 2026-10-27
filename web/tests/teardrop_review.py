"""Render phone-size tear silhouettes; report a Pip side-pull width profile.

The profile is an image-space diagnostic, not a proof of 3D volume or appeal.
Use alongside the saved native frames and crops. Example:
  python3 web/tests/teardrop_review.py before --port 4174
"""
import argparse, asyncio, json, os
from pathlib import Path
from PIL import Image, ImageDraw
from playwright.async_api import async_playwright

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'reports'/'teardrop-review'

def pip_profile(image):
    # Cream torso pixels, excluding green board, dark face and gold aim cues.
    columns={}
    for x in range(image.width):
        ys=[]
        for y in range(image.height):
            r,g,b=image.getpixel((x,y))[:3]
            if r>140 and g>125 and b>85 and 0<r-g<35 and 8<g-b<60:
                ys.append(y)
        if len(ys)>=4: columns[x]=max(ys)-min(ys)+1
    if not columns:return {}
    lo,hi=min(columns),max(columns)
    peak=max(columns.values())
    tip_x=round(lo+(hi-lo)*.80)
    tip=sum(columns.get(x,0) for x in range(tip_x-1,tip_x+2))/3
    peak_x=max(columns,key=columns.get)
    return {'bounds':[lo,hi],'max_thickness_px':peak,'max_thickness_fraction':(peak_x-lo)/max(1,hi-lo),
        'tip80_thickness_px':tip,'tip80_to_max':tip/max(1,peak),'columns':columns}

async def main(label,port):
    folder=OUT/label;folder.mkdir(parents=True,exist_ok=True)
    captures=[];checks={};errors=[]
    async with async_playwright() as p:
        browser=await p.chromium.launch(executable_path=os.environ.get('CHROMIUM_PATH','/usr/bin/chromium'),headless=True,
            args=['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader','--disable-dev-shm-usage'])
        page=await browser.new_page(viewport={'width':390,'height':844})
        page.on('pageerror',lambda e:errors.append(str(e)))
        page.on('console',lambda m:errors.append(m.text) if m.type=='error' and '404' not in m.text else None)
        await page.goto(f'http://127.0.0.1:{port}',wait_until='networkidle')
        await page.wait_for_function('!!window.__bunbreak')
        await page.evaluate('window.__bunbreak.freeze()')
        for tier in (1,2,3):
            await page.evaluate('''tier=>{const g=window.__bunbreak;g.chooseLevel(tier===1?0:tier===2?5:3);
                if(tier===3){g.release(1,{x:0,y:3});for(let i=0;i<600;i++)g.advance(1/60,false);}
                for(let i=0;i<9;i++)g.advance(1/12);
            }''',tier)
            state=await page.evaluate('window.__bunbreak.inspect()')
            id=next(b['id'] for b in state['buns'] if b['tier']==tier)
            for name,direction,strength in [('rest',[0,0],0),('right-weak',[-1,0],.3),('right',[-1,0],1),
                    ('up',[0,-1],1),('down',[0,1],1),('diagonal',[-.70710678,.70710678],1)]:
                await page.evaluate('''v=>{const g=window.__bunbreak;g.cancelAim(v[0]);for(let i=0;i<7;i++)g.advance(1/12);
                    if(v[3])g.aim(v[0],{x:v[1],y:v[2]},v[3]);for(let i=0;i<7;i++)g.advance(1/12);
                }''',[id,*direction,strength])
                pos=await page.evaluate('id=>window.__bunbreak.screenFor(id)',id)
                filename=f'tier{tier}-{name}'
                await page.screenshot(path=str(folder/(filename+'.png')))
                with Image.open(folder/(filename+'.png')) as full:
                    # Wider than the prior review, leaving room for a real tip.
                    detail=full.convert('RGB').crop((round(pos['x']-100),round(pos['y']-130),round(pos['x']+100),round(pos['y']+70)))
                    detail.save(folder/(filename+'-detail.png'))
                    if tier==1 and name=='right':checks['pip_right_profile']=pip_profile(detail)
                captures.append((tier,name,filename))
                if tier==1 and strength==1:
                    checks[name+'_field']=await page.evaluate('''async()=>{
                        const {samplePullDeformation}=await import('./js/localized_pull.js');
                        const f=window.__bunbreak.inspect().motion.buns[0].pullDeformation;
                        const c=[0,.84,0],eps=.0005;let min=Infinity,at=null,negative=0,count=0;
                        for(let x=-.7;x<=.701;x+=.1)for(let y=-.7;y<=.701;y+=.1)for(let z=-.7;z<=.701;z+=.1){
                            if(x*x+y*y+z*z>.76*.76)continue;
                            const p=[x,y+.84,z],cols=[];
                            for(let a=0;a<3;a++){
                                const plus=[...p],minus=[...p];plus[a]+=eps;minus[a]-=eps;
                                const u=samplePullDeformation(plus,f.axis,f.amount,c),v=samplePullDeformation(minus,f.axis,f.amount,c);
                                cols.push(u.map((n,i)=>(n-v[i])/(2*eps)));
                            }
                            const [a,b,d]=cols;
                            const determinant=a[0]*(b[1]*d[2]-b[2]*d[1])-b[0]*(a[1]*d[2]-a[2]*d[1])+d[0]*(a[1]*b[2]-a[2]*b[1]);
                            count++;if(determinant<0)negative++;
                            if(determinant<min){min=determinant;at=p;}
                        }
                        return {minimum_jacobian_determinant:min,at,negative_samples:negative,total_samples:count};
                    }''')
                    if label!='before':
                        field=checks[name+'_field']
                        assert field['negative_samples']==0 and field['minimum_jacobian_determinant']>0.01,field
                assert (await page.evaluate('window.__bunbreak.inspect().shots'))==(1 if tier==3 else 0)
        assert not errors,errors
        await browser.close()
    for tier in (1,2,3):
        size=300;sheet=Image.new('RGB',(size*3,(size+25)*2),'#f4f0e4');draw=ImageDraw.Draw(sheet)
        for i,(_,name,filename) in enumerate(c for c in captures if c[0]==tier):
            with Image.open(folder/(filename+'-detail.png')) as im:sheet.paste(im.resize((size,size)),((i%3)*size,(i//3)*(size+25)))
            draw.text(((i%3)*size+5,(i//3)*(size+25)+size+5),name,fill='#244b42')
        sheet.save(folder/f'tier{tier}-sheet.png')
    if label!='before' and (OUT/'before').exists():
        size=300;comparison=Image.new('RGB',(size*4,(size+25)*3),'#f4f0e4');draw=ImageDraw.Draw(comparison)
        for row,tier in enumerate((1,2,3)):
            for col,(version,direction) in enumerate((('before','right'),(label,'right'),('before','diagonal'),(label,'diagonal'))):
                file=OUT/version/f'tier{tier}-{direction}-detail.png'
                with Image.open(file) as im:comparison.paste(im.resize((size,size)),(col*size,row*(size+25)))
                draw.text((col*size+5,row*(size+25)+size+5),f'tier{tier}: {version} {direction}',fill='#244b42')
        comparison.save(OUT/'comparison.png')
    (folder/'checks.json').write_text(json.dumps({'errors':errors,'captures':len(captures),'checks':checks},indent=2))
    print(label,':',len(captures),'actual phone frames; shader/page errors clean; width profile',checks['pip_right_profile']['tip80_to_max'])

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('label');parser.add_argument('--port',type=int,default=4173)
    a=parser.parse_args();asyncio.run(main(a.label,a.port))
