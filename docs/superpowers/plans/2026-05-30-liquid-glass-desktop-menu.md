# Liquid Glass Desktop Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a desktop-style Liquid Glass settings menu window that exposes all existing CodexBar settings while preserving the current status bar menu.

**Architecture:** Keep `StatusItemController` and the `NSMenu` status bar flow intact. Add a separate SwiftUI `WindowGroup` for a desktop settings menu, backed by the same `SettingsStore`, `UsageStore`, coordinators, updater, and provider login callback already used by `PreferencesView`. Reuse the existing settings panes so all settings remain single-source, then wrap them in a desktop-native `NavigationSplitView` with system materials and macOS 26 Liquid Glass enhancements behind availability checks.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, Observation, Swift Testing/XCTest, SwiftPM.

---

## File Structure

- Create `Sources/CodexBar/DesktopMenuView.swift`
  - Owns the new desktop menu UI.
  - Uses `NavigationSplitView` with a native sidebar listing all `PreferencesTab` cases.
  - Reuses `GeneralPane`, `ProvidersPane`, `DisplayPane`, `AdvancedPane`, `AboutPane`, and `DebugPane`.
  - Applies Liquid Glass surfaces only through a small `ViewModifier` guarded by `#available(macOS 26, *)`.

- Modify `Sources/CodexBar/CodexbarApp.swift`
  - Adds a `WindowGroup("CodexBar", id: "desktop-menu")` scene.
  - Adds `Open Desktop Menu` and settings commands.
  - Keeps the existing hidden lifecycle window and `Settings` scene.
  - Registers an observer for `.codexbarOpenDesktopMenu` in `AppDelegate` so status bar menu actions can open the desktop window.

- Modify `Sources/CodexBar/AppNotifications.swift`
  - Adds `Notification.Name.codexbarOpenDesktopMenu`.

- Modify `Sources/CodexBar/MenuDescriptor.swift`
  - Adds a new `.desktopMenu` action and a matching system image.
  - Adds `Open Desktop Menu` to the meta section above `Settings...`.

- Modify `Sources/CodexBar/MenuContent.swift`
  - Maps `.desktopMenu` to a new `MenuActions.openDesktopMenu` closure.

- Modify `Sources/CodexBar/StatusItemController+MenuActionMapping.swift`
  - Maps `.desktopMenu` to `StatusItemController.showDesktopMenu`.

- Modify `Sources/CodexBar/StatusItemController+Actions.swift`
  - Adds `@objc func showDesktopMenu()` that activates the app and posts `.codexbarOpenDesktopMenu`.

- Modify `Sources/CodexBar/StatusItemController+Menu.swift`
  - Passes `openDesktopMenu` when constructing hosted SwiftUI menu content.

- Test `Tests/CodexBarTests/DesktopMenuViewTests.swift`
  - Verifies all non-debug tabs render in the desktop menu by default.
  - Verifies the debug tab appears only when `debugMenuEnabled` is true.

- Modify `Tests/CodexBarTests/StatusMenuTests.swift` or the closest existing `MenuDescriptor` test file
  - Verifies the status bar descriptor still includes the status-bar actions and now includes `Open Desktop Menu`.

## Current Code Facts

- The bundled app is a menu bar agent because `Scripts/package_app.sh` writes `<key>LSUIElement</key><true/>`.
- `CodexBarApp.body` currently has:
  - a hidden `WindowGroup("CodexBarLifecycleKeepalive")`,
  - a native SwiftUI `Settings` scene rendering `PreferencesView`.
- `PreferencesView` already exposes all setting areas through `PreferencesTab`: `general`, `providers`, `display`, `advanced`, `about`, `debug`.
- `StatusItemController` owns the status bar menu lifecycle and already opens settings by setting `PreferencesSelection.tab` and posting `.codexbarOpenSettings`.
- `MenuDescriptor.metaSection(updateReady:)` is the right shared place to add persistent status-menu actions.

## Tasks

### Task 1: Add Desktop Menu Notification

**Files:**
- Modify: `Sources/CodexBar/AppNotifications.swift`
- Test: no dedicated test; exercised through Tasks 3 and 5.

- [ ] **Step 1: Inspect the existing notification names**

Run:

```bash
sed -n '1,160p' Sources/CodexBar/AppNotifications.swift
```

Expected: file contains existing `Notification.Name` extensions used by CodexBar.

- [ ] **Step 2: Add the notification name**

Add this line to the existing `Notification.Name` extension:

```swift
static let codexbarOpenDesktopMenu = Notification.Name("codexbarOpenDesktopMenu")
```

If the file does not already have a `Notification.Name` extension, add this complete block at the end:

```swift
extension Notification.Name {
    static let codexbarOpenDesktopMenu = Notification.Name("codexbarOpenDesktopMenu")
}
```

- [ ] **Step 3: Build to catch naming issues**

Run:

```bash
swift build
```

Expected: build passes.

- [ ] **Step 4: Commit**

```bash
git add Sources/CodexBar/AppNotifications.swift
git commit -m "Add desktop menu notification"
```

### Task 2: Create DesktopMenuView

**Files:**
- Create: `Sources/CodexBar/DesktopMenuView.swift`
- Test: `Tests/CodexBarTests/DesktopMenuViewTests.swift`

- [ ] **Step 1: Write the failing smoke tests**

Create `Tests/CodexBarTests/DesktopMenuViewTests.swift`:

```swift
import CodexBarCore
import Testing
@testable import CodexBar

@MainActor
@Suite(.serialized)
struct DesktopMenuViewTests {
    @Test
    func `desktop menu builds default visible tabs`() {
        let settings = Self.makeSettingsStore(suite: "DesktopMenuViewTests-default")
        let store = Self.makeUsageStore(settings: settings)
        let selection = PreferencesSelection()

        let view = DesktopMenuView(
            settings: settings,
            store: store,
            updater: DisabledUpdaterController(),
            selection: selection)

        _ = view.body
        #expect(selection.tab == .general)
    }

    @Test
    func `desktop menu accepts debug tab when enabled`() {
        let settings = Self.makeSettingsStore(suite: "DesktopMenuViewTests-debug")
        settings.debugMenuEnabled = true
        let store = Self.makeUsageStore(settings: settings)
        let selection = PreferencesSelection()
        selection.tab = .debug

        let view = DesktopMenuView(
            settings: settings,
            store: store,
            updater: DisabledUpdaterController(),
            selection: selection)

        _ = view.body
        #expect(selection.tab == .debug)
    }

    private static func makeSettingsStore(suite: String) -> SettingsStore {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let configStore = testConfigStore(suiteName: suite)

        return SettingsStore(
            userDefaults: defaults,
            configStore: configStore,
            zaiTokenStore: NoopZaiTokenStore(),
            syntheticTokenStore: NoopSyntheticTokenStore(),
            codexCookieStore: InMemoryCookieHeaderStore(),
            claudeCookieStore: InMemoryCookieHeaderStore(),
            cursorCookieStore: InMemoryCookieHeaderStore(),
            opencodeCookieStore: InMemoryCookieHeaderStore(),
            factoryCookieStore: InMemoryCookieHeaderStore(),
            minimaxCookieStore: InMemoryMiniMaxCookieStore(),
            minimaxAPITokenStore: InMemoryMiniMaxAPITokenStore(),
            kimiTokenStore: InMemoryKimiTokenStore(),
            kimiK2TokenStore: InMemoryKimiK2TokenStore(),
            augmentCookieStore: InMemoryCookieHeaderStore(),
            ampCookieStore: InMemoryCookieHeaderStore(),
            copilotTokenStore: InMemoryCopilotTokenStore(),
            tokenAccountStore: InMemoryTokenAccountStore())
    }

    private static func makeUsageStore(settings: SettingsStore) -> UsageStore {
        UsageStore(
            fetcher: UsageFetcher(environment: [:]),
            browserDetection: BrowserDetection(cacheTTL: 0),
            settings: settings)
    }
}
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```bash
swift test --filter DesktopMenuViewTests
```

Expected: fails because `DesktopMenuView` is not defined.

- [ ] **Step 3: Add the desktop menu view**

Create `Sources/CodexBar/DesktopMenuView.swift`:

```swift
import CodexBarCore
import SwiftUI

@MainActor
struct DesktopMenuView: View {
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore
    let updater: UpdaterProviding
    @Bindable var selection: PreferencesSelection
    let managedCodexAccountCoordinator: ManagedCodexAccountCoordinator
    let codexAccountPromotionCoordinator: CodexAccountPromotionCoordinator
    let runProviderLoginFlow: @MainActor (UsageProvider) async -> Void

    init(
        settings: SettingsStore,
        store: UsageStore,
        updater: UpdaterProviding,
        selection: PreferencesSelection,
        managedCodexAccountCoordinator: ManagedCodexAccountCoordinator = ManagedCodexAccountCoordinator(),
        codexAccountPromotionCoordinator: CodexAccountPromotionCoordinator? = nil,
        runProviderLoginFlow: @escaping @MainActor (UsageProvider) async -> Void = { _ in })
    {
        self.settings = settings
        self.store = store
        self.updater = updater
        self.selection = selection
        self.managedCodexAccountCoordinator = managedCodexAccountCoordinator
        self.codexAccountPromotionCoordinator = codexAccountPromotionCoordinator
            ?? CodexAccountPromotionCoordinator(
                settingsStore: settings,
                usageStore: store,
                managedAccountCoordinator: managedCodexAccountCoordinator)
        self.runProviderLoginFlow = runProviderLoginFlow
    }

    var body: some View {
        NavigationSplitView {
            List(selection: self.$selection.tab) {
                ForEach(self.visibleTabs, id: \.self) { tab in
                    Label(tab.title, systemImage: tab.desktopMenuSystemImage)
                        .tag(tab)
                }
            }
            .navigationTitle("CodexBar")
            .listStyle(.sidebar)
        } detail: {
            self.detail(for: self.selection.tab)
                .id(self.settings.appLanguage)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(24)
                .desktopMenuGlassSurface()
        }
        .frame(minWidth: 860, idealWidth: 980, minHeight: 620, idealHeight: 700)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(self.selection.tab.title)
                    .font(.headline)
            }
        }
        .onAppear {
            self.ensureValidSelection()
        }
        .onChange(of: self.settings.debugMenuEnabled) { _, _ in
            self.ensureValidSelection()
        }
    }

    private var visibleTabs: [PreferencesTab] {
        PreferencesTab.allCases.filter { tab in
            tab != .debug || self.settings.debugMenuEnabled
        }
    }

    @ViewBuilder
    private func detail(for tab: PreferencesTab) -> some View {
        switch tab {
        case .general:
            GeneralPane(settings: self.settings, store: self.store)
        case .providers:
            ProvidersPane(
                settings: self.settings,
                store: self.store,
                managedCodexAccountCoordinator: self.managedCodexAccountCoordinator,
                codexAccountPromotionCoordinator: self.codexAccountPromotionCoordinator,
                runProviderLoginFlow: self.runProviderLoginFlow)
        case .display:
            DisplayPane(settings: self.settings, store: self.store)
        case .advanced:
            AdvancedPane(settings: self.settings)
        case .about:
            AboutPane(updater: self.updater)
        case .debug:
            DebugPane(settings: self.settings, store: self.store)
        }
    }

    private func ensureValidSelection() {
        if !self.visibleTabs.contains(self.selection.tab) {
            self.selection.tab = .general
        }
    }
}

private extension PreferencesTab {
    var desktopMenuSystemImage: String {
        switch self {
        case .general: "gearshape"
        case .providers: "square.grid.2x2"
        case .display: "eye"
        case .advanced: "slider.horizontal.3"
        case .about: "info.circle"
        case .debug: "ladybug"
        }
    }
}

private extension View {
    @ViewBuilder
    func desktopMenuGlassSurface() -> some View {
        if #available(macOS 26, *) {
            self.modifier(DesktopMenuGlassSurfaceModifier())
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

@available(macOS 26, *)
private struct DesktopMenuGlassSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        GlassEffectContainer {
            content
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
```

- [ ] **Step 4: Run focused tests and fix compile issues**

Run:

```bash
swift test --filter DesktopMenuViewTests
```

Expected: passes. If `glassEffect(.regular.interactive(), in:)` differs in the installed SDK, use the compiler's suggested `glassEffect` signature while keeping the same `#available(macOS 26, *)` guard and `GlassEffectContainer` grouping.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodexBar/DesktopMenuView.swift Tests/CodexBarTests/DesktopMenuViewTests.swift
git commit -m "Add desktop settings menu view"
```

### Task 3: Wire Desktop Window Scene And Commands

**Files:**
- Modify: `Sources/CodexBar/CodexbarApp.swift`
- Test: `Tests/CodexBarTests/DesktopMenuViewTests.swift`

- [ ] **Step 1: Add an open-window environment value**

In `CodexBarApp`, add this property next to the existing `@State` properties:

```swift
@Environment(\.openWindow) private var openWindow
```

- [ ] **Step 2: Add the desktop window scene**

Insert this scene before the existing hidden lifecycle `WindowGroup`:

```swift
WindowGroup("CodexBar", id: "desktop-menu") {
    DesktopMenuView(
        settings: self.settings,
        store: self.store,
        updater: self.appDelegate.updaterController,
        selection: self.preferencesSelection,
        managedCodexAccountCoordinator: self.managedCodexAccountCoordinator,
        codexAccountPromotionCoordinator: self.codexAccountPromotionCoordinator,
        runProviderLoginFlow: { provider in
            await self.appDelegate.runProviderLoginFlow(provider)
        })
}
.defaultSize(width: 980, height: 700)
.windowResizability(.contentMinSize)
```

- [ ] **Step 3: Add app commands**

Add this modifier to the `WindowGroup("CodexBar", id: "desktop-menu")` scene:

```swift
.commands {
    CommandGroup(after: .appSettings) {
        Button("Open Desktop Menu") {
            self.openDesktopMenu()
        }
        .keyboardShortcut(",", modifiers: [.command, .shift])
    }
}
```

Then add this method to `CodexBarApp`:

```swift
private func openDesktopMenu() {
    NSApp.activate(ignoringOtherApps: true)
    self.openWindow(id: "desktop-menu")
}
```

- [ ] **Step 4: Register the notification observer in AppDelegate**

In `applicationDidFinishLaunching(_:)`, after `self.ensureStatusController()`, add:

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(self.handleOpenDesktopMenuNotification(_:)),
    name: .codexbarOpenDesktopMenu,
    object: nil)
```

Add this method inside `AppDelegate`:

```swift
@objc private func handleOpenDesktopMenuNotification(_ notification: Notification) {
    _ = notification
    NSApp.activate(ignoringOtherApps: true)
}
```

This observer is intentionally minimal. The actual window opening is handled in Task 5 by the SwiftUI status menu path and by the app command. If an AppKit-only status menu path cannot reach `openWindow`, replace the notification with `NSApp.sendAction(#selector(AppDelegate.showDesktopMenu(_:)), to: nil, from: nil)` in Task 5 and implement the window opening with an injected closure in `AppDelegate.Dependencies`.

- [ ] **Step 5: Run desktop menu tests**

Run:

```bash
swift test --filter DesktopMenuViewTests
```

Expected: passes.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodexBar/CodexbarApp.swift
git commit -m "Wire desktop menu window"
```

### Task 4: Add Status Menu Descriptor Action

**Files:**
- Modify: `Sources/CodexBar/MenuDescriptor.swift`
- Test: `Tests/CodexBarTests/StatusMenuTests.swift` or existing menu descriptor test file.

- [ ] **Step 1: Write the failing descriptor test**

Add this test to the existing menu descriptor/status menu test suite that already creates a `SettingsStore` and `UsageStore`. If there is no helper in that file, place it in `Tests/CodexBarTests/StatusMenuTests.swift` and reuse the helpers from nearby tests:

```swift
@Test
func `meta section includes desktop menu without removing settings`() {
    let settings = Self.makeSettingsStore(suite: "StatusMenuTests-desktop-menu")
    let store = Self.makeUsageStore(settings: settings)
    let descriptor = MenuDescriptor.build(
        provider: .codex,
        store: store,
        settings: settings,
        account: AccountInfo(email: nil, plan: nil),
        updateReady: false)

    let actionTitles = descriptor.sections
        .flatMap(\.entries)
        .compactMap { entry -> (String, MenuDescriptor.MenuAction)? in
            if case let .action(title, action) = entry {
                return (title, action)
            }
            return nil
        }

    #expect(actionTitles.contains { $0.0 == "Open Desktop Menu" && $0.1 == .desktopMenu })
    #expect(actionTitles.contains { $0.1 == .settings })
    #expect(actionTitles.contains { $0.1 == .quit })
}
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```bash
swift test --filter "meta section includes desktop menu"
```

Expected: fails because `.desktopMenu` does not exist.

- [ ] **Step 3: Add the descriptor action**

In `MenuDescriptor.MenuActionSystemImage`, add:

```swift
case desktopMenu = "rectangle.3.group"
```

In `MenuDescriptor.MenuAction`, add:

```swift
case desktopMenu
```

In `metaSection(updateReady:)`, change the static entries to:

```swift
entries.append(contentsOf: [
    .action(L("Refresh"), .refresh),
    .action(L("Open Desktop Menu"), .desktopMenu),
    .action(L("Settings..."), .settings),
    .action(L("About CodexBar"), .about),
    .action(L("Quit"), .quit),
])
```

In `MenuDescriptor.MenuAction.systemImageName`, add:

```swift
case .desktopMenu: MenuDescriptor.MenuActionSystemImage.desktopMenu.rawValue
```

- [ ] **Step 4: Run the focused test**

Run:

```bash
swift test --filter "meta section includes desktop menu"
```

Expected: passes.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodexBar/MenuDescriptor.swift Tests/CodexBarTests/StatusMenuTests.swift
git commit -m "Add desktop menu status action"
```

### Task 5: Wire Status Menu Actions Without Removing Existing Menu

**Files:**
- Modify: `Sources/CodexBar/MenuContent.swift`
- Modify: `Sources/CodexBar/StatusItemController+MenuActionMapping.swift`
- Modify: `Sources/CodexBar/StatusItemController+Actions.swift`
- Modify: `Sources/CodexBar/StatusItemController+Menu.swift`
- Test: existing status menu tests.

- [ ] **Step 1: Extend `MenuActions`**

In `Sources/CodexBar/MenuContent.swift`, add this property to `MenuActions`:

```swift
let openDesktopMenu: () -> Void
```

In `MenuContent.perform(_:)`, add:

```swift
case .desktopMenu:
    self.actions.openDesktopMenu()
```

- [ ] **Step 2: Wire AppKit selector mapping**

In `Sources/CodexBar/StatusItemController+MenuActionMapping.swift`, add:

```swift
case .desktopMenu: (#selector(self.showDesktopMenu), nil)
```

- [ ] **Step 3: Add the controller action**

In `Sources/CodexBar/StatusItemController+Actions.swift`, add:

```swift
@objc func showDesktopMenu() {
    DispatchQueue.main.async {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .codexbarOpenDesktopMenu, object: nil)
    }
}
```

- [ ] **Step 4: Pass the SwiftUI menu closure**

Find every `MenuActions(` construction in `Sources/CodexBar/StatusItemController+Menu.swift` and add:

```swift
openDesktopMenu: { [weak self] in
    self?.showDesktopMenu()
},
```

Keep the existing `openSettings`, `openAbout`, `refresh`, and `quit` closures unchanged.

- [ ] **Step 5: Run status menu tests**

Run:

```bash
swift test --filter StatusMenu
```

Expected: passes.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodexBar/MenuContent.swift Sources/CodexBar/StatusItemController+MenuActionMapping.swift Sources/CodexBar/StatusItemController+Actions.swift Sources/CodexBar/StatusItemController+Menu.swift
git commit -m "Wire desktop menu status action"
```

### Task 6: Make Notification Open The SwiftUI Window Reliably

**Files:**
- Modify: `Sources/CodexBar/CodexbarApp.swift`
- Test: build and runtime validation.

- [ ] **Step 1: Add an app-level notification bridge**

In the desktop `WindowGroup` scene, add this modifier after `.windowResizability(.contentMinSize)`:

```swift
.onChange(of: self.settings.appLanguage) { _, _ in
    _ = self.settings.appLanguage
}
```

Then add this modifier to the hidden lifecycle `WindowGroup`, because it always exists while the app is running:

```swift
.onReceive(NotificationCenter.default.publisher(for: .codexbarOpenDesktopMenu)) { _ in
    self.openDesktopMenu()
}
```

The hidden lifecycle window is already present to keep SwiftUI lifecycle alive, so this uses an existing always-mounted scene instead of creating a new bridge object.

- [ ] **Step 2: Remove the minimal AppDelegate observer if duplicate windows open**

If clicking `Open Desktop Menu` opens exactly one desktop menu window, keep the observer from Task 3 because it only activates the app. If it opens multiple windows or causes duplicate activation logging, delete this block from `applicationDidFinishLaunching(_:)`:

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(self.handleOpenDesktopMenuNotification(_:)),
    name: .codexbarOpenDesktopMenu,
    object: nil)
```

And delete:

```swift
@objc private func handleOpenDesktopMenuNotification(_ notification: Notification) {
    _ = notification
    NSApp.activate(ignoringOtherApps: true)
}
```

- [ ] **Step 3: Build**

Run:

```bash
swift build
```

Expected: build passes.

- [ ] **Step 4: Commit**

```bash
git add Sources/CodexBar/CodexbarApp.swift
git commit -m "Open desktop menu from status item"
```

### Task 7: Full Verification

**Files:**
- No source edits unless verification exposes a bug.

- [ ] **Step 1: Run focused tests**

Run:

```bash
swift test --filter DesktopMenuViewTests
```

Expected: passes.

- [ ] **Step 2: Run menu tests**

Run:

```bash
swift test --filter StatusMenu
```

Expected: passes.

- [ ] **Step 3: Run the full test suite**

Run:

```bash
swift test
```

Expected: passes without keychain prompts.

- [ ] **Step 4: Run repository checks**

Run:

```bash
make check
```

Expected: passes SwiftFormat, SwiftLint, build, and tests.

- [ ] **Step 5: Package and launch the app for UI validation**

Run:

```bash
./Scripts/package_app.sh debug
pkill -x CodexBar || pkill -f CodexBar.app || true
open -n /Users/leonlei/Documents/codex\ 123/CodexBar/CodexBar.app
```

Expected: CodexBar launches as a menu bar app, keeping the existing status item visible.

- [ ] **Step 6: Manual UI validation**

Validate these outcomes:

- Status bar menu still opens from the menu bar icon.
- Status bar menu still contains `Refresh`, `Settings...`, `About CodexBar`, and `Quit`.
- Status bar menu also contains `Open Desktop Menu`.
- Clicking `Open Desktop Menu` opens the new desktop window.
- The desktop window shows a sidebar with General, Providers, Display, Advanced, and About.
- Debug appears only after enabling the existing debug menu setting.
- Each desktop sidebar item renders the same settings controls as the existing native Settings window.
- On macOS 26+, the detail surface uses Liquid Glass styling; on earlier macOS versions it falls back to regular material and remains readable.

- [ ] **Step 7: Final commit**

```bash
git status --short
git add Sources/CodexBar Tests/CodexBarTests
git commit -m "Add Liquid Glass desktop menu"
```

## Self-Review

- Spec coverage: The plan adds a desktop settings menu, uses Liquid Glass where available, exposes all existing setting panes, and keeps the existing status bar menu path.
- Placeholder scan: The plan contains concrete files, code snippets, commands, and expected results. No deferred implementation notes are required.
- Type consistency: `DesktopMenuView`, `PreferencesSelection`, `PreferencesTab`, `MenuDescriptor.MenuAction.desktopMenu`, `MenuActions.openDesktopMenu`, and `.codexbarOpenDesktopMenu` are named consistently across tasks.
