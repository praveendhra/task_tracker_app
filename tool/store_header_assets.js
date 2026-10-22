const { chromium } = require('playwright');
const fs = require('fs');
const D = process.argv[2];
const b64 = f => 'data:image/png;base64,' + fs.readFileSync(`${D}/${f}.png`).toString('base64');
const phone = (img, w, extra='') => `<div class="phone" style="width:${w}px;${extra}"><img src="${b64(img)}"></div>`;
const css = (W,H) => `
*{box-sizing:border-box;margin:0}
body{width:${W}px;height:${H}px;overflow:hidden;font-family:-apple-system,"SF Pro Display","Inter","Segoe UI",Roboto,sans-serif;
 background:radial-gradient(1400px 1000px at 85% 15%, rgba(255,255,255,.18), transparent 60%),
 linear-gradient(135deg,#3b37d6 0%,#5b4cf0 45%,#7c3aed 100%);color:#fff;position:relative}
.phone{border-radius:9.5%/4.4%;background:#0b0b12;padding:1.6%;box-shadow:0 60px 140px rgba(20,10,60,.45),0 0 0 4px rgba(255,255,255,.08) inset;position:absolute}
.phone img{width:100%;display:block;border-radius:8.2%/3.8%}
h1{font-weight:800;letter-spacing:-.02em;line-height:1.02}
p{opacity:.88;font-weight:500}
.dots{position:absolute;inset:0;background-image:radial-gradient(rgba(255,255,255,.07) 2px,transparent 2px);background-size:56px 56px;mask-image:linear-gradient(90deg,#000,transparent 70%)}
`;
const header = () => { const W=3840,H=1646; return `<html><head><style>${css(W,H)}</style></head><body><div class="dots"></div>
 <div style="position:absolute;left:300px;top:430px;width:1500px">
  <h1 style="font-size:168px">Step by step,<br>every task.</h1>
  <p style="font-size:62px;margin-top:56px">Break work into clear steps, see the next one,<br>and start each day with a summary.</p></div>
 ${phone('iphone-2-detail',640,'left:2050px;top:250px;transform:rotate(-6deg)')}
 ${phone('iphone-1-home',700,'left:2620px;top:120px;z-index:2')}
 ${phone('iphone-5-dark',640,'left:3200px;top:250px;transform:rotate(6deg)')}
</body></html>`; };
const search = () => { const W=3840,H=2560; return `<html><head><style>${css(W,H)}</style></head><body><div class="dots"></div>
 <div style="position:absolute;left:0;right:0;top:170px;text-align:center">
  <h1 style="font-size:190px">Step by step, every task.</h1>
  <p style="font-size:72px;margin-top:40px">Steps · due dates · quick add · daily summary</p></div>
 ${phone('iphone-3-new',780,'left:430px;top:820px;transform:rotate(-5deg)')}
 ${phone('iphone-1-home',860,'left:1490px;top:660px;z-index:2')}
 ${phone('iphone-4-quick',780,'left:2630px;top:820px;transform:rotate(5deg)')}
</body></html>`; };
(async () => {
  const br = await chromium.launch();
  for (const [name, W, H, html] of [['header-3840x1646',3840,1646,header()],['search-3840x2560',3840,2560,search()]]) {
    const pg = await br.newPage({ viewport:{width:W,height:H}, deviceScaleFactor:1 });
    await pg.setContent(html); await pg.waitForTimeout(500);
    await pg.screenshot({ path: `${D}/${name}.png` });
    await pg.screenshot({ path: `${D}/${name}.jpg`, type:'jpeg', quality: 90 });
    console.log('ok', name);
  }
  await br.close();
})();
