# TimesBar v0.5.0 — QoL Feature Bundle

Bundle of ten QoL features for v0.5.0. All land in a single worktree on `feature/qol-bundle`, one commit per feature, one final PR closing the corresponding GitHub issues.

## Conventions

- Branch: `feature/qol-bundle` (one bundled PR; each commit closes its issue via "Closes #N" trailer).
- Worktree: `/Users/nangert/PycharmProjects/TimesBar-qol`.
- Implementation: each task executed by a fresh Sonnet implementer subagent, then reviewed by Opus spec + quality reviewers per `superpowers:subagent-driven-development`.
- Pre-commit gate per task: `xcodebuild -scheme TimesBar build` clean (0 warnings, 0 errors); existing tests still pass; new tests written for new pure logic where applicable.
- Settings persistence: new `Storage/UserPreferences.swift` keyed off `UserDefaults.standard` with strongly-typed accessors. Used by tasks 1, 7, 8.
- Settings UI surface: existing `.settings` route is rebound from `TokenSetupForm` only to a new `SettingsView` that hosts tabs/sections for Token, Server, Behavior. Tasks 1+ extend it.

## Task 1 — Configurable Kimai base URL

**Why:** README says it's hardcoded; the only blocker for anyone else trying TimesBar with their own Kimai.

**Files:**
- `TimesBar/Storage/UserPreferences.swift` (new) — strongly-typed `UserDefaults` wrapper, starts with `baseURL: URL` accessor.
- `TimesBar/Networking/KimaiClient.swift` — default init now reads from `UserPreferences.shared.baseURL` instead of literal.
- `TimesBar/Views/SettingsView.swift` (new) — replaces direct mounting of `TokenSetupForm` for `.settings` route. Hosts the token form and a "Server" section with a base URL field.
- `TimesBar/Views/MenuBarView.swift` — `.settings` case renders `SettingsView`.
- `TimesBar/Views/FooterRow.swift` — the "Open web" button reads base URL from `UserPreferences`.
- `TimesBar/State/TimerStore.swift` — rebuild `client` if base URL changes mid-session.
- `README.md` — drop the "hardcoded" caveat; document the setting.

**Acceptance:**
- Default base URL is `https://times.lipsum.services` (preserves existing behavior for current users).
- Pasting a new URL in Settings → Server saves immediately; the next API call uses it.
- Invalid URLs (non-HTTPS, malformed) get inline validation; nothing saved.
- The "Open web" footer button respects the new URL.

## Task 2 — Sleep-wake reconciliation

**Why:** Single biggest "forgotten timer" fix; no settings UI required.

**Files:**
- `TimesBar/State/TimerStore.swift` — new `handleWillSleep()` / `handleDidWake()` that snapshot the running timer's begin, compute slept-duration, and stash a pending reconciliation prompt in `@Published var pendingSleepReconciliation: SleepReconciliation?`.
- `TimesBar/State/SleepObserver.swift` (new) — wraps `NSWorkspace.shared.notificationCenter` `willSleepNotification` / `didWakeNotification` and forwards to `TimerStore`.
- `TimesBar/Views/SleepReconciliationSheet.swift` (new) — modal-ish view shown in `MenuBarView` whenever `pendingSleepReconciliation != nil`. Three buttons: *Keep time as-is*, *Backdate stop to before sleep*, *Split: stop before sleep, start fresh now*.
- `TimesBar/Views/MenuBarView.swift` — conditionally render `SleepReconciliationSheet` above other content when there's a pending prompt.
- `TimesBar/TimesBarApp.swift` — instantiate `SleepObserver` alongside `TimerStore`.
- Tests: pure helpers in `TimerStore` for the reconciliation math (slept duration computation, "Backdate stop" date math).

**Acceptance:**
- Only triggers when sleep lasted ≥ 10 minutes AND a timer was running.
- "Backdate stop to before sleep" calls `client.updateTimesheet(id:..., end: sleepStart)` → stops the timer at the moment of sleep.
- "Split" calls `updateTimesheet` to stop the old entry at sleepStart, then `client.start(...)` with the same project/activity/description to start a new one at wake time.
- Dismissing the prompt clears `pendingSleepReconciliation` and never re-fires for that sleep.

## Task 3 — End-of-day auto-stop

**Files:**
- `TimesBar/Storage/UserPreferences.swift` — add `autoStopEnabled: Bool`, `autoStopTime: DateComponents` (hour+minute).
- `TimesBar/State/TimerStore.swift` — in `startTimers()`, add a third Timer that fires every minute; if the active timer's wall-clock crosses the configured stop time today, call `stop()` and notify.
- `TimesBar/Views/SettingsView.swift` — add **Behavior → Auto-stop** section: toggle + time picker (HH:mm).
- Tests: pure helper `shouldAutoStop(now: Date, runningSince: Date, prefs: UserPreferences) -> Bool` covering same-day, midnight wrap, disabled.

**Acceptance:**
- Disabled by default.
- When enabled at 19:00, a timer started at 09:00 stops at 19:00 (auto-stop fires within ~60 s of the configured time).
- A toast/banner (or notification) tells the user it auto-stopped, with an "undo" affordance that PATCHes end back to nil (restart).

## Task 4 — Idle detection

**Files:**
- `TimesBar/Storage/UserPreferences.swift` — add `idleDetectionEnabled: Bool`, `idleThresholdMinutes: Int` (default 15).
- `TimesBar/State/IdleMonitor.swift` (new) — wraps `CGEventSource.secondsSinceLastEventType(.combinedSessionState, .anyInputEventType)`, polls every 30 s.
- `TimesBar/State/TimerStore.swift` — on idle-threshold-crossed-while-timer-running, set `@Published var pendingIdlePrompt: IdlePrompt?` with `idleStart: Date`.
- `TimesBar/Views/IdlePromptSheet.swift` (new) — buttons *Keep time*, *Backdate stop to when I went idle*. Mirrors sleep prompt structure.
- `TimesBar/Views/MenuBarView.swift` — render the idle prompt above main content.
- `TimesBar/Views/SettingsView.swift` — Behavior → Idle detection section: toggle + minutes stepper.
- Tests: pure helper `idleStartedAt(now: Date, secondsIdle: TimeInterval) -> Date`.

**Acceptance:**
- Disabled by default.
- Threshold default 15 min, configurable 5–60 min.
- Prompt only fires once per idle session (doesn't re-fire every poll).
- Dismissing the prompt without action doesn't lose the idle period — it stays available until user clicks one of the two options.

## Task 5 — Today's logged total in the dropdown

**Files:**
- `TimesBar/State/TimerStore.swift` — derive `var todayHours: Double` from `weekHours[indexOfToday]` (already populated) + running timer's elapsed.
- `TimesBar/Views/TodayProgressView.swift` — gains a second line: `5h 12m today · 2h 48m to target` (the second segment respects `hoursPerWorkingDay`).
- Tests: extend `WeekStatsTests` (or wherever the math lives) with `todayHours(weekHours:, runningElapsed:)`.

**Acceptance:**
- Updates live (every tick) while a timer runs.
- "to target" segment switches to "over target by Xh Ym" once exceeded.
- Reads 0h 0m today when no entries logged today.

## Task 6 — Color-coded projects

**Files:**
- `TimesBar/Models/ProjectEntity.swift` — read `color` field from Kimai API (returns hex string like `#FF6B35`). If absent, fall back to a deterministic hash-derived color (stable per project ID).
- `TimesBar/Views/Theme.swift` — `Color.forProject(id:title:overrideHex:)` helper.
- `TimesBar/Views/WeekBarChart.swift` — segments tinted per-project for the days that had multiple projects (stacked bar) OR keep single-tint but pick the dominant project's color (decision: stacked).
- `TimesBar/Views/QuickStartSection.swift` — small color dot before each project name.
- `TimesBar/Views/TimeRangeBar.swift` — existing-entry gray blocks become the project's color at low opacity.
- `TimesBar/Views/ActiveTimerSection.swift` — running-timer's "green dot" becomes the project's color.

**Acceptance:**
- Hash function for fallback colors is stable (same project ID → same color across sessions) and avoids near-duplicates (uses HSL with quantized hues).
- Project picker color dots match the visualization colors.
- Color blind-safe pairing where possible (no red/green confusion in adjacent slots in the bar chart).

## Task 7 — Tags support

**Files:**
- `TimesBar/Models/TimesheetEntity.swift` — already decodes `tags: [String]` per Kimai schema; ensure it's exposed.
- `TimesBar/Networking/KimaiClient.swift` — `createTimesheet` / `updateTimesheet` / `start` accept `tags: [String]?` and serialize to comma-separated string (Kimai's edit form takes `tags` as `"foo,bar"`).
- `TimesBar/State/TimerStore.swift` — propagate `tags` arg through `logEntry`, `updateActiveTimer`, `startCheckingResult`.
- `TimesBar/Networking/KimaiClient.swift` — add `tags() async -> [String]` calling `GET /api/tags`.
- `TimesBar/Views/StartTimerForm.swift`, `EditActiveTimerForm.swift` — new `TagsField` view: chip-style multi-select with autocomplete from `store.knownTags`.
- `TimesBar/Views/QuickStartSection.swift`, `SuggestionRow` — show tag chips next to the project title.

**Acceptance:**
- Starting/editing a timer with tags persists them; refreshing the menu confirms via the recent list showing them.
- Autocomplete pulls from `/api/tags` (debounced on focus, cached in TimerStore).
- New tags can be typed; submitted as-is (Kimai creates them on the fly).

## Task 8 — Right-click edit/delete/duplicate on recent rows

**Files:**
- `TimesBar/Views/QuickStartSection.swift` — each `QuickStartRow` gains a `.contextMenu { ... }` with Edit / Duplicate / Delete.
- `TimesBar/Views/EditTimesheetForm.swift` (new) — generalized form variant of `EditActiveTimerForm`, takes any timesheet ID, exposes begin AND end editing.
- `TimesBar/Views/MenuBarView.swift` — new `.editTimesheet(id: Int)` route case mounting `EditTimesheetForm`.
- `TimesBar/State/TimerStore.swift` — `deleteTimesheet(id:)`, `duplicateTimesheet(id:)` wrappers calling `KimaiClient.deleteTimesheet` (already exists in the API) and `KimaiClient.duplicateTimesheet` (`POST /api/timesheets/{id}/duplicate`, new wrapper).
- `TimesBar/Networking/KimaiClient.swift` — new `deleteTimesheet(id:)` and `duplicateTimesheet(id:)`.

**Acceptance:**
- Right-clicking a recent row opens a native macOS context menu.
- Edit jumps into a fully-editable timesheet form (begin/end/project/activity/note/tags).
- Delete confirms with a dialog before calling DELETE.
- Duplicate immediately POSTs the duplicate; the new entry appears in `recent` on next refresh.

## Task 9 — Quick-action right-click menu bar icon

**Files:**
- `TimesBar/Views/MenuBarLabel.swift` — add `.contextMenu` (or detect right-click via `NSEvent` and post a native menu). Actions: *Start last activity*, *Stop timer*, *Log past entry*.
- `TimesBar/State/TimerStore.swift` — already has `restart`/`stop`; "Start last activity" uses the most recent entry from `recent`.

**Acceptance:**
- Right-clicking the menu bar icon shows the native macOS menu (not the dropdown).
- "Start last activity" disabled when there's a running timer; "Stop timer" disabled when there's none.

## Task 10 — Global hotkey

**Files:**
- `TimesBar/State/HotkeyManager.swift` (new) — wraps Carbon `RegisterEventHotKey` or `NSEvent.addGlobalMonitorForEvents` for global modifier+key combos.
- `TimesBar/Storage/UserPreferences.swift` — `hotkeyEnabled: Bool`, `hotkeyKeyCode: Int`, `hotkeyModifiers: UInt`.
- `TimesBar/Views/SettingsView.swift` — Behavior → Hotkey section: toggle + key-recorder field.
- `TimesBar/TimesBarApp.swift` — instantiate `HotkeyManager` alongside `TimerStore`.

**Acceptance:**
- Disabled by default; when enabled with the default combo (⌘⌥T) and pressed, the menu bar dropdown opens.
- Configuring a new combo binds it after the user "records" two key presses (first sets modifier+key, second confirms).
- Conflicts (combo already taken by another app) surface a warning text.

## Sequencing

Tasks have only loose dependencies; sequential execution is enough since they all share the same worktree:

1. Task 1 (Configurable Kimai base URL) — also stands up `UserPreferences` + `SettingsView` foundation.
2. Task 5 (Today's total) — small, independent.
3. Task 6 (Color-coded projects) — affects rendering across multiple views; do before Task 7+8 so they pick up the colors.
4. Task 7 (Tags) — before Task 8 so the edit form already understands tags.
5. Task 8 (Right-click edit/delete/duplicate).
6. Task 2 (Sleep-wake) — no settings dep.
7. Task 3 (End-of-day auto-stop) — needs prefs from Task 1.
8. Task 4 (Idle detection) — needs prefs from Task 1.
9. Task 9 (Quick-action menu bar right-click).
10. Task 10 (Global hotkey) — most fragile (Carbon API); last so it can be cut without blocking the rest.

## Definition of done (whole bundle)

- All 10 tasks merged to `feature/qol-bundle` and both `xcodebuild build` and `xcodebuild test` are green.
- Single PR opened against main listing closed issues.
- After PR merge, a `chore/prepare-v0.5.0` PR bumps `project.yml` + `Info.plist` + writes `release-notes/v0.5.0.md`.
- `make release VERSION=0.5.0` ships the GitHub release.
