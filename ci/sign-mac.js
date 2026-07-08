/* Ad-hoc signs .app bundles with @electron/osx-sign's JS API (the CLI's
   flags vary between versions; the API is stable). osx-sign signs every
   nested helper with Electron's default entitlements, which a blunt
   `codesign --deep` does not. Usage: node ci/sign-mac.js <app> [<app>...] */
const { signAsync } = require('@electron/osx-sign');

(async () => {
  const apps = process.argv.slice(2);
  if (!apps.length) { console.error('usage: node ci/sign-mac.js <path.app> [...]'); process.exit(1); }
  for (const app of apps) {
    console.log('signing (ad-hoc):', app);
    await signAsync({ app, identity: '-' });
  }
  console.log('SIGN OK');
})().catch((e) => { console.error('SIGN FAILED:', e); process.exit(1); });
