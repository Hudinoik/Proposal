/* Ad-hoc signs .app bundles with @electron/osx-sign (per-helper signing with
   Electron's default entitlements — a blunt `codesign --deep` breaks helpers).
   Tolerates both CJS and ESM export shapes across package versions.
   Usage: node ci/sign-mac.js <app> [<app>...] */

(async () => {
  const apps = process.argv.slice(2);
  if (!apps.length) { console.error('usage: node ci/sign-mac.js <path.app> [...]'); process.exit(1); }

  const mod = await import('@electron/osx-sign');
  const root = mod.default || mod;
  const sign = mod.signAsync || root.signAsync || mod.sign || root.sign;
  if (typeof sign !== 'function') {
    console.error('SIGN FAILED: no sign function exported. Available keys:', Object.keys(mod), root ? Object.keys(root) : []);
    process.exit(1);
  }
  for (const app of apps) {
    console.log('signing (ad-hoc):', app);
    /* identityValidation:false skips the keychain lookup so the ad-hoc
       identity '-' is used as-is (verified against osx-sign v1 source) */
    await sign({ app, identity: '-', identityValidation: false });
  }
  console.log('SIGN OK');
})().catch((e) => { console.error('SIGN FAILED:', e); process.exit(1); });
