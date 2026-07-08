/* Launches the packaged macOS app on the CI Mac and fails the build if it
   doesn't open a window. Usage: node ci/smoke-mac.js "<path to app binary>" */
const { _electron } = require('playwright-core');

(async () => {
  const bin = process.argv[2];
  if (!bin) { console.error('usage: node ci/smoke-mac.js <app binary>'); process.exit(1); }
  console.log('launching', bin);
  const app = await _electron.launch({ executablePath: bin, timeout: 60000 });
  const win = await app.firstWindow({ timeout: 60000 });
  const title = await win.title();
  console.log('window title:', title);
  const body = await win.locator('body').innerText();
  const ok = title.includes('TCO Agreement Generator') && body.includes('Choose the service');
  if (!ok) { console.error('SMOKE FAILED: window content unexpected'); process.exit(1); }
  await app.close();
  console.log('SMOKE OK — packaged app launches and renders on macOS');
})().catch((e) => { console.error('SMOKE FAILED:', e); process.exit(1); });
