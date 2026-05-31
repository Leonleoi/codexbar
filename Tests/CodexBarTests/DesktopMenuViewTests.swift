import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

@MainActor
@Suite(.serialized)
struct DesktopMenuViewTests {
    @Test
    func `builds desktop menu view with default settings`() {
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
    func `hides debug tab by default`() {
        #expect(DesktopMenuView.visibleTabs(debugMenuEnabled: false) == [
            .general,
            .providers,
            .display,
            .advanced,
            .about,
        ])
        #expect(DesktopMenuView.normalizedTab(.debug, debugMenuEnabled: false) == .general)
    }

    @Test
    func `shows debug tab when debug menu is enabled`() {
        #expect(DesktopMenuView.visibleTabs(debugMenuEnabled: true) == [
            .general,
            .providers,
            .display,
            .advanced,
            .about,
            .debug,
        ])
        #expect(DesktopMenuView.normalizedTab(.debug, debugMenuEnabled: true) == .debug)
    }

    @Test
    func `filters tabs by title and subtitle`() {
        #expect(DesktopMenuView.filteredTabs(searchText: "provider", debugMenuEnabled: false) == [
            .providers,
        ])
        #expect(DesktopMenuView.filteredTabs(searchText: "logging", debugMenuEnabled: false).isEmpty)
        #expect(DesktopMenuView.filteredTabs(searchText: "logging", debugMenuEnabled: true) == [
            .debug,
        ])
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
