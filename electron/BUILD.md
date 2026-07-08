# Building the desktop app

The app itself is `index.html` (kept in sync with the repo root copy).
`main.js` + `preload.js` add the native shell: a window, direct Claude Code
drafting (subscription), and native Save-as-PDF.

```bash
npm install @electron/packager electron
export ELECTRON_MIRROR="https://npmmirror.com/mirrors/electron/"   # if GitHub releases are blocked
npx electron-packager ./electron "TCO Agreement Generator" --platform=win32  --arch=x64   --icon=electron/tco.ico  --out=dist --overwrite
npx electron-packager ./electron "TCO Agreement Generator" --platform=darwin --arch=arm64 --icon=electron/tco.icns --out=dist --overwrite
npx electron-packager ./electron "TCO Agreement Generator" --platform=darwin --arch=x64   --icon=electron/tco.icns --out=dist --overwrite
# packager sometimes skips the darwin icon; if so, overwrite
#   <app>.app/Contents/Resources/electron.icns  with  electron/tco.icns
```

Zip the outputs (`zip -ry` for the .app bundles to preserve symlinks).
