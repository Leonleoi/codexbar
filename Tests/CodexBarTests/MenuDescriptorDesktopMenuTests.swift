import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

@MainActor
struct MenuDescriptorDesktopMenuTests {
    @Test
    func `meta section includes desktop menu without removing settings`() {
        let settings = Self.makeSettings(suite: "MenuDescriptorDesktopMenuTests-meta")
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        let store = UsageStore(
            fetcher: UsageFetcher(environment: [:]),
            browserDetection: BrowserDetection(cacheTTL: 0),
            settings: settings)

        let descriptor = MenuDescriptor.build(
            provider: .codex,
            store: store,
            settings: settings,
            account: AccountInfo(email: nil, plan: nil),
            updateReady: false)

        let actionTitles = descriptor.sections
            .flatMap(\.entries)
            .compactMap { entry -> (String, MenuDescriptor.MenuAction)? in
                guard case let .action(title, action) = entry else { return nil }
                return (title, action)
            }

        #expect(actionTitles.contains { $0.0 == "Open Desktop Menu" && $0.1 == .desktopMenu })
        #expect(actionTitles.contains { $0.1 == .settings })
        #expect(actionTitles.contains { $0.1 == .quit })
    }

    private static func makeSettings(suite: String) -> SettingsStore {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return SettingsStore(
            userDefaults: defaults,
            configStore: testConfigStore(suiteName: suite),
            zaiTokenStore: NoopZaiTokenStore(),
            syntheticTokenStore: NoopSyntheticTokenStore())
    }
}
