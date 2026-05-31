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
            List(selection: self.selectedTab) {
                ForEach(Self.visibleTabs(settings: self.settings), id: \.self) { tab in
                    Label(tab.title, systemImage: Self.systemImage(for: tab))
                        .tag(tab)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("CodexBar")
            .scrollContentBackground(.hidden)
            .background(DesktopMenuMaterialBackground())
        } detail: {
            self.detailView(for: self.activeTab)
                .id(self.settings.appLanguage)
                .navigationTitle(self.activeTab.title)
                .frame(minWidth: 560, idealWidth: self.activeTab.preferredWidth, maxWidth: .infinity)
                .frame(minHeight: 560, idealHeight: self.activeTab.preferredHeight, maxHeight: .infinity)
                .background(DesktopMenuMaterialBackground())
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 760, idealWidth: 980, minHeight: 600, idealHeight: 680)
        .background(DesktopMenuMaterialBackground())
        .onAppear {
            self.ensureValidSelection()
        }
        .onChange(of: self.settings.debugMenuEnabled) { _, _ in
            self.ensureValidSelection()
        }
    }

    static func visibleTabs(settings: SettingsStore) -> [PreferencesTab] {
        self.visibleTabs(debugMenuEnabled: settings.debugMenuEnabled)
    }

    static func visibleTabs(debugMenuEnabled: Bool) -> [PreferencesTab] {
        PreferencesTab.allCases.filter { tab in
            debugMenuEnabled || tab != .debug
        }
    }

    static func normalizedTab(_ tab: PreferencesTab, debugMenuEnabled: Bool) -> PreferencesTab {
        if tab == .debug, !debugMenuEnabled {
            return .general
        }
        return tab
    }

    private var selectedTab: Binding<PreferencesTab?> {
        Binding(
            get: { self.selection.tab },
            set: { newValue in
                if let newValue {
                    self.selection.tab = newValue
                }
            })
    }

    private var activeTab: PreferencesTab {
        Self.normalizedTab(self.selection.tab, debugMenuEnabled: self.settings.debugMenuEnabled)
    }

    private func ensureValidSelection() {
        let normalized = Self.normalizedTab(self.selection.tab, debugMenuEnabled: self.settings.debugMenuEnabled)
        if normalized != self.selection.tab {
            self.selection.tab = normalized
        }
    }

    private static func systemImage(for tab: PreferencesTab) -> String {
        switch tab {
        case .general: "gearshape"
        case .providers: "square.grid.2x2"
        case .display: "eye"
        case .advanced: "slider.horizontal.3"
        case .about: "info.circle"
        case .debug: "ladybug"
        }
    }

    @ViewBuilder
    private func detailView(for tab: PreferencesTab) -> some View {
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
}

private struct DesktopMenuMaterialBackground: View {
    var body: some View {
        Rectangle()
            .fill(.regularMaterial)
            .desktopMenuLiquidGlassCompatibility()
            .ignoresSafeArea()
    }
}

extension View {
    fileprivate func desktopMenuLiquidGlassCompatibility() -> some View {
        self.modifier(DesktopMenuLiquidGlassCompatibilityModifier())
    }
}

private struct DesktopMenuLiquidGlassCompatibilityModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            // Keep the macOS 26 branch isolated. The current public SDK used by CI may not
            // expose glassEffect yet, so the branch keeps the call site ready without
            // referencing unavailable symbols.
            content
        } else {
            content
        }
    }
}
