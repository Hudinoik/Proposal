# Building the desktop app

The app itself is `index.html` (kept identical to the repo-root copy).
`main.js` + `preload.js` add the native shell: window, direct Claude Code
drafting (user's subscription), native Save-as-PDF.

Everything ships via CI: `.github/workflows/build-desktop.yml`
(dispatch with input `tag: vX.Y.Z`).

- **Windows**: @electron/packager on ubuntu (icon embeds via resedit, no wine).
- **macOS**: electron-builder on macos-latest. It ad-hoc signs every nested
  helper with correct entitlements — do NOT replace this with a manual
  `codesign --deep`, which breaks Electron helpers and crashes the app on
  launch. Config lives in the root `package.json` ("build" key; two-package
  layout with `directories.app = electron`). `ci/smoke-mac.js` launches the
  packaged app on the runner and fails the build if no window renders.
- If GitHub release downloads are blocked locally, set
  `ELECTRON_MIRROR="https://npmmirror.com/mirrors/electron/"`.
