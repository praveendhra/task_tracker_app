// Renders the demo build at phone and desktop sizes, light and dark.
// Usage: node tool/screenshots.mjs <baseUrl> <outDir>
import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';

const [base = 'http://localhost:8080', out = 'screenshots'] = process.argv.slice(2);
mkdirSync(out, { recursive: true });

const viewports = {
  phone: { viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true },
  desktop: { viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1 },
};

const q = encodeURIComponent('Rotate SQL creds fri #work !high');
// [viewport, theme, query, name]
const shots = [
  ['phone', 'light', '', 'home'],
  ['phone', 'dark', '', 'home'],
  ['phone', 'light', 'screen=detail', 'detail'],
  ['phone', 'dark', 'screen=detail', 'detail'],
  ['phone', 'light', 'screen=editor', 'editor'],
  ['phone', 'light', 'screen=new', 'new'],
  ['phone', 'light', `screen=quick&q=${q}`, 'quick'],
  ['phone', 'dark', `screen=quick&q=${q}`, 'quick'],
  ['phone', 'light', 'screen=auth', 'auth'],
  ['phone', 'light', 'screen=archive', 'archive'],
  ['desktop', 'light', 'screen=detail', 'detail'],
  ['desktop', 'dark', 'screen=detail', 'detail'],
  ['desktop', 'light', 'screen=auth', 'auth'],
  ['desktop', 'light', 'screen=editor', 'editor'],
  ['desktop', 'light', `screen=quick&q=${q}`, 'quick'],
  ['desktop', 'light', 'screen=shortcuts', 'shortcuts'],
];

const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist'] });
let failed = 0;
for (const [vp, theme, query, label] of shots) {
  const ctx = await browser.newContext({ ...viewports[vp], colorScheme: theme });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
  const q = [query, `theme=${theme}`].filter(Boolean).join('&');
  const name = `${vp}-${theme}-${label}`;
  try {
    await page.goto(`${base}/?${q}`, { waitUntil: 'load' });
    await page.waitForFunction(() => !document.getElementById('boot'), null, { timeout: 45000 });
    await page.waitForTimeout(3500); // fonts, demo hook, animations
    await page.screenshot({ path: `${out}/${name}.png` });
    console.log(`ok   ${name}${errors.length ? `  (console errors: ${errors.slice(0, 3).join(' | ')})` : ''}`);
  } catch (e) {
    failed++;
    await page.screenshot({ path: `${out}/${name}-FAILED.png` }).catch(() => {});
    console.log(`FAIL ${name}: ${e.message}\n     ${errors.slice(0, 5).join('\n     ')}`);
  }
  await ctx.close();
}
await browser.close();
process.exit(failed ? 1 : 0);
