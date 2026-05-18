# TimesBar — Release Notes

## v0.1.0 — 2026-05-18

First runnable build.

- SwiftUI `MenuBarExtra` with compact label (status dot + elapsed time + 7-day sparkline).
- Active timer section with Stop button.
- Quick-start from the 5 most recent timesheets.
- Today / This week totals.
- Token stored in macOS Keychain; first-run sheet verifies via `GET /api/ping`.
- Polls `GET /api/timesheets/active` every 10s; ticks elapsed every 1s.

### Build & install (ad-hoc)

```bash
xcodegen generate
xcodebuild -project TimesBar.xcodeproj \
  -scheme TimesBar -configuration Release \
  -derivedDataPath build/derived \
  -archivePath build/TimesBar.xcarchive \
  archive
mkdir -p build/export
cp -R build/TimesBar.xcarchive/Products/Applications/TimesBar.app build/export/
codesign --force --deep --sign - build/export/TimesBar.app
cp -R build/export/TimesBar.app /Applications/
open /Applications/TimesBar.app
```

First launch may be blocked by Gatekeeper. Right-click the app in `/Applications` → `Open` to allow it, or:

```bash
xattr -dr com.apple.quarantine /Applications/TimesBar.app
```

### Login Items (optional)

`System Settings` → `General` → `Login Items` → drag `/Applications/TimesBar.app` into "Open at Login".
