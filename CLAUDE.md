# CLAUDE.md

Client service-agreement generator for TCO (The Contractors Office), built for a
non-technical user (Yehuda). Ships two ways from ONE source: `index.html` (runs as a
plain file in a browser) and `electron/` (the same file wrapped as the Windows/Mac
desktop app users actually download).

## Golden rules
- `index.html` IS the app — one self-contained file, no frameworks, no CDNs, no
  build step. ES5-style JS, string-built DOM, inline `on*` handlers.
- After ANY edit to `index.html`: `cp index.html electron/index.html` (they must
  stay identical; the desktop build packages the electron copy).
- User data lives in localStorage (`tco_app_v2` settings, `tco_draft_v2` current
  draft). Never rename keys or reshape stored data without a migration
  (see `migrateState()` / `loadDraft()` — old drafts must keep loading).
- Content defaults come from TCO's real signed agreements and pricing sheet
  (see `defaults()`); the legal clauses carry an attorney-review disclaimer — keep it.
- UI style: no emoji in chrome, inline SVG icons, navy `#052B6A` primary,
  lime `#8EB91A` accents only. Write UI copy for a non-technical reader.

## Where things are (all inside index.html)
- `defaults()` — company/branding, `services[]` (per-service wording sections,
  packages with per-tier addOns, defaultFees), `legal[]`, `rates[]`, `ai`.
- Draft model — `serviceIds[]` (multi = combined agreement), per-service wording
  copies in `svc[]`, `header`, `fees[]` (types: package/addon/onetime/monthly/
  perunit/seasonal/project), `legalOn`, `paymentTerms`.
- Rendering — `renderForm()` (left pane), `renderPreview()` (document, dynamic
  section numbering), `renderSettings()`; `dirty(structural)` saves + repaints.
- AI drafting — `buildAIPrompt()` (catalog + JSON schema) → `applyAIResult()`.
  Connection order: `window.tcoNative` (desktop → spawns `claude -p`, user's
  subscription) → localhost helper `:8765` (`tco_ai_helper.py`) → API key →
  claude.ai copy/paste. Degrade gracefully; never hard-require any of them.
- Desktop shell — `electron/main.js` (Claude Code discovery across GUI-safe
  paths, `save-pdf` via `printToPDF`), `electron/preload.js` (bridge).

## Verify (before every push)
Playwright drives the real thing; suites live in the session scratchpad
(`test_v3.js`, `test_header.js`, `test_electron.js`, `test_helper.js` — recreate
from git history if lost). Browser: `NODE_PATH=/opt/node22/lib/node_modules node
test_v3.js` against `file:///.../index.html`. Desktop: download the Linux Electron
binary and run under `xvfb-run` with a stub `claude` on PATH. Minimum bar: combo
agreement renders + renumbers, fee totals correct, AI paste-back applies, draft
survives reload, PDF generates, zero console errors (ignore the expected
`ERR_CONNECTION_REFUSED` helper ping).

## Release
Work on branch `claude/tco-proposal-generator-plan-mjyaqi`; local tag pushes are
403-blocked. Ship via GitHub Actions (`.github/workflows/build-desktop.yml`):
either dispatch with input `tag: vX.Y.Z`, or edit the `RELEASE` file (first line
= tag, bump every release) and push — both build Win x64 + Mac arm64/x64 zips
and publish a GitHub Release, which is where the user downloads the app.

iOS (`ios/`): native WKWebView shell around the same index.html (CI copies it
into `ios/Resources/` — never commit that copy). XcodeGen spec `ios/project.yml`;
the Swift shell bridges window.print → iOS print sheet, JS dialogs, and sends
external links to Safari. `.github/workflows/build-ios.yml`: `validate` job
builds + launches in an iPhone simulator (hard gate, screenshot artifact);
`testflight` job (dispatch with upload=true) archives with cloud-managed
automatic signing and uploads — needs secrets APPLE_TEAM_ID, APPSTORE_KEY_ID,
APPSTORE_ISSUER_ID, APPSTORE_PRIVATE_KEY, plus a one-time app record
(bundle id com.tco.agreementgenerator) in App Store Connect.

macOS facts (learned the hard way — don't regress):
- Mac job runs on `macos-26` (match the user's OS), packages with
  electron-builder pinned to Electron 33 (`-c.electronVersion`, macOS 10.15+),
  ad-hoc signs via `ci/sign-mac.js` (@electron/osx-sign@1, per-helper — a blunt
  `codesign --deep` breaks helpers), then `ci/smoke-mac.js` must LAUNCH the
  arm64 app before release (hard gate; Intel-under-Rosetta check is best-effort).
- Ad-hoc-signed apps crash at launch on DOWNLOADED (quarantined) copies:
  dyld "different Team IDs" refusing Electron Framework. On macOS 26.5+
  `xattr -cr` alone is NOT enough (confirmed on user's 26.5.2) — the app must
  also be re-signed locally with `codesign --force --deep --sign -`. Both steps
  ship in "Fix and Open (Mac).command" inside each Mac zip (source:
  `ci/fix-and-open-command.sh`; the blunt local --deep re-sign is fine because
  it drops hardened runtime, unlike CI signing). The real fix would be
  Developer ID signing + notarization (needs Apple Developer Program).
