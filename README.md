# TimesBar

A native macOS menu bar app for [Kimai](https://www.kimai.org/) time tracking.

Live active timer with an elapsed counter in the menu bar dropdown, one-click stop / pause / stop-with-description / discard, quick-start from recent entries, an inline form for starting fresh sessions, daily progress against an 8h target, and a weekly bar chart of clocked hours — all inside a SwiftUI `MenuBarExtra`. The Kimai API token lives in the macOS Keychain.

## Install

### Build from source

Requires Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
git clone https://github.com/nangert/TimesBar.git
cd TimesBar
make install
open /Applications/TimesBar.app
```

`make install` runs `xcodegen`, archives a Release build, ad-hoc signs the `.app`, and copies it into `/Applications`.

### Direct download

1. Grab the latest `.zip` from [Releases](https://github.com/nangert/TimesBar/releases).
2. Unzip and drag `TimesBar.app` into `/Applications`.
3. macOS Gatekeeper will block the first launch (no Apple Developer ID). To allow it, either right-click the app in `/Applications` → **Open** → confirm, or run:
   ```bash
   xattr -dr com.apple.quarantine /Applications/TimesBar.app
   ```

## Launch reminders

**Settings → Launch reminders** turns on a one-time banner the first time you activate a dev tool without a Kimai timer running. Curated list out of the box (VS Code, Xcode, the JetBrains family, Zed, Cursor); per-app toggles let you trim it. The banner has a "Start last activity" action that restarts your most recent timesheet via `/restart?copy=all`. Debounce: at most one reminder per no-timer interval — start a timer and the next idle stretch becomes eligible again.

Notification permission is requested when you first enable the master toggle. If you deny, grant it later from **System Settings → Notifications → TimesBar**.

## Languages

English and German. TimesBar follows the macOS system language — set **System Settings → General → Language & Region** to Deutsch and relaunch.

## Setup

Click the timer icon in your menu bar. Paste a Kimai API token from your Kimai user profile (**Settings → API access**) and click **Verify & save**. The token is verified via `GET /api/ping` and stored in your login keychain.

To point TimesBar at a different Kimai install, open **Settings → Server** and enter your instance base URL.

## URL schemes

TimesBar registers the `timesbar://` URL scheme so external tools (macOS Shortcuts, Alfred, Raycast, BetterTouchTool, the Terminal) can drive the timer without going through the menu bar dropdown.

| URL | Behavior |
|-----|----------|
| `timesbar://stop` | Stop the running timer. No-op if nothing is running. |
| `timesbar://startLast` | Resume your most recent timesheet via Kimai's `/restart?copy=all` (preserves description + tags). No-op if a timer is already running. |
| `timesbar://toggle` | Same as the ⌘⌥T hotkey — stop if running, otherwise resume the most recent entry. |
| `timesbar://pause` | Pause the running timer. Click Resume in the menu, or call `timesbar://startLast`, to pick up where you left off via `/restart?copy=all`. |
| `timesbar://web` | Open your Kimai instance in the default browser. |

From the Terminal:

```bash
open "timesbar://toggle"
```

From a macOS Shortcut, add the **Open URLs** action, paste the URL, and assign a keyboard shortcut via the **ⓘ** menu.

## Development

```bash
make test       # run the unit-test suite
make app        # archive + ad-hoc sign; bundle ends up in build/export
make zip        # produce build/TimesBar-v<VERSION>.zip
make clean      # delete build/ and the generated Xcode project
make release VERSION=0.1.0   # cut a tagged GitHub release with the zip
```

The Xcode project is regenerated from [`project.yml`](project.yml) on every build — `TimesBar.xcodeproj/` is gitignored on purpose.

## Architecture

See [`docs/superpowers/plans/2026-05-18-timesbar-menu-bar-app.md`](docs/superpowers/plans/2026-05-18-timesbar-menu-bar-app.md) for the original implementation plan with the file map and ticket breakdown.

## License

[MIT](LICENSE).
