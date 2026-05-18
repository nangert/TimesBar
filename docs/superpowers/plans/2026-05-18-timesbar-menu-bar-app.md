# TimesBar — Kimai Menu Bar App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a native macOS menu bar app (`TimesBar`) that talks to Kimai at `https://times.lipsum.services`, shows the active timer with a compact label and a SwiftUI dropdown, and runs in production on the user's own Mac.

**Architecture:** SwiftUI `MenuBarExtra` with `LSUIElement=YES` (no Dock icon). One `ObservableObject` (`TimerStore`) owns all state and polls Kimai every 10s via an async `KimaiClient`. The API token lives in the macOS Keychain. Project is generated from a `project.yml` via XcodeGen so the layout is reproducible from source. Tests use Swift Testing (`@Test` macros) and inject `URLSession` for HTTP mocking.

**Tech Stack:** Swift 6.2, SwiftUI, macOS 14.0 deployment target, Swift Testing, URLSession, Security framework (Keychain), XcodeGen (build-time only).

**Scope boundaries (explicitly out of scope):**
- Code signing with a Developer ID, notarization, Sparkle auto-updates, Homebrew cask.
- Raycast extension, CLI, web dashboard alternatives.
- Anything not covered by sections 0–10 of the user's spec.

---

## Ticket Overview

| # | Branch | Ticket |
|---|--------|--------|
| 1 | `feature/scaffold-xcode-project` | Workspace + XcodeGen + empty TimesBar app launches |
| 2 | `feature/timesheet-model` | `TimesheetEntity` + `JSONDecoder.kimai` |
| 3 | `feature/token-store` | Keychain-backed `TokenStore` |
| 4 | `feature/kimai-client` | `KimaiClient` (ping/active/stop/timesheets) with mocked tests |
| 5 | `feature/timer-store-logic` | Elapsed formatting + week aggregation (pure logic) |
| 6 | `feature/timer-store-polling` | Live polling + stop action |
| 7 | `feature/menu-bar-extra-shell` | `TimesBarApp` + `MenuBarExtra` wiring |
| 8 | `feature/sparkline` | 7-bar mini chart view |
| 9 | `feature/menu-bar-label` | Compact label (dot + elapsed + sparkline) |
| 10 | `feature/active-timer-section` | Dropdown: active timer + Stop button |
| 11 | `feature/totals-and-footer` | Dropdown: today/week totals + footer |
| 12 | `feature/token-setup-sheet` | First-run token entry sheet with `ping()` verification |
| 13 | `feature/quick-start` | Dropdown: recent activities + start endpoint |
| 14 | `feature/run-and-install` | Archive, install to `/Applications`, optional Login Items |

Each ticket lives on its own branch off `main`, ends with a green build (`xcodebuild build` + `xcodebuild test`), and gets a conventional commit.

---

## File Structure

```
TimesBar/
├─ project.yml                            # XcodeGen spec
├─ TimesBar.xcodeproj/                    # generated, gitignored
├─ TimesBar/
│  ├─ TimesBarApp.swift                   # @main + MenuBarExtra
│  ├─ Info.plist                          # LSUIElement = YES
│  ├─ TimesBar.entitlements               # sandbox + outgoing network
│  ├─ Models/
│  │  ├─ TimesheetEntity.swift            # Decodable model
│  │  └─ KimaiDecoder.swift               # JSONDecoder.kimai
│  ├─ Networking/
│  │  └─ KimaiClient.swift                # async URLSession wrapper
│  ├─ Storage/
│  │  └─ TokenStore.swift                 # Keychain
│  ├─ State/
│  │  └─ TimerStore.swift                 # ObservableObject
│  └─ Views/
│     ├─ MenuBarLabel.swift               # compact menu bar item
│     ├─ MenuBarView.swift                # dropdown root
│     ├─ Sparkline.swift                  # 7-bar mini chart
│     ├─ ActiveTimerSection.swift
│     ├─ QuickStartSection.swift
│     ├─ TotalsSection.swift
│     ├─ FooterRow.swift
│     └─ TokenSetupSheet.swift
├─ TimesBarTests/
│  ├─ TimesheetEntityTests.swift
│  ├─ KimaiClientTests.swift
│  ├─ TokenStoreTests.swift
│  └─ TimerStoreTests.swift
└─ docs/superpowers/plans/                # this file
```

---

### Task 1: Workspace + XcodeGen + empty TimesBar app launches

**Files:**
- Create: `/Users/nangert/PycharmProjects/TimesBar/.gitignore`
- Create: `/Users/nangert/PycharmProjects/TimesBar/project.yml`
- Create: `/Users/nangert/PycharmProjects/TimesBar/TimesBar/TimesBarApp.swift`
- Create: `/Users/nangert/PycharmProjects/TimesBar/TimesBar/Info.plist`
- Create: `/Users/nangert/PycharmProjects/TimesBar/TimesBar/TimesBar.entitlements`
- Create: `/Users/nangert/PycharmProjects/TimesBar/TimesBarTests/SmokeTests.swift`

- [ ] **Step 1: Install XcodeGen**

```bash
brew install xcodegen
xcodegen --version
```
Expected: prints version (e.g. `2.x.x`).

- [ ] **Step 2: Initialize git repo**

```bash
cd /Users/nangert/PycharmProjects/TimesBar
git init -b main
```

- [ ] **Step 3: Write `.gitignore`**

```
.DS_Store
TimesBar.xcodeproj/
build/
DerivedData/
xcuserdata/
*.xcuserstate
```

- [ ] **Step 4: Write `project.yml`**

```yaml
name: TimesBar
options:
  bundleIdPrefix: bar.times
  deploymentTarget:
    macOS: "14.0"
  developmentLanguage: en
settings:
  base:
    SWIFT_VERSION: "6.0"
    MACOSX_DEPLOYMENT_TARGET: "14.0"
    ENABLE_HARDENED_RUNTIME: YES
    CODE_SIGN_STYLE: Automatic
    CODE_SIGN_IDENTITY: "-"
targets:
  TimesBar:
    type: application
    platform: macOS
    sources:
      - TimesBar
    info:
      path: TimesBar/Info.plist
      properties:
        LSUIElement: true
        CFBundleName: TimesBar
        CFBundleShortVersionString: "0.1.0"
        CFBundleVersion: "1"
    entitlements:
      path: TimesBar/TimesBar.entitlements
      properties:
        com.apple.security.app-sandbox: true
        com.apple.security.network.client: true
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: bar.times.TimesBar
        GENERATE_INFOPLIST_FILE: NO
  TimesBarTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - TimesBarTests
    dependencies:
      - target: TimesBar
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: bar.times.TimesBarTests
        GENERATE_INFOPLIST_FILE: YES
schemes:
  TimesBar:
    build:
      targets:
        TimesBar: all
        TimesBarTests: [test]
    test:
      targets:
        - TimesBarTests
    run:
      config: Debug
```

- [ ] **Step 5: Write `TimesBar/Info.plist`** (XcodeGen will merge but we keep an explicit file for clarity)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key><string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundlePackageType</key><string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>LSUIElement</key><true/>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
</dict>
</plist>
```

- [ ] **Step 6: Write `TimesBar/TimesBar.entitlements`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key><true/>
    <key>com.apple.security.network.client</key><true/>
</dict>
</plist>
```

- [ ] **Step 7: Write `TimesBar/TimesBarApp.swift`** — minimal placeholder that launches

```swift
import SwiftUI

@main
struct TimesBarApp: App {
    var body: some Scene {
        MenuBarExtra("TimesBar", systemImage: "timer") {
            VStack(alignment: .leading, spacing: 8) {
                Text("TimesBar")
                    .font(.headline)
                Text("scaffold ok")
                    .foregroundStyle(.secondary)
                Divider()
                Button("Quit TimesBar") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .padding(12)
            .frame(width: 240)
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 8: Write smoke test `TimesBarTests/SmokeTests.swift`**

```swift
import Testing
@testable import TimesBar

@Test func appBundleIsReachable() {
    let bundle = Bundle(for: BundleAnchor.self)
    #expect(bundle.bundleIdentifier != nil)
}

final class BundleAnchor {}
```

- [ ] **Step 9: Generate project and build**

```bash
cd /Users/nangert/PycharmProjects/TimesBar
xcodegen generate
xcodebuild -project TimesBar.xcodeproj -scheme TimesBar -configuration Debug build | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 10: Run tests**

```bash
xcodebuild -project TimesBar.xcodeproj -scheme TimesBar -destination 'platform=macOS' test | tail -10
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 11: Commit**

```bash
git checkout -b feature/scaffold-xcode-project
git add .gitignore project.yml TimesBar TimesBarTests docs
git commit -m "feat: scaffold TimesBar Xcode project via XcodeGen"
```

---

### Task 2: TimesheetEntity model + JSONDecoder.kimai

**Files:**
- Create: `TimesBar/Models/TimesheetEntity.swift`
- Create: `TimesBar/Models/KimaiDecoder.swift`
- Create: `TimesBarTests/TimesheetEntityTests.swift`

- [ ] **Step 1: Write failing test `TimesBarTests/TimesheetEntityTests.swift`**

```swift
import Testing
import Foundation
@testable import TimesBar

@Test func decodesActiveTimesheet() throws {
    let json = """
    {
      "id": 42,
      "project": 7,
      "activity": 3,
      "begin": "2026-05-18T09:30:00+0200",
      "end": null,
      "description": "Kimai API work"
    }
    """.data(using: .utf8)!

    let entity = try JSONDecoder.kimai.decode(TimesheetEntity.self, from: json)

    #expect(entity.id == 42)
    #expect(entity.project == 7)
    #expect(entity.activity == 3)
    #expect(entity.end == nil)
    #expect(entity.description == "Kimai API work")
}

@Test func decodesStoppedTimesheet() throws {
    let json = """
    {"id":1,"project":1,"activity":1,"begin":"2026-05-18T09:00:00+0200","end":"2026-05-18T10:30:00+0200","description":null}
    """.data(using: .utf8)!
    let entity = try JSONDecoder.kimai.decode(TimesheetEntity.self, from: json)
    #expect(entity.end != nil)
    #expect(entity.description == nil)
}
```

- [ ] **Step 2: Add files to project sources** (XcodeGen picks up new files in `TimesBar/` automatically — just re-run)

```bash
xcodegen generate
```

- [ ] **Step 3: Run test to verify failure**

```bash
xcodebuild -project TimesBar.xcodeproj -scheme TimesBar -destination 'platform=macOS' test 2>&1 | grep -E "(error:|FAIL)" | head -5
```
Expected: compile errors — `TimesheetEntity` not defined, `JSONDecoder.kimai` not defined.

- [ ] **Step 4: Write `TimesBar/Models/TimesheetEntity.swift`**

```swift
import Foundation

struct TimesheetEntity: Decodable, Identifiable, Equatable, Sendable {
    let id: Int
    let project: Int
    let activity: Int
    let begin: Date
    let end: Date?
    let description: String?
}
```

- [ ] **Step 5: Write `TimesBar/Models/KimaiDecoder.swift`**

Kimai emits ISO 8601 with a numeric timezone like `+0200` (no colon), which `ISO8601DateFormatter` handles with `.withInternetDateTime`.

```swift
import Foundation

extension JSONDecoder {
    static let kimai: JSONDecoder = {
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        decoder.dateDecodingStrategy = .custom { container in
            let raw = try container.singleValueContainer().decode(String.self)
            if let date = formatter.date(from: raw) { return date }
            // Fallback for timezone without colon (Kimai's default)
            var alt = ISO8601DateFormatter()
            alt.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
            if let date = alt.date(from: raw) { return date }
            throw DecodingError.dataCorruptedError(
                in: try container.singleValueContainer(),
                debugDescription: "Unparseable date: \(raw)")
        }
        return decoder
    }()
}
```

- [ ] **Step 6: Regenerate + run tests**

```bash
xcodegen generate
xcodebuild -project TimesBar.xcodeproj -scheme TimesBar -destination 'platform=macOS' test 2>&1 | tail -5
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git checkout -b feature/timesheet-model
git add TimesBar/Models TimesBarTests/TimesheetEntityTests.swift project.yml
git commit -m "feat: add TimesheetEntity model and Kimai-aware JSON decoder"
```

---

### Task 3: Keychain-backed TokenStore

**Files:**
- Create: `TimesBar/Storage/TokenStore.swift`
- Create: `TimesBarTests/TokenStoreTests.swift`

The Keychain item uses a unique service per test run so test runs do not pollute the user's real keychain.

- [ ] **Step 1: Write failing test `TimesBarTests/TokenStoreTests.swift`**

```swift
import Testing
import Foundation
@testable import TimesBar

@Test func savesAndReadsToken() {
    let service = "bar.times.token.test.\(UUID().uuidString)"
    let store = TokenStore(service: service)
    defer { store.delete() }

    store.save("secret-token-xyz")
    #expect(store.read() == "secret-token-xyz")
}

@Test func overwritesExistingToken() {
    let service = "bar.times.token.test.\(UUID().uuidString)"
    let store = TokenStore(service: service)
    defer { store.delete() }

    store.save("first")
    store.save("second")
    #expect(store.read() == "second")
}

@Test func returnsNilWhenMissing() {
    let service = "bar.times.token.test.\(UUID().uuidString)"
    let store = TokenStore(service: service)
    #expect(store.read() == nil)
}
```

- [ ] **Step 2: Write `TimesBar/Storage/TokenStore.swift`**

```swift
import Foundation
import Security

struct TokenStore {
    static let defaultService = "bar.times.token"
    let service: String

    init(service: String = TokenStore.defaultService) {
        self.service = service
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
    }

    func save(_ token: String) {
        let data = Data(token.utf8)
        var query = baseQuery()
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        SecItemAdd(query as CFDictionary, nil)
    }

    func read() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }

    func delete() {
        SecItemDelete(baseQuery() as CFDictionary)
    }
}
```

- [ ] **Step 3: Run tests**

```bash
xcodegen generate
xcodebuild -project TimesBar.xcodeproj -scheme TimesBar -destination 'platform=macOS' test 2>&1 | tail -10
```
Expected: `** TEST SUCCEEDED **`. Note: Keychain access from sandboxed tests requires the host app's keychain group — if errSecMissingEntitlement appears, add `keychain-access-groups` to the app entitlements file with `$(AppIdentifierPrefix)bar.times.TimesBar`.

- [ ] **Step 4: Commit**

```bash
git checkout -b feature/token-store
git add TimesBar/Storage TimesBarTests/TokenStoreTests.swift
git commit -m "feat: add Keychain-backed TokenStore"
```

---

### Task 4: KimaiClient with mocked URLSession

**Files:**
- Create: `TimesBar/Networking/KimaiClient.swift`
- Create: `TimesBarTests/KimaiClientTests.swift`
- Create: `TimesBarTests/Support/MockURLProtocol.swift`

The client takes an injectable `URLSession` so tests can swap in `URLSession(configuration:)` wired to `MockURLProtocol`. No real network in tests.

- [ ] **Step 1: Write `TimesBarTests/Support/MockURLProtocol.swift`**

```swift
import Foundation

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}

func mockSession(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> URLSession {
    MockURLProtocol.handler = handler
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}
```

- [ ] **Step 2: Write failing test `TimesBarTests/KimaiClientTests.swift`**

```swift
import Testing
import Foundation
@testable import TimesBar

@Test func pingHitsCorrectPathWithBearerToken() async throws {
    var captured: URLRequest?
    let session = mockSession { req in
        captured = req
        let response = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (response, Data("{}".utf8))
    }
    let client = KimaiClient(token: "abc123", session: session)

    try await client.ping()

    #expect(captured?.url?.path == "/api/ping")
    #expect(captured?.value(forHTTPHeaderField: "Authorization") == "Bearer abc123")
}

@Test func activeReturnsDecodedTimesheets() async throws {
    let session = mockSession { req in
        let body = """
        [{"id":1,"project":7,"activity":3,"begin":"2026-05-18T09:30:00+0200","end":null,"description":"x"}]
        """
        let response = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (response, Data(body.utf8))
    }
    let client = KimaiClient(token: "t", session: session)
    let entries = try await client.active()
    #expect(entries.count == 1)
    #expect(entries[0].id == 1)
}

@Test func stopUsesPatchAndCorrectPath() async throws {
    var captured: URLRequest?
    let session = mockSession { req in
        captured = req
        let body = """
        {"id":99,"project":7,"activity":3,"begin":"2026-05-18T09:00:00+0200","end":"2026-05-18T10:00:00+0200","description":null}
        """
        let response = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (response, Data(body.utf8))
    }
    let client = KimaiClient(token: "t", session: session)
    _ = try await client.stop(id: 99)

    #expect(captured?.httpMethod == "PATCH")
    #expect(captured?.url?.path == "/api/timesheets/99/stop")
}

@Test func timesheetsBuildsQueryStringWithDates() async throws {
    var captured: URLRequest?
    let session = mockSession { req in
        captured = req
        let response = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (response, Data("[]".utf8))
    }
    let client = KimaiClient(token: "t", session: session)
    let begin = Date(timeIntervalSince1970: 1_700_000_000)
    let end = Date(timeIntervalSince1970: 1_700_604_800)
    _ = try await client.timesheets(begin: begin, end: end, size: 250)

    let url = try #require(captured?.url)
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
    let names = components.queryItems?.map(\.name) ?? []
    #expect(names.contains("begin"))
    #expect(names.contains("end"))
    #expect(names.contains("size"))
    #expect(components.queryItems?.first(where: { $0.name == "size" })?.value == "250")
}
```

- [ ] **Step 3: Write `TimesBar/Networking/KimaiClient.swift`**

```swift
import Foundation

struct KimaiClient {
    let baseURL: URL
    let token: String
    let session: URLSession

    init(baseURL: URL = URL(string: "https://times.lipsum.services")!,
         token: String,
         session: URLSession = .shared) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
    }

    private func request(_ path: String,
                         method: String = "GET",
                         queryItems: [URLQueryItem]? = nil,
                         body: Data? = nil) -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path),
                                       resolvingAgainstBaseURL: false)!
        if let queryItems { components.queryItems = queryItems }
        var req = URLRequest(url: components.url!)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        return req
    }

    func ping() async throws {
        _ = try await session.data(for: request("/api/ping"))
    }

    func active() async throws -> [TimesheetEntity] {
        let (data, _) = try await session.data(for: request("/api/timesheets/active"))
        return try JSONDecoder.kimai.decode([TimesheetEntity].self, from: data)
    }

    func stop(id: Int) async throws -> TimesheetEntity {
        let (data, _) = try await session.data(
            for: request("/api/timesheets/\(id)/stop", method: "PATCH"))
        return try JSONDecoder.kimai.decode(TimesheetEntity.self, from: data)
    }

    func timesheets(begin: Date, end: Date, size: Int = 500) async throws -> [TimesheetEntity] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let items = [
            URLQueryItem(name: "begin", value: formatter.string(from: begin)),
            URLQueryItem(name: "end", value: formatter.string(from: end)),
            URLQueryItem(name: "size", value: String(size)),
        ]
        let (data, _) = try await session.data(
            for: request("/api/timesheets", queryItems: items))
        return try JSONDecoder.kimai.decode([TimesheetEntity].self, from: data)
    }
}
```

- [ ] **Step 4: Regenerate, run tests**

```bash
xcodegen generate
xcodebuild -project TimesBar.xcodeproj -scheme TimesBar -destination 'platform=macOS' test 2>&1 | tail -5
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git checkout -b feature/kimai-client
git add TimesBar/Networking TimesBarTests/KimaiClientTests.swift TimesBarTests/Support
git commit -m "feat: add KimaiClient with mocked URLSession tests"
```

---

### Task 5: TimerStore — elapsed formatting + week aggregation

**Files:**
- Create: `TimesBar/State/TimerStore.swift` (logic only at this stage)
- Create: `TimesBarTests/TimerStoreTests.swift`

This task implements only the pure logic (elapsed string + week-hours aggregation) so it can be unit-tested. The polling timer comes in Task 6.

- [ ] **Step 1: Write failing tests `TimesBarTests/TimerStoreTests.swift`**

```swift
import Testing
import Foundation
@testable import TimesBar

@Test func elapsedStringFormatsHoursMinutesSeconds() {
    #expect(TimerStore.elapsedString(seconds: 0) == "00:00:00")
    #expect(TimerStore.elapsedString(seconds: 59) == "00:00:59")
    #expect(TimerStore.elapsedString(seconds: 3_600) == "01:00:00")
    #expect(TimerStore.elapsedString(seconds: 3_725) == "01:02:05")
}

@Test func weekHoursAggregatesEntriesByWeekday() {
    // Monday 2026-05-11 (Europe/Vienna) → 2h, Wednesday 2026-05-13 → 1.5h
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = TimeZone(identifier: "Europe/Vienna")!
    let mondayStart = cal.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 9))!
    let mondayEnd   = cal.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 11))!
    let wedStart    = cal.date(from: DateComponents(year: 2026, month: 5, day: 13, hour: 9))!
    let wedEnd      = cal.date(from: DateComponents(year: 2026, month: 5, day: 13, hour: 10, minute: 30))!

    let entries = [
        TimesheetEntity(id: 1, project: 1, activity: 1, begin: mondayStart, end: mondayEnd, description: nil),
        TimesheetEntity(id: 2, project: 1, activity: 1, begin: wedStart, end: wedEnd, description: nil),
    ]
    let weekStart = cal.date(from: DateComponents(year: 2026, month: 5, day: 11))!
    let hours = TimerStore.weekHours(entries: entries, weekStart: weekStart, calendar: cal)

    #expect(hours.count == 7)
    #expect(abs(hours[0] - 2.0) < 0.001)   // Monday
    #expect(abs(hours[2] - 1.5) < 0.001)   // Wednesday
    #expect(hours[1] == 0.0)               // Tuesday
}

@Test func weekHoursTreatsRunningEntryAsEndingNow() {
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = TimeZone(identifier: "Europe/Vienna")!
    let now = Date()
    let oneHourAgo = now.addingTimeInterval(-3_600)
    let entries = [
        TimesheetEntity(id: 1, project: 1, activity: 1, begin: oneHourAgo, end: nil, description: nil),
    ]
    let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
    let hours = TimerStore.weekHours(entries: entries, weekStart: weekStart, calendar: cal, now: now)
    let totalHours = hours.reduce(0, +)
    #expect(abs(totalHours - 1.0) < 0.01)
}
```

- [ ] **Step 2: Write `TimesBar/State/TimerStore.swift` (logic only)**

```swift
import Foundation
import Combine

@MainActor
final class TimerStore: ObservableObject {
    @Published var active: TimesheetEntity?
    @Published var weekHours: [Double] = Array(repeating: 0, count: 7)
    @Published var elapsedString: String = "--:--:--"
    @Published var isAuthenticated: Bool = false

    var isRunning: Bool { active != nil }

    // MARK: - Pure helpers (unit-tested)

    nonisolated static func elapsedString(seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    nonisolated static func weekHours(entries: [TimesheetEntity],
                                      weekStart: Date,
                                      calendar: Calendar,
                                      now: Date = Date()) -> [Double] {
        var buckets = Array(repeating: 0.0, count: 7)
        for entry in entries {
            let stop = entry.end ?? now
            let elapsed = stop.timeIntervalSince(entry.begin)
            guard elapsed > 0 else { continue }
            let day = calendar.dateComponents([.day], from: weekStart, to: entry.begin).day ?? 0
            guard day >= 0, day < 7 else { continue }
            buckets[day] += elapsed / 3600.0
        }
        return buckets
    }
}
```

- [ ] **Step 3: Run tests**

```bash
xcodegen generate
xcodebuild -project TimesBar.xcodeproj -scheme TimesBar -destination 'platform=macOS' test 2>&1 | tail -5
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git checkout -b feature/timer-store-logic
git add TimesBar/State TimesBarTests/TimerStoreTests.swift
git commit -m "feat: add TimerStore with elapsed formatting and weekly aggregation"
```

---

### Task 6: TimerStore — live polling and stop action

**Files:**
- Modify: `TimesBar/State/TimerStore.swift`

- [ ] **Step 1: Extend `TimerStore` with polling, ticking, and a `stop()` method**

Append to `TimesBar/State/TimerStore.swift` inside the class:

```swift
    private var pollTimer: Timer?
    private var tickTimer: Timer?
    private var client: KimaiClient?

    func bootstrap() {
        if let token = TokenStore().read() {
            client = KimaiClient(token: token)
            isAuthenticated = true
            Task { await refresh() }
            startTimers()
        } else {
            isAuthenticated = false
        }
    }

    func authenticate(with token: String) async -> Bool {
        let candidate = KimaiClient(token: token)
        do {
            try await candidate.ping()
        } catch {
            return false
        }
        TokenStore().save(token)
        client = candidate
        isAuthenticated = true
        await refresh()
        startTimers()
        return true
    }

    func signOut() {
        TokenStore().delete()
        client = nil
        active = nil
        weekHours = Array(repeating: 0, count: 7)
        elapsedString = "--:--:--"
        isAuthenticated = false
        pollTimer?.invalidate()
        tickTimer?.invalidate()
    }

    func stop() async {
        guard let client, let id = active?.id else { return }
        _ = try? await client.stop(id: id)
        await refresh()
    }

    func refresh() async {
        guard let client else { return }
        active = (try? await client.active())?.first
        await refreshWeek()
        tickElapsed()
    }

    private func refreshWeek() async {
        guard let client else { return }
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        let now = Date()
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        guard let weekStart = cal.date(from: comps) else { return }
        let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart)!
        if let entries = try? await client.timesheets(begin: weekStart, end: weekEnd) {
            weekHours = Self.weekHours(entries: entries, weekStart: weekStart, calendar: cal, now: now)
        }
    }

    private func startTimers() {
        pollTimer?.invalidate()
        tickTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickElapsed() }
        }
    }

    private func tickElapsed() {
        guard let begin = active?.begin else { elapsedString = "--:--:--"; return }
        elapsedString = Self.elapsedString(seconds: Int(Date().timeIntervalSince(begin)))
    }
```

- [ ] **Step 2: Build**

```bash
xcodebuild -project TimesBar.xcodeproj -scheme TimesBar -configuration Debug build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`. (No new tests — polling is integration-level and exercised live in Task 14.)

- [ ] **Step 3: Run existing tests to make sure logic helpers still pass**

```bash
xcodebuild -project TimesBar.xcodeproj -scheme TimesBar -destination 'platform=macOS' test 2>&1 | tail -5
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git checkout -b feature/timer-store-polling
git add TimesBar/State/TimerStore.swift
git commit -m "feat: wire TimerStore to KimaiClient with polling and stop action"
```

---

### Task 7: TimesBarApp entry + MenuBarExtra wiring

**Files:**
- Modify: `TimesBar/TimesBarApp.swift`
- Create: `TimesBar/Views/MenuBarView.swift` (placeholder)

- [ ] **Step 1: Replace `TimesBar/TimesBarApp.swift`**

```swift
import SwiftUI

@main
struct TimesBarApp: App {
    @StateObject private var store = TimerStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
                .frame(width: 320)
                .onAppear { store.bootstrap() }
        } label: {
            MenuBarLabel()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 2: Write placeholder `TimesBar/Views/MenuBarView.swift`**

```swift
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var store: TimerStore
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TimesBar").font(.headline)
            Text(store.isAuthenticated ? "Connected" : "Not connected")
                .foregroundStyle(.secondary)
            Divider()
            Button("Quit TimesBar") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
        .padding(12)
    }
}
```

- [ ] **Step 3: Write placeholder `TimesBar/Views/MenuBarLabel.swift`**

```swift
import SwiftUI

struct MenuBarLabel: View {
    @EnvironmentObject var store: TimerStore
    var body: some View {
        Image(systemName: store.isRunning ? "timer" : "timer")
    }
}
```

- [ ] **Step 4: Build + run smoke**

```bash
xcodegen generate
xcodebuild -project TimesBar.xcodeproj -scheme TimesBar -configuration Debug build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git checkout -b feature/menu-bar-extra-shell
git add TimesBar/TimesBarApp.swift TimesBar/Views
git commit -m "feat: wire MenuBarExtra to TimerStore with placeholder views"
```

---

### Task 8: Sparkline view

**Files:**
- Create: `TimesBar/Views/Sparkline.swift`

- [ ] **Step 1: Write `TimesBar/Views/Sparkline.swift`**

```swift
import SwiftUI

struct Sparkline: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            let maxValue = max(values.max() ?? 0, 0.0001)
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.85))
                        .frame(height: max(2, geo.size.height * CGFloat(value / maxValue)))
                }
            }
        }
    }
}

#Preview {
    Sparkline(values: [1, 2, 0, 3.5, 4, 1.2, 0])
        .frame(width: 60, height: 16)
        .padding()
}
```

- [ ] **Step 2: Build**

```bash
xcodegen generate
xcodebuild -project TimesBar.xcodeproj -scheme TimesBar -configuration Debug build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git checkout -b feature/sparkline
git add TimesBar/Views/Sparkline.swift
git commit -m "feat: add Sparkline mini chart view"
```

---

### Task 9: MenuBarLabel — compact label

**Files:**
- Modify: `TimesBar/Views/MenuBarLabel.swift`

- [ ] **Step 1: Replace `TimesBar/Views/MenuBarLabel.swift`**

```swift
import SwiftUI

struct MenuBarLabel: View {
    @EnvironmentObject var store: TimerStore

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(store.isRunning ? Color.green : Color.secondary)
                .frame(width: 7, height: 7)
            if store.isRunning {
                Text(store.elapsedString)
                    .font(.system(.body, design: .monospaced))
            }
            Sparkline(values: store.weekHours)
                .frame(width: 48, height: 14)
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -project TimesBar.xcodeproj -scheme TimesBar -configuration Debug build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git checkout -b feature/menu-bar-label
git add TimesBar/Views/MenuBarLabel.swift
git commit -m "feat: render compact menu bar label with dot, elapsed, sparkline"
```

---

### Task 10: ActiveTimerSection (Stop button)

**Files:**
- Create: `TimesBar/Views/ActiveTimerSection.swift`
- Modify: `TimesBar/Views/MenuBarView.swift`

- [ ] **Step 1: Write `TimesBar/Views/ActiveTimerSection.swift`**

```swift
import SwiftUI

struct ActiveTimerSection: View {
    let timesheet: TimesheetEntity
    let elapsed: String
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timesheet.description ?? "Project #\(timesheet.project)")
                        .font(.headline)
                        .lineLimit(1)
                    Text("Activity #\(timesheet.activity)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(elapsed)
                    .font(.system(.title3, design: .monospaced))
            }
            Button(role: .destructive, action: onStop) {
                Label("Stop", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
    }
}
```

- [ ] **Step 2: Update `TimesBar/Views/MenuBarView.swift`**

```swift
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var store: TimerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !store.isAuthenticated {
                Text("Sign in to Kimai in Settings")
                    .foregroundStyle(.secondary)
            } else if let timesheet = store.active {
                ActiveTimerSection(timesheet: timesheet,
                                    elapsed: store.elapsedString) {
                    Task { await store.stop() }
                }
            } else {
                Text("No active timer").foregroundStyle(.secondary)
            }
            Divider()
            FooterRow()
        }
        .padding(12)
    }
}

struct FooterRow: View {
    var body: some View {
        HStack {
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
            Spacer()
        }
    }
}
```

- [ ] **Step 3: Build**

```bash
xcodegen generate
xcodebuild -project TimesBar.xcodeproj -scheme TimesBar -configuration Debug build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git checkout -b feature/active-timer-section
git add TimesBar/Views
git commit -m "feat: show active timer with Stop button in dropdown"
```

---

### Task 11: TotalsSection + final FooterRow

**Files:**
- Create: `TimesBar/Views/TotalsSection.swift`
- Modify: `TimesBar/Views/MenuBarView.swift`

- [ ] **Step 1: Write `TimesBar/Views/TotalsSection.swift`**

```swift
import SwiftUI

struct TotalsSection: View {
    let weekHours: [Double]

    private var todayHours: Double {
        let cal = Calendar(identifier: .iso8601)
        let weekday = cal.component(.weekday, from: Date())
        // ISO calendar: Monday = 2 (Sunday = 1). Map to 0...6 with Monday = 0.
        let index = (weekday + 5) % 7
        return weekHours[safe: index] ?? 0
    }

    private var weekTotal: Double { weekHours.reduce(0, +) }

    var body: some View {
        HStack(spacing: 16) {
            stat(label: "Today", value: todayHours)
            stat(label: "This week", value: weekTotal)
            Spacer()
            Sparkline(values: weekHours)
                .frame(width: 80, height: 24)
        }
    }

    private func stat(label: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(format(value)).font(.system(.body, design: .monospaced))
        }
    }

    private func format(_ hours: Double) -> String {
        let total = Int(hours * 3600)
        return String(format: "%02d:%02d", total / 3600, (total % 3600) / 60)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
```

- [ ] **Step 2: Replace `TimesBar/Views/MenuBarView.swift`**

```swift
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var store: TimerStore
    @State private var showingSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !store.isAuthenticated {
                Text("Sign in to Kimai")
                    .font(.headline)
                Text("Add an API token to start tracking.")
                    .foregroundStyle(.secondary)
                Button("Sign in") { showingSettings = true }
                    .buttonStyle(.borderedProminent)
            } else if let timesheet = store.active {
                ActiveTimerSection(timesheet: timesheet,
                                    elapsed: store.elapsedString) {
                    Task { await store.stop() }
                }
                Divider()
                TotalsSection(weekHours: store.weekHours)
            } else {
                Text("No active timer").foregroundStyle(.secondary)
                Divider()
                TotalsSection(weekHours: store.weekHours)
            }
            Divider()
            FooterRow(showSettings: { showingSettings = true })
        }
        .padding(12)
        .sheet(isPresented: $showingSettings) {
            TokenSetupSheet().environmentObject(store)
        }
    }
}

struct FooterRow: View {
    let showSettings: () -> Void
    var body: some View {
        HStack {
            Button("Settings", action: showSettings)
            Spacer()
            Button("Open Kimai") {
                if let url = URL(string: "https://times.lipsum.services") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        .font(.caption)
    }
}
```

Note: `TokenSetupSheet` is created in Task 12 — this build will fail until that task lands. To keep this task green on its own, stub the sheet content for now and remove the stub in Task 12.

- [ ] **Step 3: Add temporary `TokenSetupSheet` stub at bottom of `MenuBarView.swift`**

```swift
struct TokenSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack { Text("Settings (stub)"); Button("Close") { dismiss() } }.padding()
    }
}
```

- [ ] **Step 4: Build**

```bash
xcodebuild -project TimesBar.xcodeproj -scheme TimesBar -configuration Debug build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git checkout -b feature/totals-and-footer
git add TimesBar/Views
git commit -m "feat: render today/week totals and footer in dropdown"
```

---

### Task 12: Token setup sheet (first-run + later changes)

**Files:**
- Create: `TimesBar/Views/TokenSetupSheet.swift`
- Modify: `TimesBar/Views/MenuBarView.swift` (remove the stub)

- [ ] **Step 1: Remove the stub from `MenuBarView.swift`**

Delete the `struct TokenSetupSheet` stub added in Task 11.

- [ ] **Step 2: Write `TimesBar/Views/TokenSetupSheet.swift`**

```swift
import SwiftUI

struct TokenSetupSheet: View {
    @EnvironmentObject var store: TimerStore
    @Environment(\.dismiss) private var dismiss
    @State private var token: String = ""
    @State private var status: Status = .idle
    @State private var isVerifying = false

    enum Status { case idle, success, failure(String) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kimai API token").font(.headline)
            Text("Paste a token from Settings → API access at times.lipsum.services.")
                .font(.caption).foregroundStyle(.secondary)
            SecureField("Token", text: $token)
                .textFieldStyle(.roundedBorder)
            HStack {
                if case let .failure(message) = status {
                    Text(message).font(.caption).foregroundStyle(.red)
                } else if case .success = status {
                    Text("Connected.").font(.caption).foregroundStyle(.green)
                }
                Spacer()
                if store.isAuthenticated {
                    Button("Sign out", role: .destructive) {
                        store.signOut()
                        dismiss()
                    }
                }
                Button("Cancel") { dismiss() }
                Button("Verify & save") {
                    isVerifying = true
                    Task {
                        let ok = await store.authenticate(with: token)
                        isVerifying = false
                        status = ok ? .success : .failure("Token rejected.")
                        if ok { dismiss() }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(token.trimmingCharacters(in: .whitespaces).isEmpty || isVerifying)
            }
        }
        .padding(16)
        .frame(width: 380)
    }
}
```

- [ ] **Step 3: Build**

```bash
xcodegen generate
xcodebuild -project TimesBar.xcodeproj -scheme TimesBar -configuration Debug build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Manual smoke test** (live network)

```bash
xcodebuild -project TimesBar.xcodeproj -scheme TimesBar -configuration Debug -derivedDataPath build run &
sleep 4
# Click the menu bar icon → Settings → paste the real Kimai token → Verify & save.
# Expect: dropdown switches from "Sign in" view to "No active timer" (or shows your current timer).
```
Then quit the running app.

- [ ] **Step 5: Commit**

```bash
git checkout -b feature/token-setup-sheet
git add TimesBar/Views
git commit -m "feat: add token setup sheet with live ping verification"
```

---

### Task 13: Quick-start section (recent timesheets)

**Files:**
- Modify: `TimesBar/Networking/KimaiClient.swift` (add `recent()` + `start(project:activity:description:)`)
- Create: `TimesBar/Views/QuickStartSection.swift`
- Modify: `TimesBar/State/TimerStore.swift` (expose recent list + `start(...)` action)
- Modify: `TimesBar/Views/MenuBarView.swift` (insert quick-start)
- Modify: `TimesBarTests/KimaiClientTests.swift` (cover new endpoints)

- [ ] **Step 1: Extend tests in `TimesBarTests/KimaiClientTests.swift`**

Append:

```swift
@Test func recentHitsCorrectPath() async throws {
    var captured: URLRequest?
    let session = mockSession { req in
        captured = req
        let response = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (response, Data("[]".utf8))
    }
    let client = KimaiClient(token: "t", session: session)
    _ = try await client.recent()
    #expect(captured?.url?.path == "/api/timesheets/recent")
}

@Test func startSendsPostWithJSONBody() async throws {
    var captured: URLRequest?
    let session = mockSession { req in
        captured = req
        let body = """
        {"id":7,"project":1,"activity":2,"begin":"2026-05-18T11:00:00+0200","end":null,"description":null}
        """
        let response = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (response, Data(body.utf8))
    }
    let client = KimaiClient(token: "t", session: session)
    _ = try await client.start(project: 1, activity: 2, description: "hi")

    #expect(captured?.httpMethod == "POST")
    #expect(captured?.url?.path == "/api/timesheets")
    let bodyData = try #require(captured?.httpBody)
    let decoded = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
    #expect(decoded?["project"] as? Int == 1)
    #expect(decoded?["activity"] as? Int == 2)
}
```

- [ ] **Step 2: Add methods to `TimesBar/Networking/KimaiClient.swift`**

Inside `KimaiClient`:

```swift
    func recent() async throws -> [TimesheetEntity] {
        let (data, _) = try await session.data(for: request("/api/timesheets/recent"))
        return try JSONDecoder.kimai.decode([TimesheetEntity].self, from: data)
    }

    func start(project: Int, activity: Int, description: String?) async throws -> TimesheetEntity {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        var payload: [String: Any] = [
            "project": project,
            "activity": activity,
            "begin": formatter.string(from: Date()),
        ]
        if let description, !description.isEmpty { payload["description"] = description }
        let body = try JSONSerialization.data(withJSONObject: payload)
        let (data, _) = try await session.data(
            for: request("/api/timesheets", method: "POST", body: body))
        return try JSONDecoder.kimai.decode(TimesheetEntity.self, from: data)
    }
```

- [ ] **Step 3: Extend `TimesBar/State/TimerStore.swift`**

Add to the class:

```swift
    @Published var recent: [TimesheetEntity] = []

    func refreshRecent() async {
        guard let client else { return }
        if let entries = try? await client.recent() {
            recent = Array(entries.prefix(5))
        }
    }

    func start(project: Int, activity: Int, description: String?) async {
        guard let client else { return }
        _ = try? await client.start(project: project, activity: activity, description: description)
        await refresh()
    }
```

Call `await refreshRecent()` from inside `refresh()` after `refreshWeek()`.

- [ ] **Step 4: Write `TimesBar/Views/QuickStartSection.swift`**

```swift
import SwiftUI

struct QuickStartSection: View {
    let recent: [TimesheetEntity]
    let onStart: (TimesheetEntity) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Quick start").font(.caption).foregroundStyle(.secondary)
            if recent.isEmpty {
                Text("No recent entries").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(recent) { entry in
                    Button {
                        onStart(entry)
                    } label: {
                        HStack {
                            Image(systemName: "play.fill").font(.caption)
                            Text(entry.description ?? "Project #\(entry.project) / Activity #\(entry.activity)")
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
```

- [ ] **Step 5: Wire into `MenuBarView.swift`**

After the active-timer / no-timer branch and before `Divider()` + `TotalsSection`, insert (only when no active timer):

```swift
            if store.isAuthenticated && store.active == nil {
                Divider()
                QuickStartSection(recent: store.recent) { entry in
                    Task {
                        await store.start(project: entry.project,
                                          activity: entry.activity,
                                          description: entry.description)
                    }
                }
            }
```

- [ ] **Step 6: Build + run tests**

```bash
xcodegen generate
xcodebuild -project TimesBar.xcodeproj -scheme TimesBar -destination 'platform=macOS' test 2>&1 | tail -5
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git checkout -b feature/quick-start
git add TimesBar TimesBarTests
git commit -m "feat: quick-start picks a recent entry and starts a new timer"
```

---

### Task 14: Archive, install, optionally add to Login Items

**Files:** (none — packaging only)

- [ ] **Step 1: Archive Release build**

```bash
cd /Users/nangert/PycharmProjects/TimesBar
xcodebuild -project TimesBar.xcodeproj \
  -scheme TimesBar \
  -configuration Release \
  -derivedDataPath build/derived \
  -archivePath build/TimesBar.xcarchive \
  archive | tail -5
```
Expected: `** ARCHIVE SUCCEEDED **`

- [ ] **Step 2: Export the .app** (ad-hoc, unsigned-from-CI perspective)

```bash
mkdir -p build/export
cp -R build/TimesBar.xcarchive/Products/Applications/TimesBar.app build/export/
codesign --force --deep --sign - build/export/TimesBar.app
```

- [ ] **Step 3: Install**

```bash
rm -rf /Applications/TimesBar.app
cp -R build/export/TimesBar.app /Applications/
open /Applications/TimesBar.app
```
If Gatekeeper blocks the first launch: right-click the app in `/Applications` → `Open` → confirm. (Or `xattr -dr com.apple.quarantine /Applications/TimesBar.app`.)

- [ ] **Step 4: Verify live**

- Menu bar icon shows up.
- Click → "Sign in" sheet opens on first run.
- Paste the real Kimai token from `https://times.lipsum.services` → Settings → API access → Verify & save.
- If you have a running timer, the menu bar label shows the elapsed time and a sparkline. Stop button stops it via Kimai.
- If no active timer, the dropdown shows Quick start (recent activities) and today/week totals.

- [ ] **Step 5: (Optional) add to Login Items**

`System Settings` → `General` → `Login Items` → drag `/Applications/TimesBar.app` into the "Open at Login" list.

- [ ] **Step 6: Commit any tooling/release notes**

```bash
git checkout -b feature/run-and-install
git add docs
git commit -m "docs: record archive/install steps for TimesBar v0.1"
```

---

## Done definition

- All 14 tickets merged.
- `xcodebuild test` green.
- `TimesBar.app` lives in `/Applications`, launches at login if configured, and successfully shows the active timer / stops it / starts a recent activity against `https://times.lipsum.services`.
