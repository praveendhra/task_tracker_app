// Store screenshots from the demo build, plus the Play feature graphic.
// Usage: node tool/store_screenshots.mjs <baseUrl> <outDir>
//   iphone-*.png   1290 x 2796  (App Store 6.7"/6.9" iPhone)
//   android-*.png  1080 x 2160  (Google Play phone)
//   feature-graphic.png 1024 x 500 (Google Play)
import { chromium } from 'playwright';
import { mkdirSync, readFileSync } from 'node:fs';

const [base = 'http://localhost:8080', out = 'store-screenshots'] = process.argv.slice(2);
mkdirSync(out, { recursive: true });

const devices = {
  iphone: { viewport: { width: 430, height: 932 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true },
  android: { viewport: { width: 360, height: 720 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true },
};
const q = encodeURIComponent('Book dentist tomorrow #home !high');
const shots = [
  ['1-home', 'light', ''],
  ['2-detail', 'light', 'screen=detail'],
  ['3-new', 'light', 'screen=new'],
  ['4-quick', 'light', `screen=quick&q=${q}`],
  ['5-dark', 'dark', ''],
  ['6-settings', 'light', 'screen=settings'],
];

const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist'] });
let failed = 0;
for (const [dev, opts] of Object.entries(devices)) {
  for (const [label, theme, query] of shots) {
    const ctx = await browser.newContext({ ...opts, colorScheme: theme });
    const page = await ctx.newPage();
    const name = `${dev}-${label}`;
    try {
      await page.goto(`${base}/?${[query, `theme=${theme}`].filter(Boolean).join('&')}`, { waitUntil: 'load' });
      await page.waitForFunction(() => !document.getElementById('boot'), null, { timeout: 45000 });
      await page.waitForTimeout(3500);
      await page.screenshot({ path: `${out}/${name}.png` });
      console.log(`ok   ${name}`);
    } catch (e) {
      failed++;
      console.log(`FAIL ${name}: ${e.message}`);
    }
    await ctx.close();
  }
}

// Feature graphic: icon, name and tagline on the brand colour.
const icon = readFileSync(new URL('../store/assets/play-icon-512.png', import.meta.url)).toString('base64');
const ctx = await browser.newContext({ viewport: { width: 1024, height: 500 }, deviceScaleFactor: 1 });
const page = await ctx.newPage();
await page.setContent(`<!doctype html><html><body style="margin:0;width:1024px;height:500px;
  background:linear-gradient(135deg,#4f46e5,#7c3aed);display:flex;align-items:center;gap:48px;padding:0 80px;box-sizing:border-box;
  font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;color:#fff">
  <img src="data:image/png;base64,${icon}" style="width:220px;height:220px;border-radius:48px;box-shadow:0 20px 50px rgba(0,0,0,.25)">
  <div><div style="font-size:64px;font-weight:800;line-height:1.05">Task Tracker</div>
  <div style="font-size:34px;opacity:.9;margin-top:10px">Step by step, every task.</div>
  <div style="font-size:24px;opacity:.75;margin-top:22px">Steps · due dates · daily summary</div></div></body></html>`);
await page.screenshot({ path: `${out}/feature-graphic.png` });
console.log('ok   feature-graphic');

await browser.close();
process.exit(failed ? 1 : 0);
